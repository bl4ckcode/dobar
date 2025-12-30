from fastapi import WebSocket, APIRouter, WebSocketDisconnect, Query, status
from bson.json_util import dumps
from datetime import datetime, timezone
import json
from jose import jwt, JWTError
import os

from app.errors import APIError
from ..models.nosql_models import menus_collection, orders_collection
from app.database import database
from app.bars_and_restaurants.models.relational_models import Order

ws_router = APIRouter(tags=["WebSocket"])

# JWT settings
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-here")
ALGORITHM = "HS256"

class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def send_json_message(self, message: str):
        for connection in self.active_connections:
            await connection.send_text(message)

manager = ConnectionManager()

@ws_router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            await manager.broadcast(f"Message: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket)

@ws_router.websocket("/ws/orders")
async def websocket_order_updates(websocket: WebSocket):
    # When a client connects, register the connection
    await manager.connect(websocket)

    try:
        # Listen for changes in the MongoDB collection related to orders
        pipeline = []  # Customize the pipeline as needed
        async with orders_collection.watch(pipeline) as change_stream:
            async for change in change_stream:
                # Convert BSON to JSON and send to all connected clients
                change_json = dumps(change)
                await manager.send_json_message(change_json)
    except WebSocketDisconnect:
        # Handle the disconnection of the WebSocket client
        manager.disconnect(websocket)


@ws_router.websocket("/ws/menus")
async def websocket_menu_updates(websocket: WebSocket):
    # When a client connects, register the connection
    await manager.connect(websocket)

    try:
        # Listen for changes in the MongoDB collection related to menus
        pipeline = []  # Can customize the pipeline if needed
        async with menus_collection.watch(pipeline) as change_stream:
            async for change in change_stream:
                # Convert BSON to JSON and send it to all connected clients
                change_json = dumps(change)
                await manager.send_json_message(change_json)
    except WebSocketDisconnect:
        # Handle the disconnection of the WebSocket client
        manager.disconnect(websocket)


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


@ws_router.websocket("/ws/orders/{order_id}/status")
async def websocket_order_status_tracking(
    websocket: WebSocket,
    order_id: int,
    token: str = Query(..., description="JWT authentication token")
):
    """
    WebSocket endpoint for authenticated real-time order status tracking.
    
    Clients connect with: ws://host/ws/orders/{order_id}/status?token={jwt_token}
    
    Sends structured events:
    {
        "type": "status_update",
        "order_id": 123,
        "status": "preparing",
        "timestamp": "2025-10-14T12:34:56Z",
        "estimated_ready_time": "2025-10-14T13:04:56Z",
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
        
        # Accept the WebSocket connection
        await websocket.accept()
        
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
        
        # Listen for changes in MongoDB orders collection for this specific order
        pipeline = [
            {"$match": {"fullDocument.order_id": order_id}}
        ]
        
        try:
            async with orders_collection.watch(pipeline) as change_stream:
                async for change in change_stream:
                    operation_type = change.get("operationType")
                    
                    if operation_type in ["update", "replace"]:
                        # Fetch latest order data from PostgreSQL
                        updated_order = await database.fetch_one(
                            Order.__table__.select().where(Order.id == order_id)
                        )
                        
                        if updated_order:
                            # Send structured status update
                            status_message = {
                                "type": "status_update",
                                "order_id": order_id,
                                "status": updated_order["status"],
                                "timestamp": datetime.now(timezone.utc).isoformat(),
                                "estimated_ready_time": updated_order["estimated_ready_time"].isoformat() if updated_order.get("estimated_ready_time") else None,
                                "completed_at": updated_order["completed_at"].isoformat() if updated_order.get("completed_at") else None,
                                "message": get_status_message(updated_order["status"])
                            }
                            await websocket.send_json(status_message)
                    
                    elif operation_type == "delete":
                        # Order was deleted
                        delete_message = {
                            "type": "order_deleted",
                            "order_id": order_id,
                            "timestamp": datetime.now(timezone.utc).isoformat(),
                            "message": "Order has been deleted"
                        }
                        await websocket.send_json(delete_message)
                        break
        
        except WebSocketDisconnect:
            pass  # Client disconnected, cleanup handled below
            
    except HTTPException as e:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason=e.detail)
    except Exception as e:
        await websocket.close(code=status.WS_1011_INTERNAL_ERROR, reason=f"Internal error: {str(e)}")


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