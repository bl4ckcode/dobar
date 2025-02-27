from fastapi import APIRouter, HTTPException, Query
from ..models.nosql_models import bars_collection

bars_geo_router = APIRouter()

@bars_geo_router.get("/nearby")
async def get_nearby_bars(longitude: float, latitude: float, max_distance: float = 5000):
    # Query for bars within max_distance (in meters)
    query = {
        "location": {
            "$near": {
                "$geometry": {"type": "Point", "coordinates": [longitude, latitude]},
                "$maxDistance": max_distance
            }
        }
    }

    nearby_bars = []
    async for bar in bars_collection.find(query):
        nearby_bars.append(bar)
    
    return nearby_bars
