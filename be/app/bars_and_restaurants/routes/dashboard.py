from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, time, timezone, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import Float, Integer, and_, case, func, literal_column, or_, select

from app.database import database
from app.errors import APIError
from app.auth.rbac_middleware import require_bar_permission, BarAuthContext
from app.auth.rbac_models import Permission
from ..models.cart_models import OrderItem as OrderItemModel
from ..models.financial_models import OrderRefund as OrderRefundModel
from ..models.relational_models import (
    Bar as BarModel,
    MenuItem as MenuItemModel,
    Order as OrderModel,
)
from ..services.order_expiry import venue_timezone
from app.payment.order_payments import REFUND_COUNTED_STATUSES

dashboard_router = APIRouter(prefix="/bars", tags=["Dashboard"])


class TrendMetric(BaseModel):
    total: int = 0
    pending: int = 0
    completed: int = 0
    cancelled: int = 0
    trend_percent: float = 0.0


class RevenueMetric(BaseModel):
    total: float = 0.0
    currency: str = "BRL"
    trend_percent: float = 0.0


class AvgTicketMetric(BaseModel):
    value: float = 0.0
    currency: str = "BRL"
    trend_percent: float = 0.0


class TopItem(BaseModel):
    name: str
    quantity: int
    revenue: float


class DashboardStatsResponse(BaseModel):
    period: str
    orders: TrendMetric
    revenue: RevenueMetric
    average_ticket: AvgTicketMetric
    top_items: List[TopItem] = []


class ScheduleInfo(BaseModel):
    day: str
    open: Optional[str] = None
    close: Optional[str] = None
    is_closed: bool = False


class BarStatusResponse(BaseModel):
    bar_id: int
    is_open: bool
    current_schedule: Optional[ScheduleInfo] = None
    next_open: Optional[str] = None
    active_orders_count: int = 0
    active_tables_count: int = 0


class ToggleStatusRequest(BaseModel):
    is_open: bool
    reason: Optional[str] = None


class ToggleStatusResponse(BaseModel):
    bar_id: int
    is_open: bool
    toggled_at: datetime
    reason: Optional[str] = None


class OrderSummary(BaseModel):
    id: int
    order_number: Optional[str] = None
    status: str
    total: float
    currency: str = "BRL"
    items_count: int = 0
    table_number: Optional[str] = None
    customer_name: Optional[str] = None
    created_at: datetime
    estimated_ready_at: Optional[datetime] = None


class PaginationInfo(BaseModel):
    total: int
    page: int
    per_page: int
    has_more: bool


class BarOrdersResponse(BaseModel):
    orders: List[OrderSummary]
    pagination: PaginationInfo


# The dashboard periods are calendar periods in the venue's own timezone:
# "today" starts at the venue's local midnight, "week" on its local Monday and
# "month" on the 1st. Each one is compared with the same elapsed time from the
# start of the previous period (clamped so the two windows never overlap).

# Revenue only counts money the venue actually kept: the order's payment
# succeeded, the order was not cancelled, and its refunds are subtracted
# (order_refunds - a refunded order stays payment_status "paid"). Refunds
# still "pending" are subtracted too: they are recorded before the payment
# engine moves the money, so while an outcome is unknown revenue errs low,
# never high. Revenue, average ticket and top items all use this same set
# of orders so the numbers agree with each other.
PAID_PAYMENT_STATUS = "paid"
CANCELLED_ORDER_STATUS = "cancelled"
# Below half a cent left after refunds, an order counts as fully refunded
# (guards against float rounding in sums of partial refunds).
FULLY_REFUNDED_TOLERANCE = 0.005

