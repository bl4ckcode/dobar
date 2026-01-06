from fastapi import APIRouter, Depends
from pydantic import BaseModel, EmailStr, field_validator
from datetime import datetime
from typing import Optional, Literal
from .rbac_models import UserProfile, UserType
from .rbac_middleware import get_current_user, AuthUser
from app.database import database
from app.errors import APIError

profile_router = APIRouter(prefix="/me", tags=["Profile"])

# Supported countries for payment gateway routing
SUPPORTED_COUNTRIES = {"BR", "AR", "US", "MX", "CL", "CO", "PE"}


class ProfileResponse(BaseModel):
    display_name: Optional[str] = None
    email: Optional[str] = None
    avatar_url: Optional[str] = None
    terms_accepted: bool = False
    privacy_accepted: bool = False
    user_type: str = "client"
    country_code: Optional[str] = None


class ProfileUpdate(BaseModel):
    display_name: Optional[str] = None
    email: Optional[EmailStr] = None


class OnboardingUpdate(BaseModel):
    """Used during onboarding to set user type and country"""
    user_type: Literal["client", "business"]
    country_code: str  # ISO 3166-1 alpha-2: BR, AR, US, etc.
    
    @field_validator("country_code")
    @classmethod
    def validate_country_code(cls, v: str) -> str:
        v = v.upper()
        if v not in SUPPORTED_COUNTRIES:
            raise ValueError(f"Unsupported country. Supported: {', '.join(sorted(SUPPORTED_COUNTRIES))}")
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
        avatar_url=profile.get("avatar_url"),
        terms_accepted=profile.get("terms_accepted", False) or False,
        privacy_accepted=profile.get("privacy_accepted", False) or False,
        user_type=profile.get("user_type", "client") or "client",
        country_code=profile.get("country_code")
    )


@profile_router.put("/profile", response_model=ProfileResponse)
async def update_profile(
    data: ProfileUpdate,
    current_user: AuthUser = Depends(get_current_user)
):
    profile = await get_or_create_profile(current_user.id)
    
    if data.display_name is not None:
        update_query = (
            UserProfile.__table__.update()
            .where(UserProfile.user_id == current_user.id)
            .values(display_name=data.display_name, updated_at=datetime.utcnow())
        )
        await database.execute(update_query)
    
    if data.email is not None:
        from .auth_models import User
        email_check = User.__table__.select().where(
            (User.email == data.email) & (User.id != current_user.id)
        )
        existing = await database.fetch_one(email_check)
        if existing:
            raise APIError.conflict("Email already in use")
        
        user_update = (
            User.__table__.update()
            .where(User.id == current_user.id)
            .values(email=data.email)
        )
        await database.execute(user_update)
    
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
    - country_code: Payment gateway routing (BR=Pix/Stone, AR=MercadoPago, US=Stripe)
    
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


# Helper to get payment gateway for a user's country
COUNTRY_PAYMENT_GATEWAYS = {
    "BR": "stone",        # Brazil: Stone/Pagar.me (Pix, credit cards)
    "AR": "mercadopago",  # Argentina: MercadoPago
    "US": "stripe",       # USA: Stripe
    "MX": "mercadopago",  # Mexico: MercadoPago
    "CL": "mercadopago",  # Chile: MercadoPago
    "CO": "mercadopago",  # Colombia: MercadoPago
    "PE": "mercadopago",  # Peru: MercadoPago
}


@profile_router.get("/payment-gateway")
async def get_user_payment_gateway(current_user: AuthUser = Depends(get_current_user)):
    """
    Get the payment gateway for the current user based on their country.
    Used by FE to know which payment methods to show.
    """
    profile = await get_or_create_profile(current_user.id)
    country = profile.get("country_code", "BR")  # Default to Brazil
    gateway = COUNTRY_PAYMENT_GATEWAYS.get(country, "stripe")  # Default to Stripe
    
    # Payment methods vary by gateway
    payment_methods = {
        "stone": ["pix", "credit_card", "debit_card"],
        "mercadopago": ["credit_card", "debit_card", "mercadopago_wallet"],
        "stripe": ["credit_card", "debit_card", "apple_pay", "google_pay"],
    }
    
    return {
        "gateway": gateway,
        "country_code": country,
        "payment_methods": payment_methods.get(gateway, ["credit_card"])
    }
