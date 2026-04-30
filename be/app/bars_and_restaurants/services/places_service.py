import httpx
import hashlib
from typing import Optional, List
from datetime import datetime, timedelta
import os

GOOGLE_PLACES_API_KEY = os.getenv("GOOGLE_PLACES_API_KEY")
GOOGLE_PLACES_BASE_URL = "https://maps.googleapis.com/maps/api/place"

_places_cache: dict = {}
CACHE_TTL_SECONDS = 3600


def _get_cache_key(endpoint: str, params: dict) -> str:
    params_str = str(sorted(params.items()))
    return hashlib.md5(f"{endpoint}:{params_str}".encode()).hexdigest()


def _get_cached(cache_key: str) -> Optional[dict]:
    if cache_key in _places_cache:
        entry = _places_cache[cache_key]
        if datetime.utcnow() < entry["expires_at"]:
            return entry["data"]
        else:
            del _places_cache[cache_key]
    return None


def _set_cached(cache_key: str, data: dict, ttl: int = CACHE_TTL_SECONDS):
    _places_cache[cache_key] = {
        "data": data,
        "expires_at": datetime.utcnow() + timedelta(seconds=ttl),
    }


async def autocomplete(
    input_text: str,
    countries: Optional[List[str]] = None,
    types: str = "establishment",
    session_token: Optional[str] = None,
    language: str = "pt-BR",
) -> dict:
    if not GOOGLE_PLACES_API_KEY:
        return {"status": "ERROR", "error_message": "Google Places API key not configured"}
    
    params = {
        "input": input_text,
        "key": GOOGLE_PLACES_API_KEY,
        "types": types,
        "language": language,
    }
    
    if countries:
        params["components"] = "|".join(f"country:{c.lower()}" for c in countries)
    
    if session_token:
        params["sessiontoken"] = session_token
    
    cache_params = {k: v for k, v in params.items() if k not in ("key", "sessiontoken")}
    cache_key = _get_cache_key("autocomplete", cache_params)
    cached = _get_cached(cache_key)
    if cached:
        return cached
    
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{GOOGLE_PLACES_BASE_URL}/autocomplete/json",
            params=params,
            timeout=10.0,
        )
        data = response.json()
    
    if data.get("status") == "OK":
        _set_cached(cache_key, data, ttl=1800)
    
    return data


async def get_place_details(
    place_id: str,
    fields: Optional[str] = None,
    session_token: Optional[str] = None,
    language: str = "pt-BR",
) -> dict:
    if not GOOGLE_PLACES_API_KEY:
        return {"status": "ERROR", "error_message": "Google Places API key not configured"}
    
    if not fields:
        fields = ",".join([
            "place_id",
            "name",
            "formatted_address",
            "geometry",
            "address_components",
            "formatted_phone_number",
            "website",
            "opening_hours",
            "types",
        ])
    
    params = {
        "place_id": place_id,
        "key": GOOGLE_PLACES_API_KEY,
        "fields": fields,
        "language": language,
    }
    
    if session_token:
        params["sessiontoken"] = session_token
    
    cache_params = {k: v for k, v in params.items() if k not in ("key", "sessiontoken")}
    cache_key = _get_cache_key("details", cache_params)
    cached = _get_cached(cache_key)
    if cached:
        return cached
    
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{GOOGLE_PLACES_BASE_URL}/details/json",
            params=params,
            timeout=10.0,
        )
        data = response.json()
    
    if data.get("status") == "OK":
        _set_cached(cache_key, data, ttl=86400)
    
    return data


def extract_country_code(address_components: List[dict]) -> Optional[str]:
    for component in address_components:
        if "country" in component.get("types", []):
            return component.get("short_name")
    return None


def extract_coordinates(geometry: dict) -> tuple[Optional[float], Optional[float]]:
    location = geometry.get("location", {})
    return (location.get("lat"), location.get("lng"))


def _derive_category(google_types: List[str]) -> str:
    types_set = set(google_types)
    
    if "night_club" in types_set:
        return "night_club"
    if "casino" in types_set:
        return "casino"
    if "lodging" in types_set and "bar" in types_set:
        return "hotel_bar"
    if "cafe" in types_set:
        return "cafe_bar"
    if "restaurant" in types_set and "bar" in types_set:
        return "restaurant_bar"
    if "bar" in types_set:
        return "bar"
    if "restaurant" in types_set:
        return "restaurant_bar"
    
    return "bar"


def parse_place_for_bar_creation(place_details: dict) -> dict:
    result = place_details.get("result", place_details)
    
    address_components = result.get("address_components", [])
    geometry = result.get("geometry", {})
    lat, lng = extract_coordinates(geometry)
    google_types = result.get("types", [])
    
    return {
        "name": result.get("name"),
        "address": result.get("formatted_address"),
        "latitude": lat,
        "longitude": lng,
        "phone_number": result.get("formatted_phone_number"),
        "country_code": extract_country_code(address_components),
        "google_place_id": result.get("place_id"),
        "_raw_opening_hours": result.get("opening_hours"),
        "category": _derive_category(google_types),
        "google_types": google_types,
    }


async def reverse_geocode(latitude: float, longitude: float) -> Optional[str]:
    """Get the country code for a given lat/lng using Google Geocoding API."""
    if not GOOGLE_PLACES_API_KEY:
        return None
    
    params = {
        "latlng": f"{latitude},{longitude}",
        "key": GOOGLE_PLACES_API_KEY,
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://maps.googleapis.com/maps/api/geocode/json",
            params=params,
            timeout=10.0,
        )
        data = response.json()
    
    if data.get("status") == "OK":
        results = data.get("results", [])
        if results:
            # Check the first result's address components for country
            for component in results[0].get("address_components", []):
                if "country" in component.get("types", []):
                    return component.get("short_name") # BR, AR, US, etc.
    return None

# =============================================================================
# GEOSPATIAL UTILS
# =============================================================================

def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great-circle distance between two points on the Earth (specified in decimal degrees).
    Returns distance in meters.
    """
    import math
    R = 6371000  # Earth radius in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    a = math.sin(delta_phi / 2) ** 2 + \
        math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    return R * c


async def find_bars_near_location(latitude: float, longitude: float, max_distance: float):
    from ..models.nosql_models import bars_collection
    
    query = {
        "location": {
            "$near": {
                "$geometry": {"type": "Point", "coordinates": [longitude, latitude]},
                "$maxDistance": max_distance  # maxDistance is in meters
            }
        }
    }
    # Perform the query to find bars within the max distance
    bars_nearby = await bars_collection.find(query).to_list(None)
    
    if not bars_nearby:
        return []

    results = []
    for bar in bars_nearby:
        # The 'location' field in MongoDB is stored as GeoJSON, where coordinates are [longitude, latitude]
        bar_lon, bar_lat = bar["location"]["coordinates"]
        # Calculate the distance between the bar and the input coordinates
        distance = haversine(latitude, longitude, bar_lat, bar_lon)
        results.append({
            "bar_id": bar["bar_id"],
            "approximateLocation": distance,
            "image_url": bar.get("image_url", None),
            "latitude": bar_lat,
            "longitude": bar_lon,
        })
    
    return results
