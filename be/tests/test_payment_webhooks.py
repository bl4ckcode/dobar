import pytest
from httpx import AsyncClient
from app.bars_and_restaurants.models.relational_models import Order as OrderModel
from app.bars_and_restaurants.models.cart_models import OrderStatusHistory as OrderStatusHistoryModel
from app.database import database
from app.payment.dpe_client import DPE_SERVICE_SECRET

# Re-use fixtures from conftest, so we don't define user/bar fixtures if they already exist
# The tests are marked asyncio

pytestmark = pytest.mark.asyncio

async def test_webhook_unauthorized(client: AsyncClient):
    payload = {
        "event": "payment.succeeded",
        "payment_id": "pay_test_123",
        "order_id": "1",
        "status": "succeeded"
    }
    response = await client.post(
        "/payments/webhook",
        json=payload,
        headers={"X-Service-Auth": "wrong-secret"}
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Unauthorized webhook"


async def test_webhook_order_not_found(client: AsyncClient):
    payload = {
        "event": "payment.succeeded",
        "payment_id": "pay_test_123",
        "order_id": "999999",
        "status": "succeeded"
    }
    response = await client.post(
        "/payments/webhook",
        json=payload,
        headers={"X-Service-Auth": DPE_SERVICE_SECRET}
    )
    assert response.status_code == 200
    assert response.json() == {"status": "ignored", "reason": "order_not_found"}


async def test_webhook_success_updates_order(client: AsyncClient, test_user, test_bar):
    # Insert an order manually
    insert_query = OrderModel.__table__.insert().values(
        user_id=test_user.id,
        bar_id=test_bar.id,
        status="pending",
        payment_status="pending",
        total_price=50.0
    )
    order_id = await database.execute(insert_query)
    
    payload = {
        "event": "payment.succeeded",
        "payment_id": "pay_webhook_test",
        "order_id": str(order_id),
        "status": "succeeded"
    }
    
    response = await client.post(
        "/payments/webhook",
        json=payload,
        headers={"X-Service-Auth": DPE_SERVICE_SECRET}
    )
    assert response.status_code == 200
    assert response.json() == {"status": "processed", "payment_status": "paid"}
    
    # Check DB
    query = OrderModel.__table__.select().where(OrderModel.id == order_id)
    updated_order = await database.fetch_one(query)
    
    assert updated_order["payment_status"] == "paid"
    assert updated_order["payment_id"] == "pay_webhook_test"
    assert updated_order["status"] == "confirmed"


async def test_webhook_already_processed(client: AsyncClient, test_user, test_bar):
    # Insert an order manually that's already paid
    insert_query = OrderModel.__table__.insert().values(
        user_id=test_user.id,
        bar_id=test_bar.id,
        status="confirmed",
        payment_status="paid",
        payment_id="pay_old",
        total_price=50.0
    )
    order_id = await database.execute(insert_query)
    
    payload = {
        "event": "payment.succeeded",
        "payment_id": "pay_old",
        "order_id": str(order_id),
        "status": "succeeded"
    }
    
    response = await client.post(
        "/payments/webhook",
        json=payload,
        headers={"X-Service-Auth": DPE_SERVICE_SECRET}
    )
    assert response.status_code == 200
    assert response.json() == {"status": "ignored", "reason": "already_processed"}


async def test_webhook_payment_failed(client: AsyncClient, test_user, test_bar):
    # Insert an order manually
    insert_query = OrderModel.__table__.insert().values(
        user_id=test_user.id,
        bar_id=test_bar.id,
        status="pending",
        payment_status="pending",
        total_price=50.0
    )
    order_id = await database.execute(insert_query)
    
    payload = {
        "event": "payment.failed",
        "payment_id": "pay_fail_test",
        "order_id": str(order_id),
        "status": "failed"
    }
    
    response = await client.post(
        "/payments/webhook",
        json=payload,
        headers={"X-Service-Auth": DPE_SERVICE_SECRET}
    )
    assert response.status_code == 200
    assert response.json() == {"status": "processed", "payment_status": "failed"}
    
    # Check DB
    query = OrderModel.__table__.select().where(OrderModel.id == order_id)
    updated_order = await database.fetch_one(query)
    
    assert updated_order["payment_status"] == "failed"
    assert updated_order["payment_id"] == "pay_fail_test"
    assert updated_order["status"] == "pending"  # Should remain pending
