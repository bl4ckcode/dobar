import pytest
from datetime import datetime, timezone
from decimal import Decimal

from app.advertising.routes import _campaign_to_response

def test_campaign_to_response_missing_dates():
    # Simulate DB dict missing created_at and updated_at
    campaign = {
        "id": 1,
        "bar_id": 16,
        "name": "Test Campaign",
        "campaign_type": "featured",
        "status": "active",
        "budget_type": "cpc",
        "budget_amount": Decimal("100.00"),
        "budget_spent": Decimal("10.00"),
        "start_time": datetime.now(timezone.utc),
        "end_time": None,
        "targeting": {},
        "creative": {},
        "impressions": 100,
        "clicks": 5,
        "conversions": 1,
        "created_at": None,
        "updated_at": None
    }
    
    response = _campaign_to_response(campaign)
    
    # Assert validation passes and dates are set
    assert response.id == 1
    assert response.created_at is not None
    assert response.updated_at is not None

def test_haversine_proximity_calculation():
    from app.advertising.services.proximity_service import ProximityService
    
    # Exact coordinates for Paulistano Bar 
    bar_lat, bar_lon = -23.5505, -46.6333
    
    # User standing identical coordinates (0 meters)
    distance = ProximityService.haversine(bar_lat, bar_lon, bar_lat, bar_lon)
    assert distance == 0.0
    
    # User walking roughly 100 meters away
    user_lat, user_lon = -23.5514, -46.6333 
    distance = ProximityService.haversine(user_lat, user_lon, bar_lat, bar_lon)
    # 100m away should trigger a 500m geofence comfortably
    assert 90 < distance < 110
    
    # User several kilometers away
    user_lat, user_lon = -23.5805, -46.6333
    distance = ProximityService.haversine(user_lat, user_lon, bar_lat, bar_lon)
    assert distance > 1000 # More than 1km, definitely outside standard geofence

import pytest
from unittest.mock import AsyncMock, patch

@pytest.mark.asyncio
async def test_order_checkout_conversion_tracking():
    with patch("app.bars_and_restaurants.routes.orders.get_redis") as mock_get_redis:
        mock_client = AsyncMock()
        mock_get_redis.return_value = mock_client
        
        # Simulate active cached campaign click 
        mock_client.get.return_value = "777"
        
        from app.bars_and_restaurants.routes.orders import create_order
        from app.bars_and_restaurants.schemas.orders import OrderCreate
        from fastapi import BackgroundTasks
        
        # Dummy order payload
        order_payload = OrderCreate(
            user_id=40,
            bar_id=10,
            order_type="dine_in",
            payment_method="pix",
            subtotal=55.0,
            total_price=55.0,
            items=[]
        )
        
        # We also need to patch database, user auth, and order queue since we are testing internal dependencies
        with patch("app.bars_and_restaurants.routes.orders.database") as mock_db, \
             patch("app.bars_and_restaurants.routes.orders.OrderQueue") as mock_oq:
             
            mock_db.execute = AsyncMock(return_value=1)
            mock_db.fetch_one = AsyncMock(return_value={"id": 1, "user_id": 40, "bar_id": 10})
            mock_oq.publish_new_order = AsyncMock()
            
            mock_bg_tasks = BackgroundTasks()
            
            # Execute route
            await create_order(
                order=order_payload,
                background_tasks=mock_bg_tasks,
                _internal=True
            )
            
            # Assert redis fetch clicked logic
            mock_client.get.assert_called_once_with("user:40:campaign_click:10")
            
            # Assert task was enqueued to process conversion
            assert len(mock_bg_tasks.tasks) == 1
            added_task = mock_bg_tasks.tasks[0]
            
            # Verify params: CampaignService.track_event(campaign_id=777, action="conversion")
            assert added_task.kwargs == {
                "campaign_id": 777,
                "action": "conversion",
                "placement": "order_checkout",
                "user_id": 40
            }
            
            # Verify redis clears cache afterwards so no double attribution occurs
            mock_client.delete.assert_called_once_with("user:40:campaign_click:10")