# Orders are created with status "pending"; a NULL status is treated the same
# way (as the orders list endpoint does).
_order_status = func.coalesce(OrderModel.status, "pending")
_refunded_amount = (
    select(func.coalesce(func.sum(OrderRefundModel.amount), 0.0))
    .where(
        OrderRefundModel.order_id == OrderModel.id,
        OrderRefundModel.status.in_(REFUND_COUNTED_STATUSES),
    )
    .correlate(OrderModel)
    .scalar_subquery()
)
_net_amount = func.coalesce(OrderModel.total_price, 0.0) - _refunded_amount
_counts_as_revenue = and_(
    OrderModel.payment_status == PAID_PAYMENT_STATUS,
    _order_status != CANCELLED_ORDER_STATUS,
    # Not fully refunded (an order that was never refunded always counts).
    or_(_refunded_amount <= 0, _net_amount > FULLY_REFUNDED_TOLERANCE),
)


def _naive_utc(value: datetime) -> datetime:
    # Order timestamps are stored as naive UTC (datetime.utcnow()).
    return value.astimezone(timezone.utc).replace(tzinfo=None)


def get_period_range(
    period: str,
    tz: Optional[ZoneInfo] = None,
    now: Optional[datetime] = None,
) -> tuple[datetime, datetime, datetime, datetime]:
    """Return ``(current_start, current_end, prev_start, prev_end)`` as naive
    UTC datetimes, to be used as half-open ``[start, end)`` windows.

    ``tz`` is the venue timezone that defines where days/weeks/months begin
    (UTC if omitted); ``now`` defaults to the current time.
    """
    tz = tz or timezone.utc
    now_utc = now.astimezone(timezone.utc) if now is not None else datetime.now(timezone.utc)
    today = now_utc.astimezone(tz).date()

    if period == "week":
        start_day = today - timedelta(days=today.weekday())
        prev_start_day = start_day - timedelta(weeks=1)
    elif period == "month":
        start_day = today.replace(day=1)
        prev_start_day = (start_day - timedelta(days=1)).replace(day=1)
    else:  # "today"
        start_day = today
        prev_start_day = today - timedelta(days=1)

    current_start = datetime.combine(start_day, time.min, tzinfo=tz).astimezone(timezone.utc)
    prev_start = datetime.combine(prev_start_day, time.min, tzinfo=tz).astimezone(timezone.utc)
    current_end = now_utc
    # Same elapsed time into the previous period, but never past its end
    # (e.g. on March 31st the previous "month" window stops at March 1st).
    prev_end = min(prev_start + (current_end - current_start), current_start)

    return (
        _naive_utc(current_start),
        _naive_utc(current_end),
        _naive_utc(prev_start),
        _naive_utc(prev_end),
    )


def calc_trend(current: float, previous: float) -> float:
    if previous == 0:
        return 100.0 if current > 0 else 0.0
    return round(((current - previous) / previous) * 100, 1)


_ONE = literal_column("1", Integer)
_ZERO = literal_column("0", Integer)
_ZERO_MONEY = literal_column("0.0", Float)


def _in_window(bar_id: int, start: datetime, end: datetime):
    return and_(
        OrderModel.bar_id == bar_id,
        OrderModel.created_at >= start,
        OrderModel.created_at < end,
    )


def _count_where(condition):
    # Inline constants, not bind parameters: PostgreSQL types an untyped
    # parameter in CASE as text, and sum(text) does not exist.
    return func.coalesce(func.sum(case((condition, _ONE), else_=_ZERO)), _ZERO)


