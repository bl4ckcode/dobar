import pytest
from decimal import Decimal
from datetime import datetime, timezone
from httpx import AsyncClient
from unittest.mock import AsyncMock

from app.bars_and_restaurants.models.wallet_models import BarWallet, FundingSource
from app.bars_and_restaurants.services.wallet_service import WalletService


@pytest.mark.asyncio
class TestBarWallet:
    
    async def test_get_or_create_bar_wallet_new_bar(self, db_session, test_bar):
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        
        assert wallet is not None
        assert wallet.bar_id == test_bar.id
        assert wallet.available_balance == Decimal("0.00")
        assert wallet.reserved_balance == Decimal("0.00")
        assert wallet.total_balance == Decimal("0.00")
    
    async def test_get_or_create_bar_wallet_existing(self, db_session, test_bar):
        wallet1 = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        wallet1.available_balance = Decimal("100.00")
        db_session.commit()
        
        wallet2 = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        
        assert wallet2.bar_id == wallet1.bar_id
        assert wallet2.available_balance == Decimal("100.00")
    
    async def test_get_bar_wallet_balance(self, db_session, test_bar):
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        wallet.available_balance = Decimal("50.00")
        wallet.reserved_balance = Decimal("10.00")
        db_session.commit()
        
        response = WalletService.get_bar_wallet_balance(db_session, test_bar.id)
        
        assert response["bar_id"] == test_bar.id
        assert response["available_balance"] == Decimal("50.00")
        assert response["reserved_balance"] == Decimal("10.00")
        assert response["total_balance"] == Decimal("60.00")
        assert "last_updated" in response
    
    async def test_validate_promotion_funding_barz_always_valid(self, db_session, test_bar):
        is_valid = WalletService.validate_promotion_funding(
            db_session, test_bar.id, Decimal("1000.00"), FundingSource.BARZ
        )
        
        assert is_valid is True
    
    async def test_validate_promotion_funding_bar_sufficient(self, db_session, test_bar):
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        wallet.available_balance = Decimal("100.00")
        db_session.commit()
        
        is_valid = WalletService.validate_promotion_funding(
            db_session, test_bar.id, Decimal("50.00"), FundingSource.BAR
        )
        
        assert is_valid is True
    
    async def test_validate_promotion_funding_bar_insufficient(self, db_session, test_bar):
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        wallet.available_balance = Decimal("10.00")
        db_session.commit()
        
        is_valid = WalletService.validate_promotion_funding(
            db_session, test_bar.id, Decimal("50.00"), FundingSource.BAR
        )
        
        assert is_valid is False
    
    async def test_reserve_bar_funds_sufficient(self, db_session, test_bar):
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        wallet.available_balance = Decimal("100.00")
        db_session.commit()
        
        success = WalletService.reserve_bar_funds(db_session, test_bar.id, Decimal("30.00"))
        
        assert success is True
        
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        assert wallet.available_balance == Decimal("70.00")
        assert wallet.reserved_balance == Decimal("30.00")
    
    async def test_reserve_bar_funds_insufficient(self, db_session, test_bar):
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        wallet.available_balance = Decimal("10.00")
        db_session.commit()
        
        success = WalletService.reserve_bar_funds(db_session, test_bar.id, Decimal("50.00"))
        
        assert success is False
        
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        assert wallet.available_balance == Decimal("10.00")
        assert wallet.reserved_balance == Decimal("0.00")
    
    async def test_release_bar_funds(self, db_session, test_bar):
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        wallet.available_balance = Decimal("50.00")
        wallet.reserved_balance = Decimal("20.00")
        db_session.commit()
        
        WalletService.release_bar_funds(db_session, test_bar.id, Decimal("20.00"))
        
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        assert wallet.available_balance == Decimal("70.00")
        assert wallet.reserved_balance == Decimal("0.00")
    
    async def test_reserve_and_release_cycle(self, db_session, test_bar):
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        wallet.available_balance = Decimal("100.00")
        db_session.commit()
        
        WalletService.reserve_bar_funds(db_session, test_bar.id, Decimal("25.00"))
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        assert wallet.available_balance == Decimal("75.00")
        assert wallet.reserved_balance == Decimal("25.00")
        
        WalletService.release_bar_funds(db_session, test_bar.id, Decimal("25.00"))
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar.id)
        assert wallet.available_balance == Decimal("100.00")
        assert wallet.reserved_balance == Decimal("0.00")


