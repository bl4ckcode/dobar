from datetime import datetime
from decimal import Decimal
from unittest.mock import AsyncMock

import httpx
import pytest

from app.auth.rbac_models import UserProfile
from app.bars_and_restaurants.models.relational_models import UserDocument, Order, Menu, MenuItem
from app.bars_and_restaurants.models.cart_models import Cart, CartItem
from app.payment import routes
from app.payment.models import PaymentCard, IdempotencyKey
from app.payment.order_payments import charge_order, customer_for_payment
from app.errors import APIError
from conftest import test_database

pytestmark = pytest.mark.asyncio


@pytest.fixture
async def payer(test_user_in_db):
    user_id = test_user_in_db["id"]
    await test_database.execute(UserProfile.__table__.insert().values(user_id=user_id, display_name="Cliente Teste"))
    await test_database.execute(UserDocument.__table__.insert().values(user_id=user_id, type="cpf", number="529.982.247-25"))
    return user_id


@pytest.fixture
def dpe(monkeypatch):
    provider = AsyncMock()
    provider.charge.return_value = {"status": "pending", "payment_id": "pay_opaque", "gateway": "stone",
        "gateway_id": "ch_provider", "amount": 25.0, "currency": "BRL", "created_at": "2026-11-02T12:00:00",
        "pix_copia_e_cola": "sandbox_payload"}
    monkeypatch.setattr(routes, "database", test_database)
    monkeypatch.setattr(routes, "get_dpe_client", lambda: provider)
    return provider


async def test_missing_customer_stops_before_provider(test_user_in_db, test_order_in_db, dpe):
    with pytest.raises(APIError) as error:
        await charge_order(test_database, dpe, test_user_in_db["id"], test_order_in_db["id"], {"type": "pix"})
    assert error.value.status_code == 422
    assert "document" in error.value.details
    dpe.charge.assert_not_called()


async def test_customer_uses_real_profile_and_normalized_cpf(payer):
    result = await customer_for_payment(test_database, payer)
    assert result["name"] == "Cliente Teste"
    assert result["document"] == "52998224725"
    assert result["email"] == "test@example.com"


async def test_charge_replay_one_provider_call(payer, test_order_in_db, dpe):
    args = (test_database, dpe, payer, test_order_in_db["id"], {"type": "pix"})
    first = await charge_order(*args, key="one-attempt")
    assert await charge_order(*args, key="one-attempt") == first
    assert dpe.charge.await_count == 1
    assert dpe.charge.call_args.kwargs["amount"] == Decimal("25.00")
    order = await test_database.fetch_one(Order.__table__.select().where(Order.id == test_order_in_db["id"]))
    assert order["payment_id"] == "pay_opaque"


@pytest.mark.parametrize("overrides", [{"expected_amount": 0.01}, {"expected_bar_id": 999999}, {"currency": "USD"}])
async def test_charge_rejects_client_tampering(payer, test_order_in_db, dpe, overrides):
    with pytest.raises(APIError) as error:
        await charge_order(test_database, dpe, payer, test_order_in_db["id"], {"type": "pix"}, **overrides)
    assert error.value.status_code == 422
    dpe.charge.assert_not_called()


async def test_charge_rejects_another_users_order(payer, test_order_in_db, dpe):
    await test_database.execute(Order.__table__.update().where(Order.id == test_order_in_db["id"]).values(user_id=999))
    with pytest.raises(APIError) as error:
        await charge_order(test_database, dpe, payer, test_order_in_db["id"], {"type": "pix"})
    assert error.value.status_code == 404
    dpe.charge.assert_not_called()


async def test_unknown_outcome_retries_same_provider_key(payer, test_order_in_db, dpe):
    result = dpe.charge.return_value
    dpe.charge.side_effect = [httpx.ReadTimeout("unknown"), result]
    args = (test_database, dpe, payer, test_order_in_db["id"], {"type": "pix"})
    with pytest.raises(APIError) as error:
        await charge_order(*args, key="same")
    assert error.value.status_code == 504
    with pytest.raises(APIError) as conflict:
        await charge_order(*args, key="different")
    assert conflict.value.status_code == 409
    await charge_order(*args, key="same")
    assert dpe.charge.call_args_list[0].kwargs["idempotency_key"] == dpe.charge.call_args_list[1].kwargs["idempotency_key"]


async def test_saved_card_resolves_owned_durable_reference(payer, test_order_in_db, dpe):
    card_id = await test_database.execute(PaymentCard.__table__.insert().values(user_id=payer, card_token="card_real",
        last_four="4242", brand="Visa", exp_month=12, exp_year=2030, is_default=0))
    await charge_order(test_database, dpe, payer, test_order_in_db["id"], {"type": "card", "payment_method_id": card_id})
    assert dpe.charge.call_args.kwargs["payment_method"]["card_id"] == "card_real"
    assert "token" not in dpe.charge.call_args.kwargs["payment_method"]


