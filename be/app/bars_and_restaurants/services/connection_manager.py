from fastapi import WebSocket, APIRouter, WebSocketDisconnect, Query, status, HTTPException
from bson.json_util import dumps
from datetime import datetime, timezone
import json
from jose import jwt, JWTError
import os
import asyncio
from typing import Dict, Set, Optional

from app.errors import APIError
from app.redis_client import get_redis
from ..models.nosql_models import menus_collection, orders_collection
from app.database import database
from app.bars_and_restaurants.models.relational_models import Order, Bar, BarOwner

ws_router = APIRouter(tags=["WebSocket"])

SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-here")
ALGORITHM = "HS256"

class RedisPubSub:
    def __init__(self):
        self._subscriber: Optional[asyncio.Task] = None
        self._running = False
    
    async def start(self, manager: "ConnectionManager"):
        if self._running:
            return
        self._running = True
        self._subscriber = asyncio.create_task(self._subscribe_loop(manager))
    
    async def stop(self):
        self._running = False
        if self._subscriber:
            self._subscriber.cancel()
            try:
                await self._subscriber
            except asyncio.CancelledError:
                pass
    
    async def _subscribe_loop(self, manager: "ConnectionManager"):
        try:
            redis = await get_redis()
            pubsub = redis.pubsub()
            await pubsub.psubscribe("ws:bar:*", "ws:order:*")
            
            async for message in pubsub.listen():
                if not self._running:
                    break
                if message["type"] == "pmessage":
                    channel = message["channel"]
                    data = json.loads(message["data"])
                    
                    if channel.startswith("ws:bar:"):
                        bar_id = int(channel.split(":")[-1])
                        await manager._local_notify_bar(bar_id, data)
                    elif channel.startswith("ws:order:"):
                        order_id = int(channel.split(":")[-1])
                        await manager._local_notify_order(order_id, data)
        except Exception as e:
            print(f"Redis pub/sub error: {e}")
            self._running = False
    
    async def publish_bar(self, bar_id: int, message: dict):
        try:
            redis = await get_redis()
            await redis.publish(f"ws:bar:{bar_id}", json.dumps(message, default=str))
        except Exception:
            pass
    
    async def publish_order(self, order_id: int, message: dict):
        try:
            redis = await get_redis()
            await redis.publish(f"ws:order:{order_id}", json.dumps(message, default=str))
        except Exception:
            pass

_pubsub = RedisPubSub()

class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []
        self.bar_connections: Dict[int, Set[WebSocket]] = {}
        self.order_connections: Dict[int, Set[WebSocket]] = {}
        self._pubsub_started = False

    async def _ensure_pubsub(self):
        if not self._pubsub_started:
            await _pubsub.start(self)
            self._pubsub_started = True

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def connect_to_bar(self, websocket: WebSocket, bar_id: int):
        await self._ensure_pubsub()
        await websocket.accept()
        if bar_id not in self.bar_connections:
            self.bar_connections[bar_id] = set()
        self.bar_connections[bar_id].add(websocket)

    def disconnect_from_bar(self, websocket: WebSocket, bar_id: int):
        if bar_id in self.bar_connections:
            self.bar_connections[bar_id].discard(websocket)
            if not self.bar_connections[bar_id]:
                del self.bar_connections[bar_id]

    async def connect_to_order(self, websocket: WebSocket, order_id: int):
        await self._ensure_pubsub()
        await websocket.accept()
        if order_id not in self.order_connections:
            self.order_connections[order_id] = set()
        self.order_connections[order_id].add(websocket)

    def disconnect_from_order(self, websocket: WebSocket, order_id: int):
        if order_id in self.order_connections:
            self.order_connections[order_id].discard(websocket)
            if not self.order_connections[order_id]:
                del self.order_connections[order_id]

    async def send_json_message(self, message: str):
        for connection in self.active_connections:
            await connection.send_text(message)

    async def notify_bar(self, bar_id: int, message: dict):
        await _pubsub.publish_bar(bar_id, message)
        await self._local_notify_bar(bar_id, message)

    async def _local_notify_bar(self, bar_id: int, message: dict):
        if bar_id in self.bar_connections:
            disconnected = []
            for websocket in self.bar_connections[bar_id]:
                try:
                    await websocket.send_json(message)
                except Exception:
                    disconnected.append(websocket)
            for ws in disconnected:
                self.bar_connections[bar_id].discard(ws)

    async def notify_order(self, order_id: int, message: dict):
        await _pubsub.publish_order(order_id, message)
        await self._local_notify_order(order_id, message)

    async def _local_notify_order(self, order_id: int, message: dict):
        if order_id in self.order_connections:
            disconnected = []
            for websocket in self.order_connections[order_id]:
                try:
                    await websocket.send_json(message)
                except Exception:
                    disconnected.append(websocket)
            for ws in disconnected:
                self.order_connections[order_id].discard(ws)

    def get_bar_connection_count(self, bar_id: int) -> int:
        return len(self.bar_connections.get(bar_id, set()))

    def get_order_connection_count(self, order_id: int) -> int:
        return len(self.order_connections.get(order_id, set()))


