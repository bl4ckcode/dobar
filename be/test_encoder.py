from fastapi.encoders import jsonable_encoder
from app.bars_and_restaurants.schemas.orders import OrderWithHistory
from datetime import datetime

obj = OrderWithHistory(
    id=1, user_id=2, bar_id=3, status="pending", total_price=10.0,
    created_at=datetime.utcnow(), updated_at=datetime.utcnow(),
    status_history=[{"status": "pending", "timestamp": datetime.utcnow()}]
)
try:
    print(jsonable_encoder(obj))
except Exception as e:
    import traceback
    traceback.print_exc()
