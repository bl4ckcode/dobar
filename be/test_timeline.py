import asyncio
from sqlalchemy import create_engine
import sys
import logging

logging.basicConfig(level=logging.DEBUG)

from app.bars_and_restaurants.schemas.orders import OrderWithHistory
from datetime import datetime

try:
    print("Testing OrderWithHistory schema validation")
    db_order = {
        "id": 1364,
        "user_id": 8,
        "bar_id": 17,
        "status": "pending",
        "total_price": 108.24,
        "created_at": datetime.now(),
        "updated_at": datetime.now(),
    }
    history = [
        {
            "id": 1,
            "order_id": 1364,
            "status": "pending",
            "timestamp": datetime.now()
        }
    ]
    obj = OrderWithHistory(**db_order, status_history=history)
    print("Success:", obj)
except Exception as e:
    print("Error:", e)
