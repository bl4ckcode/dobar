#!/usr/bin/env python3
import asyncio
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database import database
from app.bars_and_restaurants.models.relational_models import Order as OrderModel
from datetime import datetime, timezone

async def check_and_fix_order():
    """Check and fix order 1366 timestamps"""
    try:
        if not database.is_connected:
            await database.connect()
        
        # Check order 1366 specifically (the one from the logs)
        query = OrderModel.__table__.select().where(OrderModel.id == 1366)
        order = await database.fetch_one(query)
        
        if order:
            print(f'Order 1366 found:')
            print(f'  created_at: {order["created_at"]}')
            print(f'  updated_at: {order["updated_at"]}')
            print(f'  status: {order["status"]}')
            print(f'  payment_status: {order["payment_status"]}')
            
            # Fix the timestamps if they're None
            if order['created_at'] is None or order['updated_at'] is None:
                update_data = {}
                if order['created_at'] is None:
                    update_data['created_at'] = datetime.now(timezone.utc)
                if order['updated_at'] is None:
                    update_data['updated_at'] = datetime.now(timezone.utc)
                
                if update_data:
                    await database.execute(
                        OrderModel.__table__
                        .update()
                        .where(OrderModel.id == 1366)
                        .values(**update_data)
                    )
                    print(f'Fixed missing timestamps for order 1366')
                    
                    # Verify the fix
                    updated_order = await database.fetch_one(query)
                    print(f'After fix:')
                    print(f'  created_at: {updated_order["created_at"]}')
                    print(f'  updated_at: {updated_order["updated_at"]}')
            else:
                print('Timestamps are present - no fix needed')
        else:
            print('Order 1366 not found')
        
        await database.disconnect()
        print('Database connection closed')
        
    except Exception as e:
        print(f'Error: {e}')
        if database.is_connected:
            await database.disconnect()

if __name__ == "__main__":
    asyncio.run(check_and_fix_order())
