from unittest.mock import MagicMock
import httpx
import pytest
from app.bars_and_restaurants.services import venue_location as service


@pytest.fixture
def geocoder(monkeypatch):
    monkeypatch.setenv("GOOGLE_PLACES_API_KEY", "test-key")
    client = MagicMock()
    client.__enter__.return_value = client
    monkeypatch.setattr(service.httpx, "Client", lambda **kwargs: client)
    client.get.return_value.json.return_value = {
        "status": "OK", "results": [{"geometry": {
            "location_type": "ROOFTOP", "location": {"lat": -19.92, "lng": -43.94},
        }}],
    }
    return client


def test_geocodes_full_address_without_exposing_key(geocoder):
    assert service.geocode_address(" Rua Teste, 241 ") == (-19.92, -43.94)
    assert geocoder.get.call_args.kwargs["params"]["address"] == "Rua Teste, 241"
    assert geocoder.get.call_args.kwargs["params"]["components"] == "country:BR"


@pytest.mark.parametrize("change", ["partial", "approximate", "multiple", "invalid", "empty", "denied"])
def test_uncertain_results_are_not_checkin_locations(geocoder, change):
    data = geocoder.get.return_value.json.return_value
    result = data["results"][0]
    if change == "partial":
        result["partial_match"] = True
    elif change == "approximate":
        result["geometry"]["location_type"] = "APPROXIMATE"
    elif change == "multiple":
        data["results"].append(result)
    elif change == "invalid":
        result["geometry"]["location"]["lat"] = 100
    elif change == "empty":
        data["results"] = []
    else:
        data["status"] = "REQUEST_DENIED"
    assert service.geocode_address("Rua Teste, 241") is None


def test_provider_timeout_and_missing_configuration_are_recoverable(geocoder, monkeypatch):
    geocoder.get.side_effect = httpx.ReadTimeout("timeout")
    assert service.geocode_address("Rua Teste, 241") is None
    monkeypatch.delenv("GOOGLE_PLACES_API_KEY")
    geocoder.reset_mock()
    assert service.geocode_address("Rua Teste, 241") is None
    geocoder.get.assert_not_called()


def test_geojson_uses_longitude_latitude_order():
    document = {"location": {"type": "Point", "coordinates": [-43.94, -19.92]}}
    assert service.coordinates_from_geojson(document) == (-19.92, -43.94)


@pytest.mark.parametrize("document", [
    None, {}, {"location": None}, {"location": []},
    {"location": {"type": "LineString", "coordinates": [-43.94, -19.92]}},
    *({"location": {"type": "Point", "coordinates": value}} for value in (
        None, "-43.94,-19.92", [], [-43.94], [-43.94, -19.92, 0],
        [None, None], [-43.94, 91], [-181, -19.92], [True, -19.92],
        [float("nan"), -19.92], [-43.94, float("inf")],
    )),
])
def test_invalid_mongodb_locations_do_not_define_venue_position(document):
    assert service.coordinates_from_geojson(document) is None
