from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timezone, timedelta
from sqlalchemy import func, and_, or_

from app.database import database
from app.errors import APIError
from app.auth.rbac_middleware import require_bar_permission, BarAuthContext
from app.auth.rbac_models import Permission
from ..models.relational_models import Bar as BarModel, Order as OrderModel

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


def get_period_range(period: str) -> tuple[datetime, datetime, datetime, datetime]:
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    
    if period == "today":
        current_start = today_start
        current_end = now
        prev_start = today_start - timedelta(days=1)
        prev_end = prev_start + (current_end - current_start)
    elif period == "week":
        current_start = today_start - timedelta(days=today_start.weekday())
        current_end = now
        prev_start = current_start - timedelta(weeks=1)
        prev_end = prev_start + (current_end - current_start)
    elif period == "month":
        current_start = today_start.replace(day=1)
        current_end = now
        prev_month = (current_start - timedelta(days=1)).replace(day=1)
        prev_start = prev_month
        prev_end = prev_start + (current_end - current_start)
    else:
        current_start = today_start
        current_end = now
        prev_start = today_start - timedelta(days=1)
        prev_end = prev_start + (current_end - current_start)
    
    return current_start, current_end, prev_start, prev_end


def calc_trend(current: float, previous: float) -> float:
    if previous == 0:
        return 100.0 if current > 0 else 0.0
    return round(((current - previous) / previous) * 100, 1)


@dashboard_router.get("/{bar_id}/dashboard/stats", response_model=DashboardStatsResponse)
async def get_dashboard_stats(
    bar_id: int,
    period: str = Query("today", regex="^(today|week|month)$"),
    auth: BarAuthContext = Depends(require_bar_permission(Permission.BAR_VIEW))
):
    current_start, current_end, prev_start, prev_end = get_period_range(period)
    
    current_orders = await database.fetch_all(
        OrderModel.__table__.select().where(
            and_(
                OrderModel.bar_id == bar_id,
                OrderModel.created_at >= current_start,
                OrderModel.created_at <= current_end
            )
        )
    )
    
    prev_orders = await database.fetch_all(
        OrderModel.__table__.select().where(
            and_(
                OrderModel.bar_id == bar_id,
                OrderModel.created_at >= prev_start,
                OrderModel.created_at <= prev_end
            )
        )
    )
    
    current_total = len(current_orders)
    current_pending = sum(1 for o in current_orders if o["status"] == "pending")
    current_completed = sum(1 for o in current_orders if o["status"] == "completed")
    current_cancelled = sum(1 for o in current_orders if o["status"] == "cancelled")
    current_revenue = sum(o["total_price"] or 0 for o in current_orders if o["status"] != "cancelled")
    
    prev_total = len(prev_orders)
    prev_revenue = sum(o["total_price"] or 0 for o in prev_orders if o["status"] != "cancelled")
    
    current_avg = current_revenue / current_completed if current_completed > 0 else 0
    prev_completed = sum(1 for o in prev_orders if o["status"] == "completed")
    prev_avg = prev_revenue / prev_completed if prev_completed > 0 else 0
    
    top_items_query = """
        SELECT mi.name, SUM(oi.quantity) as qty, SUM(oi.quantity * oi.unit_price) as rev
        FROM order_items oi
        JOIN menu_items mi ON oi.menu_item_id = mi.id
        JOIN orders o ON oi.order_id = o.id
        WHERE o.bar_id = :bar_id 
          AND o.created_at >= :start_date 
          AND o.status != 'cancelled'
        GROUP BY mi.name
        ORDER BY qty DESC
        LIMIT 5
    """
    top_items_result = await database.fetch_all(top_items_query, {"bar_id": bar_id, "start_date": current_start})
    top_items = [TopItem(name=r["name"], quantity=int(r["qty"]), revenue=float(r["rev"] or 0)) for r in top_items_result]
    
    return DashboardStatsResponse(
        period=period,
        orders=TrendMetric(
            total=current_total,
            pending=current_pending,
            completed=current_completed,
            cancelled=current_cancelled,
            trend_percent=calc_trend(current_total, prev_total)
        ),
        revenue=RevenueMetric(
            total=round(current_revenue, 2),
            currency="BRL",
            trend_percent=calc_trend(current_revenue, prev_revenue)
        ),
        average_ticket=AvgTicketMetric(
            value=round(current_avg, 2),
            currency="BRL",
            trend_percent=calc_trend(current_avg, prev_avg)
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
    
    base_query = OrderModel.__table__.select().where(OrderModel.bar_id == bar_id)
    count_query = "SELECT COUNT(*) FROM orders WHERE bar_id = :bar_id"
    params = {"bar_id": bar_id, "limit": limit, "offset": offset}
    
    if status != "all":
        base_query = base_query.where(OrderModel.status == status)
        count_query += " AND status = :status"
        params["status"] = status
    
    base_query = base_query.order_by(OrderModel.created_at.desc()).limit(limit).offset(offset)
    
    orders = await database.fetch_all(base_query)
    total = await database.fetch_val(count_query, params)
    
    order_ids = [o["id"] for o in orders]
    items_count = {}
    if order_ids:
        items_query = """
            SELECT order_id, SUM(quantity) as cnt 
            FROM order_items 
            WHERE order_id = ANY(:ids)
            GROUP BY order_id
        """
        items_result = await database.fetch_all(items_query, {"ids": order_ids})
        items_count = {r["order_id"]: int(r["cnt"]) for r in items_result}
    
    order_summaries = []
    for o in orders:
        order_summaries.append(OrderSummary(
            id=o["id"],
            order_number=f"#{o['id']}",
            status=o["status"] or "pending",
            total=o["total_price"] or 0,
            items_count=items_count.get(o["id"], 0),
            created_at=o["created_at"],
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
