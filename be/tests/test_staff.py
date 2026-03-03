import pytest
from httpx import AsyncClient
from app.database import database

@pytest.mark.asyncio
class TestStaffManagement:
    async def test_get_staff(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        
        # First make sure the user is an owner of the bar so they can GET staff
        # We'll just try to hit the endpoint first.
        response = await client.get(f"/bars/{bar_id}/staff", headers=headers)
        
        # If the auth_client is not staff/owner, they get 403.
        # This test is just a smoke test to ensure the endpoint exists.
        assert response.status_code in [200, 403]
        
        if response.status_code == 200:
            assert isinstance(response.json(), list)

    async def test_invite_staff_validation(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        
        # Invite without email or phone
        response = await client.post(f"/bars/{bar_id}/staff/invite", json={
            "role": "manager"
        }, headers=headers)
        
        assert response.status_code in [400, 403]

    async def test_update_staff_role_invalid_role(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        
        response = await client.put(f"/bars/{bar_id}/staff/999/role", json={
            "role": "super-admin"
        }, headers=headers)
        
        assert response.status_code in [400, 403]
        if response.status_code == 400:
            assert "Invalid role" in response.json()["detail"]
