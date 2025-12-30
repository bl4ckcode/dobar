import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
class TestCartCRUD:
    async def test_get_empty_cart(self, auth_client):
        client, headers, user = auth_client
        response = await client.get("/cart/", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert "id" in data
        assert data["total_items"] == 0
        assert data["subtotal"] == 0.0
        assert data["items"] == []

    async def test_add_item_to_cart(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        cart_item = {
            "menu_item_id": 1,
            "bar_id": test_bar_in_db["id"],
            "menu_item_name": "Test Burger",
            "quantity": 2,
            "unit_price": 12.99
        }
        response = await client.post("/cart/items", json=cart_item, headers=headers)
        assert response.status_code == 201
        data = response.json()
        assert data["menu_item_name"] == "Test Burger"
        assert data["quantity"] == 2
        assert data["unit_price"] == 12.99

    async def test_add_duplicate_item_increases_quantity(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        cart_item = {
            "menu_item_id": 10,
            "bar_id": test_bar_in_db["id"],
            "menu_item_name": "Test Pizza",
            "quantity": 1,
            "unit_price": 15.99
        }
        await client.post("/cart/items", json=cart_item, headers=headers)
        response = await client.post("/cart/items", json=cart_item, headers=headers)
        assert response.status_code == 201
        assert response.json()["quantity"] == 2

    async def test_get_cart_with_items(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        cart_item = {
            "menu_item_id": 20,
            "bar_id": test_bar_in_db["id"],
            "menu_item_name": "Test Drink",
            "quantity": 3,
            "unit_price": 5.00
        }
        await client.post("/cart/items", json=cart_item, headers=headers)
        response = await client.get("/cart/", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["total_items"] == 3
        assert data["subtotal"] == 15.0

    async def test_update_cart_item_quantity(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        cart_item = {
            "menu_item_id": 30,
            "bar_id": test_bar_in_db["id"],
            "menu_item_name": "Updatable Item",
            "quantity": 1,
            "unit_price": 10.00
        }
        create_response = await client.post("/cart/items", json=cart_item, headers=headers)
        item_id = create_response.json()["id"]
        response = await client.put(f"/cart/items/{item_id}", json={"quantity": 5}, headers=headers)
        assert response.status_code == 200
        assert response.json()["quantity"] == 5

    async def test_remove_cart_item(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        cart_item = {
            "menu_item_id": 40,
            "bar_id": test_bar_in_db["id"],
            "menu_item_name": "Deletable Item",
            "quantity": 1,
            "unit_price": 8.00
        }
        create_response = await client.post("/cart/items", json=cart_item, headers=headers)
        item_id = create_response.json()["id"]
        response = await client.delete(f"/cart/items/{item_id}", headers=headers)
        assert response.status_code == 204

    async def test_clear_cart(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        for i in range(3):
            await client.post("/cart/items", json={
                "menu_item_id": 50 + i,
                "bar_id": test_bar_in_db["id"],
                "menu_item_name": f"Item {i}",
                "quantity": 1,
                "unit_price": 10.00
            }, headers=headers)
        response = await client.delete("/cart/", headers=headers)
        assert response.status_code == 204
        cart_response = await client.get("/cart/", headers=headers)
        assert cart_response.json()["total_items"] == 0


@pytest.mark.asyncio
class TestCheckout:
    async def test_checkout_empty_cart_fails(self, auth_client):
        client, headers, user = auth_client
        checkout_data = {
            "order_type": "pickup",
            "payment_method": "credit_card"
        }
        response = await client.post("/cart/checkout", json=checkout_data, headers=headers)
        assert response.status_code == 400
        assert "empty" in response.json()["detail"].lower()

    async def test_checkout_mixed_bars_fails(self, auth_client, test_bar_in_db, second_test_bar_in_db):
        client, headers, user = auth_client
        
        await client.post("/cart/items", json={
            "menu_item_id": 100,
            "bar_id": test_bar_in_db["id"],
            "menu_item_name": "Item from Bar 1",
            "quantity": 1,
            "unit_price": 10.00
        }, headers=headers)
        
        await client.post("/cart/items", json={
            "menu_item_id": 101,
            "bar_id": second_test_bar_in_db["id"],
            "menu_item_name": "Item from Bar 2",
            "quantity": 1,
            "unit_price": 10.00
        }, headers=headers)
        
        checkout_data = {
            "order_type": "pickup",
            "payment_method": "credit_card"
        }
        response = await client.post("/cart/checkout", json=checkout_data, headers=headers)
        assert response.status_code == 400
        assert "same bar" in response.json()["detail"].lower()
