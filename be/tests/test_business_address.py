from unittest.mock import AsyncMock, Mock
import pytest
from app.bars_and_restaurants.routes import business_settings as routes
from app.errors import APIError


@pytest.fixture
def details(monkeypatch):
    bar = {"id": 16, "name": "Baxo Bar", "address": "Rua Antiga, 241", "country_code": "BR", "latitude": -19.9, "longitude": -43.9}
    monkeypatch.setattr(routes, "_get_bar", AsyncMock(return_value=bar))
    monkeypatch.setattr(routes, "_enrich_with_mongo", AsyncMock(side_effect=lambda value: value))
    monkeypatch.setattr(routes, "_extract_city_state", lambda value: value)
    monkeypatch.setattr(routes, "_bar_to_details", lambda value: value)
    database = AsyncMock()
    monkeypatch.setattr(routes, "database", database)
    return bar, database


@pytest.mark.asyncio
async def test_address_edit_replaces_stale_coordinates(details, monkeypatch):
    _, database = details
    geocode = Mock(return_value=(-19.92, -43.94))
    monkeypatch.setattr(routes, "geocode_address", geocode)
    await routes.update_business_details(16, routes.BarDetailsUpdate(address="Rua Nova, 200"), auth=None)
    values = database.execute.call_args.args[0].compile().params
    assert values["latitude"] == -19.92
    assert values["longitude"] == -43.94
    assert values["address"] == "Rua Nova, 200"
    geocode.assert_called_once_with("Rua Nova, 200", "BR")


@pytest.mark.asyncio
async def test_failed_address_resolution_does_not_save_old_coordinates(details, monkeypatch):
    _, database = details
    monkeypatch.setattr(routes, "geocode_address", lambda *args: None)
    with pytest.raises(APIError) as caught:
        await routes.update_business_details(16, routes.BarDetailsUpdate(address="Unknown"), auth=None)
    assert caught.value.details == {"address": ["location_unavailable"]}
    database.execute.assert_not_called()


@pytest.mark.asyncio
async def test_unrelated_edit_preserves_configured_coordinates(details, monkeypatch):
    _, database = details
    geocode = Mock(side_effect=AssertionError("Unexpected provider call"))
    monkeypatch.setattr(routes, "geocode_address", geocode)
    await routes.update_business_details(16, routes.BarDetailsUpdate(bar_name="Novo nome"), auth=None)
    values = database.execute.call_args.args[0].compile().params
    assert "latitude" not in values
    assert "longitude" not in values
    geocode.assert_not_called()
