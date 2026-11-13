"""
Order status updates through both HTTP routes:

    PUT  /orders/{order_id}/status                 (bar owner only)
    PUT  /bars/{bar_id}/orders/{order_id}/status   (order:process at the bar)
    POST /orders/{order_id}/cancel                 (the order's customer)
    WS   /ws/bar/{bar_id}/orders commands          (order:process at the bar)

Runs against a throwaway SQLite database with real JWTs and the real RBAC
dependencies; only the Redis publisher is stubbed.
"""

import os

os.environ.setdefault("DATABASE_URL", "sqlite:///./_unused_test.db")
os.environ.setdefault("MONGO_URI", "mongodb://localhost:1")
os.environ.setdefault("MONGO_DB", "test")

import json
import shutil
from datetime import datetime, timedelta

import httpx
import pytest
import sqlalchemy as sa
from databases import Database
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from jose import jwt

from app.auth import rbac_middleware
from app.auth.auth_models import User
from app.auth.rbac_models import BarStaff, UserProfile
from app.bars_and_restaurants.models.cart_models import OrderStatusHistory
from app.bars_and_restaurants.models.relational_models import Bar, BarOwner, Order
from app.bars_and_restaurants.routes import orders as orders_routes
from app.bars_and_restaurants.schemas.orders import OrderStatusUpdate
from app.bars_and_restaurants.services import connection_manager as ws
from app.bars_and_restaurants.services import order_status
from app.bars_and_restaurants.services import sync_service
from app.errors import APIError
from app.order_queue import OrderQueue

pytestmark = pytest.mark.orders

TABLES = [t.__table__ for t in (User, UserProfile, BarOwner, Bar, BarStaff, Order, OrderStatusHistory)]

BAR_A, BAR_B = 1, 2
OWNER_A, OWNER_B, CASHIER_A, MANAGER_A, ADMIN_A, STAFF_A, CUSTOMER, INACTIVE_OWNER_A, OTHER_CUSTOMER = range(1, 10)

RESPONSE_KEYS = {
    "id", "user_id", "bar_id", "bar_name", "status", "total_price", "subtotal", "tax",
    "tip", "delivery_fee", "discount", "payment_id", "payment_status", "payment_method",
    "order_type", "created_at", "updated_at", "estimated_ready_time", "completed_at", "items",
}


# ----------------------------------------------------------------------------
# fixtures
# ----------------------------------------------------------------------------

@pytest.fixture(scope="module")
def schema_template(tmp_path_factory):
    path = tmp_path_factory.mktemp("schema") / "template.db"
    engine = sa.create_engine(f"sqlite:///{path}")
    User.metadata.create_all(engine, tables=TABLES)
    engine.dispose()
    return path


@pytest.fixture
async def db(tmp_path, monkeypatch, schema_template):
    path = tmp_path / "orders.db"
    shutil.copy(schema_template, path)

    database = Database(f"sqlite:///{path}")
    await database.connect()
    for module in (order_status, orders_routes, rbac_middleware, ws, sync_service):
        monkeypatch.setattr(module, "database", database)

    await database.execute_many(
        User.__table__.insert(),
        [
            {"id": uid, "email": f"u{uid}@example.com", "phone_number": f"+55{uid:09d}",
             "is_active": True, "email_verified": True, "phone_verified": True,
             "subscription_tier": "regular", "country_code": "BR"}
            for uid in range(1, 10)
        ],
    )
    await database.execute_many(
        BarOwner.__table__.insert(),
        [{"id": OWNER_A, "email": "oa@example.com"}, {"id": OWNER_B, "email": "ob@example.com"}],
    )
    await database.execute_many(
        Bar.__table__.insert(),
        [{"id": BAR_A, "name": "A", "owner_id": OWNER_A}, {"id": BAR_B, "name": "B", "owner_id": OWNER_B}],
    )
    staff = [
        (OWNER_A, BAR_A, "owner", True),
        (OWNER_B, BAR_B, "owner", True),
        (CASHIER_A, BAR_A, "cashier", True),
        (MANAGER_A, BAR_A, "manager", True),
        (ADMIN_A, BAR_A, "admin", True),
        (STAFF_A, BAR_A, "staff", True),
        # Ownership revoked (e.g. removed from the bar): must not count.
        (INACTIVE_OWNER_A, BAR_A, "owner", False),
    ]
    await database.execute_many(
        BarStaff.__table__.insert(),
        [{"user_id": u, "bar_id": b, "role": r, "is_active": a} for u, b, r, a in staff],
    )
    try:
        yield database
    finally:
        await database.disconnect()


@pytest.fixture
def published(monkeypatch):
    events = []

    async def fake_publish(order_id, bar_id, old_status, new_status):
        events.append({"order_id": order_id, "bar_id": bar_id,
                       "old_status": old_status, "new_status": new_status})
        return "1-0"

    monkeypatch.setattr(OrderQueue, "publish_status_change", staticmethod(fake_publish))
    return events


@pytest.fixture
def cancellations(monkeypatch):
    events = []

    async def fake_publish(order_id, bar_id, user_id, reason=None):
        events.append({"order_id": order_id, "bar_id": bar_id,
                       "user_id": user_id, "reason": reason})
        return "1-0"

    monkeypatch.setattr(OrderQueue, "publish_cancellation", staticmethod(fake_publish))
    return events


@pytest.fixture
async def client(db, published, cancellations):
    app = FastAPI()

    @app.exception_handler(APIError)
    async def _api_error(request: Request, exc: APIError):  # mirrors app.main
        return JSONResponse(status_code=exc.status_code,
                            content=exc.to_response().model_dump(exclude_none=True))

    app.include_router(orders_routes.orders_router)
    app.include_router(orders_routes.bar_orders_router)
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