async def test_status_does_not_disclose_unowned_payment(client, auth_headers, dpe):
    response = await client.get("/payments/v2/pay_other", headers=auth_headers)
    assert response.status_code == 404
    dpe.get_payment.assert_not_called()


async def test_confirmed_failure_allows_new_attempt_after_status_refresh(client, auth_headers, payer, test_order_in_db, dpe):
    args = (test_database, dpe, payer, test_order_in_db["id"], {"type": "pix"})
    await charge_order(*args, key="attempt-one")
    dpe.get_payment.return_value = {"status": "found", "payment_status": "failed", "payment_id": "pay_opaque",
        "amount": 25, "currency": "BRL", "gateway": "stone", "created_at": "2026-11-03T00:00:00"}
    response = await client.get("/payments/v2/pay_opaque", headers=auth_headers)
    assert response.status_code == 200, response.text
    assert response.json()["status"] == "failed"
    await charge_order(*args, key="attempt-two")
    assert dpe.charge.await_count == 2


@pytest.fixture
async def cart_ready(payer, test_bar_in_db, monkeypatch):
    from app.bars_and_restaurants.routes import cart
    from app.bars_and_restaurants.services import discounts, pro_coupon_service
    monkeypatch.setattr(cart, "database", test_database)
    monkeypatch.setattr(cart, "require_active_checkin", AsyncMock(return_value={"table_number": "5"}))
    monkeypatch.setattr(discounts, "calculate_progressive_discount", AsyncMock(return_value={"percentage": 0}))
    monkeypatch.setattr(pro_coupon_service, "validate_and_partition_promotions", AsyncMock(return_value={
        "discount_amount": Decimal(0), "cashback_amount": Decimal(0), "accepted_promotion_ids": []}))
    monkeypatch.setattr(pro_coupon_service, "reserve_coupons_for_order", AsyncMock())
    menu_id = await test_database.execute(Menu.__table__.insert().values(bar_id=test_bar_in_db["id"], name="Menu", is_active=True))
    item_id = await test_database.execute(MenuItem.__table__.insert().values(menu_id=menu_id, name="Real price", price=20, available=True))
    cart_id = await test_database.execute(Cart.__table__.insert().values(user_id=payer, created_at=datetime.utcnow(), updated_at=datetime.utcnow()))
    await test_database.execute(CartItem.__table__.insert().values(cart_id=cart_id, menu_item_id=item_id,
        bar_id=test_bar_in_db["id"], menu_item_name="Client name", quantity=1, unit_price=0.01))
    return cart_id


async def test_deferred_checkout_resume_and_retry_preserve_one_order(client, auth_headers, payer, cart_ready, dpe, monkeypatch):
    from app.bars_and_restaurants.routes import cart
    monkeypatch.setattr(cart, "get_dpe_client", lambda: dpe)
    body = {"order_type": "dine_in", "payment_method": "pix", "defer_payment": True}
    headers = {**auth_headers, "X-Idempotency-Key": "checkout-one"}
    first = await client.post("/cart/checkout", json=body, headers=headers)
    assert first.status_code == 201, first.text
    data = first.json()
    assert data["total"] == 22.0
    assert data["items"][0]["menu_item_name"] == "Real price"
    dpe.charge.assert_not_called()
    replay = await client.post("/cart/checkout", json=body, headers=headers)
    assert replay.status_code == 201, replay.text
    assert replay.json()["order_id"] == data["order_id"]
    pending = await client.get("/cart/checkout/pending", headers=auth_headers)
    assert pending.json()["order_id"] == data["order_id"]
    assert pending.json()["bar_id"] == data["bar_id"]
    assert len(await test_database.fetch_all(Order.__table__.select())) == 1


async def test_missing_document_keeps_cart_and_creates_no_order(client, auth_headers, payer, cart_ready, dpe):
    await test_database.execute(UserDocument.__table__.delete().where(UserDocument.user_id == payer))
    response = await client.post("/cart/checkout", json={"order_type": "dine_in", "payment_method": "pix", "defer_payment": True},
        headers={**auth_headers, "X-Idempotency-Key": "missing-profile"})
    assert response.status_code == 422
    assert await test_database.fetch_all(CartItem.__table__.select())
    assert not await test_database.fetch_all(Order.__table__.select())
    assert not await test_database.fetch_all(IdempotencyKey.__table__.select())
    dpe.charge.assert_not_called()