async def _period_order_stats(bar_id: int, start: datetime, end: datetime) -> dict:
    """Order counts and revenue (net of refunds) for the venue's orders
    created in ``[start, end)``."""
    row = await database.fetch_one(
        select(
            func.count(OrderModel.id).label("total"),
            _count_where(_order_status == "pending").label("pending"),
            _count_where(_order_status == "completed").label("completed"),
            _count_where(_order_status == CANCELLED_ORDER_STATUS).label("cancelled"),
            _count_where(_counts_as_revenue).label("paid_orders"),
            func.coalesce(
                func.sum(case((_counts_as_revenue, _net_amount), else_=_ZERO_MONEY)),
                0.0,
            ).label("revenue"),
        ).where(_in_window(bar_id, start, end))
    )
    paid_orders = int(row["paid_orders"] or 0) if row else 0
    revenue = float(row["revenue"] or 0) if row else 0.0
    return {
        "total": int(row["total"] or 0) if row else 0,
        "pending": int(row["pending"] or 0) if row else 0,
        "completed": int(row["completed"] or 0) if row else 0,
        "cancelled": int(row["cancelled"] or 0) if row else 0,
        "revenue": revenue,
        # Average over exactly the orders whose money is in ``revenue``.
        "average_ticket": revenue / paid_orders if paid_orders else 0.0,
    }


# Name snapshot taken on the order item at checkout ('' treated as missing).
_item_name_snapshot = func.nullif(OrderItemModel.menu_item_name, "")


def _top_item_label(name: Optional[str], menu_item_id: Optional[int]) -> str:
    if name:
        return name
    return f"Item #{menu_item_id}" if menu_item_id is not None else "Unknown item"


async def _top_items(bar_id: int, start: datetime, end: datetime, limit: int = 5) -> List[TopItem]:
    """Best-selling menu items among the orders that make up the period's
    revenue (paid, not cancelled, not fully refunded) created in
    ``[start, end)``.

    There is one entry per menu item, so an item renamed during the period is
    not split. It is labelled with its latest sold name: the name snapshot of
    its most recent counted sale (by order time). Renaming or deleting a menu
    item afterwards does not change it. Only when none of those sales carries
    a snapshot (legacy rows) does the label fall back to the menu item's
    current name, then to "Item #<id>". Order items without a menu item id
    (legacy) are grouped by their snapshot name instead.

    Quantities and revenue use the order items' own quantity and unit price.
    Refunds are amount-based and are not tied to specific items, so items of a
    partially refunded order are still listed at their sold price."""
    no_menu_item = OrderItemModel.menu_item_id.is_(None)
    latest_sold_name = func.first_value(_item_name_snapshot).over(
        partition_by=OrderItemModel.menu_item_id,
        # Latest sale first; rows without a snapshot last so one is used when any exists.
        order_by=(
            _item_name_snapshot.is_(None),
            OrderModel.created_at.desc(),
            OrderItemModel.id.desc(),
        ),
    )
    sales = (
        select(
            OrderItemModel.menu_item_id.label("menu_item_id"),
            # Extra grouping key only for legacy rows that have no menu item id.
            case((no_menu_item, _item_name_snapshot)).label("orphan_name"),
            case((no_menu_item, _item_name_snapshot), else_=latest_sold_name).label("sold_name"),
            OrderItemModel.quantity.label("quantity"),
            (OrderItemModel.quantity * OrderItemModel.unit_price).label("amount"),
        )
        .select_from(OrderItemModel)
        .join(OrderModel, OrderItemModel.order_id == OrderModel.id)
        .where(_in_window(bar_id, start, end), _counts_as_revenue)
        .subquery()
    )
    quantity = func.sum(sales.c.quantity)
    # Current menu name is only a fallback; the outer join never filters sales
    # of menu items that were deleted since.
    name = func.coalesce(func.max(sales.c.sold_name), func.max(MenuItemModel.name))
    rows = await database.fetch_all(
        select(
            sales.c.menu_item_id,
            name.label("name"),
            quantity.label("qty"),
            func.sum(sales.c.amount).label("rev"),
        )
        .select_from(sales)
        .outerjoin(MenuItemModel, sales.c.menu_item_id == MenuItemModel.id)
        .group_by(sales.c.menu_item_id, sales.c.orphan_name)
        .order_by(quantity.desc(), name, sales.c.menu_item_id)
        .limit(limit)
    )
    return [
        TopItem(
            name=_top_item_label(r["name"], r["menu_item_id"]),
            quantity=int(r["qty"] or 0),
            revenue=round(float(r["rev"] or 0), 2),
        )
        for r in rows
    ]