def auth(user_id: int) -> dict:
    token = jwt.encode({"sub": str(user_id)}, rbac_middleware.SECRET_KEY,
                       algorithm=rbac_middleware.ALGORITHM)
    return {"Authorization": f"Bearer {token}"}


async def make_order(db, bar_id=BAR_A, status="pending", user_id=CUSTOMER, **extra) -> int:
    now = datetime.utcnow()
    return await db.execute(Order.__table__.insert().values(
        user_id=user_id, bar_id=bar_id, status=status, total_price=42.0,
        subtotal=42.0, order_type="pickup", payment_method="pix",
        created_at=now, updated_at=now, **extra,
    ))


async def order_row(db, order_id):
    return await db.fetch_one(Order.__table__.select().where(Order.__table__.c.id == order_id))


async def history(db, order_id):
    rows = await db.fetch_all(
        OrderStatusHistory.__table__.select()
        .where(OrderStatusHistory.__table__.c.order_id == order_id)
        .order_by(OrderStatusHistory.__table__.c.id)
    )
    return [dict(r) for r in rows]


def general(order_id):
    return f"/orders/{order_id}/status"


def venue(bar_id, order_id):
    return f"/bars/{bar_id}/orders/{order_id}/status"


# ----------------------------------------------------------------------------
# general route: authorization
# ----------------------------------------------------------------------------

async def test_general_route_allows_owner_of_the_orders_bar(client, db, published):
    oid = await make_order(db)

    r = await client.put(general(oid), json={"status": "confirmed", "notes": "on it"},
                         headers=auth(OWNER_A))

    assert r.status_code == 200, r.text
    body = r.json()
    assert set(body) == RESPONSE_KEYS
    assert body["id"] == oid and body["status"] == "confirmed" and body["bar_id"] == BAR_A
    assert (await order_row(db, oid))["status"] == "confirmed"
    [h] = await history(db, oid)
    assert (h["status"], h["updated_by_user_id"], h["notes"]) == ("confirmed", OWNER_A, "on it")
    assert published == [{"order_id": oid, "bar_id": BAR_A,
                          "old_status": "pending", "new_status": "confirmed"}]


@pytest.mark.parametrize("user_id", [
    pytest.param(CUSTOMER, id="order-customer-no-bar-role"),
    pytest.param(OWNER_B, id="owner-of-other-bar"),
    pytest.param(ADMIN_A, id="admin"),
    pytest.param(MANAGER_A, id="manager"),
    pytest.param(CASHIER_A, id="cashier"),
    pytest.param(STAFF_A, id="staff"),
    pytest.param(INACTIVE_OWNER_A, id="deactivated-owner"),
])
async def test_general_route_rejects_non_owners_without_side_effects(client, db, published, user_id):
    oid = await make_order(db)
    before = dict(await order_row(db, oid))

    r = await client.put(general(oid), json={"status": "cancelled"}, headers=auth(user_id))

    assert r.status_code == 403, r.text
    assert r.json()["error_code"] == "FORBIDDEN"
    assert dict(await order_row(db, oid)) == before
    assert await history(db, oid) == []
    assert published == []


async def test_general_route_checks_owner_before_transition(client, db):
    # A non-owner must get 403, not a 400 that would reveal the order's status.
    oid = await make_order(db, status="completed")

    r = await client.put(general(oid), json={"status": "confirmed"}, headers=auth(OWNER_B))

    assert r.status_code == 403
    assert "completed" not in r.text


async def test_general_route_requires_authentication(client, db):
    oid = await make_order(db)
    r = await client.put(general(oid), json={"status": "confirmed"})
    assert r.status_code == 401
    assert (await order_row(db, oid))["status"] == "pending"


async def test_general_route_unknown_order_is_404(client, db):
    r = await client.put(general(9999), json={"status": "confirmed"}, headers=auth(OWNER_A))
    assert r.status_code == 404
    assert r.json()["error_code"] == "ORDER_NOT_FOUND"


# ----------------------------------------------------------------------------
# venue-scoped route: authorization (unchanged behaviour)
# ----------------------------------------------------------------------------

@pytest.mark.parametrize("user_id", [
    pytest.param(OWNER_A, id="owner"),
    pytest.param(ADMIN_A, id="admin"),
    pytest.param(MANAGER_A, id="manager"),
    pytest.param(CASHIER_A, id="cashier"),
])
async def test_venue_route_allows_order_process(client, db, published, user_id):
    oid = await make_order(db)

    r = await client.put(venue(BAR_A, oid), json={"status": "confirmed"}, headers=auth(user_id))

    assert r.status_code == 200, r.text
    assert set(r.json()) == RESPONSE_KEYS
    assert r.json()["status"] == "confirmed"
    assert r.headers["X-Bar-Id"] == str(BAR_A)
    [h] = await history(db, oid)
    assert h["updated_by_user_id"] == user_id
    assert published[0]["old_status"] == "pending"


@pytest.mark.parametrize("user_id", [
    pytest.param(STAFF_A, id="staff-view-only"),
    pytest.param(CUSTOMER, id="no-bar-role"),
    pytest.param(OWNER_B, id="owner-of-other-bar"),
    pytest.param(INACTIVE_OWNER_A, id="deactivated-owner"),
])
async def test_venue_route_rejects_without_order_process(client, db, published, user_id):
    oid = await make_order(db)
    r = await client.put(venue(BAR_A, oid), json={"status": "confirmed"}, headers=auth(user_id))
    assert r.status_code == 403
    assert (await order_row(db, oid))["status"] == "pending"
    assert published == []


async def test_venue_route_cannot_touch_another_bars_order(client, db, published):
    other = await make_order(db, bar_id=BAR_B)

    r = await client.put(venue(BAR_A, other), json={"status": "confirmed"}, headers=auth(OWNER_A))

    assert r.status_code == 404
    assert (await order_row(db, other))["status"] == "pending"
    assert await history(db, other) == []
    assert published == []


