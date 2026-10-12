import pytest
import os
from httpx import AsyncClient
from app.database import database
from app.bars_and_restaurants.models.relational_models import Order, Bar
from app.advertising.models import AdvertisingCampaign, AdvertisingSubscription

# Helper function to create a JWT token for testing (copied from conftest to avoid import issues)
def create_test_token(user_id: int) -> str:
    from datetime import datetime, timedelta, timezone
    from jose import jwt
    
    SECRET_KEY = os.getenv("SECRET_KEY", "test_secret_key_for_testing_only")
    ALGORITHM = "HS256"
    
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=60)
    
    to_encode = {
        "sub": str(user_id),
        "exp": expire,
        "iat": now,
        "type": "access"
    }
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

@pytest.fixture
async def pro_user_in_db(cleanup_database):
    from app.auth.auth_models import User
    user_data = {
        "firebase_uid": "pro_user_uid_123",
        "phone_number": "+1999999999",
        "email": "pro@example.com",
        "is_active": True,
        "subscription_tier": "pro"
    }
    user_id = await database.execute(User.__table__.insert().values(**user_data))
    return {"id": user_id, **user_data}

@pytest.fixture
async def pro_auth_client(client: AsyncClient, pro_user_in_db):
    token = create_test_token(pro_user_in_db["id"])
    headers = {"Authorization": f"Bearer {token}"}
    return client, headers, pro_user_in_db

@pytest.mark.asyncio
class TestProFeatures:
    async def test_pro_user_checkout_priority(self, pro_auth_client, test_bar_in_db):
        client, headers, user = pro_auth_client
        
        # Add item to cart
        await client.post("/cart/items", json={
            "menu_item_id": 1,
            "bar_id": test_bar_in_db["id"],
            "menu_item_name": "Pro Item",
            "quantity": 1,
            "unit_price": 100.00
        }, headers=headers)
        
        # Checkout
        response = await client.post("/cart/checkout", json={
            "order_type": "pickup",
            "payment_method": "credit_card"
        }, headers=headers)
        
        assert response.status_code == 201
        order_id = response.json()["order_id"]
        
        # Verify order is priority in DB
        order = await database.fetch_one(
            Order.__table__.select().where(Order.id == order_id)
        )
        assert order["is_priority"] is True

    async def test_regular_user_checkout_not_priority(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        
        await client.post("/cart/items", json={
            "menu_item_id": 2,
            "bar_id": test_bar_in_db["id"],
            "menu_item_name": "Regular Item",
            "quantity": 1,
            "unit_price": 50.00
        }, headers=headers)
        
        response = await client.post("/cart/checkout", json={
            "order_type": "pickup",
            "payment_method": "credit_card"
        }, headers=headers)
        
        order_id = response.json()["order_id"]
        order = await database.fetch_one(
            Order.__table__.select().where(Order.id == order_id)
        )
        assert order["is_priority"] is False

    async def test_pro_business_ranking_boost(self, client):
        # Create a VIP bar and a Regular bar
        from app.bars_and_restaurants.models.relational_models import Bar, BarOwner
        
        owner_id = 9999
        await database.execute(BarOwner.__table__.insert().values(id=owner_id, name="Owner", email="owner99@test.com"))
        
        vip_bar_id = await database.execute(Bar.__table__.insert().values(
            name="VIP Bar", address="Address 1", owner_id=owner_id, subscription_tier="vip"
        ))
        reg_bar_id = await database.execute(Bar.__table__.insert().values(
            name="Regular Bar", address="Address 2", owner_id=owner_id, subscription_tier="regular"
        ))
        
        from app.bars_and_restaurants.routes.bars import get_bars_by_ids
        
        bars_info = [
            {"bar_id": reg_bar_id, "approximateLocation": 10}, # Closer
            {"bar_id": vip_bar_id, "approximateLocation": 100} # Farther
        ]
        
        sorted_bars = await get_bars_by_ids(bars_info)
        
        # VIP bar should be first despite being farther
        assert sorted_bars[0]["id"] == vip_bar_id
        assert sorted_bars[1]["id"] == reg_bar_id

    async def test_push_notification_campaign_gating(self, client, test_bar_in_db):
        from app.advertising.routes import _get_allowed_campaign_types
        assert "push_notification" not in _get_allowed_campaign_types("regular")
        assert "push_notification" in _get_allowed_campaign_types("vip")
        assert "push_notification" in _get_allowed_campaign_types("master")
