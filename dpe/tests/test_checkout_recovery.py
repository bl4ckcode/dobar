from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from dobar_payment.api import routes
from dobar_payment.api.app import create_app
from dobar_payment.api.dependencies import GatewayRegistry, InMemoryPaymentStore
from dobar_payment.api.schemas import ChargeRequestAPI, SaveCardRequestAPI
from dobar_payment.core.webhooks import WebhookPayload
from dobar_payment.gateways.stone import APIException, StonePaymentGateway


@pytest.fixture
def gateway():
    with patch("dobar_payment.gateways.stone._get_pagarme_client", return_value=MagicMock()):
        return StonePaymentGateway({"PAGARME_USERNAME": "test"})


@pytest.fixture
def store(monkeypatch):
    store = InMemoryPaymentStore()
    registry = GatewayRegistry()
    monkeypatch.setattr(routes, "payment_store", store)
    monkeypatch.setattr(routes, "gateway_registry", registry)
    return store, registry


def customer():
    return {"name": "Cliente", "email": "cliente@example.com", "document": "12345678901"}


def charge_request(**changes):
    return ChargeRequestAPI.model_validate(
        {
            "order_id": "42",
            "user_id": "7",
            "bar_id": "3",
            "amount_cents": 29,
            "payment_method": {"type": "pix"},
            "customer_info": customer(),
            "idempotency_key": "checkout-42",
            **changes,
        }
    )


@pytest.mark.asyncio
async def test_pix_passes_exact_cents_method_and_provider_idempotency(gateway):
    response = SimpleNamespace(id="or_1", status="pending", amount=29, charges=[])
    gateway._run_sync = AsyncMock(return_value=response)
    result = await gateway.create_charge(
        amount=0.29,
        currency="BRL",
        customer=customer(),
        payment_method={"type": "pix"},
        idempotency_key="attempt-1",
        amount_cents=29,
        metadata={"order_id": "42"},
    )
    request = gateway._run_sync.call_args.args[1]
    assert request.items[0].amount == 29
    assert request.payments[0].payment_method == "pix"
    assert request.code == "42"
    assert request.metadata == {"order_id": "42"}
    assert gateway._run_sync.call_args.kwargs["idempotency_key"] == "attempt-1"
    assert result["status"] == "pending"


@pytest.mark.asyncio
async def test_saved_card_registers_real_reference_without_pan(gateway):
    gateway._run_sync = AsyncMock(
        side_effect=[
            SimpleNamespace(data=[]),
            SimpleNamespace(id="cus_1"),
            SimpleNamespace(
                id="card_1", brand="visa", last_four_digits="1234", exp_month=12, exp_year=2030
            ),
        ]
    )
    result = await gateway.save_card("7", "token_abc", customer(), "save-7")
    customer_model = gateway._run_sync.call_args_list[1].args[1]
    card_model = gateway._run_sync.call_args_list[2].args[2]
    assert customer_model.code == "dobar_user_7"
    assert customer_model.address is None
    assert card_model.token == "token_abc"
    assert not hasattr(card_model, "number")
    assert result["card_id"] == "card_1"
    assert result["customer_id"] == "cus_1"
    assert "token" not in result


@pytest.mark.asyncio
async def test_saved_provider_customer_survives_email_change(gateway):
    gateway._run_sync = AsyncMock(side_effect=[
        SimpleNamespace(data=[SimpleNamespace(id="cus_original")]),
        SimpleNamespace(id="cus_original"),
    ])
    model = gateway._build_customer({**customer(), "code": "dobar_user_7"})
    result = await gateway._provider_customer(model, "attempt-1")
    assert result.id == "cus_original"
    assert gateway._run_sync.call_args_list[0].kwargs["code"] == "dobar_user_7"
    assert gateway._run_sync.call_args.args[1] == "cus_original"
    assert gateway._run_sync.call_args.args[2].email == customer()["email"]


@pytest.mark.asyncio
async def test_card_charge_uses_provider_customer_and_card(gateway):
    gateway._run_sync = AsyncMock(
        side_effect=[
            SimpleNamespace(id="cus_1"),
            SimpleNamespace(id="or_1", status="paid", charges=[]),
        ]
    )
    result = await gateway.create_charge(
        amount=20,
        currency="BRL",
        customer=customer(),
        payment_method={"type": "card", "card_id": "card_1"},
        idempotency_key="attempt-1",
    )
    request = gateway._run_sync.call_args.args[1]
    assert request.customer_id == "cus_1"
    assert request.customer is None
    assert request.payments[0].credit_card.card_id == "card_1"
    assert result["status"] == "succeeded"


def test_legacy_token_maps_to_provider_card_token(gateway):
    assert gateway._build_credit_card({"token": "token_abc"}).card_token == "token_abc"


@pytest.mark.asyncio
async def test_psp_rejects_missing_customer_data_without_provider_call(gateway, monkeypatch):
    monkeypatch.setenv("PAGARME_ACCOUNT_TYPE", "psp")
    gateway._run_sync = AsyncMock()
    result = await gateway.create_charge(
        amount=20, currency="BRL", customer=customer(), payment_method={"type": "pix"}
    )
    assert result["error_code"] == "VALIDATION_ERROR"
    gateway._run_sync.assert_not_called()


