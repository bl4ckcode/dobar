"""
Tests for enhanced order management endpoints.
"""

import pytest
from httpx import AsyncClient
from datetime import datetime, timedelta

from app.bars_and_restaurants.models.relational_models import Order, Bar
from app.bars_and_restaurants.models.cart_models import OrderItem, OrderStatusHistory


class TestOrderHistory:
    """Test order history and listing."""
    
    @pytest.mark.asyncio
    async def test_get_empty_order_history(self, client: AsyncClient, mock_firebase_token):
        """Test getting order history when user has no orders."""
        response = await client.get(
            "/orders/user/me",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["orders"] == []
        assert data["total"] == 0
        assert data["page"] == 1
        assert data["page_size"] == 10
    
    @pytest.mark.asyncio
    async def test_get_order_history_with_orders(self, client: AsyncClient, mock_firebase_token, setup_database, sample_user_data):
        """Test getting order history with multiple orders."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create multiple orders
        for i in range(5):
            order_data = {
                "user_id": sample_user_data["id"],
                "bar_id": bar_id,
                "status": "completed" if i < 3 else "pending",
                "order_type": "delivery",
                "subtotal": 50.00,
                "tax": 5.00,
                "tip": 10.00,
                "delivery_fee": 5.00,
                "discount": 0.00,
                "total": 70.00,
                "payment_method": "credit_card",
                "payment_status": "completed"
            }
            await database.execute(Order.__table__.insert().values(**order_data))
        
        # Get order history
        response = await client.get(
            "/orders/user/me",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert len(data["orders"]) == 5
        assert data["total"] == 5
    
    @pytest.mark.asyncio
    async def test_get_order_history_with_status_filter(self, client: AsyncClient, mock_firebase_token, setup_database, sample_user_data):
        """Test filtering order history by status."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create orders with different statuses
        statuses = ["pending", "confirmed", "preparing", "completed", "completed"]
        for status in statuses:
            order_data = {
                "user_id": sample_user_data["id"],
                "bar_id": bar_id,
                "status": status,
                "order_type": "pickup",
                "subtotal": 30.00,
                "tax": 3.00,
                "total": 33.00,
                "payment_method": "credit_card",
                "payment_status": "completed"
            }
            await database.execute(Order.__table__.insert().values(**order_data))
        
        # Filter by completed status
        response = await client.get(
            "/orders/user/me?status=completed",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert len(data["orders"]) == 2
        for order in data["orders"]:
            assert order["status"] == "completed"
    
    @pytest.mark.asyncio
    async def test_order_history_pagination(self, client: AsyncClient, mock_firebase_token, setup_database, sample_user_data):
        """Test pagination of order history."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create 25 orders
        for i in range(25):
            order_data = {
                "user_id": sample_user_data["id"],
                "bar_id": bar_id,
                "status": "completed",
                "order_type": "delivery",
                "subtotal": 50.00,
                "total": 50.00,
                "payment_method": "credit_card",
                "payment_status": "completed"
            }
            await database.execute(Order.__table__.insert().values(**order_data))
        
        # Get first page
        response1 = await client.get(
            "/orders/user/me?page=1&page_size=10",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response1.status_code == 200
        data1 = response1.json()
        assert len(data1["orders"]) == 10
        assert data1["total"] == 25
        assert data1["page"] == 1
        
        # Get second page
        response2 = await client.get(
            "/orders/user/me?page=2&page_size=10",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response2.status_code == 200
        data2 = response2.json()
        assert len(data2["orders"]) == 10
        assert data2["page"] == 2


class TestOrderDetails:
    """Test order detail retrieval."""
    
    @pytest.mark.asyncio
    async def test_get_order_details(self, client: AsyncClient, mock_firebase_token, setup_database, sample_user_data):
        """Test getting order details."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create an order
        order_data = {
            "user_id": sample_user_data["id"],
            "bar_id": bar_id,
            "status": "confirmed",
            "order_type": "delivery",
            "subtotal": 45.00,
            "tax": 4.50,
            "tip": 9.00,
            "delivery_fee": 5.00,
            "discount": 0.00,
            "total": 63.50,
            "payment_method": "credit_card",
            "payment_status": "completed",
            "special_instructions": "Ring doorbell"
        }
        order_id = await database.execute(Order.__table__.insert().values(**order_data))
        
        # Get order details
        response = await client.get(
            f"/orders/{order_id}",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == order_id
        assert data["status"] == "confirmed"
        assert data["special_instructions"] == "Ring doorbell"
    
    @pytest.mark.asyncio
    async def test_get_nonexistent_order(self, client: AsyncClient, mock_firebase_token):
        """Test getting a non-existent order returns 404."""
        response = await client.get(
            "/orders/99999",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 404
    
    @pytest.mark.asyncio
    async def test_cannot_view_other_users_order(self, client: AsyncClient, mock_firebase_token, setup_database):
        """Test that users cannot view other users' orders."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create an order for a different user (user_id = 999)
        order_data = {
            "user_id": 999,
            "bar_id": bar_id,
            "status": "pending",
            "order_type": "pickup",
            "subtotal": 20.00,
            "total": 20.00,
            "payment_method": "credit_card",
            "payment_status": "completed"
        }
        order_id = await database.execute(Order.__table__.insert().values(**order_data))
        
        # Try to get order details as different user
        response = await client.get(
            f"/orders/{order_id}",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 403


class TestOrderTimeline:
    """Test order timeline/status history."""
    
    @pytest.mark.asyncio
    async def test_get_order_timeline(self, client: AsyncClient, mock_firebase_token, setup_database, sample_user_data):
        """Test getting order timeline with status history."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create an order
        order_data = {
            "user_id": sample_user_data["id"],
            "bar_id": bar_id,
            "status": "preparing",
            "order_type": "pickup",
            "subtotal": 25.00,
            "total": 25.00,
            "payment_method": "credit_card",
            "payment_status": "completed"
        }
        order_id = await database.execute(Order.__table__.insert().values(**order_data))
        
        # Add status history entries
        history_entries = [
            {"order_id": order_id, "previous_status": "pending", "new_status": "confirmed", "note": "Order confirmed"},
            {"order_id": order_id, "previous_status": "confirmed", "new_status": "preparing", "note": "Started preparation"}
        ]
        
        for entry in history_entries:
            await database.execute(OrderStatusHistory.__table__.insert().values(**entry))
        
        # Get order timeline
        response = await client.get(
            f"/orders/{order_id}/timeline",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == order_id
        assert "status_history" in data
        assert len(data["status_history"]) == 2
        assert data["status_history"][0]["new_status"] == "confirmed"
        assert data["status_history"][1]["new_status"] == "preparing"
    
    @pytest.mark.asyncio
    async def test_timeline_requires_ownership(self, client: AsyncClient, mock_firebase_token, setup_database):
        """Test that timeline endpoint requires order ownership."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create an order for a different user
        order_data = {
            "user_id": 999,
            "bar_id": bar_id,
            "status": "pending",
            "order_type": "pickup",
            "subtotal": 20.00,
            "total": 20.00,
            "payment_method": "credit_card",
            "payment_status": "completed"
        }
        order_id = await database.execute(Order.__table__.insert().values(**order_data))
        
        # Try to get timeline
        response = await client.get(
            f"/orders/{order_id}/timeline",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 403


class TestOrderCancellation:
    """Test order cancellation."""
    
    @pytest.mark.asyncio
    async def test_cancel_pending_order(self, client: AsyncClient, mock_firebase_token, setup_database, sample_user_data):
        """Test canceling a pending order."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create a pending order
        order_data = {
            "user_id": sample_user_data["id"],
            "bar_id": bar_id,
            "status": "pending",
            "order_type": "delivery",
            "subtotal": 30.00,
            "total": 30.00,
            "payment_method": "credit_card",
            "payment_status": "completed"
        }
        order_id = await database.execute(Order.__table__.insert().values(**order_data))
        
        # Cancel order
        response = await client.post(
            f"/orders/{order_id}/cancel",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "cancelled"
        
        # Verify status history was created
        history = await database.fetch_all(
            OrderStatusHistory.__table__.select().where(OrderStatusHistory.order_id == order_id)
        )
        assert len(history) == 1
        assert history[0]["new_status"] == "cancelled"
        assert history[0]["note"] == "Cancelled by customer"
    
    @pytest.mark.asyncio
    async def test_cancel_confirmed_order(self, client: AsyncClient, mock_firebase_token, setup_database, sample_user_data):
        """Test canceling a confirmed order."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create a confirmed order
        order_data = {
            "user_id": sample_user_data["id"],
            "bar_id": bar_id,
            "status": "confirmed",
            "order_type": "pickup",
            "subtotal": 25.00,
            "total": 25.00,
            "payment_method": "credit_card",
            "payment_status": "completed"
        }
        order_id = await database.execute(Order.__table__.insert().values(**order_data))
        
        # Cancel order
        response = await client.post(
            f"/orders/{order_id}/cancel",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 200
        assert response.json()["status"] == "cancelled"
    
    @pytest.mark.asyncio
    async def test_cannot_cancel_preparing_order(self, client: AsyncClient, mock_firebase_token, setup_database, sample_user_data):
        """Test that preparing orders cannot be cancelled."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create a preparing order
        order_data = {
            "user_id": sample_user_data["id"],
            "bar_id": bar_id,
            "status": "preparing",
            "order_type": "pickup",
            "subtotal": 25.00,
            "total": 25.00,
            "payment_method": "credit_card",
            "payment_status": "completed"
        }
        order_id = await database.execute(Order.__table__.insert().values(**order_data))
        
        # Try to cancel
        response = await client.post(
            f"/orders/{order_id}/cancel",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 400
        assert response.json()["error_code"] == "ORDER_CANCELLED"
        assert "cannot cancel" in response.json()["message"].lower()
    
    @pytest.mark.asyncio
    async def test_cannot_cancel_other_users_order(self, client: AsyncClient, mock_firebase_token, setup_database):
        """Test that users cannot cancel other users' orders."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create an order for a different user
        order_data = {
            "user_id": 999,
            "bar_id": bar_id,
            "status": "pending",
            "order_type": "pickup",
            "subtotal": 20.00,
            "total": 20.00,
            "payment_method": "credit_card",
            "payment_status": "completed"
        }
        order_id = await database.execute(Order.__table__.insert().values(**order_data))
        
        # Try to cancel
        response = await client.post(
            f"/orders/{order_id}/cancel",
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 403


class TestOrderStatusUpdate:
    """Test order status updates (for bar owners)."""
    
    @pytest.mark.asyncio
    async def test_update_order_status(self, client: AsyncClient, mock_firebase_token, setup_database, sample_user_data):
        """Test updating order status."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create a confirmed order
        order_data = {
            "user_id": sample_user_data["id"],
            "bar_id": bar_id,
            "status": "confirmed",
            "order_type": "pickup",
            "subtotal": 25.00,
            "total": 25.00,
            "payment_method": "credit_card",
            "payment_status": "completed"
        }
        order_id = await database.execute(Order.__table__.insert().values(**order_data))
        
        # Update status to preparing
        response = await client.put(
            f"/orders/{order_id}/status",
            json={
                "new_status": "preparing",
                "note": "Started preparing order"
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "preparing"
        
        # Verify status history was created
        history = await database.fetch_all(
            OrderStatusHistory.__table__.select().where(OrderStatusHistory.order_id == order_id)
        )
        assert len(history) == 1
        assert history[0]["new_status"] == "preparing"
        assert history[0]["note"] == "Started preparing order"
    
    @pytest.mark.asyncio
    async def test_invalid_status_transition(self, client: AsyncClient, mock_firebase_token, setup_database, sample_user_data):
        """Test that invalid status transitions are rejected."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create a pending order
        order_data = {
            "user_id": sample_user_data["id"],
            "bar_id": bar_id,
            "status": "pending",
            "order_type": "pickup",
            "subtotal": 25.00,
            "total": 25.00,
            "payment_method": "credit_card",
            "payment_status": "completed"
        }
        order_id = await database.execute(Order.__table__.insert().values(**order_data))
        
        # Try to jump directly to completed (invalid)
        response = await client.put(
            f"/orders/{order_id}/status",
            json={
                "new_status": "completed"
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 400
        assert response.json()["error_code"] == "BAD_REQUEST"
        assert "invalid" in response.json()["message"].lower()
    
    @pytest.mark.asyncio
    async def test_update_completed_order_status(self, client: AsyncClient, mock_firebase_token, setup_database, sample_user_data):
        """Test that completed orders cannot be updated."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create a completed order
        order_data = {
            "user_id": sample_user_data["id"],
            "bar_id": bar_id,
            "status": "completed",
            "order_type": "pickup",
            "subtotal": 25.00,
            "total": 25.00,
            "payment_method": "credit_card",
            "payment_status": "completed"
        }
        order_id = await database.execute(Order.__table__.insert().values(**order_data))
        
        # Try to update status
        response = await client.put(
            f"/orders/{order_id}/status",
            json={
                "new_status": "preparing"
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 400
    
    @pytest.mark.asyncio
    async def test_status_update_sets_completed_at(self, client: AsyncClient, mock_firebase_token, setup_database, sample_user_data):
        """Test that completing an order sets completed_at timestamp."""
        from app.database import database
        
        # Create a bar
        bar_data = {
            "name": "Test Bar",
            "address": "123 Test St",
            "latitude": 40.7128,
            "longitude": -74.0060
        }
        bar_id = await database.execute(Bar.__table__.insert().values(**bar_data))
        
        # Create a ready order
        order_data = {
            "user_id": sample_user_data["id"],
            "bar_id": bar_id,
            "status": "ready",
            "order_type": "pickup",
            "subtotal": 25.00,
            "total": 25.00,
            "payment_method": "credit_card",
            "payment_status": "completed"
        }
        order_id = await database.execute(Order.__table__.insert().values(**order_data))
        
        # Complete the order
        response = await client.put(
            f"/orders/{order_id}/status",
            json={
                "new_status": "completed"
            },
            headers={"Authorization": f"Bearer {mock_firebase_token}"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "completed"
        assert data["completed_at"] is not None
