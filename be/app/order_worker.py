import asyncio
from app.order_queue import OrderQueueConsumer
from app.bars_and_restaurants.services.connection_manager import notify_new_order, notify_order_status_change
from app.bars_and_restaurants.services.push_notifications import (
    notify_new_order_push,
    notify_order_status_push,
)


async def _get_order_user_token(order_id: int) -> tuple[str | None, int | None]:
    try:
        from app.database import database
        from app.bars_and_restaurants.models.relational_models import Order
        from app.auth.rbac_models import UserProfile

        order = await database.fetch_one(Order.__table__.select().where(Order.id == order_id))
        if not order:
            return None, None
        profile = await database.fetch_one(
            UserProfile.__table__.select().where(UserProfile.user_id == order["user_id"])
        )
        if not profile:
            return None, None
        if not profile["push_notifications_enabled"] or not profile["order_updates_enabled"]:
            return None, None
        return profile["fcm_token"], order["user_id"]
    except Exception:
        return None, None


async def _get_bar_owner_tokens(bar_id: int) -> list[str]:
    try:
        from app.database import database
        from app.auth.rbac_models import BarStaff, UserProfile

        staff_records = await database.fetch_all(
            BarStaff.__table__.select().where(
                (BarStaff.bar_id == bar_id)
                & (BarStaff.is_active == True)
                & (BarStaff.role.in_(["owner", "admin", "manager", "cashier"]))
            )
        )
        tokens = []
        for s in staff_records:
            profile = await database.fetch_one(
                UserProfile.__table__.select().where(UserProfile.user_id == s["user_id"])
            )
            if profile and profile["fcm_token"] and profile["push_notifications_enabled"]:
                tokens.append(profile["fcm_token"])
        return tokens
    except Exception:
        return []


async def handle_order_created(order_id: int, data: dict):
    bar_id = data.get("bar_id")
    if bar_id:
        await notify_new_order(bar_id, {
            "id": order_id,
            "status": "pending",
            "total_price": data.get("total_price", 0),
            "items_count": data.get("items_count", 0),
        })
        owner_tokens = await _get_bar_owner_tokens(bar_id)
        if owner_tokens:
            await notify_new_order_push(
                bar_id=bar_id,
                bar_name=data.get("bar_name", ""),
                order_id=order_id,
                total_price=float(data.get("total_price", 0)),
                owner_device_tokens=owner_tokens,
            )


async def handle_status_change(order_id: int, data: dict):
    bar_id = data.get("bar_id")
    new_status = data.get("new_status")
    if bar_id and new_status:
        await notify_order_status_change(order_id, bar_id, new_status)
        user_token, user_id = await _get_order_user_token(order_id)
        if user_token and user_id:
            await notify_order_status_push(
                user_device_token=user_token,
                user_id=user_id,
                order_id=order_id,
                status=new_status,
                bar_name=data.get("bar_name", ""),
            )


async def handle_order_cancelled(order_id: int, data: dict):
    bar_id = data.get("bar_id")
    if bar_id:
        await notify_order_status_change(order_id, bar_id, "cancelled")
        user_token, user_id = await _get_order_user_token(order_id)
        if user_token and user_id:
            await notify_order_status_push(
                user_device_token=user_token,
                user_id=user_id,
                order_id=order_id,
                status="cancelled",
                bar_name=data.get("bar_name", ""),
            )


async def start_order_worker(consumer_name: str = "worker-1"):
    consumer = OrderQueueConsumer(consumer_name)
    consumer.on("order.created", handle_order_created)
    consumer.on("order.status_changed", handle_status_change)
    consumer.on("order.cancelled", handle_order_cancelled)

    print(f"Starting order queue worker: {consumer_name}")
    await consumer.start()


if __name__ == "__main__":
    asyncio.run(start_order_worker())