@pytest.mark.asyncio
async def test_charge_caches_exact_retry_and_rejects_different_amount(store):
    payment_store, registry = store
    provider = SimpleNamespace(
        create_charge=AsyncMock(
            return_value={
                "status": "pending",
                "charge_id": "ch_1",
                "transaction_id": "tx_1",
                "order_id": "or_1",
            }
        )
    )
    registry.register("stone", provider)
    first, status = await routes.PaymentRoutes.create_charge(charge_request())
    second, _ = await routes.PaymentRoutes.create_charge(charge_request())
    conflict, conflict_status = await routes.PaymentRoutes.create_charge(
        charge_request(amount_cents=30)
    )
    assert status == 200
    assert first.payment_id == second.payment_id
    assert first.gateway_id == "ch_1"
    assert conflict_status == 409
    assert conflict.error_code == "IDEMPOTENCY_CONFLICT"
    assert provider.create_charge.await_count == 1
    assert provider.create_charge.call_args.kwargs["amount_cents"] == 29
    assert payment_store.get_payment(first.payment_id)["gateway_order_id"] == "or_1"


@pytest.mark.asyncio
async def test_card_api_keeps_one_use_token_out_of_saved_response(store):
    _, registry = store
    provider = SimpleNamespace(
        save_card=AsyncMock(
            return_value={
                "card_id": "card_1",
                "customer_id": "cus_1",
                "brand": "visa",
                "last_four": "1234",
                "exp_month": 12,
                "exp_year": 2030,
            }
        )
    )
    registry.register("stone", provider)
    request = SaveCardRequestAPI(
        user_id="7", token="token_abc", customer_info=customer(), idempotency_key="save-7"
    )
    response, status = await routes.PaymentRoutes.save_card(request)
    replay, _ = await routes.PaymentRoutes.save_card(request)
    assert status == 200
    assert response.card_id == replay.card_id == "card_1"
    assert "token" not in response.model_dump()
    assert provider.save_card.await_count == 1


@pytest.mark.asyncio
async def test_polling_refreshes_pending_pix_from_provider(store):
    payment_store, registry = store
    registry.register(
        "stone", SimpleNamespace(get_charge=AsyncMock(return_value={"status": "succeeded"}))
    )
    payment_store.store_payment(
        "pay_1",
        {
            "payment_id": "pay_1",
            "status": "pending",
            "gateway": "stone",
            "gateway_id": "ch_1",
            "amount_cents": 29,
            "currency": "BRL",
            "created_at": datetime.now(timezone.utc).isoformat(),
        },
    )
    response, status = await routes.PaymentRoutes.get_payment("pay_1")
    assert status == 200
    assert response.status == "succeeded"


def test_validation_errors_never_log_or_return_payment_input(caplog):
    app = create_app(enable_auth=False, gateways={})
    client = TestClient(app)
    sensitive = "token_sensitive"
    response = client.post(
        "/cards",
        json={
            "user_id": "7",
            "token": sensitive,
            "customer_info": {
                "name": "Cliente",
                "email": "invalid-sensitive-email",
                "document": "private",
            },
            "idempotency_key": "save",
        },
    )
    assert response.status_code == 422
    assert sensitive not in response.text + caplog.text
    assert "invalid-sensitive-email" not in response.text + caplog.text


def test_new_card_endpoint_requires_service_auth():
    client = TestClient(create_app(gateways={}))
    response = client.post("/cards", json={})
    assert response.status_code == 401


@pytest.mark.asyncio
@pytest.mark.parametrize("operation", ["charge", "save", "status"])
async def test_provider_exception_never_reveals_card_reference(gateway, operation, caplog):
    gateway._run_sync = AsyncMock(side_effect=APIException(
        "Rejected token_sensitive with private provider request", SimpleNamespace(status_code=422),
    ))
    if operation == "charge":
        result = await gateway.create_charge(
            amount=20, currency="BRL", customer=customer(), payment_method={"type": "pix"},
        )
    elif operation == "save":
        result = await gateway.save_card("7", "token_sensitive", customer(), "save-7")
    else:
        result = await gateway.get_charge("ch_private")
    assert result["status"] == "error"
    assert result["error_code"] == "VALIDATION_ERROR"
    assert "sensitive" not in str(result) + caplog.text
    assert "private" not in str(result) + caplog.text


@pytest.mark.asyncio
async def test_verified_webhook_resolves_dpe_payment_and_updates_polling(store):
    payment_store, _ = store
    payment_store.store_payment(
        "pay_1",
        {
            "payment_id": "pay_1",
            "status": "pending",
            "gateway": "stone",
            "gateway_id": "ch_1",
            "order_id": "42",
            "amount_cents": 29,
        },
    )
    payload = WebhookPayload(
        "stone",
        "charge.paid",
        "wh_1",
        datetime.now(timezone.utc),
        {"id": "ch_1", "amount": 29},
        b"{}",
        {},
    )
    with (
        patch("dobar_payment.core.webhooks.WebhookHandler.handle", return_value=payload),
        patch("httpx.AsyncClient.post", new_callable=AsyncMock) as post,
    ):
        post.return_value = MagicMock()
        response, status = await routes.WebhookRoutes.process_gateway_webhook("stone", b"{}", {})
    assert status == 200
    assert response["status"] == "processed"
    assert post.call_args.kwargs["json"]["payment_id"] == "pay_1"
    assert post.call_args.kwargs["json"]["order_id"] == "42"
    assert payment_store.get_payment("pay_1")["status"] == "succeeded"
