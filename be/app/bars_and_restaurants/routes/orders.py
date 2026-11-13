from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, status, Query, BackgroundTasks
from sqlalchemy import and_, or_, desc
from typing import Optional, List
from datetime import datetime, timezone

from app.errors import APIError
from app.order_queue import OrderQueue
from ..services.realtime_updates import stream_order_changes
from ..services.order_expiry import MAX_ORDER_LIFETIME, is_order_expired
from ..services.order_status import (
    fetch_order,
    apply_status_transition,
    cancel_order_as_customer,
)
from ..models.relational_models import Order as OrderModel, Bar as BarModel
from ..models.cart_models import OrderItem as OrderItemModel, OrderStatusHistory as OrderStatusHistoryModel
from ..schemas.orders import (
    OrderCreate, 
    Order as OrderSchema, 
    OrderStatusUpdate, 
    OrderWithHistory,
    OrderHistoryResponse,
    SyncRequest,
    SyncResponse
)
from app.database import database
from app.auth.middleware import get_current_active_user, get_optional_user
from app.auth.auth_models import User
from app.auth.admin import require_internal_or_admin
from app.auth.rbac_models import Permission, ConsumerSubscriptionTier
from app.auth.rbac_middleware import get_current_user as get_rbac_user, AuthUser, require_bar_permission, BarAuthContext
from app.redis_client import get_redis
from app.advertising.services.campaign_service import CampaignService

orders_router = APIRouter(prefix="/orders", tags=["Orders"])
bar_orders_router = APIRouter(prefix="/bars/{bar_id}/orders", tags=["Bar Orders"])

@orders_router.websocket("/ws/orders")
async def orders_websocket(websocket: WebSocket):
    await websocket.accept()
    try:
        async for change in stream_order_changes():
            await websocket.send_text(change)
    except WebSocketDisconnect:
        print("Client disconnected")

@orders_router.post("/", response_model=OrderSchema)
async def create_order(
    order: OrderCreate,
    background_tasks: BackgroundTasks,
    _internal: bool = Depends(require_internal_or_admin)
):
    order_data = order.model_dump()
    order_data["status"] = order_data.get("status", "pending")
    order_data["created_at"] = datetime.utcnow()
    order_data["updated_at"] = datetime.utcnow()
    
    query = OrderModel.__table__.insert().values(**order_data)
    order_id = await database.execute(query)
    
    query = OrderModel.__table__.select().where(OrderModel.id == order_id)
    db_order = await database.fetch_one(query)
    
    # Try to fetch RBAC user to check for PRO status
    is_priority = False
    try:
        query_user = (
            User.__table__.select().where(User.id == order.user_id)
        )
        user_row = await database.fetch_one(query_user)
        if user_row and user_row.get("subscription_tier") == ConsumerSubscriptionTier.PRO.value:
            is_priority = True
            order_data["is_priority"] = True

        # Attribution Conversion Check (DOB-57)
        redis_client = await get_redis()
        click_key = f"user:{order.user_id}:campaign_click:{order.bar_id}"
        campaign_id_str = await redis_client.get(click_key)
        if campaign_id_str:
            background_tasks.add_task(
                CampaignService.track_event,
                campaign_id=int(campaign_id_str),
                action="conversion",
                placement="order_checkout",
                user_id=order.user_id
            )
            await redis_client.delete(click_key)

    except Exception:
        pass

    await OrderQueue.publish_new_order(
        order_id=order_id,
        bar_id=order.bar_id,
        user_id=order.user_id,
        total=float(order.total_price) if order.total_price else 0,
        is_priority=is_priority
    )
    
    return db_order