# ----------------------------------------------------------------------------
# shared transition behaviour (both routes)
# ----------------------------------------------------------------------------

ROUTES = {
    "general": lambda oid: general(oid),
    "venue": lambda oid: venue(BAR_A, oid),
}


@pytest.mark.parametrize("route", ROUTES)
async def test_full_lifecycle(client, db, published, route):
    oid = await make_order(db)
    eta = (datetime.utcnow() + timedelta(minutes=15)).replace(microsecond=0)

    for new in ("confirmed", "preparing", "ready", "completed"):
        payload = {"status": new}
        if new == "preparing":
            payload["estimated_ready_time"] = eta.isoformat()
        r = await client.put(ROUTES[route](oid), json=payload, headers=auth(OWNER_A))
        assert r.status_code == 200, r.text
        assert r.json()["status"] == new

    row = await order_row(db, oid)
    assert row["status"] == "completed"
    assert row["completed_at"] is not None
    assert row["estimated_ready_time"] == eta
    assert [h["status"] for h in await history(db, oid)] == ["confirmed", "preparing", "ready", "completed"]
    assert [(e["old_status"], e["new_status"]) for e in published] == [
        ("pending", "confirmed"), ("confirmed", "preparing"),
        ("preparing", "ready"), ("ready", "completed"),
    ]


INVALID = [
    ("pending", "ready"),
    ("pending", "completed"),
    ("pending", "pending"),
    ("confirmed", "pending"),
    ("ready", "cancelled"),
    ("completed", "cancelled"),
    ("cancelled", "confirmed"),
    ("pending", "bogus"),
]


@pytest.mark.parametrize("route", ROUTES)
@pytest.mark.parametrize("current,new", INVALID)
async def test_invalid_transitions_rejected_identically(client, db, published, route, current, new):
    oid = await make_order(db, status=current)

    r = await client.put(ROUTES[route](oid), json={"status": new}, headers=auth(OWNER_A))

    assert r.status_code == 400
    assert r.json() == {"error_code": "BAD_REQUEST",
                        "message": f"Invalid status transition from {current} to {new}"}
    assert (await order_row(db, oid))["status"] == current
    assert await history(db, oid) == []
    assert published == []


def test_transition_table_matches_documented_flow():
    assert {k: set(v) for k, v in order_status.ORDER_STATUS_TRANSITIONS.items()} == {
        "pending": {"confirmed", "preparing", "cancelled"},
        "confirmed": {"preparing", "cancelled"},
        "preparing": {"ready", "cancelled"},
        "ready": {"completed"},
        "completed": set(),
        "cancelled": set(),
    }
    with pytest.raises(TypeError):
        order_status.ORDER_STATUS_TRANSITIONS["completed"] = frozenset({"pending"})


# ----------------------------------------------------------------------------
# races: the status changed after the route read the order
# ----------------------------------------------------------------------------

async def test_stale_read_cannot_double_complete(db, published):
    oid = await make_order(db, status="ready")
    stale = await order_row(db, oid)

    first = await order_status.apply_status_transition(stale, OrderStatusUpdate(status="completed"), OWNER_A)
    assert first["status"] == "completed"

    with pytest.raises(APIError) as exc:
        await order_status.apply_status_transition(stale, OrderStatusUpdate(status="completed"), CASHIER_A)

    assert exc.value.status_code == 400
    assert exc.value.message == "Invalid status transition from completed to completed"
    assert [h["status"] for h in await history(db, oid)] == ["completed"]
    assert len(published) == 1


async def test_stale_read_cannot_confirm_cancelled_order(db, published):
    oid = await make_order(db)
    stale = await order_row(db, oid)  # both requests read "pending"

    await order_status.apply_status_transition(stale, OrderStatusUpdate(status="cancelled"), OWNER_A)
    with pytest.raises(APIError) as exc:
        await order_status.apply_status_transition(stale, OrderStatusUpdate(status="confirmed"), CASHIER_A)

    assert exc.value.status_code == 400
    assert (await order_row(db, oid))["status"] == "cancelled"
    assert [h["status"] for h in await history(db, oid)] == ["cancelled"]
    assert [e["new_status"] for e in published] == ["cancelled"]


async def test_stale_read_revalidates_against_current_status(db, published):
    # confirm then cancel is valid when run one after the other, so a
    # cancel that read "pending" still succeeds, reporting the real previous
    # status ("confirmed") in its event.
    oid = await make_order(db)
    stale = await order_row(db, oid)

    await order_status.apply_status_transition(stale, OrderStatusUpdate(status="confirmed"), OWNER_A)
    result = await order_status.apply_status_transition(stale, OrderStatusUpdate(status="cancelled"), CASHIER_A)

    assert result["status"] == "cancelled"
    assert [h["status"] for h in await history(db, oid)] == ["confirmed", "cancelled"]
    assert [(e["old_status"], e["new_status"]) for e in published] == [
        ("pending", "confirmed"), ("confirmed", "cancelled")]


async def test_persistent_contention_gives_up_with_conflict(db, published, monkeypatch):
    oid = await make_order(db, status="confirmed")
    stale = await order_row(db, oid)
    await db.execute(Order.__table__.update().where(Order.__table__.c.id == oid).values(status="preparing"))
    stale_pending = {**dict(stale), "status": "pending"}

    async def always_stale(order_id, bar_id=None):
        return stale_pending

    monkeypatch.setattr(order_status, "fetch_order", always_stale)

    with pytest.raises(APIError) as exc:
        await order_status.apply_status_transition(stale, OrderStatusUpdate(status="cancelled"), OWNER_A)

    assert exc.value.status_code == 409
    assert (await order_row(db, oid))["status"] == "preparing"
    assert await history(db, oid) == []
    assert published == []


