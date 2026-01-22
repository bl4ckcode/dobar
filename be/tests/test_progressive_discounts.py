import pytest
from datetime import datetime, timezone

@pytest.mark.asyncio
class TestProgressiveDiscounts:
    async def test_service_connection(self, auth_client):
        """Verify service uses the correct test database."""
        from app.bars_and_restaurants.services.discounts import calculate_progressive_discount
        # Check if logic runs without error
        result = await calculate_progressive_discount(1, 1)
        assert result["percentage"] == 0.0
        assert result["current_order_number"] == 1

    async def test_discount_tiers_logic(self, auth_client, test_bar_in_db, test_user_in_db, setup_database):
        """
        Verify progressive discount tier calculation based on order count.
        """
        from app.bars_and_restaurants.services.discounts import calculate_progressive_discount
        from app.bars_and_restaurants.services import discounts
        from app.bars_and_restaurants.models.relational_models import Order as OrderModel
        
        # Import database from conftest - it's the patched test_database
        database = discounts.database
        
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        user_id = user["id"]
        
        # Tier 1: No prior orders = 0% discount
        result1 = await calculate_progressive_discount(user_id, bar_id)
        assert result1["percentage"] == 0.0, f"Expected 0%, got {result1['percentage']}"
        assert result1["current_order_number"] == 1
        
        # Simulate creating an order in the session
        now = datetime.now(timezone.utc)
        await database.execute(OrderModel.__table__.insert().values(
            user_id=user_id, bar_id=bar_id, status="confirmed", 
            total_price=100.0, subtotal=100.0, tax=10.0, order_type="dine_in",
            payment_method="credit_card", created_at=now
        ))
        
        # Tier 2: 1 prior order = 5% discount
        result2 = await calculate_progressive_discount(user_id, bar_id)
        assert result2["percentage"] == 0.05, f"Expected 5%, got {result2['percentage']}"
        assert result2["current_order_number"] == 2
        
        # Simulate second order
        await database.execute(OrderModel.__table__.insert().values(
            user_id=user_id, bar_id=bar_id, status="confirmed", 
            total_price=100.0, subtotal=100.0, tax=10.0, order_type="dine_in",
            payment_method="credit_card", created_at=now
        ))
        
        # Tier 3: 2 prior orders = 10% discount
        result3 = await calculate_progressive_discount(user_id, bar_id)
        assert result3["percentage"] == 0.10, f"Expected 10%, got {result3['percentage']}"
        assert result3["current_order_number"] == 3
        
        # Simulate third order
        await database.execute(OrderModel.__table__.insert().values(
            user_id=user_id, bar_id=bar_id, status="confirmed", 
            total_price=100.0, subtotal=100.0, tax=10.0, order_type="dine_in",
            payment_method="credit_card", created_at=now
        ))
        
        # Tier 4 (cap): 3+ prior orders = 15% discount
        result4 = await calculate_progressive_discount(user_id, bar_id)
        assert result4["percentage"] == 0.15, f"Expected 15%, got {result4['percentage']}"
        assert result4["current_order_number"] == 4
