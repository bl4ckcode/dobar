from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from ..services.realtime_updates import stream_order_changes
from ..models.relational_models import Order as OrderModel
from ..schemas.orders import OrderCreate, Order as OrderSchema
from app.database import database  # Use the async database connection

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
async def create_order(order: OrderCreate):
    # Convert Pydantic model to dictionary
    order_data = order.model_dump()
    
    # Create a new order
    query = OrderModel.__table__.insert().values(**order_data)
    order_id = await database.execute(query)
    
    # Fetch the newly created order
    query = OrderModel.__table__.select().where(OrderModel.id == order_id)
    db_order = await database.fetch_one(query)
    
    return db_order

@orders_router.get("/{order_id}", response_model=OrderSchema)
async def read_order(order_id: int):
    # Fetch the order by ID
    query = OrderModel.__table__.select().where(OrderModel.id == order_id)
    db_order = await database.fetch_one(query)
    
    if db_order is None:
        raise HTTPException(status_code=404, detail="Order not found")
    
    return db_order