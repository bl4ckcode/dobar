from typing import List, Dict, Any
from app.database import database

class TargetingService:
    @staticmethod
    async def find_audience_for_campaign(bar_id: int, targeting: dict) -> List[Dict[str, Any]]:
        """
        Calculates the user audience for a campaign based on:
        - Past orders (customers)
        - Favorites
        - Explicit filters
        """
        # Targeting strategy: 
        # For MVP, we will target any user who has placed an order at this metric/bar 
        # AND has push_notifications_enabled.
        
        # In a fully scaled scenario (DOB-58 Geofencing), this would cross-reference 
        # a PostGIS or REDIS GEO index of live active user locations.
        
        from app.bars_and_restaurants.models.relational_models import Order
        from app.auth.rbac_models import UserProfile
        from sqlalchemy import select, distinct
        
        # 1. Get unique user IDs who have ordered from this bar
        query = select(distinct(Order.user_id)).where(Order.bar_id == bar_id)
        order_records = await database.fetch_all(query)
        user_ids = [record["user_id"] for record in order_records if record["user_id"]]
        
        if not user_ids:
            return []
            
        # 2. Get their FCM tokens if push is enabled
        profile_query = select(UserProfile.user_id, UserProfile.fcm_token).where(
            UserProfile.user_id.in_(user_ids),
            UserProfile.push_notifications_enabled == True,
            UserProfile.fcm_token.isnot(None)
        )
        
        profiles = await database.fetch_all(profile_query)
        
        return [dict(p) for p in profiles]
