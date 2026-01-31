import asyncio
from app.order_queue import OrderQueueConsumer
from app.bars_and_restaurants.services.connection_manager import notify_new_order, notify_order_status_change

async def handle_order_created(order_id: int, data: dict):
    bar_id = data.get("bar_id")
    if bar_id:
        await notify_new_order(bar_id, {
            "id": order_id,
            "status": "pending",
            "total_price": data.get("total_price", 0),
            "items_count": data.get("items_count", 0),
        })

async def handle_status_change(order_id: int, data: dict):
    bar_id = data.get("bar_id")
    new_status = data.get("new_status")
    if bar_id and new_status:
        await notify_order_status_change(order_id, bar_id, new_status)

async def handle_order_cancelled(order_id: int, data: dict):
    bar_id = data.get("bar_id")
    if bar_id:
        await notify_order_status_change(order_id, bar_id, "cancelled")

async def start_order_worker(consumer_name: str = "worker-1"):
    consumer = OrderQueueConsumer(consumer_name)
    consumer.on("order.created", handle_order_created)
    consumer.on("order.status_changed", handle_status_change)
    consumer.on("order.cancelled", handle_order_cancelled)
    
    print(f"Starting order queue worker: {consumer_name}")
    await consumer.start()

if __name__ == "__main__":
    asyncio.run(start_order_worker())
