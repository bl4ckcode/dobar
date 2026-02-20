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
