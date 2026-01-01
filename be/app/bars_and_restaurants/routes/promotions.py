import time
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form, Query
from sqlalchemy import and_, or_

from app.bars_and_restaurants.services.image_upload import generate_presigned_url, upload_image_to_s3, extract_s3_key
from app.errors import APIError
from ..models.relational_models import Promotion as PromotionModel, Bar as BarModel
from ..models.nosql_models import bars_collection
from ..schemas.promotions import Promotion, PromotionCreate, PromotionUpdate, PromotionWithBar
from app.database import database

promotions_router = APIRouter(prefix="/promotions", tags=["Promotions"])


# Helper functions
async def get_bar_by_id(bar_id: int):
    query = BarModel.__table__.select().where(BarModel.id == bar_id)
    return await database.fetch_one(query)


async def get_promotion_by_id(promotion_id: int):
    query = PromotionModel.__table__.select().where(PromotionModel.id == promotion_id)
    return await database.fetch_one(query)


def add_presigned_url(promo: dict) -> dict:
    """Add presigned URL and expiration to promotion dict."""
    if promo.get("image_url"):
        promo["image_url"] = generate_presigned_url(extract_s3_key(promo["image_url"]))
        promo["image_url_expiration"] = int(time.time()) + 3600
    return promo


# Routes
@promotions_router.get("/", response_model=list[Promotion])
async def get_promotions(
    active_only: bool = Query(True, description="Only return active promotions"),
    limit: int = Query(50, ge=1, le=100, description="Maximum number of promotions to return")
):
    """Get all promotions. By default, only active promotions are returned."""
    if active_only:
        query = PromotionModel.__table__.select().where(
            PromotionModel.is_active == True
        ).order_by(PromotionModel.created_at.desc()).limit(limit)
    else:
        query = PromotionModel.__table__.select().order_by(
            PromotionModel.created_at.desc()
        ).limit(limit)
    
    promotions = await database.fetch_all(query)
    
    # Add presigned URLs to all promotions
    result = []
    for promo in promotions:
        promo_dict = dict(promo)
        add_presigned_url(promo_dict)
        result.append(promo_dict)
    
    return result  # Returns empty list if no promotions - Flutter friendly!


@promotions_router.get("/bar/{bar_id}", response_model=list[Promotion])
async def get_promotions_by_bar(
    bar_id: int,
    active_only: bool = Query(True, description="Only return active promotions")
):
    """Get all promotions for a specific bar."""
    # Check if bar exists
    bar = await get_bar_by_id(bar_id)
    if not bar:
        raise APIError.partner_not_found("Bar not found")
    
    if active_only:
        query = PromotionModel.__table__.select().where(
            and_(
                PromotionModel.bar_id == bar_id,
                PromotionModel.is_active == True
            )
        ).order_by(PromotionModel.created_at.desc())
    else:
        query = PromotionModel.__table__.select().where(
            PromotionModel.bar_id == bar_id
        ).order_by(PromotionModel.created_at.desc())
    
    promotions = await database.fetch_all(query)
    
    result = []
    for promo in promotions:
        promo_dict = dict(promo)
        add_presigned_url(promo_dict)
        result.append(promo_dict)
    
    return result  # Returns empty list if no promotions for this bar