@orders_router.get("/user/me", response_model=OrderHistoryResponse)
async def get_my_orders(
    cursor: Optional[str] = None,
    limit: int = Query(20, ge=1, le=100),
    status: Optional[str] = None,
    current_user: User = Depends(get_current_active_user)
):
    import base64

    query = OrderModel.__table__.select().where(OrderModel.user_id == current_user.id)

    if status:
        query = query.where(OrderModel.status == status)

    if cursor:
        try:
            decoded = base64.b64decode(cursor.encode()).decode()
            cursor_ts, cursor_id = decoded.split("|")
            from datetime import datetime
            cursor_dt = datetime.fromisoformat(cursor_ts)
            query = query.where(
                (OrderModel.created_at < cursor_dt) |
                ((OrderModel.created_at == cursor_dt) & (OrderModel.id < int(cursor_id)))
            )
        except Exception:
            pass

    query = query.order_by(desc(OrderModel.created_at), desc(OrderModel.id))
    query = query.limit(limit + 1)

    rows = await database.fetch_all(query)
    has_more = len(rows) > limit
    orders = rows[:limit]

    next_cursor = None
    if has_more and orders:
        last = orders[-1]
        raw = f"{last['created_at'].isoformat()}|{last['id']}"
        next_cursor = base64.b64encode(raw.encode()).decode()

    bar_ids = list({o["bar_id"] for o in orders})
    bar_names = {}
    if bar_ids:
        from app.bars_and_restaurants.models.relational_models import Bar
        bar_rows = await database.fetch_all(
            Bar.__table__.select().with_only_columns(Bar.id, Bar.name).where(Bar.id.in_(bar_ids))
        )
        bar_names = {b["id"]: b["name"] for b in bar_rows}

    return OrderHistoryResponse(
        orders=[OrderSchema(**{**dict(o), "bar_name": bar_names.get(o["bar_id"])}) for o in orders],
        next_cursor=next_cursor,
        has_more=has_more
    )


@orders_router.get("/{order_id}", response_model=OrderSchema)
async def get_order(
    order_id: int,
    current_user: User = Depends(get_current_active_user)
):
    """Get order details. Users can only view their own orders."""
    # Fetch the order by ID
    query = OrderModel.__table__.select().where(OrderModel.id == order_id)
    db_order = await database.fetch_one(query)
    
    if db_order is None:
        raise APIError.order_not_found()
    
    # Verify ownership
    if db_order["user_id"] != current_user.id:
        raise APIError.forbidden("You don't have permission to view this order")
    
    return db_order


@orders_router.get("/{order_id}/timeline", response_model=OrderWithHistory)
async def get_order_timeline(
    order_id: int,
    current_user: User = Depends(get_current_active_user)
):
    """Get order details with full status history and items."""
    # Fetch the order
    query = OrderModel.__table__.select().where(OrderModel.id == order_id)
    db_order = await database.fetch_one(query)
    
    if db_order is None:
        raise APIError.order_not_found()
    
    # Verify ownership
    if db_order["user_id"] != current_user.id:
        raise APIError.forbidden("You don't have permission to view this order")
    
    # Fetch order items
    items_query = (
        OrderItemModel.__table__
        .select()
        .where(OrderItemModel.order_id == order_id)
    )
    order_items = await database.fetch_all(items_query)
    
    # Fetch status history
    history_query = (
        OrderStatusHistoryModel.__table__
        .select()
        .where(OrderStatusHistoryModel.order_id == order_id)
        .order_by(OrderStatusHistoryModel.timestamp)
    )
    status_history = await database.fetch_all(history_query)
    
    order_dict = dict(db_order)
    from ..schemas.orders import OrderItem as OrderItemSchema
    items_serialized = [
        OrderItemSchema(
            id=item["id"],
            order_id=item["order_id"],
            menu_item_id=item["menu_item_id"],
            menu_item_name=item["menu_item_name"],
            quantity=item["quantity"],
            unit_price=item["unit_price"],
            total_price=item["total_price"],
            created_at=item["created_at"]
        )
        for item in order_items
    ]
    
    return OrderWithHistory(
        **order_dict,
        items=items_serialized,
        status_history=[dict(h) for h in status_history]
    )


@orders_router.post("/{order_id}/cancel", response_model=OrderSchema)
async def cancel_order(
    order_id: int,
    current_user: User = Depends(get_current_active_user)
):
    """Cancel an order. Only allowed if status is pending or confirmed."""
    db_order = await fetch_order(order_id)

    # Verify ownership
    if db_order["user_id"] != current_user.id:
        raise APIError.forbidden("You don't have permission to cancel this order")

    # The pending/confirmed check is enforced at write time, so a bar that
    # advances the order concurrently is never overwritten by the cancel.
    return await cancel_order_as_customer(db_order, current_user.id)


