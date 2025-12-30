import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestOrderCreation:
    async def test_create_order(self, client: AsyncClient, test_user_in_db, test_bar_in_db):
        response = await client.post("/orders/", json={
            "user_id": test_user_in_db["id"],
            "bar_id": test_bar_in_db["id"],
            "order_type": "pickup",
            "payment_method": "credit_card",
            "subtotal": 20.00,
            "tax": 5.00,
            "total_price": 25.00
        })
        assert response.status_code == 200
        data = response.json()
        assert data["user_id"] == test_user_in_db["id"]
        assert data["bar_id"] == test_bar_in_db["id"]
        assert data["status"] == "pending"


@pytest.mark.asyncio
class TestOrderRetrieval:
    async def test_get_my_orders(self, auth_client, test_order_in_db):
        client, headers, user = auth_client
        response = await client.get("/orders/user/me", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert "orders" in data
        assert len(data["orders"]) >= 1
        assert data["orders"][0]["id"] == test_order_in_db["id"]

    async def test_get_my_orders_pagination(self, auth_client, test_order_in_db):
        client, headers, user = auth_client
        response = await client.get("/orders/user/me?page=1&page_size=5", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["page"] == 1
        assert data["page_size"] == 5

    async def test_get_order_by_id(self, auth_client, test_order_in_db):
        client, headers, user = auth_client
        response = await client.get(f"/orders/{test_order_in_db['id']}", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == test_order_in_db["id"]

    async def test_get_order_not_found(self, auth_client):
        client, headers, user = auth_client
        response = await client.get("/orders/999999", headers=headers)
        assert response.status_code == 404


@pytest.mark.asyncio
class TestOrderTimeline:
    async def test_get_order_timeline(self, auth_client, test_order_in_db):
        client, headers, user = auth_client
        response = await client.get(f"/orders/{test_order_in_db['id']}/timeline", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == test_order_in_db["id"]
        assert "status_history" in data


@pytest.mark.asyncio
class TestOrderCancellation:
    async def test_cancel_pending_order(self, auth_client, test_order_in_db):
        client, headers, user = auth_client
        response = await client.post(f"/orders/{test_order_in_db['id']}/cancel", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "cancelled"

    async def test_cancel_completed_order_fails(self, auth_client, test_completed_order_in_db):
        client, headers, user = auth_client
        response = await client.post(f"/orders/{test_completed_order_in_db['id']}/cancel", headers=headers)
        assert response.status_code == 400
        assert "cannot cancel" in response.json()["detail"].lower()


@pytest.mark.asyncio
class TestOrderStatusUpdate:
    async def test_update_order_status_valid_transition(self, auth_client, test_order_in_db):
        client, headers, user = auth_client
        response = await client.put(
            f"/orders/{test_order_in_db['id']}/status",
            json={"status": "confirmed"},
            headers=headers
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "confirmed"

    async def test_update_order_status_invalid_transition(self, auth_client, test_order_in_db):
        client, headers, user = auth_client
        response = await client.put(
            f"/orders/{test_order_in_db['id']}/status",
            json={"status": "completed"},
            headers=headers
        )
        assert response.status_code == 400
        assert "invalid status transition" in response.json()["detail"].lower()
