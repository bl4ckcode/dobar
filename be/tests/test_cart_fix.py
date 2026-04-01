import pytest
from unittest.mock import patch, MagicMock
from app.errors import APIError

@pytest.mark.asyncio
async def test_checkout_payment_failure_no_double_rollback(auth_client, test_bar_in_db):
    """
    Test that a payment failure doesn't cause an IndexError (double rollback)
    and returns a proper 400 error.
    """
    client, headers, user = auth_client
    
    # 1. Add item to cart
    await client.post("/cart/items", json={
        "menu_item_id": 1,
        "bar_id": test_bar_in_db["id"],
        "menu_item_name": "Test Item",
        "quantity": 1,
        "unit_price": 10.00
    }, headers=headers)
    
    # 2. Mock payment gateway to fail with an exception
    # This simulates the AttributeError or any other exception during payment
    with patch("app.bars_and_restaurants.routes.cart.get_payment_gateway") as mock_get_gateway:
        mock_gateway = MagicMock()
        # Mock create_charge to raise an exception
        mock_gateway.create_charge.side_effect = Exception("Simulated Payment Error")
        mock_get_gateway.return_value = mock_gateway
        
        # 3. Perform checkout
        checkout_data = {
            "order_type": "dine_in",
            "payment_method": "credit_card",
            "location_identifier": "table_1"
        }
        
        response = await client.post("/cart/checkout", json=checkout_data, headers=headers)
        
        # 4. Verify results
        # Before the fix, this would be 500 because of IndexError in rollback
        # After the fix, it should be 400 (Payment Declined)
        assert response.status_code == 400
        data = response.json()
        assert data["error_code"] == "PAYMENT_DECLINED"
        assert "Simulated Payment Error" in data["message"]

@pytest.mark.asyncio
async def test_checkout_success(auth_client, test_bar_in_db):
    """
    Test that a successful checkout works with the new user_dict logic.
    """
    client, headers, user = auth_client
    
    # 1. Add item to cart
    await client.post("/cart/items", json={
        "menu_item_id": 2,
        "bar_id": test_bar_in_db["id"],
        "menu_item_name": "Success Item",
        "quantity": 1,
        "unit_price": 15.00
    }, headers=headers)
    
    # 2. Perform checkout (using stub payment gateway which succeeds by default)
    checkout_data = {
        "order_type": "dine_in",
        "payment_method": "credit_card",
        "location_identifier": "table_2"
    }
    
    response = await client.post("/cart/checkout", json=checkout_data, headers=headers)
    
    # 3. Verify results
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "confirmed"
    assert data["payment_status"] == "completed"
    assert "order_id" in data