@orders_router.put("/{order_id}/status", response_model=OrderSchema)
async def update_order_status(
    order_id: int,
    status_update: OrderStatusUpdate,
    current_user: AuthUser = Depends(get_current_active_user)
):
    """
    Update order status. Only allowed for the owner of the order's bar.
    Status flow: pending -> confirmed -> preparing -> ready -> completed
    (pending may also go straight to preparing)
    """
    db_order = await fetch_order(order_id)

    # Authorize before validating the transition, so error messages never
    # reveal an order's status to someone who doesn't own its bar.
    if not current_user.is_bar_owner(db_order["bar_id"]):
        raise APIError.forbidden("Only the bar owner can update this order's status")

    return await apply_status_transition(db_order, status_update, current_user.id)


@orders_router.post("/sync", response_model=SyncResponse)
async def sync_offline_operations(
    sync_request: SyncRequest,
    current_user: User = Depends(get_current_active_user)
):
    from ..services.sync_service import sync_operations
    result = await sync_operations(current_user.id, [op.model_dump() for op in sync_request.operations])
    return SyncResponse(**result)


# =============================================================================
# CASHIER OPERATIONS (BAR-SCOPED ORDERS)
# =============================================================================

@bar_orders_router.get("/live", response_model=List[OrderSchema])
async def get_live_orders(
    bar_id: int,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ORDER_VIEW))
):
    """
    Fetch the active (live) orders for a specific bar: orders not yet
    'completed' or 'cancelled' whose operating day has not closed yet.

    An order expires at the close of the venue's operating day (venue local
    time) in which it was created. Overnight shifts are supported. Bars
    without configured hours expire orders 24h after creation. See
    services/order_expiry.py.
    """
    bar = await database.fetch_one(
        BarModel.__table__.select().where(BarModel.id == bar_id)
    )
    if bar is None:
        return []
    bar = dict(bar)

    now_utc = datetime.now(timezone.utc)
    # No order is live for more than MAX_ORDER_LIFETIME, so older rows can be
    # skipped in SQL. created_at is stored as naive UTC.
    oldest_live = (now_utc - MAX_ORDER_LIFETIME).replace(tzinfo=None)

    query = (
        OrderModel.__table__
        .select()
        .where(
            and_(
                OrderModel.bar_id == bar_id,
                OrderModel.status.in_(["pending", "confirmed", "preparing", "ready"]),
                OrderModel.created_at > oldest_live,
            )
        )
        .order_by(desc(OrderModel.is_priority), OrderModel.created_at.asc())
    )

    orders = await database.fetch_all(query)

    operating_hours = bar.get("operating_hours")
    tz_name = bar.get("timezone")

    result = []
    for order in orders:
        order_dict = dict(order)

        if is_order_expired(order_dict["created_at"], operating_hours, tz_name, now=now_utc):
            continue

        # Fetch items for this order
        items_query = (
            OrderItemModel.__table__
            .select()
            .where(OrderItemModel.order_id == order_dict["id"])
        )
        order_items = await database.fetch_all(items_query)

        from ..schemas.orders import OrderItem as OrderItemSchema
        items_serialized = [
            OrderItemSchema(
                id=item["id"],
                order_id=item["order_id"],
                menu_item_id=item["menu_item_id"],
                menu_item_name=item["menu_item_name"],
                quantity=item["quantity"],
                unit_price=item["unit_price"],
                total_price=item["total_price"],
                created_at=item["created_at"]
            )
            for item in order_items
        ]

        result.append(OrderSchema(**order_dict, items=items_serialized))

    return result


@bar_orders_router.put("/{order_id}/status", response_model=OrderSchema)
async def update_bar_order_status(
    bar_id: int,
    order_id: int,
    status_update: OrderStatusUpdate,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ORDER_PROCESS))
):
    """
    Update order status. Protected by RBAC for bar staff.
    Status flow: pending -> confirmed -> preparing -> ready -> completed
    (pending may also go straight to preparing)
    """
    db_order = await fetch_order(order_id, bar_id=bar_id)
    return await apply_status_transition(db_order, status_update, auth.user.id)