@dashboard_router.get("/{bar_id}/dashboard/stats", response_model=DashboardStatsResponse)
async def get_dashboard_stats(
    bar_id: int,
    period: str = Query("today", regex="^(today|week|month)$"),
    # Revenue, average ticket and sales rankings are business analytics, not
    # something every staff member at the venue should see.
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ANALYTICS_VIEW))
):
    bar = await database.fetch_one(
        select(BarModel.timezone).where(BarModel.id == bar_id)
    )
    if not bar:
        raise APIError.partner_not_found("Bar not found")

    current_start, current_end, prev_start, prev_end = get_period_range(
        period, venue_timezone(bar["timezone"])
    )

    current = await _period_order_stats(bar_id, current_start, current_end)
    previous = await _period_order_stats(bar_id, prev_start, prev_end)
    top_items = await _top_items(bar_id, current_start, current_end)

    return DashboardStatsResponse(
        period=period,
        orders=TrendMetric(
            total=current["total"],
            pending=current["pending"],
            completed=current["completed"],
            cancelled=current["cancelled"],
            trend_percent=calc_trend(current["total"], previous["total"])
        ),
        revenue=RevenueMetric(
            total=round(current["revenue"], 2),
            currency="BRL",
            trend_percent=calc_trend(current["revenue"], previous["revenue"])
        ),
        average_ticket=AvgTicketMetric(
            value=round(current["average_ticket"], 2),
            currency="BRL",
            trend_percent=calc_trend(current["average_ticket"], previous["average_ticket"])
        ),
        top_items=top_items
    )


@dashboard_router.get("/{bar_id}/orders", response_model=BarOrdersResponse)
async def get_bar_orders(
    bar_id: int,
    limit: int = Query(10, ge=1, le=50),
    page: int = Query(1, ge=1),
    status: str = Query("all", regex="^(all|pending|preparing|ready|completed|cancelled)$"),
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ORDER_VIEW))
):
    offset = (page - 1) * limit
    
    if status != "all":
        orders_query = """
            SELECT id, status, total_price, created_at, estimated_ready_time 
            FROM orders 
            WHERE bar_id = :bar_id AND status = :status
            ORDER BY created_at DESC NULLS LAST LIMIT :lim OFFSET :offs
        """
        count_query = "SELECT COUNT(*) FROM orders WHERE bar_id = :bar_id AND status = :status"
        query_params = {"bar_id": bar_id, "status": status, "lim": limit, "offs": offset}
        count_params = {"bar_id": bar_id, "status": status}
    else:
        orders_query = """
            SELECT id, status, total_price, created_at, estimated_ready_time 
            FROM orders 
            WHERE bar_id = :bar_id
            ORDER BY created_at DESC NULLS LAST LIMIT :lim OFFSET :offs
        """
        count_query = "SELECT COUNT(*) FROM orders WHERE bar_id = :bar_id"
        query_params = {"bar_id": bar_id, "lim": limit, "offs": offset}
        count_params = {"bar_id": bar_id}
    
    orders = await database.fetch_all(orders_query, query_params)
    total = await database.fetch_val(count_query, count_params)
    
    order_ids = [o["id"] for o in orders]
    items_count = {}
    if order_ids:
        placeholders = ", ".join([f":id{i}" for i in range(len(order_ids))])
        items_query = f"""
            SELECT order_id, SUM(quantity) as cnt 
            FROM order_items 
            WHERE order_id IN ({placeholders})
            GROUP BY order_id
        """
        items_params = {f"id{i}": oid for i, oid in enumerate(order_ids)}
        items_result = await database.fetch_all(items_query, items_params)
        items_count = {r["order_id"]: int(r["cnt"]) for r in items_result}
    
    order_summaries = []
    for o in orders:
        created = o["created_at"] or datetime.utcnow()
        order_summaries.append(OrderSummary(
            id=o["id"],
            order_number=f"#{o['id']}",
            status=o["status"] or "pending",
            total=o["total_price"] or 0,
            items_count=items_count.get(o["id"], 0),
            created_at=created,
            estimated_ready_at=o["estimated_ready_time"]
        ))
    
    return BarOrdersResponse(
        orders=order_summaries,
        pagination=PaginationInfo(
            total=total or 0,
            page=page,
            per_page=limit,
            has_more=(page * limit) < (total or 0)
        )
    )