async def test_order_deleted_midway_is_404(db, published):
    oid = await make_order(db)
    stale = await order_row(db, oid)
    await db.execute(Order.__table__.delete().where(Order.__table__.c.id == oid))

    with pytest.raises(APIError) as exc:
        await order_status.apply_status_transition(stale, OrderStatusUpdate(status="confirmed"), OWNER_A)
    assert exc.value.status_code == 404


# ----------------------------------------------------------------------------
# failure handling
# ----------------------------------------------------------------------------

@pytest.mark.parametrize("route", ROUTES)
async def test_history_failure_rolls_back_and_hides_db_error(client, db, published, route):
    oid = await make_order(db)
    await db.execute("DROP TABLE order_status_history")

    r = await client.put(ROUTES[route](oid), json={"status": "confirmed"}, headers=auth(OWNER_A))

    assert r.status_code == 500
    assert r.json() == {"error_code": "SERVER_UNAVAILABLE", "message": "Failed to update order status"}
    assert (await order_row(db, oid))["status"] == "pending"  # update rolled back with the insert
    assert published == []


async def test_publish_failure_does_not_fail_committed_update(client, db, monkeypatch):
    async def boom(**kwargs):
        raise RuntimeError("redis down")

    monkeypatch.setattr(OrderQueue, "publish_status_change", staticmethod(boom))
    oid = await make_order(db)

    r = await client.put(general(oid), json={"status": "confirmed"}, headers=auth(OWNER_A))

    assert r.status_code == 200
    assert (await order_row(db, oid))["status"] == "confirmed"


# ----------------------------------------------------------------------------
# customer cancellation: POST /orders/{order_id}/cancel
# ----------------------------------------------------------------------------

def cancel(order_id):
    return f"/orders/{order_id}/cancel"


def test_customer_cancel_policy_is_within_state_machine():
    assert order_status.CUSTOMER_CANCELLABLE_STATUSES == {"pending", "confirmed"}
    for s in order_status.CUSTOMER_CANCELLABLE_STATUSES:
        assert order_status.is_valid_transition(s, "cancelled")


@pytest.mark.parametrize("current", ["pending", "confirmed"])
async def test_customer_can_cancel(client, db, published, cancellations, current):
    oid = await make_order(db, status=current)

    r = await client.post(cancel(oid), headers=auth(CUSTOMER))

    assert r.status_code == 200, r.text
    assert set(r.json()) == RESPONSE_KEYS
    assert r.json()["status"] == "cancelled"
    assert r.json()["completed_at"] is None
    [h] = await history(db, oid)
    assert (h["status"], h["updated_by_user_id"], h["notes"]) == ("cancelled", CUSTOMER, "Cancelled by customer")
    assert cancellations == [{"order_id": oid, "bar_id": BAR_A, "user_id": CUSTOMER,
                              "reason": "Cancelled by customer"}]
    assert published == []  # cancel emits order.cancelled, not order.status_changed


@pytest.mark.parametrize("current", ["preparing", "ready", "completed", "cancelled"])
async def test_customer_cannot_cancel_after_confirmation(client, db, cancellations, current):
    oid = await make_order(db, status=current)

    r = await client.post(cancel(oid), headers=auth(CUSTOMER))

    assert r.status_code == 400
    assert r.json() == {"error_code": "ORDER_CANCELLED",
                        "message": f"Cannot cancel order with status: {current}"}
    assert (await order_row(db, oid))["status"] == current
    assert await history(db, oid) == []
    assert cancellations == []


@pytest.mark.parametrize("user_id", [
    pytest.param(OWNER_A, id="bar-owner"),
    pytest.param(CASHIER_A, id="cashier"),
    pytest.param(OWNER_B, id="unrelated-user"),
])
async def test_only_the_customer_can_cancel(client, db, cancellations, user_id):
    oid = await make_order(db, status="completed")

    r = await client.post(cancel(oid), headers=auth(user_id))

    assert r.status_code == 403  # and no status leak via the 400 message
    assert "completed" not in r.text
    assert (await order_row(db, oid))["status"] == "completed"
    assert cancellations == []


async def test_cancel_unknown_order_is_404(client, db):
    r = await client.post(cancel(9999), headers=auth(CUSTOMER))
    assert r.status_code == 404
    assert r.json()["error_code"] == "ORDER_NOT_FOUND"


@pytest.mark.parametrize("read_as,advanced_to", [
    ("confirmed", ["preparing", "ready", "completed"]),
    ("pending", ["confirmed", "preparing"]),
    ("pending", ["preparing"]),  # cashier skips the confirm step
    ("pending", ["cancelled"]),
])
async def test_cancel_does_not_overwrite_status_advanced_after_read(
    client, db, published, cancellations, monkeypatch, read_as, advanced_to
):
    """The route reads a cancellable status, then the bar advances the order
    before the cancellation writes. The newer status must survive."""
    oid = await make_order(db, status=read_as)
    real_fetch = orders_routes.fetch_order

    async def fetch_then_operator_advances(order_id, bar_id=None):
        snapshot = await real_fetch(order_id, bar_id)
        current = snapshot
        for new in advanced_to:
            current = await order_status.apply_status_transition(
                current, OrderStatusUpdate(status=new), OWNER_A)
        return snapshot  # the route carries on with the stale read

    monkeypatch.setattr(orders_routes, "fetch_order", fetch_then_operator_advances)

    r = await client.post(cancel(oid), headers=auth(CUSTOMER))

    final = advanced_to[-1]
    assert r.status_code == 400, r.text
    assert r.json() == {"error_code": "ORDER_CANCELLED",
                        "message": f"Cannot cancel order with status: {final}"}
    row = await order_row(db, oid)
    assert row["status"] == final
    if final == "completed":
        assert row["completed_at"] is not None
    assert [h["status"] for h in await history(db, oid)] == advanced_to
    assert all(h["updated_by_user_id"] == OWNER_A for h in await history(db, oid))
    assert cancellations == []
    assert [e["new_status"] for e in published] == advanced_to


