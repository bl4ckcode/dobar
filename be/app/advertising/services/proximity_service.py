import math
from datetime import datetime, timezone
from sqlalchemy import select, and_, func

from app.database import database
from app.redis_client import redis
from app.push_queue import PushQueue
from app.advertising.models import AdvertisingCampaign, CampaignStatus, CampaignType
from app.bars_and_restaurants.models.relational_models import Bar
from app.auth.rbac_models import UserProfile

class ProximityService:
    
    @staticmethod
    def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Calculate the great circle distance between two points 
        on the earth (specified in decimal degrees) in meters.
        """
        # Convert decimal degrees to radians 
        lon1, lat1, lon2, lat2 = map(math.radians, [lon1, lat1, lon2, lat2])
        
        # Haversine formula 
        dlon = lon2 - lon1 
        dlat = lat2 - lat1 
        a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
        c = 2 * math.asin(math.sqrt(a)) 
        # Radius of earth in kilometers is 6371. Multiply by 1000 for meters
        meters = 6371000 * c
        return meters

    @staticmethod
    async def process_geofence(user_id: int, latitude: float, longitude: float):
        """
        Receives user coordinates and checks against active PUSH campaigns
        containing proximity radius settings.
        """
        # Fetch the user's FCM token and ensure push is enabled
        profile_query = "SELECT fcm_token, push_notifications_enabled FROM user_profiles WHERE user_id = :uid"
        user = await database.fetch_one(profile_query, {"uid": user_id})
        
        if not user or not user["fcm_token"] or not user["push_notifications_enabled"]:
            return  # No push token or disabled pushes
            
        # 1. Fetch available bars with active PUSH campaigns
        # Optimization: In a real PostGIS environment, we would use ST_DWithin here.
        # Since we are using standard unmanaged PostgreSQL without geometric types,
        # we will fetch bars with campaigns and do math in-memory (or via simpler bounding box SQL)
        # We will bound using rough latitude/longitude box for optimization
        # 1 deg lat ~ 111km. 500m ~ 0.0045 deg
        delta = 0.005
        
        query = select(Bar.id, Bar.name, Bar.latitude, Bar.longitude, AdvertisingCampaign).join(
            AdvertisingCampaign, AdvertisingCampaign.bar_id == Bar.id
        ).where(
            and_(
                AdvertisingCampaign.status == CampaignStatus.ACTIVE,
                AdvertisingCampaign.campaign_type == CampaignType.PUSH_NOTIFICATION,
                Bar.latitude.between(latitude - delta, latitude + delta),
                Bar.longitude.between(longitude - delta, longitude + delta)
            )
        )
        
        potential_bars = await database.fetch_all(query)
        
        for record in potential_bars:
            bar_id = record["id"]
            bar_name = record["name"]
            bar_lat = record["latitude"]
            bar_lon = record["longitude"]
            
            # The campaign is stored as fields with prefixes depending on SQLAlchemy fetch,
            # but since we selected the whole AdvertisingCampaign model, let's extract it manually.
            campaign_id = record["id_1"]  # SQLAlchemy usually suffixes joined identically named columns
            campaign_name = record["name_1"]
            targeting = record["targeting"]
            
            if not targeting or "proximity" not in targeting or targeting["proximity"] != True:
                continue  # Not a geofenced campaign
                
            radius_km = targeting.get("radius_km", 0.5)
            radius_meters = radius_km * 1000
            
            if not bar_lat or not bar_lon:
                continue
                
            distance = ProximityService.haversine(latitude, longitude, bar_lat, bar_lon)
            
            if distance <= radius_meters:
                # User is inside Geofence!
                lock_key = f"user:{user_id}:geofence_lock:{campaign_id}"
                is_locked = await redis.get(lock_key)
                
                if not is_locked:
                    # Dispatch to native redis queue
                    await PushQueue.publish_campaign_launch(
                        campaign_id=campaign_id,
                        bar_name=bar_name,
                        target_audience=[{"id": user_id, "fcm_token": user["fcm_token"]}]
                    )
                    
                    # Lock for 24 hours so they don't get spammed if they hang around the bar bounds
                    await redis.set(lock_key, "1", ex=86400)
                    
                    # A single batch ping should usually only trigger 1 campaign at a time to be safe
                    # But we'll let it process multiple if they overlap precisely
