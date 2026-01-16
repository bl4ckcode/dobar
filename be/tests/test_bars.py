import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestBarOwners:
    async def test_create_bar_owner(self, auth_client):
        client, headers, _ = auth_client
        response = await client.post("/barowners/", json={
            "id": 12345,
            "name": "John Owner",
            "email": "john@owner.com",
            "phone_number": "+1234567890"
        }, headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == 12345
        assert data["name"] == "John Owner"
        assert data["email"] == "john@owner.com"

    async def test_create_duplicate_bar_owner_fails(self, auth_client):
        client, headers, _ = auth_client
        owner_data = {
            "id": 99999,
            "name": "Duplicate Owner",
            "email": "dup@owner.com",
            "phone_number": "+9876543210"
        }
        response1 = await client.post("/barowners/", json=owner_data, headers=headers)
        assert response1.status_code == 200
        response2 = await client.post("/barowners/", json=owner_data, headers=headers)
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


@pytest.mark.asyncio
class TestBulkMenuItems:
    async def test_bulk_create_menu_items(self, auth_client, test_menu_in_db):
        client, headers, _ = auth_client
        menu_id = test_menu_in_db["id"]
        items = [
            {"name": "Item 1", "price": 10.50, "description": "First item", "category": "Drinks", "available": True},
            {"name": "Item 2", "price": 15.00, "description": "Second item", "category": "Food", "available": True},
            {"name": "Item 3", "price": 8.25, "description": "Third item", "category": "Drinks", "available": False}
        ]
        response = await client.post(f"/menus/{menu_id}/items/bulk", json={"items": items}, headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["created_count"] == 3
        assert len(data["items"]) == 3
        assert data["items"][0]["name"] == "Item 1"
        assert data["items"][0]["price"] == 10.50
        assert data["items"][1]["category"] == "Food"

    async def test_bulk_create_empty_list_fails(self, auth_client, test_menu_in_db):
        client, headers, _ = auth_client
        menu_id = test_menu_in_db["id"]
        response = await client.post(f"/menus/{menu_id}/items/bulk", json={"items": []}, headers=headers)
        assert response.status_code == 422

    async def test_bulk_create_menu_not_found(self, auth_client):
        client, headers, _ = auth_client
        items = [{"name": "Item 1", "price": 10.50}]
        response = await client.post("/menus/999999/items/bulk", json={"items": items}, headers=headers)
        assert response.status_code == 404

    async def test_bulk_create_requires_auth(self, client: AsyncClient, test_menu_in_db):
        menu_id = test_menu_in_db["id"]
        items = [{"name": "Item 1", "price": 10.50}]
        response = await client.post(f"/menus/{menu_id}/items/bulk", json={"items": items})
        assert response.status_code in [401, 403]
