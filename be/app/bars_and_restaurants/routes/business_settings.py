"""
Business Settings Routes - Bar profile, contact, deactivation management
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime, timezone
from decimal import Decimal

from ...database import database
from ...auth.rbac_middleware import (
    AuthUser, BarAuthContext, get_current_user,
    require_bar_permission, require_bar_role
)
from ...auth.rbac_models import Permission, BarRole
from ..models.relational_models import Bar as BarModel
from ..models.cart_models import OrderItem, Cart, CartItem
from ..models.relational_models import Order, Menu, MenuItem, Promotion, BundlePromotion, Notification
from ...advertising.models import AdvertisingCampaign, AdvertisingImpression, AdvertisingInvoice, AdvertisingSubscription
from ...errors import APIError


business_settings_router = APIRouter(prefix="/bars/{bar_id}", tags=["Business Settings"])


# =============================================================================
# SCHEMAS
# =============================================================================

class BarDetailsResponse(BaseModel):
    bar_id: int
    bar_name: str
    description: Optional[str] = None
    category: Optional[str] = None
    address: Optional[str] = None
    country: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    cover_image_url: Optional[str] = None
    logo_url: Optional[str] = None
    timezone: Optional[str] = None
    operating_hours: Optional[dict] = None
    status: str = "active"
    rating: float = 0.0
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class BarDetailsUpdate(BaseModel):
    bar_name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=2000)
    category: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    cover_image_url: Optional[str] = None
    logo_url: Optional[str] = None
    operating_hours: Optional[dict] = None


class ContactResponse(BaseModel):
    bar_id: int
    phone: Optional[str] = None
    email: Optional[str] = None
    website: Optional[str] = None
    instagram: Optional[str] = None
    facebook: Optional[str] = None
    whatsapp: Optional[str] = None
    whatsapp_enabled: bool = False
    updated_at: Optional[datetime] = None


class ContactUpdate(BaseModel):
    phone: Optional[str] = Field(None, max_length=20)
    email: Optional[str] = Field(None, max_length=255)
    website: Optional[str] = Field(None, max_length=255)
    instagram: Optional[str] = Field(None, max_length=100)
    facebook: Optional[str] = Field(None, max_length=100)
    whatsapp: Optional[str] = Field(None, max_length=20)
    whatsapp_enabled: Optional[bool] = None


class DeleteResult(BaseModel):
    message: str
    deleted_records: dict
    receipt_id: str


class DeactivateRequest(BaseModel):
    reason: Optional[str] = Field(None, description="temporary_closure, vacation, maintenance, other")
    estimated_return_date: Optional[datetime] = None


class StatusResponse(BaseModel):
    bar_id: int
    status: str
    message: str
    deactivated_at: Optional[datetime] = None
    reactivated_at: Optional[datetime] = None
    estimated_return_date: Optional[datetime] = None


# =============================================================================
# HELPERS
# =============================================================================

async def _get_bar(bar_id: int) -> dict:
    """Fetch bar by ID or raise 404."""
    query = BarModel.__table__.select().where(BarModel.id == bar_id)
    bar = await database.fetch_one(query)
    if not bar:
        raise APIError.not_found("Bar not found")
    return dict(bar)


def _bar_to_details(bar: dict) -> BarDetailsResponse:
    return BarDetailsResponse(
        bar_id=bar["id"],
        bar_name=bar.get("name", ""),
        description=bar.get("description"),
        category=bar.get("category"),
        address=bar.get("address"),
        country=bar.get("country_code", "BR"),
        latitude=bar.get("latitude"),
        longitude=bar.get("longitude"),
        cover_image_url=bar.get("cover_url"),
        logo_url=bar.get("logo_url"),
        timezone=bar.get("timezone", "America/Sao_Paulo"),
        operating_hours=bar.get("operating_hours"),
        status=bar.get("status", "active"),
        rating=bar.get("rating", 0.0),
        created_at=bar.get("created_at"),
        updated_at=bar.get("updated_at"),
    )


def _bar_to_contact(bar: dict) -> ContactResponse:
    return ContactResponse(
        bar_id=bar["id"],
        phone=bar.get("phone_number"),
        email=bar.get("email"),
        website=bar.get("website"),
        instagram=bar.get("instagram"),
        facebook=bar.get("facebook"),
        whatsapp=bar.get("whatsapp"),
        whatsapp_enabled=bar.get("whatsapp_enabled", False),
        updated_at=bar.get("updated_at"),
    )


# =============================================================================
# ROUTES
# =============================================================================

@business_settings_router.get("/details", response_model=BarDetailsResponse)
async def get_business_details(
    bar_id: int,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.BAR_EDIT)),
):
    """Get full business profile details."""
    bar = await _get_bar(bar_id)
    return _bar_to_details(bar)


@business_settings_router.put("/details", response_model=BarDetailsResponse)
async def update_business_details(
    bar_id: int,
    update: BarDetailsUpdate,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.BAR_EDIT)),
):
    """Update business profile details (partial update)."""
    bar = await _get_bar(bar_id)
    
    values = {}
    field_map = {
        "bar_name": "name",
        "description": "description",
        "category": "category",
        "address": "address",
        "latitude": "latitude",
        "longitude": "longitude",
        "cover_image_url": "cover_url",
        "logo_url": "logo_url",
        "operating_hours": "operating_hours",
    }
    
    for req_field, db_field in field_map.items():
        val = getattr(update, req_field, None)
        if val is not None:
            values[db_field] = val
    
    if not values:
        return _bar_to_details(bar)
    
    values["updated_at"] = datetime.now(timezone.utc)
    
    await database.execute(
        BarModel.__table__.update()
        .where(BarModel.id == bar_id)
        .values(**values)
    )
    
    updated_bar = await _get_bar(bar_id)
    return _bar_to_details(updated_bar)


@business_settings_router.get("/contact", response_model=ContactResponse)
async def get_contact_settings(
    bar_id: int,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.BAR_EDIT)),
):
    """Get bar contact information."""
    bar = await _get_bar(bar_id)
    return _bar_to_contact(bar)


@business_settings_router.put("/contact", response_model=ContactResponse)
async def update_contact_settings(
    bar_id: int,
    update: ContactUpdate,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.BAR_EDIT)),
):
    """Update bar contact information (partial update)."""
    bar = await _get_bar(bar_id)
    
    values = {}
    field_map = {
        "phone": "phone_number",
        "email": "email",
        "website": "website",
        "instagram": "instagram",
        "facebook": "facebook",
        "whatsapp": "whatsapp",
        "whatsapp_enabled": "whatsapp_enabled",
    }
    
    for req_field, db_field in field_map.items():
        val = getattr(update, req_field, None)
        if val is not None:
            values[db_field] = val
    
    if not values:
        return _bar_to_contact(bar)
    
    values["updated_at"] = datetime.now(timezone.utc)
    
    await database.execute(
        BarModel.__table__.update()
        .where(BarModel.id == bar_id)
        .values(**values)
    )
    
    updated_bar = await _get_bar(bar_id)
    return _bar_to_contact(updated_bar)


@business_settings_router.delete("/data", response_model=DeleteResult)
async def delete_business_data(
    bar_id: int,
    auth: BarAuthContext = Depends(require_bar_role(BarRole.OWNER)),
):
    """Permanently delete all business data. Owner only. Irreversible."""
    import uuid
    receipt_id = f"del_biz_{uuid.uuid4().hex[:12]}"
    deleted = {}
    
    # Delete advertising data
    result = await database.execute(
        AdvertisingImpression.__table__.delete().where(
            AdvertisingImpression.campaign_id.in_(
                AdvertisingCampaign.__table__.select().with_only_columns(
                    AdvertisingCampaign.id
                ).where(AdvertisingCampaign.bar_id == bar_id)
            )
        )
    )
    deleted["impressions"] = result
    
    result = await database.execute(
        AdvertisingCampaign.__table__.delete().where(
            AdvertisingCampaign.bar_id == bar_id
        )
    )
    deleted["campaigns"] = result
    
    result = await database.execute(
        AdvertisingInvoice.__table__.delete().where(
            AdvertisingInvoice.bar_id == bar_id
        )
    )
    deleted["invoices"] = result
    
    await database.execute(
        AdvertisingSubscription.__table__.delete().where(
            AdvertisingSubscription.bar_id == bar_id
        )
    )
    
    # Delete orders and related data
    result = await database.execute(
        OrderItem.__table__.delete().where(
            OrderItem.order_id.in_(
                Order.__table__.select().with_only_columns(
                    Order.id
                ).where(Order.bar_id == bar_id)
            )
        )
    )
    
    from ..models.cart_models import OrderStatusHistory
    await database.execute(
        OrderStatusHistory.__table__.delete().where(
            OrderStatusHistory.order_id.in_(
                Order.__table__.select().with_only_columns(
                    Order.id
                ).where(Order.bar_id == bar_id)
            )
        )
    )
    
    result = await database.execute(
        Order.__table__.delete().where(Order.bar_id == bar_id)
    )
    deleted["orders"] = result
    
    # Delete menu items and menus
    result = await database.execute(
        MenuItem.__table__.delete().where(
            MenuItem.menu_id.in_(
                Menu.__table__.select().with_only_columns(
                    Menu.id
                ).where(Menu.bar_id == bar_id)
            )
        )
    )
    
    result = await database.execute(
        Menu.__table__.delete().where(Menu.bar_id == bar_id)
    )
    
    # Delete promotions
    result = await database.execute(
        Promotion.__table__.delete().where(Promotion.bar_id == bar_id)
    )
    deleted["promotions"] = result
    
    result = await database.execute(
        BundlePromotion.__table__.delete().where(BundlePromotion.bar_id == bar_id)
    )
    
    # Nullify sensitive bar fields instead of deleting the bar record
    await database.execute(
        BarModel.__table__.update()
        .where(BarModel.id == bar_id)
        .values(
            name=f"[DELETED] {bar_id}",
            address=None,
            phone_number=None,
            email=None,
            description=None,
            logo_url=None,
            cover_url=None,
            photo_urls=None,
            operating_hours=None,
            latitude=None,
            longitude=None,
            website=None,
            instagram=None,
            facebook=None,
            whatsapp=None,
            business_id=None,
            verification_status="deleted",
            status="deleted",
            updated_at=datetime.now(timezone.utc),
        )
    )
    
    return DeleteResult(
        message="Business data permanently deleted",
        deleted_records=deleted,
        receipt_id=receipt_id,
    )


@business_settings_router.post("/deactivate", response_model=StatusResponse)
async def deactivate_account(
    bar_id: int,
    request: DeactivateRequest,
    auth: BarAuthContext = Depends(require_bar_role(BarRole.OWNER)),
):
    """Temporarily deactivate business profile."""
    bar = await _get_bar(bar_id)
    
    if bar.get("status") == "deactivated":
        raise HTTPException(status_code=400, detail="Business is already deactivated")
    
    now = datetime.now(timezone.utc)
    await database.execute(
        BarModel.__table__.update()
        .where(BarModel.id == bar_id)
        .values(
            status="deactivated",
            deactivated_at=now,
            deactivation_reason=request.reason,
            estimated_return_date=request.estimated_return_date,
            updated_at=now,
        )
    )
    
    return StatusResponse(
        bar_id=bar_id,
        status="deactivated",
        message="Business account deactivated successfully. Data preserved.",
        deactivated_at=now,
        estimated_return_date=request.estimated_return_date,
    )


@business_settings_router.post("/reactivate", response_model=StatusResponse)
async def reactivate_account(
    bar_id: int,
    auth: BarAuthContext = Depends(require_bar_role(BarRole.OWNER)),
):
    """Reactivate a deactivated business profile."""
    bar = await _get_bar(bar_id)
    
    if bar.get("status") != "deactivated":
        raise HTTPException(status_code=400, detail="Account is not currently deactivated")
    
    now = datetime.now(timezone.utc)
    await database.execute(
        BarModel.__table__.update()
        .where(BarModel.id == bar_id)
        .values(
            status="active",
            deactivated_at=None,
            deactivation_reason=None,
            estimated_return_date=None,
            updated_at=now,
        )
    )
    
    return StatusResponse(
        bar_id=bar_id,
        status="active",
        message="Business account reactivated successfully.",
        reactivated_at=now,
    )