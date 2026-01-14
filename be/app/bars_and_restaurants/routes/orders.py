from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, status, Query
from sqlalchemy import and_, or_, desc
from typing import Optional, List
from datetime import datetime, timezone

from app.errors import APIError
from ..services.realtime_updates import stream_order_changes
from ..models.relational_models import Order as OrderModel
from ..models.cart_models import OrderItem as OrderItemModel, OrderStatusHistory as OrderStatusHistoryModel
from ..schemas.orders import (
    OrderCreate, 
    Order as OrderSchema, 
    OrderStatusUpdate, 
    OrderWithHistory,
    OrderListResponse,
    SyncRequest,
    SyncResponse
)
from app.database import database
from app.auth.middleware import get_current_active_user, get_optional_user
from app.auth.auth_models import User
from app.auth.admin import require_internal_or_admin

orders_router = APIRouter(prefix="/orders", tags=["Orders"])

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
    
    return db_order

@orders_router.get("/user/me", response_model=OrderListResponse)
async def get_my_orders(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    status: Optional[str] = None,
    current_user: User = Depends(get_current_active_user)
):
    """Get the current user's order history with pagination."""
    # Build query
    query = OrderModel.__table__.select().where(OrderModel.user_id == current_user["id"])
    
    # Filter by status if provided
    if status:
        query = query.where(OrderModel.status == status)
    
    # Order by created_at descending (newest first)
    query = query.order_by(desc(OrderModel.created_at))
    
    # Get total count
    count_query = query.with_only_columns(OrderModel.id).alias("count")
    total = await database.fetch_val(f"SELECT COUNT(*) FROM ({count_query.compile(compile_kwargs={'literal_binds': True})}) AS count")
    
    # Apply pagination
    offset = (page - 1) * page_size
    query = query.limit(page_size).offset(offset)
    
    # Fetch orders
    orders = await database.fetch_all(query)
    
    return OrderListResponse(
        orders=[OrderSchema(**dict(order)) for order in orders],
        total=total or 0,
        page=page,
        page_size=page_size
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
    if db_order["user_id"] != current_user["id"]:
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
    if db_order["user_id"] != current_user["id"]:
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
    if db_order["user_id"] != current_user["id"]:
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
            "updated_by_user_id": current_user["id"],
            "notes": "Cancelled by customer"
        }
        await database.execute(
            OrderStatusHistoryModel.__table__.insert().values(**history_data)
        )
        
        await transaction.commit()
        
        # Fetch updated order
        updated_order = await database.fetch_one(
            OrderModel.__table__.select().where(OrderModel.id == order_id)
        )
        
        # TODO: Trigger refund if payment was completed
        # TODO: Trigger WebSocket notification
        
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
            "updated_by_user_id": current_user["id"],
            "notes": status_update.notes
        }
        await database.execute(
            OrderStatusHistoryModel.__table__.insert().values(**history_data)
        )
        
        await transaction.commit()
        
        # Fetch updated order
        updated_order = await database.fetch_one(
            OrderModel.__table__.select().where(OrderModel.id == order_id)
        )
        
        # TODO: Trigger WebSocket notification
        
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
    result = await sync_operations(current_user["id"], [op.model_dump() for op in sync_request.operations])
    return SyncResponse(**result)