@promotions_router.get("/nearby", response_model=list[PromotionWithBar])
async def get_promotions_nearby(
    latitude: float = Query(..., description="Latitude of the location"),
    longitude: float = Query(..., description="Longitude of the location"),
    max_distance: float = Query(5000, description="Max distance in meters (default: 5000m)"),
    active_only: bool = Query(True, description="Only return active promotions")
):
    """Get active promotions from bars near a location."""
    # Find bars near the location using MongoDB geospatial query
    geo_query = {
        "location": {
            "$near": {
                "$geometry": {"type": "Point", "coordinates": [longitude, latitude]},
                "$maxDistance": max_distance
            }
        }
    }
    
    bars_nearby = await bars_collection.find(geo_query).to_list(None)
    
    if not bars_nearby:
        return []  # No bars nearby
    
    bar_ids = [bar["bar_id"] for bar in bars_nearby]
    
    # Get promotions for these bars
    if active_only:
        query = PromotionModel.__table__.select().where(
            and_(
                PromotionModel.bar_id.in_(bar_ids),
                PromotionModel.is_active == True
            )
        ).order_by(PromotionModel.created_at.desc())
    else:
        query = PromotionModel.__table__.select().where(
            PromotionModel.bar_id.in_(bar_ids)
        ).order_by(PromotionModel.created_at.desc())
    
    promotions = await database.fetch_all(query)
    
    if not promotions:
        return []
    
    # Get bar details for enrichment
    bar_query = BarModel.__table__.select().where(BarModel.id.in_(bar_ids))
    bars = await database.fetch_all(bar_query)
    bar_map = {bar["id"]: dict(bar) for bar in bars}
    
    # Create distance map from MongoDB results
    distance_map = {}
    for bar in bars_nearby:
        bar_lon, bar_lat = bar["location"]["coordinates"]
        # Simple Haversine approximation
        from math import radians, sin, cos, sqrt, atan2
        R = 6371000  # Earth radius in meters
        phi1, phi2 = radians(latitude), radians(bar_lat)
        delta_phi = radians(bar_lat - latitude)
        delta_lambda = radians(bar_lon - longitude)
        a = sin(delta_phi/2)**2 + cos(phi1)*cos(phi2)*sin(delta_lambda/2)**2
        distance_map[bar["bar_id"]] = R * 2 * atan2(sqrt(a), sqrt(1-a))
    
    # Enrich promotions with bar info
    result = []
    for promo in promotions:
        promo_dict = dict(promo)
        add_presigned_url(promo_dict)
        bar = bar_map.get(promo_dict["bar_id"], {})
        promo_dict["bar_name"] = bar.get("name")
        promo_dict["bar_address"] = bar.get("address")
        promo_dict["approximate_location"] = distance_map.get(promo_dict["bar_id"])
        result.append(promo_dict)
    
    return result


@promotions_router.get("/{promotion_id}", response_model=Promotion)
async def get_promotion(promotion_id: int):
    """Get a specific promotion by ID."""
    promo = await get_promotion_by_id(promotion_id)
    
    if not promo:
        raise APIError.not_found("Promotion not found")
    
    promo_dict = dict(promo)
    add_presigned_url(promo_dict)
    
    return promo_dict


@promotions_router.post("/", response_model=Promotion)
async def create_promotion(
    bar_id: int = Form(...),
    title: str = Form(...),
    description: Optional[str] = Form(None),
    discount_type: str = Form("percentage"),
    discount_value: float = Form(...),
    start_time: Optional[str] = Form(None),
    end_time: Optional[str] = Form(None),
    start_date: Optional[datetime] = Form(None),
    end_date: Optional[datetime] = Form(None),
    recurring: bool = Form(False),
    recurring_days: Optional[str] = Form(None),  # Comma-separated: "monday,tuesday,wednesday"
    terms: Optional[str] = Form(None),
    is_active: bool = Form(True),
    image: Optional[UploadFile] = File(None)
):
    """Create a new promotion for a bar."""
    # Check if bar exists
    bar = await get_bar_by_id(bar_id)
    if not bar:
        raise APIError.partner_not_found("Bar not found")
    
    # Upload image if provided
    image_url = None
    if image:
        try:
            image_url = await upload_image_to_s3(image.file, image.filename)
        except Exception as e:
            raise APIError.server_error("Failed to upload image") from e
    
    # Parse recurring days
    recurring_days_list = None
    if recurring_days:
        recurring_days_list = [day.strip().lower() for day in recurring_days.split(",")]
    
    # Create promotion
    promo_data = {
        "bar_id": bar_id,
        "title": title,
        "description": description,
        "discount_type": discount_type,
        "discount_value": discount_value,
        "start_time": start_time,
        "end_time": end_time,
        "start_date": start_date,
        "end_date": end_date,
        "recurring": recurring,
        "recurring_days": recurring_days_list,
        "terms": terms,
        "is_active": is_active,
        "image_url": image_url,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }
    
    query = PromotionModel.__table__.insert().values(**promo_data)
    promo_id = await database.execute(query)
    
    # Fetch and return the created promotion
    created_promo = await get_promotion_by_id(promo_id)
    promo_dict = dict(created_promo)
    add_presigned_url(promo_dict)
    
    return promo_dict


