import asyncio
import json
from datetime import datetime, timezone, timedelta
from app.redis_client import get_redis
from app.push_queue import PushQueueConsumer
import traceback

class PushNotificationWorker:
    def __init__(self):
        self.consumer = PushQueueConsumer("push-worker")
        self.consumer.on("campaign.launched", self.handle_campaign_launch)
        self.MAX_PUSHES_PER_DAY = 3
    
    async def _check_fatigue(self, user_id: int) -> bool:
        """Check if user has exceeded their daily push limit."""
        client = await get_redis()
        now = datetime.now(timezone.utc)
        today_date = now.strftime("%Y-%m-%d")
        key = f"user:{user_id}:push_count:{today_date}"
        
        count = await client.get(key)
        if count and int(count) >= self.MAX_PUSHES_PER_DAY:
            return False
        
        # Increment and set expiry to 24h + some buffer just in case
        pipe = client.pipeline()
        pipe.incr(key)
        pipe.expire(key, 86400 * 2) 
        await pipe.execute()
        return True

    async def get_targeted_users(self, bar_id: int, targeting: dict) -> list[dict]:
        """Fetch users based on distance or other targeting criteria."""
        from app.database import database
        from app.advertising.services.targeting_service import TargetingService
        
        # Use our TargetingService to get users matching criteria
        users = await TargetingService.find_audience_for_campaign(bar_id, targeting)
        return users

    async def handle_campaign_launch(self, campaign_id: int, data: dict):
        print(f"[{datetime.now(timezone.utc)}] Processing Campaign Launch {campaign_id}")
        
        bar_id = data.get("bar_id")
        targeting = data.get("targeting", {})
        creative = data.get("creative", {})
        
        if not bar_id:
            return
            
        try:
            users_to_target = await self.get_targeted_users(bar_id, targeting)
            
            if not users_to_target:
                print(f"No users found for campaign {campaign_id}")
                return
                
            from app.bars_and_restaurants.services.push_notifications import push_service
            
            sent_count = 0
            for user in users_to_target:
                user_id = user["user_id"]
                fcm_token = user["fcm_token"]
                
                if not fcm_token:
                    continue
                    
                # Fatigue check
                can_send = await self._check_fatigue(user_id)
                if not can_send:
                    continue
                
                # Send push
                await push_service.send_notification(
                    token=fcm_token,
                    title=creative.get("tagline") or "New offer from Barz!",
                    body="Tap to see the latest exclusive offer for you.",
                    data={
                        "action": "campaign_push",
                        "bar_id": str(bar_id),
                        "campaign_id": str(campaign_id)
                    }
                )
                sent_count += 1
            
            print(f"Successfully processed campaign {campaign_id}. Sent to {sent_count} users.")
            
        except Exception as e:
            print(f"Error processing campaign {campaign_id}: {e}")
            traceback.print_exc()

    async def start(self):
        print("Starting Push Notification Worker...")
        await self.consumer.start()

async def main():
    worker = PushNotificationWorker()
    await worker.start()

if __name__ == "__main__":
    asyncio.run(main())
