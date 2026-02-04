import pytest
from httpx import AsyncClient
from datetime import datetime, timedelta

@pytest.mark.asyncio
class TestLocationAndPromotions:

    async def test_get_location_config_defaults(self, client: AsyncClient, test_bar_in_db):
        """Test fetching location config for a bar (default values)."""
        response = await client.get(f"/bars/{test_bar_in_db['id']}/location-config")
        assert response.status_code == 200
        data = response.json()
        assert "method" in data
        assert "spots" in data
        assert data["method"] == "table_number"  # Default
        assert data["spots"] == []

    async def test_get_promotions_empty(self, client: AsyncClient, test_bar_in_db):
        """Test fetching promotions when none exist."""
        response = await client.get(f"/bars/{test_bar_in_db['id']}/promotions")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) == 0

    async def test_fetch_active_promotions_with_data(self, client: AsyncClient, test_bar_in_db):
        """Test fetching a promotion that was inserted directly into the DB."""
        from app.bars_and_restaurants.models.relational_models import Promotion
        from app.database import database as db
        
        bar_id = test_bar_in_db["id"]
        
        # 1. Insert promotion directly into DB
        promo_data = {
            "bar_id": bar_id,
            "title": "Direct DB Promo",
            "benefit_text": "10% off",
            "promotion_type": "discount",
            "discount_type": "percentage",
            "discount_value": 10.0,
            "is_active": True,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        
        insert_query = Promotion.__table__.insert().values(**promo_data)
        await db.execute(insert_query)
        
        # 2. Fetch using the NEW endpoint
        response_fetch = await client.get(f"/bars/{bar_id}/promotions")
        assert response_fetch.status_code == 200
        data = response_fetch.json()
        assert len(data) >= 1
        found = False
        for p in data:
            if p["title"] == "Direct DB Promo":
                assert p["benefit_text"] == "10% off"
                found = True
                break
        assert found

    async def test_location_config_404(self, client: AsyncClient):
        """Test 404 for non-existent bar."""
        response = await client.get("/bars/9999999/location-config")
        assert response.status_code == 404