async def test_checkout_preserves_location_selected_after_checkin(client, auth_headers, payer, cart_ready, dpe, monkeypatch):
    from app.bars_and_restaurants.routes import cart
    monkeypatch.setattr(cart, "require_active_checkin", AsyncMock(return_value={"table_number": None}))
    response = await client.post("/cart/checkout", json={"order_type": "dine_in", "payment_method": "pix",
        "defer_payment": True, "location_identifier": " 7 "},
        headers={**auth_headers, "X-Idempotency-Key": "late-table"})
    assert response.status_code == 201, response.text
    order = await test_database.fetch_one(Order.__table__.select().where(Order.id == response.json()["order_id"]))
    assert order["location_identifier"] == "7"


@pytest.mark.parametrize("incoming,expected", [("pending", "pending"), ("authorized", "pending"), ("succeeded", "paid")])
async def test_webhook_preserves_payment_states(client, test_order_in_db, dpe, incoming, expected):
    from app.payment.dpe_client import DPE_SERVICE_SECRET
    await test_database.execute(Order.__table__.update().where(Order.id == test_order_in_db["id"]).values(
        payment_id="pay_bound", payment_status="pending"))
    response = await client.post("/payments/webhook", json={"event": "payment.updated", "payment_id": "pay_bound",
        "order_id": str(test_order_in_db["id"]), "status": incoming, "amount_cents": 2500, "currency": "BRL"},
        headers={"X-Service-Auth": DPE_SERVICE_SECRET})
    assert response.status_code == 200, response.text
    order = await test_database.fetch_one(Order.__table__.select().where(Order.id == test_order_in_db["id"]))
    assert order["payment_status"] == expected


async def test_webhook_recovers_success_after_failed_and_preserves_paid(client, test_order_in_db, dpe):
    from app.payment.dpe_client import DPE_SERVICE_SECRET
    await test_database.execute(Order.__table__.update().where(Order.id == test_order_in_db["id"]).values(
        payment_id="pay_bound", payment_status="failed", status="preparing"))
    body = {"event": "payment.updated", "payment_id": "pay_bound", "order_id": str(test_order_in_db["id"]), "status": "succeeded"}
    headers = {"X-Service-Auth": DPE_SERVICE_SECRET}
    assert (await client.post("/payments/webhook", json=body, headers=headers)).status_code == 200
    body["status"] = "failed"
    await client.post("/payments/webhook", json=body, headers=headers)
    order = await test_database.fetch_one(Order.__table__.select().where(Order.id == test_order_in_db["id"]))
    assert order["payment_status"] == "paid"
    assert order["status"] == "preparing"


async def test_webhook_rejects_cross_payment_confirmation(client, test_order_in_db, dpe):
    from app.payment.dpe_client import DPE_SERVICE_SECRET
    await test_database.execute(Order.__table__.update().where(Order.id == test_order_in_db["id"]).values(
        payment_id="pay_bound", payment_status="pending"))
    response = await client.post("/payments/webhook", json={"event": "payment.succeeded", "payment_id": "pay_other",
        "order_id": str(test_order_in_db["id"]), "status": "succeeded"}, headers={"X-Service-Auth": DPE_SERVICE_SECRET})
    assert response.status_code == 409
    order = await test_database.fetch_one(Order.__table__.select().where(Order.id == test_order_in_db["id"]))
    assert order["payment_status"] == "pending"


async def test_immediate_payment_rewards_reconcile_once(payer, test_order_in_db, dpe):
    from app.bars_and_restaurants.models.wallet_models import ProCouponUsage, ProCouponStatus, CashbackLedger, UserWallet
    from app.payment.order_payments import settle_order_rewards
    now = datetime.utcnow()
    await test_database.execute(ProCouponUsage.__table__.insert().values(user_id=payer,
        bar_id=test_order_in_db["bar_id"], order_id=test_order_in_db["id"], period_key="2026-11",
        status=ProCouponStatus.RESERVED, cashback_amount=Decimal("2.50"), created_at=now, updated_at=now))
    dpe.charge.return_value = {**dpe.charge.return_value, "status": "succeeded"}
    await charge_order(test_database, dpe, payer, test_order_in_db["id"], {"type": "pix"})
    await settle_order_rewards(test_database, test_order_in_db)
    entries = await test_database.fetch_all(CashbackLedger.__table__.select())
    assert len(entries) == 1
    wallet = await test_database.fetch_one(UserWallet.__table__.select().where(UserWallet.user_id == payer))
    assert Decimal(str(wallet["pending_balance"])) == Decimal("2.50")
    reservation = await test_database.fetch_one(ProCouponUsage.__table__.select())
    assert reservation["status"] == ProCouponStatus.REDEEMED
