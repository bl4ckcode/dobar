import math
import time
import re
from fastapi import APIRouter, UploadFile, File, Form, Depends, Body
from fastapi.params import Query
from pydantic import EmailStr
from sqlalchemy import and_
from typing import Optional

from app.bars_and_restaurants.services.image_upload import generate_presigned_url, upload_image_to_s3, extract_s3_key
from app.errors import APIError
from app.auth.dependencies import get_current_user
from app.auth.auth_models import User
from ..models.relational_models import Bar as BarModel, BarOwner
from ..models.nosql_models import bars_collection
from ..schemas.bars import Bar, BarCreate, BarResponse
from ..models.nosql_models import insert_bar_into_mongo
from app.database import database

bars_router = APIRouter(prefix="/bars", tags=["Bars"])


# =============================================================================
# BUSINESS ID VALIDATION
# =============================================================================

def validate_cnpj(cnpj: str) -> bool:
    """Validate Brazilian CNPJ using modulo 11 algorithm."""
    cnpj = re.sub(r'[^\d]', '', cnpj)
    if len(cnpj) != 14:
        return False
    if cnpj == cnpj[0] * 14:  # All same digits
        return False
    
    # First check digit
    weights1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    sum1 = sum(int(cnpj[i]) * weights1[i] for i in range(12))
    d1 = 11 - (sum1 % 11)
    d1 = 0 if d1 >= 10 else d1
    
    # Second check digit
    weights2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    sum2 = sum(int(cnpj[i]) * weights2[i] for i in range(13))
    d2 = 11 - (sum2 % 11)
    d2 = 0 if d2 >= 10 else d2
    
    return cnpj[-2:] == f"{d1}{d2}"


def validate_cpf(cpf: str) -> bool:
    """Validate Brazilian CPF using modulo 11 algorithm."""
    cpf = re.sub(r'[^\d]', '', cpf)
    if len(cpf) != 11:
        return False
    if cpf == cpf[0] * 11:  # All same digits
        return False
    
    # First check digit
    sum1 = sum(int(cpf[i]) * (10 - i) for i in range(9))
    d1 = 11 - (sum1 % 11)
    d1 = 0 if d1 >= 10 else d1
    
    # Second check digit
    sum2 = sum(int(cpf[i]) * (11 - i) for i in range(10))
    d2 = 11 - (sum2 % 11)
    d2 = 0 if d2 >= 10 else d2
    
    return cpf[-2:] == f"{d1}{d2}"


def validate_business_id(country_code: str, business_id: str, business_id_type: str) -> tuple[bool, str]:
    """
    Validate business ID based on country and type.
    Returns (is_valid, error_message).
    """
    if not business_id:
        return True, ""  # Optional field
    
    business_id_clean = re.sub(r'[^\dA-Za-z]', '', business_id)
    
    validators = {
        "BR": {
            "CNPJ": (lambda x: len(re.sub(r'[^\d]', '', x)) == 14 and validate_cnpj(x), "Invalid CNPJ format"),
            "CPF": (lambda x: len(re.sub(r'[^\d]', '', x)) == 11 and validate_cpf(x), "Invalid CPF format"),
        },
        "PT": {
            "NIF": (lambda x: len(re.sub(r'[^\d]', '', x)) == 9, "NIF must be 9 digits"),
        },
        "US": {
            "EIN": (lambda x: len(re.sub(r'[^\d]', '', x)) == 9, "EIN must be 9 digits"),
        },
        "ES": {
            "CIF": (lambda x: len(x) == 9 and x[0].isalpha(), "CIF must be letter + 8 digits"),
        },
        "MX": {
            "RFC": (lambda x: 12 <= len(x) <= 13, "RFC must be 12-13 characters"),
        },
        "AR": {
            "CUIT": (lambda x: len(re.sub(r'[^\d]', '', x)) == 11, "CUIT must be 11 digits"),
        },
    }
    
    country_validators = validators.get(country_code.upper(), {})
    validator = country_validators.get(business_id_type.upper() if business_id_type else "", None)
    
    if validator:
        is_valid, error = validator
        if not is_valid(business_id):
            return False, error
    
    return True, ""

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
    
    # Check for duplicate business_id in the same country
    if bar_data.get("business_id"):
        existing_business = await database.fetch_one(
            BarModel.__table__.select().where(
                and_(
                    BarModel.country_code == bar_data.get("country_code", "BR"),
                    BarModel.business_id == bar_data["business_id"]
                )
            )
        )
        if existing_business:
            raise APIError.conflict("A bar with this business ID already exists")
    
    # Validate business ID format
    if bar_data.get("business_id"):
        is_valid, error_msg = validate_business_id(
            bar_data.get("country_code", "BR"),
            bar_data["business_id"],
            bar_data.get("business_id_type", "")
        )
        if not is_valid:
            raise APIError.validation_error(error_msg)
    
    # Separate PostgreSQL and MongoDB fields
    mongo_only_fields = {"latitude", "longitude", "image_url"}
    bar_postgres_data = {
        key: value for key, value in bar_data.items() 
        if key not in mongo_only_fields and value is not None
    }
    
    # Create the bar in PostgreSQL
    query = BarModel.__table__.insert().values(**bar_postgres_data)
    bar_id = await database.execute(query)

    # Insert bar into MongoDB for geospatial and menu
    image_url = bar_data.get("image_url") or bar_data.get("logo_url")
    await insert_bar_into_mongo(bar_id, bar_data["latitude"], bar_data["longitude"], image_url)

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