@pytest.mark.asyncio
class TestCartCalculate:
    
    async def test_calculate_empty_cart_fails(self, auth_client):
        client, headers, user = auth_client
        response = await client.post("/cart/calculate", json={"active_promotion_ids": []}, headers=headers)
        assert response.status_code == 400
        assert response.json()["error_code"] == "CART_EMPTY"
    
    async def test_calculate_cart_no_promotions(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        
        await client.post("/cart/items", json={
            "menu_item_id": 1,
            "bar_id": test_bar_in_db["id"],
            "menu_item_name": "Test Item",
            "quantity": 2,
            "unit_price": 10.00
        }, headers=headers)
        
        response = await client.post("/cart/calculate", json={"active_promotion_ids": []}, headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["subtotal"] == 20.0
        assert data["total_items"] == 2
    
    async def test_calculate_cart_with_valid_promotion(self, auth_client, test_bar_in_db, test_promotion):
        client, headers, user = auth_client
        
        await client.post("/cart/items", json={
            "menu_item_id": 1,
            "bar_id": test_bar_in_db["id"],
            "menu_item_name": "Test Item",
            "quantity": 1,
            "unit_price": 100.00
        }, headers=headers)
        
        response = await client.post("/cart/calculate", json={
            "active_promotion_ids": [test_promotion["id"]]
        }, headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert data["subtotal"] == 100.0
    
    async def test_calculate_skips_inactive_promotions(self, auth_client, test_bar_in_db, inactive_promotion):
        client, headers, user = auth_client
        
        await client.post("/cart/items", json={
            "menu_item_id": 1,
            "bar_id": test_bar_in_db["id"],
            "menu_item_name": "Test Item",
            "quantity": 1,
            "unit_price": 100.00
        }, headers=headers)
        
        response = await client.post("/cart/calculate", json={
            "active_promotion_ids": [inactive_promotion["id"]]
        }, headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert data["subtotal"] == 100.0
    
    async def test_calculate_skips_unfunded_bar_promotions(self, auth_client, test_bar_in_db, db_session):
        client, headers, user = auth_client
        
        from app.bars_and_restaurants.models.relational_models import Promotion as PromotionModel
        
        promo = PromotionModel(
            bar_id=test_bar_in_db["id"],
            title="Unfunded Promo",
            discount_type="fixed",
            discount_value=50.00,
            promotion_type="cashback",
            is_active=True
        )
        db_session.add(promo)
        db_session.commit()
        
        wallet = WalletService.get_or_create_bar_wallet(db_session, test_bar_in_db["id"])
        wallet.available_balance = Decimal("10.00")
        db_session.commit()
        
        await client.post("/cart/items", json={
            "menu_item_id": 1,
            "bar_id": test_bar_in_db["id"],
            "menu_item_name": "Test Item",
            "quantity": 1,
            "unit_price": 100.00
        }, headers=headers)
        
        response = await client.post("/cart/calculate", json={
            "active_promotion_ids": [promo.id]
        }, headers=headers)
        
        assert response.status_code == 200


@pytest.mark.asyncio
class TestRedisLocking:
    
    async def test_checkout_uses_redis_lock(self, auth_client, test_bar_in_db, mocker):
        client, headers, user = auth_client
        
        await client.post("/cart/items", json={
            "menu_item_id": 1,
            "bar_id": test_bar_in_db["id"],
            "menu_item_name": "Test Item",
            "quantity": 1,
            "unit_price": 10.00
        }, headers=headers)
        
        mock_lock_enter = mocker.patch("app.redis_client.WalletLock.__aenter__", new_callable=AsyncMock)
        mock_lock_enter.return_value = None
        mocker.patch("app.redis_client.WalletLock.__aexit__", new_callable=AsyncMock, return_value=False)
        mocker.patch(
            "app.bars_and_restaurants.services.connection_manager.manager.notify_bar",
            new_callable=AsyncMock
        )
        mock_transaction = mocker.MagicMock()
        mock_transaction.commit = AsyncMock()
        mock_transaction.rollback = AsyncMock()
        mocker.patch(
            "app.bars_and_restaurants.routes.cart.database.transaction",
            new_callable=AsyncMock,
            return_value=mock_transaction
        )
        
        checkout_data = {
            "order_type": "pickup",
            "payment_method": "credit_card"
        }
        
        await client.post("/cart/checkout", json=checkout_data, headers=headers)
        
        mock_lock_enter.assert_called_once()


@pytest.mark.asyncio
class TestSpotAvailability:
    
    async def test_spot_availability_bar_not_found(self, auth_client):
        client, headers, user = auth_client
        response = await client.get("/bars/99999/spots/table-1/availability", headers=headers)
        assert response.status_code == 404
    
    async def test_spot_not_in_bar_config(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        response = await client.get(f"/bars/{test_bar_in_db['id']}/spots/nonexistent-spot/availability", headers=headers)
        assert response.status_code == 404
    
    async def test_spot_available_no_active_orders(self, auth_client, test_bar_with_spots):
        client, headers, user = auth_client
        bar_id = test_bar_with_spots["id"]
        
        response = await client.get(f"/bars/{bar_id}/spots/table-1/availability", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["is_available"] is True
        assert data["message"] is None
    
    async def test_spot_occupied_with_active_order(self, auth_client, test_bar_with_spots, db_session, test_user):
        from app.bars_and_restaurants.models.relational_models import Order as OrderModel
        
        client, headers, user = auth_client
        bar_id = test_bar_with_spots["id"]
        
        order = OrderModel(
            user_id=test_user.id,
            bar_id=bar_id,
            status="pending",
            location_identifier="table-1",
            total_price=50.00,
            order_type="dine_in"
        )
        db_session.add(order)
        db_session.commit()
        
        response = await client.get(f"/bars/{bar_id}/spots/table-1/availability", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["is_available"] is False
        assert data["message"] == "Spot occupied"
