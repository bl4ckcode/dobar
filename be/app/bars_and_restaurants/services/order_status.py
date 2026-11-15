"""
Order status transitions shared by every HTTP route that changes an order's
status:

    PUT  /orders/{order_id}/status                 (bar owners only)
    PUT  /bars/{bar_id}/orders/{order_id}/status   (requires order:process)
    POST /orders/{order_id}/cancel                 (the order's customer)
    WS   /ws/bar/{bar_id}/orders commands          (requires order:process)

Status flow: pending -> confirmed -> preparing -> ready -> completed
A pending order may also go straight to preparing (busy venues skip the
separate confirm step). pending / confirmed / preparing may also go to
cancelled; customers may only cancel while the order is pending or confirmed.

Routes are responsible for loading the order and authorizing the caller
*before* calling into this module so that transition errors (which echo the
current status) are never shown to callers without access.

Every write is a compare-and-set: the UPDATE is conditioned on the status that
was validated, so two concurrent requests can never both act on the same
previous status (e.g. an operator completing an order while the customer
cancels it, or a double "completed"). If another writer got there first, the
order is re-read and the request re-validated against the new status, giving
the same result as running the requests one after another.
"""

import logging
from datetime import datetime
from types import MappingProxyType
from typing import Awaitable, Callable, Mapping, Optional

from sqlalchemy import and_

from app.database import database
from app.errors import APIError
from app.order_queue import OrderQueue
from ..models.cart_models import OrderStatusHistory as OrderStatusHistoryModel
from ..models.relational_models import Order as OrderModel
from ..schemas.orders import OrderStatusUpdate

logger = logging.getLogger(__name__)


ORDER_STATUS_TRANSITIONS: Mapping[str, frozenset] = MappingProxyType({
    "pending": frozenset({"confirmed", "preparing", "cancelled"}),
    "confirmed": frozenset({"preparing", "cancelled"}),
    "preparing": frozenset({"ready", "cancelled"}),
    "ready": frozenset({"completed"}),
    "completed": frozenset(),
    "cancelled": frozenset(),
})

# Customers may cancel only before the bar starts preparing the order.
CUSTOMER_CANCELLABLE_STATUSES = frozenset({"pending", "confirmed"})
CUSTOMER_CANCEL_REASON = "Cancelled by customer"

# Bar dashboard commands (WS /ws/bar/{bar_id}/orders) -> target status.
# Whether the move is allowed is still decided by ORDER_STATUS_TRANSITIONS.
ORDER_ACTION_STATUSES: Mapping[str, str] = MappingProxyType({
    "confirm": "confirmed",
    "prepare": "preparing",
    "ready": "ready",
    "complete": "completed",
    "cancel": "cancelled",
})


def _validate_workflow() -> None:
    """Fail at import if the tables above stop agreeing with each other."""
    reachable = set().union(*ORDER_STATUS_TRANSITIONS.values())
    unknown = reachable - set(ORDER_STATUS_TRANSITIONS)
    if unknown:
        raise RuntimeError(f"Transitions lead to undefined statuses: {sorted(unknown)}")
    for action, target in ORDER_ACTION_STATUSES.items():
        if target not in reachable:
            raise RuntimeError(f"Action {action!r} targets unreachable status {target!r}")
    for status in CUSTOMER_CANCELLABLE_STATUSES:
        if "cancelled" not in ORDER_STATUS_TRANSITIONS.get(status, ()):
            raise RuntimeError(f"Customers may cancel {status!r} but the workflow does not allow it")


_validate_workflow()

# The state machine is acyclic, so an order can only change status a handful
# of times; this bound only matters if some other writer moves orders
# backwards while we keep losing the race.
_MAX_WRITE_ATTEMPTS = 5

_orders = OrderModel.__table__


def is_valid_transition(current_status: Optional[str], new_status: str) -> bool:
    return new_status in ORDER_STATUS_TRANSITIONS.get(current_status, frozenset())


def can_customer_cancel(current_status: Optional[str]) -> bool:
    return current_status in CUSTOMER_CANCELLABLE_STATUSES


def status_for_action(action) -> Optional[str]:
    """Target status for a bar dashboard action, or None if unknown."""
    return ORDER_ACTION_STATUSES.get(action) if isinstance(action, str) else None


async def fetch_order(order_id: int, bar_id: Optional[int] = None):
    """Load an order, optionally scoped to a bar. Raises 404 if not found."""
    condition = _orders.c.id == order_id
    if bar_id is not None:
        condition = and_(condition, _orders.c.bar_id == bar_id)
    order = await database.fetch_one(_orders.select().where(condition))
    if order is None:
        raise APIError.order_not_found()
    return order


class _StatusChanged(Exception):
    """The order's status changed between validation and write."""


