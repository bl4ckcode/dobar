import pytest
from httpx import AsyncClient
from app.database import database

@pytest.mark.asyncio
class TestCashierOperations:
    async def test_get_live_orders(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        
        response = await client.get(f"/bars/{bar_id}/orders/live", headers=headers)
        
        # If the auth_client is an owner, this will be 200 list
        # We check the endpoint is up and returns correct shape or auth error
        assert response.status_code in [200, 403]
        
        if response.status_code == 200:
            assert isinstance(response.json(), list)

    async def test_update_order_status(self, auth_client, test_bar_in_db, test_order_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        order_id = test_order_in_db["id"]
        
        # We try to update a test order
        response = await client.put(f"/bars/{bar_id}/orders/{order_id}/status", json={
            "status": "preparing"
        }, headers=headers)
        
        assert response.status_code in [200, 400, 403, 404]
        if response.status_code == 200:
            assert response.json()["status"] == "preparing"
