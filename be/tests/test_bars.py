import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestBarOwners:
    async def test_create_bar_owner(self, client: AsyncClient):
        response = await client.post("/barowners/", json={
            "id": 12345,
            "name": "John Owner",
            "email": "john@owner.com",
            "phone_number": "+1234567890"
        })
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == 12345
        assert data["name"] == "John Owner"
        assert data["email"] == "john@owner.com"

    async def test_create_duplicate_bar_owner_fails(self, client: AsyncClient):
        owner_data = {
            "id": 99999,
            "name": "Duplicate Owner",
            "email": "dup@owner.com",
            "phone_number": "+9876543210"
        }
        response1 = await client.post("/barowners/", json=owner_data)
        assert response1.status_code == 200
        response2 = await client.post("/barowners/", json=owner_data)
        assert response2.status_code == 409
        assert response2.json()["error_code"] == "CONFLICT"
        assert "already exists" in response2.json()["message"].lower()


@pytest.mark.asyncio
class TestBars:
    async def test_get_bar_by_id(self, client: AsyncClient, test_bar_in_db):
        response = await client.get(f"/bars/{test_bar_in_db['id']}")
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == test_bar_in_db["id"]
        assert data["name"] == test_bar_in_db["name"]

    async def test_get_bar_not_found(self, client: AsyncClient):
        response = await client.get("/bars/999999")
        assert response.status_code == 404