async def test_cancel_after_concurrent_confirm_still_succeeds(client, db, published, cancellations, monkeypatch):
    # pending -> confirmed keeps the order cancellable, so (as if the requests
    # had run one after another) the customer's cancel goes through.
    oid = await make_order(db)
    real_fetch = orders_routes.fetch_order

    async def fetch_then_confirm(order_id, bar_id=None):
        snapshot = await real_fetch(order_id, bar_id)
        await order_status.apply_status_transition(snapshot, OrderStatusUpdate(status="confirmed"), OWNER_A)
        return snapshot

    monkeypatch.setattr(orders_routes, "fetch_order", fetch_then_confirm)

    r = await client.post(cancel(oid), headers=auth(CUSTOMER))

    assert r.status_code == 200, r.text
    assert r.json()["status"] == "cancelled"
    assert [h["status"] for h in await history(db, oid)] == ["confirmed", "cancelled"]
    assert len(cancellations) == 1


async def test_operator_cannot_overwrite_customer_cancel(db, published, cancellations):
    oid = await make_order(db, status="confirmed")
    stale = await order_row(db, oid)

    await order_status.cancel_order_as_customer(stale, CUSTOMER)
    with pytest.raises(APIError) as exc:
        await order_status.apply_status_transition(stale, OrderStatusUpdate(status="preparing"), OWNER_A)

    assert exc.value.status_code == 400
    assert exc.value.message == "Invalid status transition from cancelled to preparing"
    assert (await order_row(db, oid))["status"] == "cancelled"
    assert published == []


async def test_double_cancel_records_once(db, cancellations):
    oid = await make_order(db)
    stale = await order_row(db, oid)

    await order_status.cancel_order_as_customer(stale, CUSTOMER)
    with pytest.raises(APIError) as exc:
        await order_status.cancel_order_as_customer(stale, CUSTOMER)

    assert exc.value.status_code == 400
    assert exc.value.message == "Cannot cancel order with status: cancelled"
    assert len(await history(db, oid)) == 1
    assert len(cancellations) == 1


async def test_cancel_db_failure_rolls_back_and_hides_db_error(client, db, cancellations):
    oid = await make_order(db)
    await db.execute("DROP TABLE order_status_history")

    r = await client.post(cancel(oid), headers=auth(CUSTOMER))

    assert r.status_code == 500
    assert r.json() == {"error_code": "SERVER_UNAVAILABLE", "message": "Failed to cancel order"}
    assert (await order_row(db, oid))["status"] == "pending"
    assert cancellations == []


async def test_cancel_publish_failure_does_not_fail_committed_cancel(client, db, monkeypatch):
    async def boom(**kwargs):
        raise RuntimeError("redis down")

    monkeypatch.setattr(OrderQueue, "publish_cancellation", staticmethod(boom))
    oid = await make_order(db)

    r = await client.post(cancel(oid), headers=auth(CUSTOMER))

    assert r.status_code == 200
    assert (await order_row(db, oid))["status"] == "cancelled"


# ----------------------------------------------------------------------------
# pending -> preparing (busy venues skip the confirm step)
# ----------------------------------------------------------------------------

@pytest.mark.parametrize("route,user_id", [
    pytest.param("venue", CASHIER_A, id="cashier-venue-route"),
    pytest.param("venue", MANAGER_A, id="manager-venue-route"),
    pytest.param("general", OWNER_A, id="owner-general-route"),
])
async def test_pending_can_go_straight_to_preparing(client, db, published, route, user_id):
    oid = await make_order(db)

    r = await client.put(ROUTES[route](oid), json={"status": "preparing"}, headers=auth(user_id))

    assert r.status_code == 200, r.text
    assert r.json()["status"] == "preparing"
    assert [(h["status"], h["updated_by_user_id"]) for h in await history(db, oid)] == [("preparing", user_id)]
    assert published == [{"order_id": oid, "bar_id": BAR_A,
                          "old_status": "pending", "new_status": "preparing"}]

    # and the rest of the workflow continues as usual
    for new in ("ready", "completed"):
        r = await client.put(ROUTES[route](oid), json={"status": new}, headers=auth(user_id))
        assert r.status_code == 200, r.text
    assert (await order_row(db, oid))["completed_at"] is not None


async def test_pending_to_preparing_still_needs_order_process(client, db):
    oid = await make_order(db)
    r = await client.put(venue(BAR_A, oid), json={"status": "preparing"}, headers=auth(STAFF_A))
    assert r.status_code == 403
    assert (await order_row(db, oid))["status"] == "pending"


async def test_customer_cannot_cancel_once_preparing(client, db, cancellations):
    oid = await make_order(db)
    r = await client.put(venue(BAR_A, oid), json={"status": "preparing"}, headers=auth(CASHIER_A))
    assert r.status_code == 200

    r = await client.post(cancel(oid), headers=auth(CUSTOMER))

    assert r.status_code == 400
    assert r.json()["message"] == "Cannot cancel order with status: preparing"
    assert cancellations == []


# ----------------------------------------------------------------------------
# bar WebSocket commands: /ws/bar/{bar_id}/orders
# ----------------------------------------------------------------------------

@pytest.fixture
def ws_notifications(monkeypatch):
    sent = {"order": [], "bar": []}

    async def notify_order(order_id, message):
        sent["order"].append(message)

    async def notify_bar(bar_id, message):
        sent["bar"].append(message)

    monkeypatch.setattr(ws.manager, "notify_order", notify_order)
    monkeypatch.setattr(ws.manager, "notify_bar", notify_bar)
    return sent


