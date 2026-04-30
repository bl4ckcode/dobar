from fastapi import APIRouter, Depends
from pydantic import BaseModel, EmailStr, field_validator
from datetime import datetime
from typing import Optional, Literal
from .rbac_models import UserProfile, UserType
from .rbac_middleware import get_current_user, AuthUser
from app.database import database
from app.errors import APIError

profile_router = APIRouter(prefix="/me", tags=["Profile"])

# =============================================================================
# PAYMENT GATEWAY CONFIGURATION
# =============================================================================
# Gateway-driven approach: Define which gateway serves which countries/regions
# Countries can be enabled/disabled without code changes via environment or DB
# 
# Current Gateways:
# - stone: Brazil (Pagar.me/Stone - Pix, cards)
# - stripe: US, Canada, Europe, Australia, and 40+ countries
# - mercadopago: Latin America (AR, MX, CL, CO, PE, UY, VE, etc.)
# - paypal: Global (available in 200+ countries)
#
# NOTE: Regulatory compliance must be verified per country before launch
# =============================================================================

# Gateway capabilities and supported payment methods
GATEWAY_CONFIG = {
    "stone": {
        "name": "Stone/Pagar.me",
        "payment_methods": ["pix", "credit_card", "debit_card", "boleto"],
        "currencies": ["BRL"],
        "regions": ["Brazil"],
    },
    "stripe": {
        "name": "Stripe",
        "payment_methods": ["credit_card", "debit_card", "apple_pay", "google_pay"],
        "currencies": ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "MXN", "BRL"],
        "regions": ["North America", "Europe", "Asia Pacific", "Latin America"],
    },
    "mercadopago": {
        "name": "MercadoPago",
        "payment_methods": ["credit_card", "debit_card", "mercadopago_wallet", "pix"],
        "currencies": ["ARS", "MXN", "CLP", "COP", "PEN", "UYU", "BRL"],
        "regions": ["Latin America"],
    },
    "paypal": {
        "name": "PayPal",
        "payment_methods": ["paypal", "credit_card", "debit_card"],
        "currencies": ["USD", "EUR", "GBP", "CAD", "AUD", "BRL", "MXN"],
        "regions": ["Global"],
    },
}

# Country → Primary Gateway mapping
# Countries not in this list will use "stripe" as fallback (widest coverage)
# This can be moved to database for dynamic configuration
COUNTRY_GATEWAY_MAP = {
    # Brazil - Stone/Pagar.me for Pix support
    "BR": "stone",
    
    # Latin America - MercadoPago (strong local presence)
    "AR": "mercadopago",  # Argentina
    "MX": "mercadopago",  # Mexico
    "CL": "mercadopago",  # Chile
    "CO": "mercadopago",  # Colombia
    "PE": "mercadopago",  # Peru
    "UY": "mercadopago",  # Uruguay
    "VE": "mercadopago",  # Venezuela
    "EC": "mercadopago",  # Ecuador
    "PY": "mercadopago",  # Paraguay
    "BO": "mercadopago",  # Bolivia
    
    # North America - Stripe
    "US": "stripe",       # United States
    "CA": "stripe",       # Canada
    
    # Europe - Stripe (can add more as needed)
    "GB": "stripe",       # United Kingdom
    "DE": "stripe",       # Germany
    "FR": "stripe",       # France
    "ES": "stripe",       # Spain
    "IT": "stripe",       # Italy
    "PT": "stripe",       # Portugal
    "NL": "stripe",       # Netherlands
    "BE": "stripe",       # Belgium
    "IE": "stripe",       # Ireland
    
    # Asia Pacific - Stripe
    "AU": "stripe",       # Australia
    "NZ": "stripe",       # New Zealand
    "JP": "stripe",       # Japan
    "SG": "stripe",       # Singapore
}

# Countries currently ENABLED for operation
# Start with core markets, expand as regulatory compliance is verified
# This can be moved to database/env for dynamic control
ENABLED_COUNTRIES = {
    # Phase 1: Brazil (home market)
    "BR",
    
    # Phase 2: Latin America expansion
    "AR", "MX", "CL", "CO", "PE",
    
    # Phase 3: North America
    "US", "CA",
    
    # Future phases: Add countries as compliance is verified
    # "UY", "EC", "PY", "GB", "ES", "PT", etc.
}

def get_gateway_for_country(country_code: str) -> str:
    """Get the payment gateway for a country. Falls back to Stripe."""
    return COUNTRY_GATEWAY_MAP.get(country_code.upper(), "stripe")

def get_payment_methods_for_country(country_code: str) -> list:
    """Get available payment methods based on country's gateway."""
    gateway = get_gateway_for_country(country_code)
    config = GATEWAY_CONFIG.get(gateway, GATEWAY_CONFIG["stripe"])
    return config["payment_methods"]