@bars_router.post("/wizard", response_model=BarResponse, summary="Create Bar (Wizard Flow)")
async def create_bar_wizard(bar_data: BarCreate, current_user: User = Depends(get_current_user)):
    from datetime import datetime
    from ..models.bank_account import BarBankAccount
    from ..services import bank_account_service as bas
    from app.auth.rbac_models import BarStaff
    
    data = bar_data.model_dump(exclude_none=True)
    
    data["owner_id"] = current_user.id
    
    bank_account_data = data.pop("bank_account", None)
    
    if bank_account_data:
        country_code = bank_account_data.get("country_code", data.get("country_code", "BR"))
        valid, error = bas.validate_bank_account_for_country(country_code, bank_account_data)
        if not valid:
            raise APIError.validation_error(f"Bank account: {error}")
    
    existing_owner = await get_bar_owner_by_id(current_user.id)
    if not existing_owner:
        user_email = current_user.email if hasattr(current_user, 'email') else current_user["email"] if "email" in dict(current_user._mapping) else None
        user_phone = current_user.phone_number if hasattr(current_user, 'phone_number') else current_user["phone_number"] if "phone_number" in dict(current_user._mapping) else None
        owner_insert = {
            "id": current_user.id,
            "name": data.get("name", "Bar Owner"),
            "email": data.get("email") or user_email,
            "phone_number": data.get("phone_number") or user_phone
        }
        await database.execute(BarOwner.__table__.insert().values(**owner_insert))
    
    if data.get("operating_hours"):
        data["operating_hours"] = {
            day: hours.model_dump() if hasattr(hours, 'model_dump') else hours
            for day, hours in data["operating_hours"].items()
            if hours is not None
        }
    
    created_bar = await create_new_bar(data)
    bar_id = created_bar["id"]
    
    staff_insert = {
        "user_id": current_user.id,
        "bar_id": bar_id,
        "role": "owner",
        "is_active": True,
        "accepted_at": datetime.utcnow()
    }
    await database.execute(BarStaff.__table__.insert().values(**staff_insert))
    
    if bank_account_data:
        country_code = bank_account_data.get("country_code", data.get("country_code", "BR"))
        
        bank_account_insert = {
            "bar_id": bar_id,
            "country_code": country_code.upper(),
            "bank_code": bank_account_data.get("bank_code"),
            "branch_code": bank_account_data.get("branch_code"),
            "account_number_encrypted": bas.encrypt_value(bank_account_data.get("account_number")),
            "account_type": bank_account_data.get("account_type"),
            "pix_key_encrypted": bas.encrypt_value(bank_account_data.get("pix_key")),
            "pix_key_type": bank_account_data.get("pix_key_type"),
            "clabe_encrypted": bas.encrypt_value(bank_account_data.get("clabe")),
            "cbu_encrypted": bas.encrypt_value(bank_account_data.get("cbu")),
            "routing_number": bank_account_data.get("routing_number"),
            "account_holder_name": bank_account_data.get("account_holder_name"),
        }
        bank_account_insert = {k: v for k, v in bank_account_insert.items() if v is not None}
        
        query = BarBankAccount.__table__.insert().values(**bank_account_insert)
        await database.execute(query)
    
    return BarResponse(
        id=created_bar["id"],
        name=created_bar["name"],
        address=created_bar["address"],
        country_code=created_bar["country_code"] or "BR",
        business_id=created_bar["business_id"],
        business_id_type=created_bar["business_id_type"],
        verification_status=created_bar["verification_status"] or "pending",
        created_at=created_bar["created_at"] or datetime.utcnow()
    )


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
    max_distance: float = Query(5000, description="Max distance in meters (default: 5000m)"),
    category: Optional[str] = Query(None, description="Filter by category: bar, night_club, restaurant_bar, cafe_bar, hotel_bar, casino")
):
    bar_ids = await find_bars_near_location(latitude, longitude, max_distance)
    
    if not bar_ids:
        return []
    
    bars = await get_bars_by_ids(bar_ids)
    
    if not bars:
        return []
    
    if category:
        bars = [b for b in bars if b.get("category") == category]

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