async def ws_command(order_id, action, user_id, bar_id=BAR_A, reason=None):
    return await ws.handle_bar_owner_command(
        bar_id=bar_id, order_id=order_id, action=action, reason=reason, user_id=user_id)


async def test_ws_command_uses_shared_transition(db, published, ws_notifications):
    oid = await make_order(db)

    result = await ws_command(oid, "prepare", CASHIER_A)  # pending -> preparing

    assert set(result) == {"type", "action", "order_id", "new_status", "timestamp", "message"}
    assert (result["type"], result["new_status"]) == ("command_success", "preparing")
    assert (await order_row(db, oid))["status"] == "preparing"
    [h] = await history(db, oid)  # previously WS commands wrote no history
    assert (h["status"], h["updated_by_user_id"]) == ("preparing", CASHIER_A)
    assert published == [{"order_id": oid, "bar_id": BAR_A,
                          "old_status": "pending", "new_status": "preparing"}]
    # existing direct socket notifications are kept, same shapes
    assert [m["status"] for m in ws_notifications["order"]] == ["preparing"]
    assert ws_notifications["order"][0]["type"] == "status_update"
    assert ws_notifications["bar"][0]["type"] == "order_update"
    assert ws_notifications["bar"][0]["updated_by"] == "bar_owner"


async def test_ws_command_full_lifecycle_and_completed_at(db, ws_notifications):
    oid = await make_order(db)
    for action in ("confirm", "prepare", "ready", "complete"):
        assert (await ws_command(oid, action, MANAGER_A))["type"] == "command_success"
    row = await order_row(db, oid)
    assert row["status"] == "completed" and row["completed_at"] is not None
    assert [h["status"] for h in await history(db, oid)] == ["confirmed", "preparing", "ready", "completed"]


async def test_ws_cancel_records_reason(db, ws_notifications):
    oid = await make_order(db, status="confirmed")
    result = await ws_command(oid, "cancel", CASHIER_A, reason="Out of stock")
    assert result["type"] == "command_success"
    [h] = await history(db, oid)
    assert (h["status"], h["notes"]) == ("cancelled", "Out of stock")


@pytest.mark.parametrize("current,action", [
    ("cancelled", "confirm"),   # would revive a customer-cancelled order
    ("cancelled", "prepare"),
    ("completed", "cancel"),
    ("ready", "confirm"),       # would move the order backwards
    ("preparing", "confirm"),
    ("pending", "complete"),    # would skip straight to the end
    ("ready", "ready"),
])
async def test_ws_command_rejects_invalid_transitions(db, published, ws_notifications, current, action):
    oid = await make_order(db, status=current)
    before = dict(await order_row(db, oid))

    result = await ws_command(oid, action, OWNER_A)

    new = order_status.status_for_action(action)
    assert result == {"type": "error", "message": f"Invalid status transition from {current} to {new}"}
    assert dict(await order_row(db, oid)) == before
    assert await history(db, oid) == []
    assert published == []
    assert ws_notifications == {"order": [], "bar": []}


@pytest.mark.parametrize("user_id", [
    pytest.param(STAFF_A, id="view-only-staff"),
    pytest.param(INACTIVE_OWNER_A, id="membership-revoked-mid-session"),
    pytest.param(OWNER_B, id="other-bar-owner"),
    pytest.param(CUSTOMER, id="no-membership"),
    pytest.param(None, id="no-user"),
])
async def test_ws_command_requires_order_process_per_command(db, published, ws_notifications, user_id):
    oid = await make_order(db)

    result = await ws_command(oid, "confirm", user_id)

    assert result == {"type": "error",
                      "message": "You don't have permission to process orders at this bar"}
    assert (await order_row(db, oid))["status"] == "pending"
    assert published == [] and ws_notifications == {"order": [], "bar": []}


async def test_ws_command_demoted_cashier_loses_access(db, ws_notifications):
    oid = await make_order(db)
    assert (await ws_command(oid, "confirm", CASHIER_A))["type"] == "command_success"

    # demoted to view-only while their dashboard socket is still open
    await db.execute(BarStaff.__table__.update()
                     .where(BarStaff.__table__.c.user_id == CASHIER_A).values(role="staff"))

    result = await ws_command(oid, "prepare", CASHIER_A)
    assert result["type"] == "error"
    assert (await order_row(db, oid))["status"] == "confirmed"


async def test_ws_command_honours_custom_permissions(db, ws_notifications):
    # same rules as require_bar_permission: custom permissions extend the role
    await db.execute(BarStaff.__table__.update()
                     .where(BarStaff.__table__.c.user_id == STAFF_A)
                     .values(custom_permissions='["order:process"]'))
    oid = await make_order(db)
    assert (await ws_command(oid, "confirm", STAFF_A))["type"] == "command_success"


@pytest.mark.parametrize("order_id,action,message", [
    ("abc", "confirm", "Invalid order_id"),
    (True, "confirm", "Invalid order_id"),
    ([1], "confirm", "Invalid order_id"),
    (9999, "confirm", "Order 9999 not found"),
    (None, "explode", "Invalid order_id"),
])
async def test_ws_command_input_validation(db, ws_notifications, order_id, action, message):
    result = await ws_command(order_id, action, OWNER_A)
    assert result == {"type": "error", "message": message}


async def test_ws_command_unknown_action_and_other_bar(db, ws_notifications):
    oid = await make_order(db)
    other = await make_order(db, bar_id=BAR_B)
    assert await ws_command(oid, "explode", OWNER_A) == {"type": "error", "message": "Unknown action: explode"}
    assert await ws_command(other, "confirm", OWNER_A) == {
        "type": "error", "message": "Order does not belong to this bar"}
    assert (await order_row(db, other))["status"] == "pending"


