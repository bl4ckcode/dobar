from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, status, Query, BackgroundTasks
from sqlalchemy import and_, or_, desc
from typing import Optional, List
from datetime import datetime, timezone

from app.errors import APIError
from app.order_queue import OrderQueue
from ..services.realtime_updates import stream_order_changes
from ..models.relational_models import Order as OrderModel
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
    from datetime import datetime, timezone
    order_data = order.model_dump()
    order_data["status"] = order_data.get("status", "pending")
    order_data["created_at"] = datetime.now(timezone.utc)
    order_data["updated_at"] = datetime.now(timezone.utc)
    
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

    return OrderHistoryResponse(
        orders=[OrderSchema(**dict(o)) for o in orders],
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
    """Get order details with full status history."""
    # Fetch the order
    query = OrderModel.__table__.select().where(OrderModel.id == order_id)
    db_order = await database.fetch_one(query)
    
    if db_order is None:
        raise APIError.order_not_found()
    
    # Verify ownership
    if db_order["user_id"] != current_user.id:
        raise APIError.forbidden("You don't have permission to view this order")
    
    history_query = (
        OrderStatusHistoryModel.__table__
        .select()
        .where(OrderStatusHistoryModel.order_id == order_id)
        .order_by(OrderStatusHistoryModel.timestamp)
    )
    status_history = await database.fetch_all(history_query)
    
    return OrderWithHistory(
        **dict(db_order),
        status_history=[dict(h) for h in status_history]
    )


@orders_router.post("/{order_id}/cancel", response_model=OrderSchema)
async def cancel_order(
    order_id: int,
    current_user: User = Depends(get_current_active_user)
):
    """Cancel an order. Only allowed if status is pending or confirmed."""
    # Fetch the order
    query = OrderModel.__table__.select().where(OrderModel.id == order_id)
    db_order = await database.fetch_one(query)
    
    if db_order is None:
        raise APIError.order_not_found()
    
    # Verify ownership
    if db_order["user_id"] != current_user.id:
        raise APIError.forbidden("You don't have permission to cancel this order")
    
    # Check if order can be cancelled
    if db_order["status"] not in ["pending", "confirmed"]:
        raise APIError.order_cancelled(f"Cannot cancel order with status: {db_order['status']}")
    
    # Start transaction
    transaction = await database.transaction()
    
    try:
        # Update order status
        update_query = (
            OrderModel.__table__
            .update()
            .where(OrderModel.id == order_id)
            .values(
                status="cancelled",
                updated_at=datetime.now(timezone.utc)
            )
        )
        await database.execute(update_query)
        
        history_data = {
            "order_id": order_id,
            "status": "cancelled",
            "updated_by_user_id": current_user.id,
            "notes": "Cancelled by customer"
        }
        await database.execute(
            OrderStatusHistoryModel.__table__.insert().values(**history_data)
        )
        
        await transaction.commit()
        
        updated_order = await database.fetch_one(
            OrderModel.__table__.select().where(OrderModel.id == order_id)
        )
        
        await OrderQueue.publish_cancellation(
            order_id=order_id,
            bar_id=db_order["bar_id"],
            user_id=current_user.id,
            reason="Cancelled by customer"
        )
        
        return updated_order
        
    except Exception as e:
        await transaction.rollback()
        raise APIError.server_error(f"Failed to cancel order: {str(e)}")


@orders_router.put("/{order_id}/status", response_model=OrderSchema)
async def update_order_status(
    order_id: int,
    status_update: OrderStatusUpdate,
    current_user: User = Depends(get_current_active_user)
):
    """
    Update order status. Only allowed for bar owners.
    Status flow: pending -> confirmed -> preparing -> ready -> completed
    """
    # Fetch the order
    query = OrderModel.__table__.select().where(OrderModel.id == order_id)
    db_order = await database.fetch_one(query)
    
    if db_order is None:
        raise APIError.order_not_found()
    
    # TODO: Verify user is bar owner of the bar
    # For now, we'll allow any authenticated user (should be restricted to bar owners)
    
    # Validate status transition
    valid_transitions = {
        "pending": ["confirmed", "cancelled"],
        "confirmed": ["preparing", "cancelled"],
        "preparing": ["ready", "cancelled"],
        "ready": ["completed"],
        "completed": [],
        "cancelled": []
    }
    
    if status_update.status not in valid_transitions.get(db_order["status"], []):
        raise APIError.bad_request(
            f"Invalid status transition from {db_order['status']} to {status_update.status}"
        )
    
    # Start transaction
    transaction = await database.transaction()
    
    try:
        update_data = {
            "status": status_update.status,
            "updated_at": datetime.now(timezone.utc)
        }
        
        if status_update.status == "completed":
            update_data["completed_at"] = datetime.now(timezone.utc)
        
        # Update estimated_ready_time if provided
        if status_update.estimated_ready_time:
            update_data["estimated_ready_time"] = status_update.estimated_ready_time
        
        # Update order status
        update_query = (
            OrderModel.__table__
            .update()
            .where(OrderModel.id == order_id)
            .values(**update_data)
        )
        await database.execute(update_query)
        
        history_data = {
            "order_id": order_id,
            "status": status_update.status,
            "updated_by_user_id": current_user.id,
            "notes": status_update.notes
        }
        await database.execute(
            OrderStatusHistoryModel.__table__.insert().values(**history_data)
        )
        
        await transaction.commit()
        
        updated_order = await database.fetch_one(
            OrderModel.__table__.select().where(OrderModel.id == order_id)
        )
        
        await OrderQueue.publish_status_change(
            order_id=order_id,
            bar_id=db_order["bar_id"],
            old_status=db_order["status"],
            new_status=status_update.status
        )
        
        return updated_order
        
    except Exception as e:
        await transaction.rollback()
        raise APIError.server_error(f"Failed to update order status: {str(e)}")


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
    Fetch all active (live) orders for a specific bar.
    Active orders are those not in 'completed' or 'cancelled' status.
    """
    query = (
        OrderModel.__table__
        .select()
        .where(
            and_(
                OrderModel.bar_id == bar_id,
                # active statuses typical of a pipeline
                OrderModel.status.in_(["pending", "confirmed", "preparing", "ready"])
            )
        )
        .order_by(desc(OrderModel.is_priority), OrderModel.created_at.asc())
    )
    
    orders = await database.fetch_all(query)
    
    return [OrderSchema(**dict(order)) for order in orders]


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
    """
    # Fetch the order
    query = OrderModel.__table__.select().where(
        and_(OrderModel.id == order_id, OrderModel.bar_id == bar_id)
    )
    db_order = await database.fetch_one(query)
    
    if db_order is None:
        raise APIError.order_not_found()
    
    # Validate status transition
    valid_transitions = {
        "pending": ["confirmed", "cancelled"],
        "confirmed": ["preparing", "cancelled"],
        "preparing": ["ready", "cancelled"],
        "ready": ["completed"],
        "completed": [],
        "cancelled": []
    }
    
    if status_update.status not in valid_transitions.get(db_order["status"], []):
        raise APIError.bad_request(
            f"Invalid status transition from {db_order['status']} to {status_update.status}"
        )
    
    # Start transaction
    transaction = await database.transaction()
    
    try:
        update_data = {
            "status": status_update.status,
            "updated_at": datetime.now(timezone.utc)
        }
        
        if status_update.status == "completed":
            update_data["completed_at"] = datetime.now(timezone.utc)
        
        if status_update.estimated_ready_time:
            update_data["estimated_ready_time"] = status_update.estimated_ready_time
        
        # Update order status
        update_query = (
            OrderModel.__table__
            .update()
            .where(OrderModel.id == order_id)
            .values(**update_data)
        )
        await database.execute(update_query)
        
        history_data = {
            "order_id": order_id,
            "status": status_update.status,
            "updated_by_user_id": auth.user.id,
            "notes": status_update.notes
        }
        await database.execute(
            OrderStatusHistoryModel.__table__.insert().values(**history_data)
        )
        
        await transaction.commit()
        
        updated_order = await database.fetch_one(
            OrderModel.__table__.select().where(OrderModel.id == order_id)
        )
        
        # This will trigger the webhooks via order_worker.py -> connection_manager.py
        await OrderQueue.publish_status_change(
            order_id=order_id,
            bar_id=bar_id,
            old_status=db_order["status"],
            new_status=status_update.status
        )
        
        return updated_order
        
    except Exception as e:
        await transaction.rollback()
        raise APIError.server_error(f"Failed to update order status: {str(e)}")