def is_country_enabled(country_code: str) -> bool:
    """Check if a country is currently enabled for operations."""
    return country_code.upper() in ENABLED_COUNTRIES


class ProfileResponse(BaseModel):
    display_name: Optional[str] = None
    email: Optional[str] = None
    phone_number: Optional[str] = None
    avatar_url: Optional[str] = None
    terms_accepted: bool = False
    privacy_accepted: bool = False
    user_type: str = "client"
    country_code: Optional[str] = None
    subscription_tier: str = "regular"
    is_pro: bool = False


class ProfileUpdate(BaseModel):
    display_name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None
    avatar_url: Optional[str] = None


class CountryUpdate(BaseModel):
    country_code: str  # ISO 3166-1 alpha-2

    @field_validator("country_code")
    @classmethod
    def validate_country_code(cls, v: str) -> str:
        v = v.upper()
        if not is_country_enabled(v):
            enabled_list = ", ".join(sorted(ENABLED_COUNTRIES))
            raise ValueError(f"Country not yet enabled. Currently available: {enabled_list}")
        return v


class NotificationPreferences(BaseModel):
    push_notifications_enabled: bool = True
    order_updates_enabled: bool = True
    promotions_enabled: bool = True


class PrivacySettings(BaseModel):
    data_sharing_enabled: bool = False
    location_enabled: bool = False


class FcmTokenUpdate(BaseModel):
    token: str
    platform: Literal["ios", "android", "web"] = "android"


class OnboardingUpdate(BaseModel):
    """Used during onboarding to set user type and country"""
    user_type: Literal["client", "business"]
    country_code: str  # ISO 3166-1 alpha-2: BR, AR, US, etc.
    
    @field_validator("country_code")
    @classmethod
    def validate_country_code(cls, v: str) -> str:
        v = v.upper()
        if not is_country_enabled(v):
            enabled_list = ", ".join(sorted(ENABLED_COUNTRIES))
            raise ValueError(f"Country not yet enabled. Currently available: {enabled_list}")
        return v


async def get_or_create_profile(user_id: int) -> dict:
    query = UserProfile.__table__.select().where(UserProfile.user_id == user_id)
    profile = await database.fetch_one(query)
    
    if not profile:
        insert_query = UserProfile.__table__.insert().values(user_id=user_id)
        await database.execute(insert_query)
        profile = await database.fetch_one(query)
    
    return dict(profile) if profile else {}


@profile_router.get("/profile", response_model=ProfileResponse)
async def get_profile(current_user: AuthUser = Depends(get_current_user)):
    profile = await get_or_create_profile(current_user.id)
    
    from .auth_models import User
    user_query = User.__table__.select().where(User.id == current_user.id)
    user = await database.fetch_one(user_query)
    
    return ProfileResponse(
        display_name=profile.get("display_name"),
        email=user["email"] if user else None,
        phone_number=user["phone_number"] if user else None,
        avatar_url=profile.get("avatar_url"),
        terms_accepted=profile.get("terms_accepted", False) or False,
        privacy_accepted=profile.get("privacy_accepted", False) or False,
        user_type=profile.get("user_type", "client") or "client",
        country_code=(user["country_code"] if user and user["country_code"] else profile.get("country_code")) or "BR",
        subscription_tier=(dict(user).get("subscription_tier") or "regular") if user else "regular",
        is_pro=dict(user).get("subscription_tier") == "pro" if user else False
    )


@profile_router.put("/profile", response_model=ProfileResponse)
async def update_profile(
    data: ProfileUpdate,
    current_user: AuthUser = Depends(get_current_user)
):
    profile = await get_or_create_profile(current_user.id)
    from .auth_models import User
    
    profile_updates = {}
    
    if data.display_name is not None:
        profile_updates["display_name"] = data.display_name
    
    if data.avatar_url is not None:
        profile_updates["avatar_url"] = data.avatar_url
    
    if profile_updates:
        profile_updates["updated_at"] = datetime.utcnow()
        await database.execute(
            UserProfile.__table__.update()
            .where(UserProfile.user_id == current_user.id)
            .values(**profile_updates)
        )
    
    if data.email is not None:
        email_check = User.__table__.select().where(
            (User.email == data.email) & (User.id != current_user.id)
        )
        if await database.fetch_one(email_check):
            raise APIError.conflict("Email already in use")
        await database.execute(
            User.__table__.update()
            .where(User.id == current_user.id)
            .values(email=data.email)
        )
    
    if data.phone_number is not None:
        phone_check = User.__table__.select().where(
            (User.phone_number == data.phone_number) & (User.id != current_user.id)
        )
        if await database.fetch_one(phone_check):
            raise APIError.conflict("Phone number already in use")
        await database.execute(
            User.__table__.update()
            .where(User.id == current_user.id)
            .values(phone_number=data.phone_number)
        )
    
    return await get_profile(current_user)


