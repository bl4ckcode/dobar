from fastapi import WebSocket, APIRouter, WebSocketDisconnect
from bson.json_util import dumps
from ..models.nosql_models import menus_collection, orders_collection

ws_router = APIRouter(tags=["WebSocket"])

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