@dashboard_router.get("/{bar_id}/status", response_model=BarStatusResponse)
async def get_bar_status(
    bar_id: int,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.BAR_VIEW))
):
    bar = await database.fetch_one(
        BarModel.__table__.select().where(BarModel.id == bar_id)
    )
    if not bar:
        raise APIError.partner_not_found("Bar not found")
    
    active_orders = await database.fetch_val(
        "SELECT COUNT(*) FROM orders WHERE bar_id = :bar_id AND status IN ('pending', 'confirmed', 'preparing', 'ready')",
        {"bar_id": bar_id}
    )
    
    operating_hours = bar["operating_hours"] or {}
    days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    today_idx = datetime.now(timezone.utc).weekday()
    today_name = days[today_idx]
    today_hours = operating_hours.get(today_name, {})
    
    current_schedule = None
    if today_hours:
        current_schedule = ScheduleInfo(
            day=today_name,
            open=today_hours.get("open"),
            close=today_hours.get("close"),
            is_closed=today_hours.get("is_closed", False)
        )
    
    is_open = not (today_hours.get("is_closed", False))
    if is_open and today_hours.get("open") and today_hours.get("close"):
        now_time = datetime.now(timezone.utc).strftime("%H:%M")
        open_time = today_hours.get("open", "00:00")
        close_time = today_hours.get("close", "23:59")
        if close_time < open_time:
            is_open = now_time >= open_time or now_time <= close_time
        else:
            is_open = open_time <= now_time <= close_time
    
    next_open = None
    if not is_open:
        for i in range(1, 8):
            next_idx = (today_idx + i) % 7
            next_day = days[next_idx]
            next_hours = operating_hours.get(next_day, {})
            if not next_hours.get("is_closed", False) and next_hours.get("open"):
                next_open = f"{next_day.capitalize()} {next_hours['open']}"
                break
    
    return BarStatusResponse(
        bar_id=bar_id,
        is_open=is_open,
        current_schedule=current_schedule,
        next_open=next_open,
        active_orders_count=active_orders or 0,
        active_tables_count=0
    )


@dashboard_router.post("/{bar_id}/status/toggle", response_model=ToggleStatusResponse)
async def toggle_bar_status(
    bar_id: int,
    request: ToggleStatusRequest,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.BAR_EDIT))
):
    bar = await database.fetch_one(
        BarModel.__table__.select().where(BarModel.id == bar_id)
    )
    if not bar:
        raise APIError.partner_not_found("Bar not found")
    
    days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    today_idx = datetime.now(timezone.utc).weekday()
    today_name = days[today_idx]
    
    operating_hours = dict(bar["operating_hours"] or {})
    if today_name not in operating_hours:
        operating_hours[today_name] = {}
    
    operating_hours[today_name]["is_closed"] = not request.is_open
    operating_hours[today_name]["manual_override"] = True
    operating_hours[today_name]["override_reason"] = request.reason
    
    await database.execute(
        BarModel.__table__.update()
        .where(BarModel.id == bar_id)
        .values(operating_hours=operating_hours, updated_at=datetime.now(timezone.utc))
    )
    
    return ToggleStatusResponse(
        bar_id=bar_id,
        is_open=request.is_open,
        toggled_at=datetime.now(timezone.utc),
        reason=request.reason
    )