@profile_router.post("/update-country", response_model=ProfileResponse)
async def update_country(
    data: CountryUpdate,
    current_user: AuthUser = Depends(get_current_user)
):
    """
    Update user's registered country. 
    Used when a traveler confirms location update to unlock local bars.
    """
    from .auth_models import User
    
    # Update both User and UserProfile for consistency during transition
    await database.execute(
        User.__table__.update()
        .where(User.id == current_user.id)
        .values(country_code=data.country_code)
    )
    
    await database.execute(
        UserProfile.__table__.update()
        .where(UserProfile.user_id == current_user.id)
        .values(country_code=data.country_code, updated_at=datetime.utcnow())
    )
    
    return await get_profile(current_user)


@profile_router.post("/accept-terms")
async def accept_terms(current_user: AuthUser = Depends(get_current_user)):
    await get_or_create_profile(current_user.id)
    
    update_query = (
        UserProfile.__table__.update()
        .where(UserProfile.user_id == current_user.id)
        .values(
            terms_accepted=True,
            terms_accepted_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
    )
    await database.execute(update_query)
    
    return {"message": "Terms accepted", "terms_accepted": True}


@profile_router.post("/accept-privacy")
async def accept_privacy(current_user: AuthUser = Depends(get_current_user)):
    await get_or_create_profile(current_user.id)
    
    update_query = (
        UserProfile.__table__.update()
        .where(UserProfile.user_id == current_user.id)
        .values(
            privacy_accepted=True,
            privacy_accepted_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
    )
    await database.execute(update_query)
    
    return {"message": "Privacy policy accepted", "privacy_accepted": True}


@profile_router.post("/onboarding", response_model=ProfileResponse)
async def complete_onboarding(
    data: OnboardingUpdate,
    current_user: AuthUser = Depends(get_current_user)
):
    """
    Complete user onboarding by setting user type and country.
    This determines:
    - user_type: "client" (bar-goer) or "business" (bar owner/staff)
    - country_code: Payment gateway routing based on country
    
    Call this after phone/social login when is_new_user=true.
    """
    await get_or_create_profile(current_user.id)
    
    update_query = (
        UserProfile.__table__.update()
        .where(UserProfile.user_id == current_user.id)
        .values(
            user_type=data.user_type,
            country_code=data.country_code,
            updated_at=datetime.utcnow()
        )
    )
    await database.execute(update_query)
    
    return await get_profile(current_user)


@profile_router.get("/payment-gateway")
async def get_user_payment_gateway(current_user: AuthUser = Depends(get_current_user)):
    """
    Get the payment gateway for the current user based on their country.
    Used by FE to know which payment methods to show.
    """
    profile = await get_or_create_profile(current_user.id)
    country = profile.get("country_code", "BR")  # Default to Brazil
    gateway = get_gateway_for_country(country)
    payment_methods = get_payment_methods_for_country(country)
    gateway_info = GATEWAY_CONFIG.get(gateway, GATEWAY_CONFIG["stripe"])
    
    return {
        "gateway": gateway,
        "gateway_name": gateway_info["name"],
        "country_code": country,
        "payment_methods": payment_methods,
        "currencies": gateway_info["currencies"],
    }


@profile_router.get("/available-countries")
async def get_available_countries():
    """
    Get list of countries currently enabled for BARZ operations.
    This is a public endpoint (no auth required) for onboarding UI.
    """
    countries_info = []
    for code in sorted(ENABLED_COUNTRIES):
        gateway = get_gateway_for_country(code)
        gateway_info = GATEWAY_CONFIG.get(gateway, {})
        countries_info.append({
            "code": code,
            "gateway": gateway,
            "gateway_name": gateway_info.get("name", gateway),
            "payment_methods": get_payment_methods_for_country(code),
        })
    
    return {
        "enabled_countries": list(sorted(ENABLED_COUNTRIES)),
        "countries": countries_info,
        "total": len(ENABLED_COUNTRIES),
    }


@profile_router.get("/notification-preferences", response_model=NotificationPreferences)
async def get_notification_preferences(current_user: AuthUser = Depends(get_current_user)):
    profile = await get_or_create_profile(current_user.id)
    return NotificationPreferences(
        push_notifications_enabled=profile.get("push_notifications_enabled", True) if profile.get("push_notifications_enabled") is not None else True,
        order_updates_enabled=profile.get("order_updates_enabled", True) if profile.get("order_updates_enabled") is not None else True,
        promotions_enabled=profile.get("promotions_enabled", True) if profile.get("promotions_enabled") is not None else True,
    )


@profile_router.put("/notification-preferences", response_model=NotificationPreferences)
async def update_notification_preferences(
    data: NotificationPreferences,
    current_user: AuthUser = Depends(get_current_user)
):
    await get_or_create_profile(current_user.id)
    await database.execute(
        UserProfile.__table__.update()
        .where(UserProfile.user_id == current_user.id)
        .values(
            push_notifications_enabled=data.push_notifications_enabled,
            order_updates_enabled=data.order_updates_enabled,
            promotions_enabled=data.promotions_enabled,
            updated_at=datetime.utcnow()
        )
    )
    return data


@profile_router.get("/privacy-settings", response_model=PrivacySettings)
async def get_privacy_settings(current_user: AuthUser = Depends(get_current_user)):
    profile = await get_or_create_profile(current_user.id)
    return PrivacySettings(
        data_sharing_enabled=profile.get("data_sharing_enabled", False) or False,
        location_enabled=profile.get("location_enabled", False) or False,
    )


@profile_router.put("/privacy-settings", response_model=PrivacySettings)
async def update_privacy_settings(
    data: PrivacySettings,
    current_user: AuthUser = Depends(get_current_user)
):
    await get_or_create_profile(current_user.id)
    await database.execute(
        UserProfile.__table__.update()
        .where(UserProfile.user_id == current_user.id)
        .values(
            data_sharing_enabled=data.data_sharing_enabled,
            location_enabled=data.location_enabled,
            updated_at=datetime.utcnow()
        )
    )
    return data


@profile_router.put("/fcm-token")
async def update_fcm_token(
    data: FcmTokenUpdate,
    current_user: AuthUser = Depends(get_current_user)
):
    await get_or_create_profile(current_user.id)
    await database.execute(
        UserProfile.__table__.update()
        .where(UserProfile.user_id == current_user.id)
        .values(
            fcm_token=data.token,
            fcm_token_updated_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
    )
    return {"message": "FCM token updated"}


@profile_router.delete("/data")
async def delete_user_data(current_user: AuthUser = Depends(get_current_user)):
    from .auth_models import User, Token, RefreshToken
    from .mfa_models import MFASecret
    from .recovery_models import RecoveryToken
    from app.bars_and_restaurants.models.wallet_models import UserWallet, CashbackLedger
    from app.bars_and_restaurants.models.cart_models import Cart, CartItem, OrderItem
    from app.bars_and_restaurants.models.relational_models import Order
    import hashlib

    uid = current_user.id

    await database.execute(CartItem.__table__.delete().where(
        CartItem.cart_id.in_(
            Cart.__table__.select().where(Cart.user_id == uid).with_only_columns(Cart.id)
        )
    ))
    await database.execute(Cart.__table__.delete().where(Cart.user_id == uid))

    orders = await database.fetch_all(
        Order.__table__.select().where(Order.user_id == uid).with_only_columns(Order.id)
    )
    order_ids = [o["id"] for o in orders]
    if order_ids:
        await database.execute(OrderItem.__table__.delete().where(OrderItem.order_id.in_(order_ids)))
    await database.execute(Order.__table__.delete().where(Order.user_id == uid))

    await database.execute(CashbackLedger.__table__.delete().where(CashbackLedger.user_id == uid))
    await database.execute(UserWallet.__table__.delete().where(UserWallet.user_id == uid))
    await database.execute(MFASecret.__table__.delete().where(MFASecret.user_id == uid))
    await database.execute(RecoveryToken.__table__.delete().where(RecoveryToken.user_id == uid))
    await database.execute(RefreshToken.__table__.delete().where(RefreshToken.user_id == uid))
    await database.execute(Token.__table__.delete().where(Token.user_id == uid))
    await database.execute(UserProfile.__table__.delete().where(UserProfile.user_id == uid))
    await database.execute(User.__table__.delete().where(User.id == uid))

    anon_ref = hashlib.sha256(str(uid).encode()).hexdigest()[:16]

    return {
        "message": "All user data has been permanently deleted",
        "reference": f"DEL-{anon_ref}",
        "deleted_at": datetime.utcnow().isoformat(),
    }


class LocationPoint(BaseModel):
    latitude: float
    longitude: float

class LocationBatchRequest(BaseModel):
    points: list[LocationPoint]

@profile_router.post("/location/batch")
async def process_location_batch(
    payload: LocationBatchRequest,
    current_user: AuthUser = Depends(get_current_user)
):
    """
    Receives optimized batched location points from the mobile client
    and processes proximity checks for geofenced push campaigns. (DOB-58)
    """
    from app.advertising.services.proximity_service import ProximityService
    
    # Take the latest point for proximity resolution
    if payload.points:
        latest = payload.points[-1]
        await ProximityService.process_geofence(
            user_id=current_user.id,
            latitude=latest.latitude,
            longitude=latest.longitude
        )
        
    return {"status": "processed"}
