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
        assert response.json()["error_code"] == "CART_EMPTY"

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
        assert response.json()["error_code"] == "BAD_REQUEST"
        assert "same bar" in response.json()["message"].lower()

    async def test_checkout_pix_returns_pix_fields(self, auth_client, test_bar_in_db):
        """Test that PIX checkout returns pix_qr_code, pix_copia_e_cola, and pix_expires_at fields."""
        client, headers, user = auth_client
        
        from app.auth.rbac_models import UserProfile
        from app.bars_and_restaurants.models.relational_models import UserDocument, Menu, MenuItem
        from conftest import test_database
        from unittest.mock import AsyncMock
        await test_database.execute(UserProfile.__table__.insert().values(user_id=user["id"], display_name="Cliente Teste"))
        await test_database.execute(UserDocument.__table__.insert().values(user_id=user["id"], type="cpf", number="52998224725"))
        menu_id = await test_database.execute(Menu.__table__.insert().values(bar_id=test_bar_in_db["id"], name="Menu", is_active=True))
        item_id = await test_database.execute(MenuItem.__table__.insert().values(menu_id=menu_id, name="PIX Test Item", price=10, available=True))
        await client.post("/cart/items", json={
            "menu_item_id": item_id, "bar_id": test_bar_in_db["id"], "menu_item_name": "PIX Test Item",
            "quantity": 1, "unit_price": 10.00,
        }, headers=headers)

        # Mock DPE client to return PIX payment data
        class MockDPEClient:
            async def charge(self, **kwargs):
                return {
                    "status": "pending",
                    "payment_id": "pay_pix_test_123",
                    "gateway": "pagarme",
                    "gateway_id": "ch_pix_123",
                    "amount": 10.00,
                    "currency": "BRL",
                    "created_at": "2026-01-01T00:00:00Z",
                    "pix_qr_code": "00020126...PIX_CODE...6304XXXX",
                    "pix_copia_e_cola": "00020126...PIX_COPIA_E_COLA...6304XXXX",
                    "pix_qr_code_url": "https://api.pagarme.com/pix/qr/123.png",
                    "pix_expires_at": "2026-01-01T01:00:00Z",
                }
        
        from unittest.mock import patch
        with patch("app.bars_and_restaurants.routes.cart.get_dpe_client", return_value=MockDPEClient()), patch("app.bars_and_restaurants.routes.cart.require_active_checkin", AsyncMock(return_value={"table_number": "5"})):
            checkout_data = {
                "order_type": "pickup",
                "payment_method": "pix"
            }
            response = await client.post("/cart/checkout", json=checkout_data, headers=headers)
        
        assert response.status_code == 201
        data = response.json()
        assert data["payment_status"] == "pending"  # PIX stays pending until webhook confirms
        assert data["pix_qr_code"] == "00020126...PIX_CODE...6304XXXX"
        assert data["pix_copia_e_cola"] == "00020126...PIX_COPIA_E_COLA...6304XXXX"
        assert data["pix_expires_at"] == "2026-01-01T01:00:00Z"
        assert data["payment_id"] == "pay_pix_test_123"
