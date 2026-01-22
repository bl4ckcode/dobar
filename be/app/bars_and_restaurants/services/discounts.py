from datetime import datetime, timedelta, timezone
from sqlalchemy import func, and_
from app.database import database
from ..models.relational_models import Order as OrderModel

# Progressive Discount Tiers
# Logic: Rewarding loyalty during a "session" (e.g. a night out)
# Reset period: 12 hours
DISCOUNT_TIERS = {
    1: 0.00,  # 1st order: 0%
    2: 0.05,  # 2nd order: 5%
    3: 0.10,  # 3rd order: 10%
    4: 0.15,  # 4th+ order: 15% (Capped)
}
SESSION_HOURS = 12

async def calculate_progressive_discount(user_id: int, bar_id: int) -> dict:
    """
    Calculate the progressive discount for a user at a specific bar.
    Based on the number of non-cancelled orders in the last 12 hours.
    """
    now = datetime.now(timezone.utc)
    session_start = now - timedelta(hours=SESSION_HOURS)
    
    
    # Count valid orders in the current session
    # Status must be valid (not cancelled)
    # Using raw SQL for compatibility with databases fetch_val
    query = """
        SELECT COUNT(*) 
        FROM orders 
        WHERE user_id = :user_id 
        AND bar_id = :bar_id 
        AND created_at >= :session_start 
        AND status != 'cancelled'
    """
    
    values = {
        "user_id": user_id,
        "bar_id": bar_id,
        "session_start": session_start
    }
    
    order_count = await database.fetch_val(query=query, values=values)
    order_count = order_count or 0
    
    # Current order is the (n+1)th order
    current_order_number = order_count + 1
    
    # Determine discount tier
    # If order_number > max tier, use max tier
    max_tier = max(DISCOUNT_TIERS.keys())
    effective_tier = min(current_order_number, max_tier)
    
    percentage = DISCOUNT_TIERS.get(effective_tier, 0.00)
    
    return {
        "percentage": percentage,
        "order_count_in_session": order_count,
        "current_order_number": current_order_number,
        "tier_applied": effective_tier,
        "reason": f"Progressive Discount: Order #{current_order_number} in session"
    }
