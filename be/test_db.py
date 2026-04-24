import asyncio
from app.database import database
from app.bars_and_restaurants.models.relational_models import Order as OrderModel
from app.bars_and_restaurants.models.cart_models import OrderStatusHistory as OrderStatusHistoryModel
from app.bars_and_restaurants.schemas.orders import OrderWithHistory

async def main():
    await database.connect()
    
    # create a dummy order
    query = OrderModel.__table__.insert().values(user_id=1, bar_id=1, status="pending", total_price=10.0)
    order_id = await database.execute(query)
    
    query = OrderModel.__table__.select().where(OrderModel.id == order_id)
    db_order = await database.fetch_one(query)
    
    history_query = OrderStatusHistoryModel.__table__.select().where(OrderStatusHistoryModel.order_id == order_id)
    status_history = await database.fetch_all(history_query)
    
    print("DB order:", dict(db_order))
    
    try:
        obj = OrderWithHistory(
            **dict(db_order),
            status_history=[dict(h) for h in status_history]
        )
        print("Success!", obj)
    except Exception as e:
        import traceback
        traceback.print_exc()

    await database.disconnect()

asyncio.run(main())