async def test_ws_command_cannot_overwrite_concurrent_customer_cancel(db, published, cancellations,
                                                                      ws_notifications, monkeypatch):
    """The handler reads 'pending', the customer cancels, then the handler
    writes. The cancellation must survive."""
    oid = await make_order(db)

    class CancelAfterRead:
        def __init__(self, inner):
            self._inner = inner

        def __getattr__(self, name):
            return getattr(self._inner, name)

        async def fetch_one(self, query, values=None):
            row = await self._inner.fetch_one(query, values)
            await order_status.cancel_order_as_customer(row, CUSTOMER)
            return row

    monkeypatch.setattr(ws, "database", CancelAfterRead(db))

    result = await ws_command(oid, "prepare", CASHIER_A)

    assert result == {"type": "error", "message": "Invalid status transition from cancelled to preparing"}
    assert (await order_row(db, oid))["status"] == "cancelled"
    assert [h["notes"] for h in await history(db, oid)] == ["Cancelled by customer"]
    assert published == [] and ws_notifications == {"order": [], "bar": []}


class FakeWebSocket:
    def __init__(self, incoming):
        self.incoming = list(incoming)
        self.sent = []
        self.closed = None

    async def accept(self):
        pass

    async def send_json(self, message):
        self.sent.append(message)

    async def receive_text(self):
        if not self.incoming:
            raise ws.WebSocketDisconnect()
        return self.incoming.pop(0)

    async def close(self, code=1000, reason=None):
        self.closed = (code, reason)


async def test_ws_endpoint_records_the_connected_user(db, published, ws_notifications, monkeypatch):
    async def no_pubsub():
        pass

    monkeypatch.setattr(ws.manager, "_ensure_pubsub", no_pubsub)
    oid = await make_order(db)
    token = auth(CASHIER_A)["Authorization"].split()[1]
    sock = FakeWebSocket([
        json.dumps({"action": "prepare", "order_id": oid}),
        json.dumps({"action": "confirm", "order_id": oid}),  # preparing -> confirmed: rejected
    ])

    await ws.websocket_bar_owner_dashboard(sock, BAR_A, token=token)

    replies = [m for m in sock.sent if m["type"] in ("command_success", "error")]
    assert [r["type"] for r in replies] == ["command_success", "error"]
    assert replies[1]["message"] == "Invalid status transition from preparing to confirmed"
    [h] = await history(db, oid)
    assert (h["status"], h["updated_by_user_id"]) == ("preparing", CASHIER_A)


# ----------------------------------------------------------------------------
# RBAC helper shared with the HTTP dependency
# ----------------------------------------------------------------------------

@pytest.mark.parametrize("user_id", [
    pytest.param(OWNER_A, id="owner"),
    pytest.param(ADMIN_A, id="admin"),
    pytest.param(MANAGER_A, id="manager"),
    pytest.param(CASHIER_A, id="cashier"),
])
async def test_ws_permissions_match_http_dependency(client, db, user_id):
    oid = await make_order(db)
    r = await client.put(venue(BAR_A, oid), json={"status": "confirmed"}, headers=auth(user_id))
    http_permissions = set(r.headers["X-Bar-Permissions"].split(","))
    assert await rbac_middleware.get_active_bar_permissions(user_id, BAR_A) == http_permissions


# ----------------------------------------------------------------------------
# single source of truth for statuses / actions
# ----------------------------------------------------------------------------

def test_action_map_is_central_and_read_only():
    assert dict(order_status.ORDER_ACTION_STATUSES) == {
        "confirm": "confirmed", "prepare": "preparing", "ready": "ready",
        "complete": "completed", "cancel": "cancelled",
    }
    with pytest.raises(TypeError):
        order_status.ORDER_ACTION_STATUSES["reopen"] = "pending"
    assert not hasattr(ws, "_ACTION_STATUS_MAP")  # no local copy left behind


@pytest.mark.parametrize("action", [None, 1, ["confirm"], {"a": 1}, "CONFIRM", "", "reopen"])
def test_status_for_action_rejects_unknown(action):
    assert order_status.status_for_action(action) is None


@pytest.mark.parametrize("attr,broken,error", [
    ("ORDER_ACTION_STATUSES", {"reopen": "pending"}, "unreachable status 'pending'"),
    ("ORDER_ACTION_STATUSES", {"archive": "archived"}, "unreachable status 'archived'"),
    ("CUSTOMER_CANCELLABLE_STATUSES", frozenset({"ready"}), "Customers may cancel 'ready'"),
    ("ORDER_STATUS_TRANSITIONS", {"pending": frozenset({"shipped"})}, "undefined statuses: ['shipped']"),
])
def test_inconsistent_workflow_tables_fail_fast(monkeypatch, attr, broken, error):
    monkeypatch.setattr(order_status, attr, broken)
    with pytest.raises(RuntimeError, match=error.replace("[", r"\[").replace("]", r"\]")):
        order_status._validate_workflow()


async def test_ws_commands_follow_the_central_action_map(db, ws_notifications, monkeypatch):
    monkeypatch.setattr(order_status, "ORDER_ACTION_STATUSES",
                        {**order_status.ORDER_ACTION_STATUSES, "start": "preparing"})
    oid = await make_order(db)
    result = await ws_command(oid, "start", CASHIER_A)
    assert (result["type"], result["new_status"]) == ("command_success", "preparing")


# ----------------------------------------------------------------------------
# POST /orders/sync: customers only see their own orders
# ----------------------------------------------------------------------------

def sync_body(*ops):
    return {"operations": [
        {"type": "cancel_order", "order_id": oid, "client_timestamp": "2026-01-01T12:00:00Z"}
        for oid in ops
    ]}


NOT_FOUND = {"conflict_type": "order_not_found", "server_state": None,
             "resolution": "Order no longer exists"}


def conflict_without_operation(conflict):
    return {k: v for k, v in conflict.items() if k != "operation"}


