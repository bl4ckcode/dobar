from fastapi import APIRouter, HTTPException
from fastapi.params import Query
from sqlalchemy import and_

from app.errors import CustomHTTPException
from ..models.relational_models import Bar as BarModel, BarOwner
from ..models.nosql_models import bars_collection
from ..schemas.bars import BarCreate, Bar
from ..models.nosql_models import insert_bar_into_mongo  # Import from nosql models
from app.database import database  # Use the async database connection

bars_router = APIRouter(prefix="/bars", tags=["Bars"])

# Helper functions
async def get_bar_owner_by_id(id: int):
    query = BarOwner.__table__.select().where(BarOwner.id == id)
    return await database.fetch_one(query)

async def get_existing_bar(owner_id: int, address: str):
    existiing_owner = await get_bar_owner_by_id(owner_id)
    if not existiing_owner:
        raise CustomHTTPException.not_found()

    query = BarModel.__table__.select().where(
        and_(
            BarModel.owner_id == owner_id,
            BarModel.address == address
        )
    )
    return await database.fetch_one(query)

async def create_new_bar(bar_data: dict):
    owner_id = bar_data["owner_id"]

    # Check for duplicate bar entry by the same owner (e.g., same address)
    existing_bar = await get_existing_bar(owner_id, bar_data["address"])
    
    if existing_bar:
        raise CustomHTTPException.conflict()
    
    # Create the bar in PostgreSQL
    bar_postgres_data = {key: value for key, value in bar_data.items() if key not in ["latitude", "longitude"]}
    query = BarModel.__table__.insert().values(**bar_postgres_data)
    bar_id = await database.execute(query)

    # Insert bar into MongoDB for geospatial and menu
    await insert_bar_into_mongo(bar_id, bar_data["latitude"], bar_data["longitude"])

    return await database.fetch_one(BarModel.__table__.select().where(BarModel.id == bar_id))

# Helper function to get bars from PostgreSQL by bar IDs
async def get_bars_by_ids(bar_ids: list[int]):
    query = BarModel.__table__.select().where(BarModel.id.in_(bar_ids))
    return await database.fetch_all(query)

# Helper function to perform a geospatial query in MongoDB
async def find_bars_near_location(latitude: float, longitude: float, max_distance: float):
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

    # Extract bar IDs from the MongoDB results
    bar_ids = [bar["bar_id"] for bar in bars_nearby]
    return bar_ids

@bars_router.post("/", response_model=Bar)
async def create_bar(bar: BarCreate):
    bar_data = { 
        "name": bar.name,
        "address": bar.address,
        "latitude": bar.latitude,
        "longitude": bar.longitude,
        "phone_number": bar.phone_number,
        "email": bar.email,
        "owner_id": bar.owner_id,
    }
    return await create_new_bar(bar_data)

@bars_router.get("/{bar_id}", response_model=Bar)
async def read_bar(bar_id: int):
    # Fetch the bar by ID
    query = BarModel.__table__.select().where(BarModel.id == bar_id)
    db_bar = await database.fetch_one(query)
    
    if db_bar is None:
        raise CustomHTTPException.not_found()
    
    return db_bar

@bars_router.get("/", response_model=list[Bar])
async def get_bars(
    latitude: float = Query(..., description="Latitude of the location"),
    longitude: float = Query(..., description="Longitude of the location"),
    max_distance: float = Query(5000, description="Max distance in meters (default: 5000m)")
):
    # Perform a geospatial query in MongoDB to find bars near the given location
    bar_ids = await find_bars_near_location(latitude, longitude, max_distance)
    
    if not bar_ids:
        raise CustomHTTPException.not_found("No bars found within the specified distance")
    
    # Fetch bar details from PostgreSQL using the bar IDs
    bars = await get_bars_by_ids(bar_ids)
    
    if not bars:
        raise CustomHTTPException.not_found("No bars found")

    return bars