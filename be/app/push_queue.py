import json
import asyncio
from typing import Optional, Callable, Dict, Any
from datetime import datetime
from app.redis_client import get_redis

class PushQueue:
    STREAM_NAME = "push:events"
    GROUP_NAME = "push-processors"
    MAX_LEN = 50000
    
    @staticmethod
    async def publish(event_type: str, campaign_id: int, data: dict) -> str:
        client = await get_redis()
        try:
            message = {
                "type": event_type,
                "campaign_id": str(campaign_id),
                "data": json.dumps(data, default=str),
                "timestamp": datetime.utcnow().isoformat(),
            }
            msg_id = await client.xadd(
                PushQueue.STREAM_NAME,
                message,
                maxlen=PushQueue.MAX_LEN,
                approximate=True
            )
            return msg_id
        except Exception as e:
            print(f"Queue publish error: {e}")
            return None
    
    @staticmethod
    async def publish_campaign_launch(campaign_id: int, bar_id: int, targeting: dict, creative: dict):
        return await PushQueue.publish("campaign.launched", campaign_id, {
            "bar_id": bar_id,
            "targeting": targeting,
            "creative": creative,
        })


class PushQueueConsumer:
    def __init__(self, consumer_name: str = "push-worker-1"):
        self.consumer_name = consumer_name
        self._running = False
        self._handlers: Dict[str, Callable] = {}
    
    def on(self, event_type: str, handler: Callable):
        self._handlers[event_type] = handler
    
    async def _ensure_group(self, client):
        try:
            await client.xgroup_create(
                PushQueue.STREAM_NAME,
                PushQueue.GROUP_NAME,
                id="0",
                mkstream=True
            )
        except Exception:
            pass
    
    async def start(self):
        self._running = True
        client = await get_redis()
        await self._ensure_group(client)
        
        while self._running:
            try:
                messages = await client.xreadgroup(
                    PushQueue.GROUP_NAME,
                    self.consumer_name,
                    {PushQueue.STREAM_NAME: ">"},
                    count=10,
                    block=5000
                )
                
                if not messages:
                    continue
                
                for stream, entries in messages:
                    for msg_id, fields in entries:
                        try:
                            event_type = fields.get("type")
                            handler = self._handlers.get(event_type)
                            if handler:
                                campaign_id = int(fields.get("campaign_id", 0))
                                data = json.loads(fields.get("data", "{}"))
                                await handler(campaign_id, data)
                            
                            await client.xack(stream, PushQueue.GROUP_NAME, msg_id)
                        except Exception as e:
                            print(f"Push task processing error for msg {msg_id}: {e}")
            except Exception as e:
                print(f"Push queue fetch error: {e}")
                await asyncio.sleep(1)
    
    def stop(self):
        self._running = False
