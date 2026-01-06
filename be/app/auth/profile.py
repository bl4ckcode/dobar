from fastapi import APIRouter, Depends
from pydantic import BaseModel, EmailStr
from datetime import datetime, timezone
from typing import Optional
from .rbac_models import UserProfile
from .rbac_middleware import get_current_user, AuthUser
from app.database import database
from app.errors import APIError

profile_router = APIRouter(prefix="/me", tags=["Profile"])


class ProfileResponse(BaseModel):
    display_name: Optional[str] = None
    email: Optional[str] = None
    avatar_url: Optional[str] = None
    terms_accepted: bool = False
    privacy_accepted: bool = False
    user_type: str = "client"


class ProfileUpdate(BaseModel):
    display_name: Optional[str] = None
    email: Optional[EmailStr] = None


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
        user_type=profile.get("user_type", "client") or "client"
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
            .values(display_name=data.display_name, updated_at=datetime.now(timezone.utc))
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
            terms_accepted_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
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
            privacy_accepted_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        )
    )
    await database.execute(update_query)
    
    return {"message": "Privacy policy accepted", "privacy_accepted": True}