async def _compare_and_set_status(
    order,
    *,
    new_status: str,
    actor_user_id: int,
    notes: Optional[str],
    extra_values: Mapping,
    check: Callable[[Optional[str]], None],
    publish: Callable[[Optional[str]], Awaitable],
    failure_message: str,
):
    """
    Shared write path. ``check(old_status)`` raises the caller's APIError if
    the change is not allowed from ``old_status``; it is re-run against fresh
    data whenever a concurrent writer changes the status first.
    ``publish(old_status)`` runs once the change is committed.
    """
    order_id = order["id"]
    bar_id = order["bar_id"]

    for _ in range(_MAX_WRITE_ATTEMPTS):
        old_status = order["status"]
        check(old_status)

        now = datetime.utcnow()
        values = {"status": new_status, "updated_at": now, **extra_values}
        if new_status == "completed":
            values["completed_at"] = now

        try:
            async with database.transaction():
                updated_order = await database.fetch_one(
                    _orders.update()
                    .where(and_(
                        _orders.c.id == order_id,
                        _orders.c.bar_id == bar_id,
                        _orders.c.status == old_status,
                    ))
                    .values(**values)
                    .returning(*_orders.c)
                )
                if updated_order is None:
                    # Raising here rolls back the (empty) transaction.
                    raise _StatusChanged()

                await database.execute(
                    OrderStatusHistoryModel.__table__.insert().values(
                        order_id=order_id,
                        status=new_status,
                        updated_by_user_id=actor_user_id,
                        notes=notes,
                    )
                )
        except _StatusChanged:
            order = await fetch_order(order_id, bar_id)
            continue
        except Exception:
            # Log the details but don't send raw DB errors to the client.
            logger.exception(
                "Failed to update status of order %s to %s", order_id, new_status
            )
            raise APIError.server_error(failure_message)

        # Committed. Publishing feeds order_worker.py -> connection_manager.py
        # (webhooks / live updates); it is best-effort and never undoes the update.
        try:
            await publish(old_status)
        except Exception:
            logger.exception("Failed to publish status change for order %s", order_id)

        return updated_order

    raise APIError.conflict(
        "Order status was changed concurrently; reload the order and retry"
    )


async def apply_status_transition(
    order,
    status_update: OrderStatusUpdate,
    actor_user_id: int,
):
    """
    Move an already-authorized ``order`` (a row from ``fetch_order``) to
    ``status_update.status`` on behalf of the bar. Records a history entry in
    the same transaction, publishes ``order.status_changed`` once committed,
    and returns the updated order row.

    Raises APIError 400 if the transition is not allowed from the order's
    current status, 404 if the order has disappeared, 409 if the write keeps
    losing to concurrent status changes, and 500 on database failure.
    """
    new_status = status_update.status

    def check(old_status):
        if not is_valid_transition(old_status, new_status):
            raise APIError.bad_request(
                f"Invalid status transition from {old_status} to {new_status}"
            )

    async def publish(old_status):
        await OrderQueue.publish_status_change(
            order_id=order["id"],
            bar_id=order["bar_id"],
            old_status=old_status,
            new_status=new_status,
        )

    extra = {}
    if status_update.estimated_ready_time:
        extra["estimated_ready_time"] = status_update.estimated_ready_time

    return await _compare_and_set_status(
        order,
        new_status=new_status,
        actor_user_id=actor_user_id,
        notes=status_update.notes,
        extra_values=extra,
        check=check,
        publish=publish,
        failure_message="Failed to update order status",
    )


async def cancel_order_as_customer(order, customer_user_id: int):
    """
    Cancel an already-authorized ``order`` on behalf of its customer. Only
    allowed while the order is pending or confirmed, and checked against the
    status at write time: if the bar advanced the order in the meantime (e.g.
    to preparing or completed) the cancellation is rejected instead of
    overwriting it. Publishes ``order.cancelled`` once committed.

    Raises APIError 400 (ORDER_CANCELLED) if the order can no longer be
    cancelled, 404 if it has disappeared, 409 on persistent contention and
    500 on database failure.
    """
    def check(old_status):
        if not can_customer_cancel(old_status):
            raise APIError.order_cancelled(
                f"Cannot cancel order with status: {old_status}"
            )

    async def publish(old_status):
        await OrderQueue.publish_cancellation(
            order_id=order["id"],
            bar_id=order["bar_id"],
            user_id=customer_user_id,
            reason=CUSTOMER_CANCEL_REASON,
        )

    return await _compare_and_set_status(
        order,
        new_status="cancelled",
        actor_user_id=customer_user_id,
        notes=CUSTOMER_CANCEL_REASON,
        extra_values={},
        check=check,
        publish=publish,
        failure_message="Failed to cancel order",
    )
