import asyncio
from datetime import datetime, timezone
from app.database import database
from app.bars_and_restaurants.models.relational_models import Order as OrderModel
from app.bars_and_restaurants.models.cart_models import OrderStatusHistory as OrderStatusHistoryModel
from app.bars_and_restaurants.schemas.orders import OrderWithHistory

async def main():
    await database.connect()
    
    print("=== Testing OrderWithHistory schema validation ===")
    
    # Test 1: Create order WITHOUT timestamps (reproduces the bug)
    print("\n1. Testing order with NULL timestamps (should fail):")
    try:
        query = OrderModel.__table__.insert().values(
            user_id=1, 
            bar_id=1, 
            status="pending", 
            total_price=10.0
            # Note: NO created_at/updated_at - this reproduces the bug
        )
        order_id = await database.execute(query)
        
        query = OrderModel.__table__.select().where(OrderModel.id == order_id)
        db_order = await database.fetch_one(query)
        
        print(f"DB order: {dict(db_order)}")
        
        # This should fail with validation error
        obj = OrderWithHistory(
            **dict(db_order),
            status_history=[]
        )
        print("❌ UNEXPECTED: OrderWithHistory created with NULL timestamps")
        
    except Exception as e:
        print(f"✅ EXPECTED: Validation failed - {str(e)}")
    
    # Test 2: Create order WITH timestamps (the fix)
    print("\n2. Testing order WITH timestamps (should succeed):")
    try:
        query = OrderModel.__table__.insert().values(
            user_id=2, 
            bar_id=1, 
            status="pending", 
            total_price=15.0,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        order_id = await database.execute(query)
        
        query = OrderModel.__table__.select().where(OrderModel.id == order_id)
        db_order = await database.fetch_one(query)
        
        print(f"DB order: {dict(db_order)}")
        
        # This should succeed
        obj = OrderWithHistory(
            **dict(db_order),
            status_history=[]
        )
        print("✅ SUCCESS: OrderWithHistory created with proper timestamps")
        print(f"   Order ID: {obj.id}")
        print(f"   Created: {obj.created_at}")
        print(f"   Updated: {obj.updated_at}")
        
    except Exception as e:
        print(f"❌ UNEXPECTED: Validation failed - {str(e)}")
        import traceback
        traceback.print_exc()

    await database.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
