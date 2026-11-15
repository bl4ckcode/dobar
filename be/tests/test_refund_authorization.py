"""
POST /payments/v2/refund authorization.

A payment may only be refunded by:
* the consumer who paid it (the order is theirs), or
* the venue it was paid to: an active member of the order's bar holding
  ``order:refund`` there (owner / admin by default, or a custom grant).

Everyone else is refused *before* the payment engine is called. Strangers get
the same 404 as an unknown payment (payment ids cannot be probed); members of
the venue without the refund permission get a 403.
"""

import json
from datetime import datetime, timezone

import pytest

from conftest import create_test_token, test_database
from app.auth.auth_models import User
from app.auth.rbac_models import BarStaff
from app.bars_and_restaurants.models.financial_models import OrderRefund
from app.bars_and_restaurants.models.relational_models import Bar, Order
import app.payment.routes as payment_routes


pytestmark = pytest.mark.asyncio

_counter = {"n": 0}


def _next():
    _counter["n"] += 1
    return _counter["n"]


class FakeDPE:
    def __init__(self):
        self.calls = []

    async def refund(self, payment_id, amount=None, reason=None, idempotency_key=None):
        self.calls.append(payment_id)
        return {
            "status": "succeeded",
            "refund_id": f"re_{len(self.calls)}_{payment_id}",
            "payment_id": payment_id,
            "amount": amount if amount is not None else 100.0,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }


@pytest.fixture
def dpe(client, monkeypatch):
    fake = FakeDPE()
    monkeypatch.setattr(payment_routes, "database", test_database)
    monkeypatch.setattr(payment_routes, "get_dpe_client", lambda: fake)
    return fake


async def make_user():
    n = _next()
    user_id = await test_database.execute(User.__table__.insert().values(
        firebase_uid=f"refund-uid-{n}",
        email=f"refund{n}@example.com",
        phone_number=f"+55117{n:08d}",
        is_active=True,
        email_verified=True,
        phone_verified=False,
    ))
    return {"id": user_id}


async def make_bar():
    n = _next()
    return await test_database.execute(Bar.__table__.insert().values(
        name=f"Refund Bar {n}",
        address=f"{n} Refund St",
        phone_number="+5511000000000",
        email=f"refund{n}@bar.test",
        owner_id=1,
    ))


async def add_staff(user, bar_id, role, custom_permissions=None, is_active=True):
    await test_database.execute(BarStaff.__table__.insert().values(
        user_id=user["id"],
        bar_id=bar_id,
        role=role,
        custom_permissions=json.dumps(custom_permissions) if custom_permissions else None,
        is_active=is_active,
    ))


async def make_paid_order(bar_id, consumer, payment_id):
    now = datetime.utcnow()
    return await test_database.execute(Order.__table__.insert().values(
        user_id=consumer["id"],
        bar_id=bar_id,
        status="completed",
        payment_status="paid",
        payment_id=payment_id,
        total_price=100.0,
        created_at=now,
        updated_at=now,
    ))


async def refund(client, user, payment_id, amount=None):
    body = {"payment_id": payment_id}
    if amount is not None:
        body["amount"] = amount
    return await client.post(
        "/payments/v2/refund", json=body,
        headers={"Authorization": f"Bearer {create_test_token(user['id'])}"},
    )


async def recorded_refunds():
    return await test_database.fetch_all(OrderRefund.__table__.select())


@pytest.fixture
async def sale():
    """A venue and a consumer's paid order there."""
    bar_id = await make_bar()
    consumer = await make_user()
    order_id = await make_paid_order(bar_id, consumer, "pay_sale")
    return {"bar_id": bar_id, "consumer": consumer, "order_id": order_id, "payment_id": "pay_sale"}


# ---------------------------------------------------------------------------
# Allowed
# ---------------------------------------------------------------------------

async def test_consumer_can_refund_their_own_payment(client, dpe, sale):
    response = await refund(client, sale["consumer"], sale["payment_id"], amount=40.0)

    assert response.status_code == 200
    assert dpe.calls == [sale["payment_id"]]
    [row] = await recorded_refunds()
    assert row["order_id"] == sale["order_id"]
    assert row["requested_by_user_id"] == sale["consumer"]["id"]


@pytest.mark.parametrize("role", ["owner", "admin"])
async def test_venue_with_refund_permission_can_refund(client, dpe, sale, role):
    operator = await make_user()
    await add_staff(operator, sale["bar_id"], role)

    response = await refund(client, operator, sale["payment_id"])

    assert response.status_code == 200
    assert dpe.calls == [sale["payment_id"]]
    [row] = await recorded_refunds()
    assert row["bar_id"] == sale["bar_id"]
    assert row["requested_by_user_id"] == operator["id"]


async def test_custom_refund_permission_at_the_venue_allows_refund(client, dpe, sale):
    operator = await make_user()
    await add_staff(operator, sale["bar_id"], "cashier", custom_permissions=["order:refund"])

    response = await refund(client, operator, sale["payment_id"])

    assert response.status_code == 200
    assert dpe.calls == [sale["payment_id"]]


# ---------------------------------------------------------------------------
# Refused before the payment engine is called
# ---------------------------------------------------------------------------

async def test_another_consumer_cannot_refund(client, dpe, sale):
    stranger = await make_user()

    response = await refund(client, stranger, sale["payment_id"])

    assert response.status_code == 404
    assert dpe.calls == []
    assert await recorded_refunds() == []


@pytest.mark.parametrize("role", ["manager", "cashier", "staff"])
async def test_venue_member_without_refund_permission_cannot_refund(client, dpe, sale, role):
    operator = await make_user()
    await add_staff(operator, sale["bar_id"], role)

    response = await refund(client, operator, sale["payment_id"])

    assert response.status_code == 403
    assert "order:refund" in response.text
    assert dpe.calls == []
    assert await recorded_refunds() == []


async def test_owner_of_another_venue_cannot_refund(client, dpe, sale):
    other_owner = await make_user()
    await add_staff(other_owner, await make_bar(), "owner")

    response = await refund(client, other_owner, sale["payment_id"])

    assert response.status_code == 404
    assert dpe.calls == []


async def test_inactive_venue_membership_cannot_refund(client, dpe, sale):
    former_owner = await make_user()
    await add_staff(former_owner, sale["bar_id"], "owner", is_active=False)

    response = await refund(client, former_owner, sale["payment_id"])

    assert response.status_code == 404
    assert dpe.calls == []


async def test_consumer_of_one_order_cannot_refund_another_at_same_venue(client, dpe, sale):
    # Being a customer of the venue gives no rights over other customers' payments.
    await make_paid_order(sale["bar_id"], sale["consumer"], "pay_mine")
    other_consumer = await make_user()
    await make_paid_order(sale["bar_id"], other_consumer, "pay_theirs")

    response = await refund(client, sale["consumer"], "pay_theirs")

    assert response.status_code == 404
    assert dpe.calls == []


async def test_unknown_payment_is_not_found(client, dpe, sale):
    response = await refund(client, sale["consumer"], "pay_does_not_exist")

    assert response.status_code == 404
    assert dpe.calls == []


async def test_unauthenticated_request_is_rejected(client, dpe, sale):
    response = await client.post("/payments/v2/refund", json={"payment_id": sale["payment_id"]})

    assert response.status_code in (401, 403)
    assert dpe.calls == []
