import math
import os
import httpx


def valid_coordinates(latitude, longitude):
    return all(
        isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)
        for value in (latitude, longitude)
    ) and -90 <= latitude <= 90 and -180 <= longitude <= 180


def coordinates_from_geojson(document):
    if not isinstance(document, dict):
        return None
    location = document.get("location")
    if not isinstance(location, dict) or location.get("type") != "Point":
        return None
    coordinates = location.get("coordinates")
    if not isinstance(coordinates, (list, tuple)) or len(coordinates) != 2:
        return None
    longitude, latitude = coordinates
    return (latitude, longitude) if valid_coordinates(latitude, longitude) else None


def geocode_address(address, country="BR"):
    key = os.getenv("GOOGLE_PLACES_API_KEY")
    if not key or not (address or "").strip():
        return None
    try:
        with httpx.Client(timeout=10.0) as client:
            response = client.get(
                "https://maps.googleapis.com/maps/api/geocode/json",
                params={"address": address.strip(), "components": f"country:{country or 'BR'}", "language": "pt-BR", "key": key},
            )
            response.raise_for_status()
            data = response.json()
        results = data.get("results", [])
        if data.get("status") != "OK" or len(results) != 1:
            return None
        result = results[0]
        if result.get("partial_match") or result.get("geometry", {}).get("location_type") != "ROOFTOP":
            return None
        location = result["geometry"]["location"]
        latitude, longitude = location.get("lat"), location.get("lng")
        return (latitude, longitude) if valid_coordinates(latitude, longitude) else None
    except (httpx.HTTPError, ValueError, TypeError, KeyError, AttributeError):
        return None