manager = ConnectionManager()


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

async def verify_token_and_get_user_id(token: str) -> int:
    """Verify JWT token and extract user_id."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: int = payload.get("user_id")
        if user_id is None:
            raise APIError.invalid_token()
        return user_id
    except JWTError:
        raise APIError.invalid_token()


async def verify_bar_owner(token: str, bar_id: int) -> dict:
    """
    Verify that the token belongs to an owner of the specified bar.
    Returns owner info if valid.
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        owner_id = payload.get("owner_id") or payload.get("user_id")
        
        if owner_id is None:
            return None
        
        # Check if this owner owns the bar
        query = Bar.__table__.select().where(Bar.id == bar_id)
        bar = await database.fetch_one(query)
        
        if not bar:
            return None
        
        if bar["owner_id"] != owner_id:
            return None
        
        return {"owner_id": owner_id, "bar_id": bar_id, "bar_name": bar["name"]}
    except JWTError:
        return None


def get_status_message(status: str) -> str:
    """Get user-friendly message for order status."""
    messages = {
        "pending": "Your order has been received and is awaiting confirmation",
        "confirmed": "Your order has been confirmed and will be prepared soon",
        "preparing": "Your order is being prepared",
        "ready": "Your order is ready for pickup/delivery",
        "completed": "Your order has been completed",
        "cancelled": "Your order has been cancelled"
    }
    return messages.get(status, f"Order status: {status}")


def get_bar_status_message(status: str) -> str:
    """Get bar-owner-friendly message for order status."""
    messages = {
        "pending": "New order received! Awaiting your confirmation",
        "confirmed": "Order confirmed, ready to prepare",
        "preparing": "Order is being prepared",
        "ready": "Order is ready for customer",
        "completed": "Order completed",
        "cancelled": "Order was cancelled"
    }
    return messages.get(status, f"Order status: {status}")


# =============================================================================
# WEBSOCKET ENDPOINTS
# =============================================================================

