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
from app.auth.middleware import get_current_user, AuthUser
from app.auth.auth_models import User
from ..models.relational_models import Bar as BarModel, BarOwner, Promotion as PromotionModel, Order
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
            "image_url_expiration": current_time + 3600 if info.get("image_url") else None,  # Expire in 1 hour
            "latitude": info.get("latitude"),
            "longitude": info.get("longitude"),
        }
        for info in bars_info
    }
    
    # Map PostgreSQL results into a dictionary for fast lookup by ID
    pg_bars_map = {dict(bar)["id"]: dict(bar) for bar in pg_bars}
    
    # Reassemble merged results in the ORIGINAL order of bar_ids (distance order)
    merged_results = []
    for b_info in bars_info:
        # Robustly handle string/int bar_id from MongoDB
        try:
            b_id = int(b_info["bar_id"])
        except (ValueError, TypeError):
            continue

        if b_id in pg_bars_map:
            bar_dict = pg_bars_map[b_id].copy() # Use .copy() to avoid mutating the map source
            if b_id in extra_data:
                bar_dict.update(extra_data[b_id])
            merged_results.append(bar_dict)
    
    # Sort: Premium bars first (master, vip, pro), then by distance (approximateLocation)
    tier_weights = {"master": 0, "vip": 1, "pro": 2, "regular": 3}
    merged_results.sort(
        key=lambda x: (
            tier_weights.get(x.get("subscription_tier"), 3),
            x.get("approximateLocation", 0)
        )
    )
    
    # Trace for debugging
    print(f"DEBUG: get_bars_by_ids: Matched {len(merged_results)}/{len(bars_info)} bars, PRO first.")
    
    return merged_results


from app.bars_and_restaurants.services.places_service import find_bars_near_location


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
        user_email = current_user.email
        user_phone = current_user.phone_number
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
    max_distance: float = Query(50000, description="Max distance in meters (default: 50000m)"),
    current_user: AuthUser = Depends(get_current_user),
    category: Optional[str] = Query(None, description="Filter by category: bar, night_club, restaurant_bar, cafe_bar, hotel_bar, casino")
):
    bar_ids = await find_bars_near_location(latitude, longitude, max_distance)
    
    if not bar_ids:
        return []
    
    bars = await get_bars_by_ids(bar_ids)
    
    if not bars:
        return []

    # Filter by user country
    user_country = current_user.country_code or "BR"
    bars = [b for b in bars if (b.get("country_code") or "BR") == user_country]
    
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
        raise APIError.partner_not_found(f"Bar with ID {bar_id} not found in PostgreSQL")
    
    # Fetch image_url from MongoDB (where it's actually stored)
    mongo_bar = await bars_collection.find_one({"bar_id": bar_id})
    
    if not mongo_bar or not mongo_bar.get("image_url"):
        # Fallback: Check if there's a logo_url or image_url in PostgreSQL (some legacy items might differ)
        # For now, we strictly follow the MongoDB source of truth for dynamic metadata
        raise APIError.not_found(f"No image URL found in MongoDB for bar {bar_id}")
    
    try:
        raw_image_url = mongo_bar["image_url"]
        
        # Security/Sanity Check: If it's already a presigned URL or has query params, 
        # we still want to extract the base key to get a FRESH presigned URL.
        s3_key = extract_s3_key(raw_image_url)
        
        if not s3_key:
            raise ValueError("Could not extract S3 key from URL")
            
        new_url = generate_presigned_url(s3_key)
        
        if not new_url:
            raise APIError.server_error("Failed to generate presigned URL from S3")
            
        return {
            "bar_id": bar_id,
            "image_url": new_url,
            "image_url_expiration": int(time.time()) + 3600  # Expires in 1 hour
        }
    except Exception as e:
        import logging
        logging.error(f"Error refreshing image for bar {bar_id}: {str(e)}")
        raise APIError.server_error(f"Image refresh failed: {str(e)}")


@bars_router.get("/{bar_id}/location-config")
async def get_location_config(bar_id: int):
    """
    Get the Place Location configuration for a bar.
    Used by Frontend to render "Where are you?" UI (Table Number vs Spot List vs Free Text).
    """
    query = BarModel.__table__.select().where(BarModel.id == bar_id)
    bar = await database.fetch_one(query)
    
    if not bar:
        raise APIError.partner_not_found("Bar not found")
    
    return {
        "method": bar["location_method"] or "table_number",
        "spots": bar["location_spots"] or []
    }


@bars_router.get("/{bar_id}/spots/{spot_id}/availability")
async def check_spot_availability(bar_id: int, spot_id: str):
    """
    Check if a specific spot (table/seat) is available.
    Returns { "is_available": bool, "message": str | None }
    """
    # 1. Get bar
    query = BarModel.__table__.select().where(BarModel.id == bar_id)
    bar = await database.fetch_one(query)
    
    if not bar:
        raise APIError.partner_not_found("Bar not found")
    
    # 2. Check if spot exists in bar config
    location_spots = bar["location_spots"] or []
    
    # Handle potential string format from SQLite/legacy data
    if isinstance(location_spots, str):
        import json
        try:
            location_spots = json.loads(location_spots)
        except json.JSONDecodeError:
            location_spots = []
            
    spot_exists = any(spot.get("id") == spot_id for spot in location_spots)
    
    if not spot_exists:
        raise APIError.partner_not_found("Spot not found in bar configuration")
    
    # 3. Check for active orders at this spot
    # Active = pending, preparing, ready (not completed, cancelled)
    query = Order.__table__.select().where(
        and_(
            Order.bar_id == bar_id,
            Order.location_identifier == spot_id,
            Order.status.in_(["pending", "preparing", "ready"])
        )
    )
    existing_order = await database.fetch_one(query)
    
    if existing_order:
        return {"is_available": False, "message": "Spot occupied"}
    
    return {"is_available": True, "message": None}


@bars_router.get("/{bar_id}/promotions")
async def get_bar_promotions(bar_id: int):
    """
    Get active promotions for a specific bar.
    Used by Frontend to populate the Active Promotions bottom sheet.
    """
    # Check if bar exists
    bar_query = BarModel.__table__.select().where(BarModel.id == bar_id)
    bar = await database.fetch_one(bar_query)
    if not bar:
        raise APIError.partner_not_found("Bar not found")

    # Fetch active promotions
    query = PromotionModel.__table__.select().where(
        and_(
            PromotionModel.bar_id == bar_id,
            PromotionModel.is_active == True
        )
    ).order_by(PromotionModel.created_at.desc())
    
    promotions = await database.fetch_all(query)
    
    result = []
    current_time = int(time.time())
    
    for promo in promotions:
        promo_dict = dict(promo)
        # Handle image URL signing if present
        if promo_dict.get("image_url"):
            promo_dict["image_url"] = generate_presigned_url(extract_s3_key(promo_dict["image_url"]))
            promo_dict["image_url_expiration"] = current_time + 3600
        result.append(promo_dict)
    
    return result