@pytest.mark.parametrize("status,expected", [
    ("pending", None),
    ("confirmed", None),
    ("preparing", {"conflict_type": "cannot_cancel", "server_state": {"status": "preparing"},
                   "resolution": "Cannot cancel order in status: preparing"}),
    ("ready", {"conflict_type": "cannot_cancel", "server_state": {"status": "ready"},
               "resolution": "Cannot cancel order in status: ready"}),
    ("cancelled", "already_cancelled"),
    ("completed", "already_completed"),
])
async def test_sync_owned_order_keeps_existing_contract(client, db, status, expected):
    done = datetime(2026, 1, 2, 3, 4, 5)
    oid = await make_order(db, status=status, completed_at=done if status == "completed" else None)
    row = await order_row(db, oid)

    r = await client.post("/orders/sync", json=sync_body(oid), headers=auth(CUSTOMER))

    assert r.status_code == 200, r.text
    body = r.json()
    op = sync_body(oid)["operations"][0]
    if expected is None:
        assert body == {"synced": [{"operation": {**op, "bar_id": None}, "result": "pending_execution"}],
                        "conflicts": []}
        return
    assert body["synced"] == []
    [conflict] = body["conflicts"]
    assert conflict["operation"]["order_id"] == oid
    if expected == "already_cancelled":
        expected = {"conflict_type": "already_cancelled",
                    "server_state": {"status": "cancelled", "updated_at": row["updated_at"].isoformat()},
                    "resolution": "Order was already cancelled"}
    elif expected == "already_completed":
        expected = {"conflict_type": "already_completed",
                    "server_state": {"status": "completed", "completed_at": done.isoformat()},
                    "resolution": "Order was already completed"}
    assert conflict_without_operation(conflict) == expected


@pytest.mark.parametrize("status", ["pending", "confirmed", "preparing", "ready", "cancelled", "completed"])
@pytest.mark.parametrize("caller", [
    pytest.param(OTHER_CUSTOMER, id="other-customer"),
    pytest.param(OWNER_A, id="owner-of-the-orders-bar"),
])
async def test_sync_unrelated_order_looks_nonexistent(client, db, status, caller):
    done = datetime(2026, 1, 2, 3, 4, 5)
    oid = await make_order(db, status=status, completed_at=done)
    row = await order_row(db, oid)

    r = await client.post("/orders/sync", json=sync_body(oid, 9999), headers=auth(caller))

    assert r.status_code == 200, r.text
    body = r.json()
    assert body["synced"] == []
    unrelated, missing = body["conflicts"]
    # indistinguishable from an order that does not exist
    assert conflict_without_operation(unrelated) == NOT_FOUND
    assert conflict_without_operation(missing) == NOT_FOUND
    # nothing about the order leaks anywhere in the response
    for secret in (status, row["updated_at"].isoformat(), done.isoformat(), row["created_at"].isoformat()):
        assert secret not in r.text
    # and the order itself is untouched
    assert (await order_row(db, oid))["status"] == status


async def test_sync_nonexistent_order(client, db):
    r = await client.post("/orders/sync", json=sync_body(9999), headers=auth(CUSTOMER))
    assert r.status_code == 200
    [conflict] = r.json()["conflicts"]
    assert conflict["operation"]["order_id"] == 9999
    assert conflict_without_operation(conflict) == NOT_FOUND


async def test_sync_mixed_batch_keeps_order_and_only_reveals_own(client, db):
    mine_pending = await make_order(db, status="pending")
    mine_ready = await make_order(db, status="ready")
    theirs = await make_order(db, status="confirmed", user_id=OTHER_CUSTOMER)

    r = await client.post("/orders/sync", json=sync_body(theirs, mine_pending, 9999, mine_ready),
                          headers=auth(CUSTOMER))

    body = r.json()
    assert [s["operation"]["order_id"] for s in body["synced"]] == [mine_pending]
    assert [(c["operation"]["order_id"], c["conflict_type"]) for c in body["conflicts"]] == [
        (theirs, "order_not_found"), (9999, "order_not_found"), (mine_ready, "cannot_cancel")]


async def test_sync_requires_authentication(client, db):
    oid = await make_order(db)
    r = await client.post("/orders/sync", json=sync_body(oid))
    assert r.status_code == 401


@pytest.mark.parametrize("status", ["pending", "confirmed", "preparing", "ready", "cancelled", "completed"])
async def test_sync_and_cancel_route_agree_on_eligibility(client, db, status):
    synced_id = await make_order(db, status=status)
    cancel_id = await make_order(db, status=status)

    sync = await client.post("/orders/sync", json=sync_body(synced_id), headers=auth(CUSTOMER))
    cancelled = await client.post(cancel(cancel_id), headers=auth(CUSTOMER))

    assert bool(sync.json()["synced"]) == (cancelled.status_code == 200)


async def test_sync_uses_shared_cancellation_policy(client, db, monkeypatch):
    monkeypatch.setattr(order_status, "CUSTOMER_CANCELLABLE_STATUSES", frozenset({"pending"}))
    oid = await make_order(db, status="confirmed")

    r = await client.post("/orders/sync", json=sync_body(oid), headers=auth(CUSTOMER))

    assert [c["conflict_type"] for c in r.json()["conflicts"]] == ["cannot_cancel"]


async def test_sync_create_order_operation_unchanged(client, db):
    body = {"operations": [
        {"type": "create_order", "bar_id": BAR_A, "client_timestamp": "t"},
        {"type": "create_order", "bar_id": 999, "client_timestamp": "t"},
        {"type": "something_else", "client_timestamp": "t"},
    ]}
    r = await client.post("/orders/sync", json=body, headers=auth(CUSTOMER))
    data = r.json()
    assert [s["result"] for s in data["synced"]] == ["pending_execution", "unknown_operation"]
    assert [c["conflict_type"] for c in data["conflicts"]] == ["bar_not_found"]