@ws_router.websocket("/ws/bar/{bar_id}/orders")
async def websocket_bar_owner_dashboard(
    websocket: WebSocket,
    bar_id: int,
    token: str = Query(..., description="JWT authentication token for bar owner")
):
    """
    🍺 BAR OWNER DASHBOARD - Real-time order notifications
    
    Connect: ws://host/ws/bar/{bar_id}/orders?token={jwt_token}
    
    Events sent to bar owner:
    
    1. Connection established:
    {
        "type": "connected",
        "bar_id": 12,
        "bar_name": "Bar do Zé",
        "timestamp": "2026-01-02T12:00:00Z",
        "message": "Connected to Bar do Zé order updates",
        "pending_orders_count": 3
    }
    
    2. New order received:
    {
        "type": "new_order",
        "order_id": 456,
        "bar_id": 12,
        "status": "pending",
        "total_price": 45.90,
        "items_count": 3,
        "timestamp": "2026-01-02T12:05:00Z",
        "message": "New order received! Awaiting your confirmation"
    }
    
    3. Order status changed:
    {
        "type": "order_update",
        "order_id": 456,
        "bar_id": 12,
        "status": "preparing",
        "timestamp": "2026-01-02T12:10:00Z",
        "message": "Order is being prepared"
    }
    
    Bar owner can send commands:
    - {"action": "confirm", "order_id": 456}
    - {"action": "ready", "order_id": 456}
    - {"action": "complete", "order_id": 456}
    - {"action": "cancel", "order_id": 456, "reason": "Out of stock"}
    """
    # Verify bar owner authentication
    owner_info = await verify_bar_owner(token, bar_id)
    
    if not owner_info:
        await websocket.close(
            code=status.WS_1008_POLICY_VIOLATION, 
            reason="Not authorized to access this bar's orders"
        )
        return
    
    # Connect to bar-specific channel
    await manager.connect_to_bar(websocket, bar_id)
    
    try:
        # Get count of pending orders
        pending_query = Order.__table__.select().where(
            (Order.bar_id == bar_id) & (Order.status == "pending")
        )
        pending_orders = await database.fetch_all(pending_query)
        
        # Send connection confirmation with pending orders count
        welcome_message = {
            "type": "connected",
            "bar_id": bar_id,
            "bar_name": owner_info["bar_name"],
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "message": f"Connected to {owner_info['bar_name']} order updates",
            "pending_orders_count": len(pending_orders),
            "active_connections": manager.get_bar_connection_count(bar_id)
        }
        await websocket.send_json(welcome_message)
        
        # Send list of current pending orders
        if pending_orders:
            for order in pending_orders:
                order_notification = {
                    "type": "pending_order",
                    "order_id": order["id"],
                    "bar_id": bar_id,
                    "status": order["status"],
                    "total_price": float(order["total_price"]) if order.get("total_price") else 0,
                    "created_at": order["created_at"].isoformat() if order.get("created_at") else None,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "message": "Pending order awaiting confirmation"
                }
                await websocket.send_json(order_notification)
        
        # Listen for incoming commands from bar owner AND watch for new orders
        while True:
            try:
                # Wait for commands from bar owner (with timeout for heartbeat)
                data = await asyncio.wait_for(
                    websocket.receive_text(), 
                    timeout=30.0  # 30 second timeout for heartbeat
                )
                
                # Parse command
                try:
                    command = json.loads(data)
                    action = command.get("action")
                    order_id = command.get("order_id")
                    
                    if action and order_id:
                        result = await handle_bar_owner_command(
                            bar_id=bar_id,
                            order_id=order_id,
                            action=action,
                            reason=command.get("reason"),
                            websocket=websocket
                        )
                        await websocket.send_json(result)
                    else:
                        await websocket.send_json({
                            "type": "error",
                            "message": "Invalid command. Required: action, order_id"
                        })
                        
                except json.JSONDecodeError:
                    await websocket.send_json({
                        "type": "error",
                        "message": "Invalid JSON format"
                    })
                    
            except asyncio.TimeoutError:
                # Send heartbeat to keep connection alive
                await websocket.send_json({
                    "type": "heartbeat",
                    "timestamp": datetime.now(timezone.utc).isoformat()
                })
                
    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect_from_bar(websocket, bar_id)


async def handle_bar_owner_command(
    bar_id: int, 
    order_id: int, 
    action: str, 
    reason: str = None,
    websocket: WebSocket = None
) -> dict:
    """
    Handle commands from bar owner to update order status.
    """
    # Verify order belongs to this bar
    query = Order.__table__.select().where(Order.id == order_id)
    order = await database.fetch_one(query)
    
    if not order:
        return {"type": "error", "message": f"Order {order_id} not found"}
    
    if order["bar_id"] != bar_id:
        return {"type": "error", "message": "Order does not belong to this bar"}
    
    # Map actions to statuses
    action_status_map = {
        "confirm": "confirmed",
        "prepare": "preparing",
        "ready": "ready",
        "complete": "completed",
        "cancel": "cancelled"
    }
    
    new_status = action_status_map.get(action)
    if not new_status:
        return {"type": "error", "message": f"Unknown action: {action}"}
    
    # Update order status in database
    update_data = {
        "status": new_status,
        "updated_at": datetime.now(timezone.utc)
    }
    
    if new_status == "completed":
        update_data["completed_at"] = datetime.now(timezone.utc)
    
    update_query = Order.__table__.update().where(Order.id == order_id).values(**update_data)
    await database.execute(update_query)
    
    # Prepare notification for user tracking this order
    user_notification = {
        "type": "status_update",
        "order_id": order_id,
        "status": new_status,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "message": get_status_message(new_status)
    }
    
    # Notify user watching this order
    await manager.notify_order(order_id, user_notification)
    
    # Notify other bar owner connections (if multiple devices)
    bar_notification = {
        "type": "order_update",
        "order_id": order_id,
        "bar_id": bar_id,
        "status": new_status,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "message": get_bar_status_message(new_status),
        "updated_by": "bar_owner"
    }
    await manager.notify_bar(bar_id, bar_notification)
    
    return {
        "type": "command_success",
        "action": action,
        "order_id": order_id,
        "new_status": new_status,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "message": f"Order {order_id} status updated to {new_status}"
    }


