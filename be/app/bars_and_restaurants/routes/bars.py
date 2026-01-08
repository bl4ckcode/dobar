import math
import time
from fastapi import APIRouter, UploadFile, File, Form, Depends
from fastapi.params import Query
from pydantic import EmailStr
from sqlalchemy import and_

from app.bars_and_restaurants.services.image_upload import generate_presigned_url, upload_image_to_s3, extract_s3_key
from app.errors import APIError
from ..models.relational_models import Bar as BarModel, BarOwner
from ..models.nosql_models import bars_collection
from ..schemas.bars import Bar
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
        raise APIError.partner_not_found("Bar owner not found")

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
        raise APIError.conflict("A bar with this address already exists for this owner")
    
    # Create the bar in PostgreSQL (exclude MongoDB-only fields)
    bar_postgres_data = {key: value for key, value in bar_data.items() if key not in ["latitude", "longitude", "image_url"]}
    query = BarModel.__table__.insert().values(**bar_postgres_data)
    bar_id = await database.execute(query)

    # Insert bar into MongoDB for geospatial and menu
    await insert_bar_into_mongo(bar_id, bar_data["latitude"], bar_data["longitude"], bar_data["image_url"])

    # Fetch the newly created bar from PostgreSQL
    return await database.fetch_one(BarModel.__table__.select().where(BarModel.id == bar_id))

# Helper function to get bars from PostgreSQL by bar IDs along with their approximateLocation
async def get_bars_by_ids(bars_info: list[dict]):
    # Extract just the bar IDs from the bars_info list
    bar_ids = [info["bar_id"] for info in bars_info]
    
    # Fetch the bar details from PostgreSQL for those IDs
    query = BarModel.__table__.select().where(BarModel.id.in_(bar_ids))
    pg_bars = await database.fetch_all(query)

    current_time = int(time.time())  # Get current timestamp

    # Create a mapping from bar_id to the extra attributes from Mongo
    extra_data = {
        info["bar_id"]: {
            "approximateLocation": info.get("approximateLocation"),
            "image_url": generate_presigned_url(extract_s3_key(info.get("image_url"))) if info.get("image_url") else None,
            "image_url_expiration": current_time + 3600 if info.get("image_url") else None  # Expire in 1 hour

        }
        for info in bars_info
    }
    
    # Merge extra data into the PostgreSQL data
    merged_results = []
    for bar in pg_bars:
        bar_dict = dict(bar)  # Convert the Record to a dictionary
        bar_id = bar_dict["id"]
        if bar_id in extra_data:
            bar_dict.update(extra_data[bar_id])
        merged_results.append(bar_dict)
    
    return merged_results

def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great-circle distance between two points on the Earth (specified in decimal degrees).
    Returns distance in meters.
    """
    R = 6371000  # Earth radius in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    a = math.sin(delta_phi / 2) ** 2 + \
        math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    return R * c

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
        })
    
    return results

@bars_router.post("/", response_model=Bar)
async def create_bar(name: str = Form(...),
    address: str = Form(...),
    phone_number: str = Form(...),
    email: EmailStr = Form(...),
    owner_id: int = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    image: UploadFile = File(...)
):
    # Upload image to S3
    try:
        image_url = await upload_image_to_s3(image.file, image.filename)
    except Exception as e:
        raise APIError.server_error("Failed to upload image") from e

    bar_data = { 
        "name": name,
        "address": address,
        "latitude": latitude,
        "longitude": longitude,
        "phone_number": phone_number,
        "email": email,
        "owner_id": owner_id,
        "image_url": image_url,
    }
    
    # Create the bar in PostgreSQL and MongoDB
    return await create_new_bar(bar_data)

@bars_router.get("/{bar_id}", response_model=Bar)
async def read_bar(bar_id: int):
    # Fetch the bar by ID
    query = BarModel.__table__.select().where(BarModel.id == bar_id)
    db_bar = await database.fetch_one(query)
    
    if db_bar is None:
        raise APIError.partner_not_found("Bar not found")
    
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
        return []  # Return empty array for Flutter - no bars nearby is a valid state
    
    # Fetch bar details from PostgreSQL using the bar IDs
    bars = await get_bars_by_ids(bar_ids)
    
    if not bars:
        return []  # Return empty array for Flutter

    return bars

@bars_router.put("/{bar_id}/image", response_model=dict)
async def update_bar_image(bar_id: int, image: UploadFile = File(...)):
    # Upload the new image to S3 and get the URL
    try:
        image_url = await upload_image_to_s3(image.file, image.filename)
    except Exception as e:
        raise APIError.server_error("Failed to upload image") from e
    
    # Update the document in MongoDB for the given bar_id
    update_result = await bars_collection.update_one(
        {"bar_id": bar_id},
        {"$set": {"image_url": image_url}}
    )
    
    # Check if any document was updated
    if update_result.modified_count == 0:
        raise APIError.partner_not_found("Bar not found or image URL already exists")
    
    return {"message": "Image updated successfully", "image_url": image_url}

@bars_router.get("/{bar_id}/refresh-image")
async def refresh_image_url(bar_id: int):
    """
    Refresh the presigned S3 URL for a bar's image.
    The image_url is stored in MongoDB, not PostgreSQL.
    """
    # First check if bar exists in PostgreSQL
    bar = await database.fetch_one(BarModel.__table__.select().where(BarModel.id == bar_id))
    if not bar:
        raise APIError.partner_not_found("Bar not found")
    
    # Fetch image_url from MongoDB (where it's actually stored)
    mongo_bar = await bars_collection.find_one({"bar_id": bar_id})
    
    if not mongo_bar or not mongo_bar.get("image_url"):
        raise APIError.not_found("No image available for this bar")
    
    # Generate fresh presigned URL from the S3 key
    s3_key = extract_s3_key(mongo_bar["image_url"])
    new_url = generate_presigned_url(s3_key)
    
    return {
        "image_url": new_url,
        "image_url_expiration": int(time.time()) + 3600  # Expires in 1 hour
    }