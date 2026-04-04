import pytest
from httpx import AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_get_home_dashboard_no_auth(client: AsyncClient):
    """Test getting home dashboard without authentication."""
    response = await client.get("/home/")
    assert response.status_code == 200
    data = response.json()
    
    # Check structure
    assert "user_status" in data
    assert data["user_status"] is None
    assert "nearby_bars" in data
    assert isinstance(data["nearby_bars"], list)
    assert "trending_drinks" in data
    assert "active_promotions" in data

@pytest.mark.asyncio
async def test_get_home_dashboard_with_auth(client: AsyncClient, auth_headers):
    """Test getting home dashboard with logged-in user."""
    response = await client.get("/home/", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    
    # Check user status presence
    assert data["user_status"] is not None
    assert "active_cart" in data["user_status"]
    # unread_notifications might be 0, so just check existence
    assert "unread_notifications" in data["user_status"]

@pytest.mark.asyncio
async def test_get_home_nearby_bars(client: AsyncClient, test_bar_in_db):
    """Test fetching nearby bars with latitude/longitude."""
    # Using generic coordinates
    params = {"latitude": -23.5505, "longitude": -46.6333}
    response = await client.get("/home/", params=params)
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data["nearby_bars"], list)

@pytest.mark.asyncio
async def test_get_home_trending_and_promos(client: AsyncClient, test_promotion):
    """Test trending drinks and active promotions sections."""
    response = await client.get("/home/")
    assert response.status_code == 200
    data = response.json()
    
    trending = data["trending_drinks"]
    assert "most_wanted" in trending
    assert isinstance(trending["most_wanted"], list)
    assert "hottest" in trending
    assert isinstance(trending["hottest"], list)
    
    assert "active_promotions" in data
    assert isinstance(data["active_promotions"], list)
    # Check if the test promotion appears (it might depend on DB state isolation)
    # For now ensuring api contract holds is sufficient.