@ws_router.websocket("/ws/orders/{order_id}/status")
async def websocket_order_status_tracking(
    websocket: WebSocket,
    order_id: int,
    token: str = Query(..., description="JWT authentication token")
):
    """
    📱 USER ORDER TRACKING - Real-time order status updates
    
    Connect: ws://host/ws/orders/{order_id}/status?token={jwt_token}
    
    Events sent to user:
    {
        "type": "status_update",
        "order_id": 123,
        "status": "preparing",
        "timestamp": "2026-01-02T12:34:56Z",
        "estimated_ready_time": "2026-01-02T13:04:56Z",
        "message": "Your order is being prepared"
    }
    """
    try:
        # Verify authentication token
        user_id = await verify_token_and_get_user_id(token)
        
        # Verify order exists and belongs to user
        query = Order.__table__.select().where(Order.id == order_id)
        order = await database.fetch_one(query)
        
        if not order:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Order not found")
            return
        
        if order["user_id"] != user_id:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Not authorized to track this order")
            return
        
        # Connect to order-specific channel
        await manager.connect_to_order(websocket, order_id)
        
        # Send initial order status
        initial_message = {
            "type": "connected",
            "order_id": order_id,
            "status": order["status"],
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "estimated_ready_time": order["estimated_ready_time"].isoformat() if order.get("estimated_ready_time") else None,
            "message": f"Connected to order {order_id} status updates"
        }
        await websocket.send_json(initial_message)
        
        # Keep connection alive with heartbeat
        while True:
            try:
                # Wait for client ping or timeout
                await asyncio.wait_for(websocket.receive_text(), timeout=30.0)
            except asyncio.TimeoutError:
                # Send heartbeat
                await websocket.send_json({
                    "type": "heartbeat",
                    "timestamp": datetime.now(timezone.utc).isoformat()
                })
                
    except WebSocketDisconnect:
        pass
    except Exception as e:
        await websocket.close(code=status.WS_1011_INTERNAL_ERROR, reason=f"Internal error: {str(e)}")
    finally:
        manager.disconnect_from_order(websocket, order_id)


# =============================================================================
# HELPER FUNCTION TO NOTIFY FROM OTHER PARTS OF THE APP
# =============================================================================

async def notify_new_order(bar_id: int, order: dict):
    """
    Call this when a new order is created to notify the bar owner.
    
    Usage from orders.py:
        from app.bars_and_restaurants.services.connection_manager import notify_new_order
        await notify_new_order(bar_id, order_dict)
    """
    notification = {
        "type": "new_order",
        "order_id": order.get("id"),
        "bar_id": bar_id,
        "status": order.get("status", "pending"),
        "total_price": float(order.get("total_price", 0)),
        "items_count": order.get("items_count", 0),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "message": "🔔 New order received! Awaiting your confirmation"
    }
    await manager.notify_bar(bar_id, notification)


async def notify_order_status_change(order_id: int, bar_id: int, new_status: str):
    """
    Call this when order status changes to notify both user and bar owner.
    
    Usage:
        from app.bars_and_restaurants.services.connection_manager import notify_order_status_change
        await notify_order_status_change(order_id, bar_id, "preparing")
    """
    # Notify user
    user_msg = {
        "type": "status_update",
        "order_id": order_id,
        "status": new_status,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "message": get_status_message(new_status)
    }
    await manager.notify_order(order_id, user_msg)
    
    # Notify bar
    bar_msg = {
        "type": "order_update",
        "order_id": order_id,
        "bar_id": bar_id,
        "status": new_status,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "message": get_bar_status_message(new_status)
    }
    await manager.notify_bar(bar_id, bar_msg)