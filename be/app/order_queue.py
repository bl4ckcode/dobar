import json
import asyncio
from typing import Optional, Callable, Dict, Any
from datetime import datetime
from app.redis_client import get_redis

class OrderQueue:
    STREAM_NAME = "orders:events"
    GROUP_NAME = "order-processors"
    MAX_LEN = 10000
    
    @staticmethod
    async def publish(event_type: str, order_id: int, data: dict) -> str:
        client = await get_redis()
        try:
            message = {
                "type": event_type,
                "order_id": str(order_id),
                "data": json.dumps(data, default=str),
                "timestamp": datetime.utcnow().isoformat(),
            }
            msg_id = await client.xadd(
                OrderQueue.STREAM_NAME,
                message,
                maxlen=OrderQueue.MAX_LEN,
                approximate=True
            )
            return msg_id
        except Exception as e:
            print(f"Queue publish error: {e}")
            return None
    
    @staticmethod
    async def publish_new_order(order_id: int, bar_id: int, user_id: int, total: float):
        return await OrderQueue.publish("order.created", order_id, {
            "bar_id": bar_id,
            "user_id": user_id,
            "total_price": total,
        })
    
    @staticmethod
    async def publish_status_change(order_id: int, bar_id: int, old_status: str, new_status: str):
        return await OrderQueue.publish("order.status_changed", order_id, {
            "bar_id": bar_id,
            "old_status": old_status,
            "new_status": new_status,
        })
    
    @staticmethod
    async def publish_cancellation(order_id: int, bar_id: int, user_id: int, reason: str = None):
        return await OrderQueue.publish("order.cancelled", order_id, {
            "bar_id": bar_id,
            "user_id": user_id,
            "reason": reason,
        })


class OrderQueueConsumer:
    def __init__(self, consumer_name: str = "worker-1"):
        self.consumer_name = consumer_name
        self._running = False
        self._handlers: Dict[str, Callable] = {}
    
    def on(self, event_type: str, handler: Callable):
        self._handlers[event_type] = handler
    
    async def _ensure_group(self, client):
        try:
            await client.xgroup_create(
                OrderQueue.STREAM_NAME,
                OrderQueue.GROUP_NAME,
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
                    OrderQueue.GROUP_NAME,
                    self.consumer_name,
                    {OrderQueue.STREAM_NAME: ">"},
                    count=10,
                    block=5000
                )
                
                if not messages:
                    continue
                
                for stream, entries in messages:
                    for msg_id, fields in entries:
                        try:
                            event_type = fields.get("type")
                            order_id = int(fields.get("order_id", 0))
                            data = json.loads(fields.get("data", "{}"))
                            
                            handler = self._handlers.get(event_type)
                            if handler:
                                await handler(order_id, data)
                            
                            await client.xack(OrderQueue.STREAM_NAME, OrderQueue.GROUP_NAME, msg_id)
                        except Exception as e:
                            print(f"Queue consumer error: {e}")
                            
            except asyncio.CancelledError:
                break
            except Exception as e:
                print(f"Queue loop error: {e}")
                await asyncio.sleep(1)
    
    async def stop(self):
        self._running = False
