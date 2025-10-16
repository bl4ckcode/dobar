"""
Tests for cart endpoints.
"""

import pytest
from httpx import AsyncClient
from datetime import datetime
from unittest.mock import AsyncMock, MagicMock

from app.auth.auth_models import User
from app.bars_and_restaurants.models.cart_models import Cart, CartItem
from app.bars_and_restaurants.models.relational_models import Order, MenuItem, Bar


class TestCartCRUD:
    """Test cart CRUD operations."""
    
    @pytest.mark.asyncio
    async def test_get_empty_cart(self, client: AsyncClient, mock_firebase_token):
        """Test getting an empty cart creates a new cart."""
        response = await client.get(
            "/cart/",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert "id" in data
        assert data["total_items"] == 0
        assert data["subtotal"] == 0
        assert data["items"] == []
    
    @pytest.mark.asyncio
    async def test_add_item_to_cart(self, client: AsyncClient, mock_firebase_token, setup_database):
        """Test adding an item to the cart."""
        from app.database import database
        
        # Create a bar and menu item
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        menu_item_data = {
            "bar_id": bar_id,
            "name": "Test Burger",
            "description": "Delicious burger",
            "price": 12.99,
            "category": "Food"
        }
        menu_item_id = await database.execute(MenuItem.__table__.insert().values(**menu_item_data))
        
        # Add item to cart
        cart_item_payload = {
            "menu_item_id": menu_item_id,
            "bar_id": bar_id,
            "menu_item_name": "Test Burger",
            "quantity": 2,
            "unit_price": 12.99
        }
        
        response = await client.post(
            "/cart/items",
            json=cart_item_payload,
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 201
        data = response.json()
        assert data["menu_item_id"] == menu_item_id
        assert data["quantity"] == 2
        assert data["unit_price"] == 12.99
    
    @pytest.mark.asyncio
    async def test_add_duplicate_item_increases_quantity(self, client: AsyncClient, mock_firebase_token, setup_database):
        """Test adding the same item twice increases quantity."""
        from app.database import database
        
        # Create a bar and menu item
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        menu_item_data = {
            "bar_id": bar_id,
            "name": "Test Pizza",
            "description": "Delicious pizza",
            "price": 15.99,
            "category": "Food"
        }
        menu_item_id = await database.execute(MenuItem.__table__.insert().values(**menu_item_data))
        
        cart_item_payload = {
            "menu_item_id": menu_item_id,
            "bar_id": bar_id,
            "menu_item_name": "Test Pizza",
            "quantity": 1,
            "unit_price": 15.99
        }
        
        # Add item first time
        response1 = await client.post(
            "/cart/items",
            json=cart_item_payload,
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        assert response1.status_code == 201
        item_id = response1.json()["id"]
        
        # Add item second time
        response2 = await client.post(
            "/cart/items",
            json=cart_item_payload,
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        assert response2.status_code == 201
        data = response2.json()
        assert data["id"] == item_id  # Same item
        assert data["quantity"] == 2  # Quantity increased
    
    @pytest.mark.asyncio
    async def test_get_cart_with_items(self, client: AsyncClient, mock_firebase_token, setup_database):
        """Test getting a cart with items shows correct totals."""
        from app.database import database
        
        # Create bar and menu items
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        menu_item1_data = {
            "bar_id": bar_id,
            "name": "Burger",
            "description": "Burger",
            "price": 10.00,
            "category": "Food"
        }
        menu_item1_id = await database.execute(MenuItem.__table__.insert().values(**menu_item1_data))
        
        menu_item2_data = {
            "bar_id": bar_id,
            "name": "Fries",
            "description": "Fries",
            "price": 5.00,
            "category": "Food"
        }
        menu_item2_id = await database.execute(MenuItem.__table__.insert().values(**menu_item2_data))
        
        # Add items to cart
        await client.post(
            "/cart/items",
            json={
                "menu_item_id": menu_item1_id,
                "bar_id": bar_id,
                "menu_item_name": "Burger",
                "quantity": 2,
                "unit_price": 10.00
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        await client.post(
            "/cart/items",
            json={
                "menu_item_id": menu_item2_id,
                "bar_id": bar_id,
                "menu_item_name": "Fries",
                "quantity": 1,
                "unit_price": 5.00
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        # Get cart
        response = await client.get(
            "/cart/",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["total_items"] == 3  # 2 burgers + 1 fries
        assert data["subtotal"] == 25.00  # (2 * 10) + (1 * 5)
        assert len(data["items"]) == 2
    
    @pytest.mark.asyncio
    async def test_update_cart_item_quantity(self, client: AsyncClient, mock_firebase_token, setup_database):
        """Test updating cart item quantity."""
        from app.database import database
        
        # Create bar and menu item
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        menu_item_data = {
            "bar_id": bar_id,
            "name": "Test Item",
            "description": "Test",
            "price": 8.00,
            "category": "Food"
        }
        menu_item_id = await database.execute(MenuItem.__table__.insert().values(**menu_item_data))
        
        # Add item to cart
        add_response = await client.post(
            "/cart/items",
            json={
                "menu_item_id": menu_item_id,
                "bar_id": bar_id,
                "menu_item_name": "Test Item",
                "quantity": 2,
                "unit_price": 8.00
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        item_id = add_response.json()["id"]
        
        # Update quantity
        response = await client.put(
            f"/cart/items/{item_id}",
            json={"quantity": 5},
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["quantity"] == 5
    
    @pytest.mark.asyncio
    async def test_update_nonexistent_cart_item(self, client: AsyncClient, mock_firebase_token):
        """Test updating a non-existent cart item returns 404."""
        response = await client.put(
            "/cart/items/99999",
            json={"quantity": 3},
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 404
        assert "not found" in response.json()["detail"].lower()
    
    @pytest.mark.asyncio
    async def test_remove_cart_item(self, client: AsyncClient, mock_firebase_token, setup_database):
        """Test removing an item from the cart."""
        from app.database import database
        
        # Create bar and menu item
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        menu_item_data = {
            "bar_id": bar_id,
            "name": "Test Item",
            "description": "Test",
            "price": 8.00,
            "category": "Food"
        }
        menu_item_id = await database.execute(MenuItem.__table__.insert().values(**menu_item_data))
        
        # Add item to cart
        add_response = await client.post(
            "/cart/items",
            json={
                "menu_item_id": menu_item_id,
                "bar_id": bar_id,
                "menu_item_name": "Test Item",
                "quantity": 2,
                "unit_price": 8.00
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        item_id = add_response.json()["id"]
        
        # Remove item
        response = await client.delete(
            f"/cart/items/{item_id}",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 204
        
        # Verify item is removed
        cart_response = await client.get(
            "/cart/",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        assert len(cart_response.json()["items"]) == 0
    
    @pytest.mark.asyncio
    async def test_clear_cart(self, client: AsyncClient, mock_firebase_token, setup_database):
        """Test clearing the entire cart."""
        from app.database import database
        
        # Create bar and menu items
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        for i in range(3):
            menu_item_data = {
                "bar_id": bar_id,
                "name": f"Item {i}",
                "description": "Test",
                "price": 10.00,
                "category": "Food"
            }
            menu_item_id = await database.execute(MenuItem.__table__.insert().values(**menu_item_data))
            
            await client.post(
                "/cart/items",
                json={
                    "menu_item_id": menu_item_id,
                    "bar_id": bar_id,
                    "menu_item_name": f"Item {i}",
                    "quantity": 1,
                    "unit_price": 10.00
                },
                headers={"Authorization": f"Bearer {mock_firebase_token}"}
            )
        
        # Clear cart
        response = await client.delete(
            "/cart/",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 204
        
        # Verify cart is empty
        cart_response = await client.get(
            "/cart/",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        assert len(cart_response.json()["items"]) == 0
        assert cart_response.json()["total_items"] == 0


class TestCheckout:
    """Test checkout flow."""
    
    @pytest.mark.asyncio
    async def test_checkout_empty_cart(self, client: AsyncClient, mock_firebase_token):
        """Test checkout with empty cart returns error."""
        response = await client.post(
            "/cart/checkout",
            json={
                "order_type": "delivery",
                "payment_method": "credit_card",
                "tip": 5.00
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 400
        assert "empty" in response.json()["detail"].lower()
    
    @pytest.mark.asyncio
    async def test_checkout_mixed_bars(self, client: AsyncClient, mock_firebase_token, setup_database):
        """Test checkout with items from different bars returns error."""
        from app.database import database
        
        # Create two bars
        bar1_data = {
            "name": "Bar 1",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar1_id = await database.execute(Bar.__table__.insert().values(**bar1_data))
        
        bar2_data = {
            "name": "Bar 2",
            "address": "456 Test Ave",
            "latitude": 40.7138,
            "longitude": -74.0070
        }
        bar2_id = await database.execute(Bar.__table__.insert().values(**bar2_data))
        
        # Add items from different bars
        for bar_id in [bar1_id, bar2_id]:
            menu_item_data = {
                "bar_id": bar_id,
                "name": f"Item from Bar {bar_id}",
                "description": "Test",
                "price": 10.00,
                "category": "Food"
            }
            menu_item_id = await database.execute(MenuItem.__table__.insert().values(**menu_item_data))
            
            await client.post(
                "/cart/items",
                json={
                    "menu_item_id": menu_item_id,
                    "bar_id": bar_id,
                    "menu_item_name": f"Item from Bar {bar_id}",
                    "quantity": 1,
                    "unit_price": 10.00
                },
                headers={"Authorization": f"Bearer {mock_firebase_token}"}
            )
        
        # Attempt checkout
        response = await client.post(
            "/cart/checkout",
            json={
                "order_type": "delivery",
                "payment_method": "credit_card",
                "tip": 5.00
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 400
        assert "same bar" in response.json()["detail"].lower()
    
    @pytest.mark.asyncio
    async def test_successful_checkout(self, client: AsyncClient, mock_firebase_token, setup_database, mock_payment_gateway):
        """Test successful checkout flow."""
        from app.database import database
        
        # Create bar and menu item
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        menu_item_data = {
            "bar_id": bar_id,
            "name": "Test Item",
            "description": "Test",
            "price": 20.00,
            "category": "Food"
        }
        menu_item_id = await database.execute(MenuItem.__table__.insert().values(**menu_item_data))
        
        # Add item to cart
        await client.post(
            "/cart/items",
            json={
                "menu_item_id": menu_item_id,
                "bar_id": bar_id,
                "menu_item_name": "Test Item",
                "quantity": 2,
                "unit_price": 20.00
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        # Mock successful payment
        mock_payment_gateway.create_charge.return_value = {
            "status": "succeeded",
            "id": "ch_test123"
        }
        
        # Checkout
        response = await client.post(
            "/cart/checkout",
            json={
                "order_type": "pickup",
                "payment_method": "credit_card",
                "tip": 5.00,
                "special_instructions": "Extra napkins please"
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 201
        data = response.json()
        assert "order_id" in data
        assert data["status"] == "confirmed"
        assert data["payment_status"] == "completed"
        assert data["payment_id"] == "ch_test123"
        assert data["total"] > 0
        
        # Verify cart is cleared
        cart_response = await client.get(
            "/cart/",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        assert len(cart_response.json()["items"]) == 0
    
    @pytest.mark.asyncio
    async def test_checkout_payment_failure(self, client: AsyncClient, mock_firebase_token, setup_database, mock_payment_gateway):
        """Test checkout with payment failure."""
        from app.database import database
        
        # Create bar and menu item
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        menu_item_data = {
            "bar_id": bar_id,
            "name": "Test Item",
            "description": "Test",
            "price": 15.00,
            "category": "Food"
        }
        menu_item_id = await database.execute(MenuItem.__table__.insert().values(**menu_item_data))
        
        # Add item to cart
        await client.post(
            "/cart/items",
            json={
                "menu_item_id": menu_item_id,
                "bar_id": bar_id,
                "menu_item_name": "Test Item",
                "quantity": 1,
                "unit_price": 15.00
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        # Mock payment failure
        mock_payment_gateway.create_charge.return_value = {
            "status": "failed",
            "message": "Insufficient funds"
        }
        
        # Attempt checkout
        response = await client.post(
            "/cart/checkout",
            json={
                "order_type": "delivery",
                "payment_method": "credit_card",
                "tip": 3.00
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 402
        assert "Insufficient funds" in response.json()["detail"]
        
        # Verify cart still has items
        cart_response = await client.get(
            "/cart/",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        assert len(cart_response.json()["items"]) == 1
    
    @pytest.mark.asyncio
    async def test_checkout_calculates_totals_correctly(self, client: AsyncClient, mock_firebase_token, setup_database, mock_payment_gateway):
        """Test that checkout calculates totals correctly."""
        from app.database import database
        
        # Create bar and menu item
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        menu_item_data = {
            "bar_id": bar_id,
            "name": "Test Item",
            "description": "Test",
            "price": 100.00,
            "category": "Food"
        }
        menu_item_id = await database.execute(MenuItem.__table__.insert().values(**menu_item_data))
        
        # Add item to cart
        await client.post(
            "/cart/items",
            json={
                "menu_item_id": menu_item_id,
                "bar_id": bar_id,
                "menu_item_name": "Test Item",
                "quantity": 1,
                "unit_price": 100.00
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        # Mock successful payment
        mock_payment_gateway.create_charge.return_value = {
            "status": "succeeded",
            "id": "ch_test123"
        }
        
        # Checkout with delivery
        response = await client.post(
            "/cart/checkout",
            json={
                "order_type": "delivery",
                "payment_method": "credit_card",
                "tip": 15.00
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 201
        data = response.json()
        
        # Verify totals: subtotal=100, tax=10 (10%), tip=15, delivery_fee=5
        # Total should be 100 + 10 + 15 + 5 = 130
        assert data["total"] == 130.00