@promotions_router.put("/{promotion_id}", response_model=Promotion)
async def update_promotion(
    promotion_id: int,
    title: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    discount_type: Optional[str] = Form(None),
    discount_value: Optional[float] = Form(None),
    start_time: Optional[str] = Form(None),
    end_time: Optional[str] = Form(None),
    start_date: Optional[datetime] = Form(None),
    end_date: Optional[datetime] = Form(None),
    recurring: Optional[bool] = Form(None),
    recurring_days: Optional[str] = Form(None),
    terms: Optional[str] = Form(None),
    is_active: Optional[bool] = Form(None),
    image: Optional[UploadFile] = File(None)
):
    """Update an existing promotion."""
    promo = await get_promotion_by_id(promotion_id)
    if not promo:
        raise APIError.not_found("Promotion not found")
    
    # Build update data (only include non-None values)
    update_data = {"updated_at": datetime.utcnow()}
    
    if title is not None:
        update_data["title"] = title
    if description is not None:
        update_data["description"] = description
    if discount_type is not None:
        update_data["discount_type"] = discount_type
    if discount_value is not None:
        update_data["discount_value"] = discount_value
    if start_time is not None:
        update_data["start_time"] = start_time
    if end_time is not None:
        update_data["end_time"] = end_time
    if start_date is not None:
        update_data["start_date"] = start_date
    if end_date is not None:
        update_data["end_date"] = end_date
    if recurring is not None:
        update_data["recurring"] = recurring
    if recurring_days is not None:
        update_data["recurring_days"] = [day.strip().lower() for day in recurring_days.split(",")]
    if terms is not None:
        update_data["terms"] = terms
    if is_active is not None:
        update_data["is_active"] = is_active
    
    # Handle image upload
    if image:
        try:
            update_data["image_url"] = await upload_image_to_s3(image.file, image.filename)
        except Exception as e:
            raise APIError.server_error("Failed to upload image") from e
    
    # Execute update
    query = PromotionModel.__table__.update().where(
        PromotionModel.id == promotion_id
    ).values(**update_data)
    await database.execute(query)
    
    # Fetch and return updated promotion
    updated_promo = await get_promotion_by_id(promotion_id)
    promo_dict = dict(updated_promo)
    add_presigned_url(promo_dict)
    
    return promo_dict


@promotions_router.delete("/{promotion_id}")
async def delete_promotion(promotion_id: int):
    """Delete a promotion."""
    promo = await get_promotion_by_id(promotion_id)
    if not promo:
        raise APIError.not_found("Promotion not found")
    
    query = PromotionModel.__table__.delete().where(PromotionModel.id == promotion_id)
    await database.execute(query)
    
    return {"message": "Promotion deleted successfully", "id": promotion_id}


@promotions_router.put("/{promotion_id}/toggle-active", response_model=Promotion)
async def toggle_promotion_active(promotion_id: int):
    """Toggle the active status of a promotion."""
    promo = await get_promotion_by_id(promotion_id)
    if not promo:
        raise APIError.not_found("Promotion not found")
    
    new_status = not promo["is_active"]
    
    query = PromotionModel.__table__.update().where(
        PromotionModel.id == promotion_id
    ).values(is_active=new_status, updated_at=datetime.utcnow())
    await database.execute(query)
    
    updated_promo = await get_promotion_by_id(promotion_id)
    promo_dict = dict(updated_promo)
    add_presigned_url(promo_dict)
    
    return promo_dict
