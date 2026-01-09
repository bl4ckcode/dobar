from fastapi import APIRouter, Depends
from datetime import datetime, timedelta, timezone
from jose import jwt
from .auth_models import User, RefreshToken
from app.database import database
from .schemas import GoogleLogin, AppleLogin, Token, RefreshTokenRequest, LogoutRequest
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth as firebase_auth
from app.errors import APIError
import os
import httpx
import secrets

auth_router = APIRouter(prefix="/auth", tags=["Auth"])

SECRET_KEY = os.getenv("SECRET_KEY", "fallback-secret-key")
ALGORITHM = "HS256"

# Access token: short-lived (1 hour default)
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))

# Refresh token: long-lived (30 days default, or match provider token)
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "30"))

# Maximum allowed expiration from FE (90 days) - prevents abuse
MAX_TOKEN_EXPIRE_DAYS = 90

GOOGLE_TOKEN_INFO_URL = "https://oauth2.googleapis.com/tokeninfo"


async def get_user_by_firebase_uid(firebase_uid: str):
    query = User.__table__.select().where(User.firebase_uid == firebase_uid)
    return await database.fetch_one(query)


async def get_user_by_google_id(google_id: str):
    query = User.__table__.select().where(User.google_id == google_id)
    return await database.fetch_one(query)


async def get_user_by_apple_id(apple_id: str):
    query = User.__table__.select().where(User.apple_id == apple_id)
    return await database.fetch_one(query)


async def get_user_by_email(email: str):
    query = User.__table__.select().where(User.email == email)
    return await database.fetch_one(query)


def calculate_expiration(provider_expiration: int = None) -> tuple[datetime, datetime]:
    """
    Calculate access and refresh token expiration times.
    
    If provider_expiration is given (Unix timestamp), use it for refresh token
    (capped at MAX_TOKEN_EXPIRE_DAYS). Otherwise use defaults.
    
    Returns: (access_token_exp, refresh_token_exp)
    """
    now = datetime.now(timezone.utc)
    access_exp = now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    if provider_expiration:
        # Use provider's expiration for refresh token (capped at max)
        provider_exp = datetime.fromtimestamp(provider_expiration, tz=timezone.utc)
        max_exp = now + timedelta(days=MAX_TOKEN_EXPIRE_DAYS)
        refresh_exp = min(provider_exp, max_exp)
        
        # Ensure refresh token is at least as long as access token
        if refresh_exp <= access_exp:
            refresh_exp = now + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    else:
        refresh_exp = now + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    
    return access_exp, refresh_exp


async def create_access_token(user_id: int, expires_at: datetime = None) -> tuple[str, int]:
    """
    Create a short-lived JWT access token.
    
    Returns: (token, expires_in_seconds)
    """
    now = datetime.now(timezone.utc)
    if expires_at is None:
        expires_at = now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    expires_in = int((expires_at - now).total_seconds())
    
    payload = {
        "sub": str(user_id),
        "exp": expires_at,
        "iat": now,
        "type": "access"
    }
    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    return token, expires_in


async def create_refresh_token(
    user_id: int,
    expires_at: datetime,
    provider: str = None,
    device_info: str = None
) -> str:
    """
    Create a long-lived refresh token and store it in the database.
    
    Returns: refresh token string
    """
    # Generate a secure random token
    token = secrets.token_urlsafe(64)
    
    # Store in database
    insert_query = RefreshToken.__table__.insert().values(
        user_id=user_id,
        token=token,
        expires_at=expires_at,
        provider=provider,
        device_info=device_info
    )
    await database.execute(insert_query)
    
    return token


async def create_tokens(
    user_id: int,
    provider: str = None,
    provider_expiration: int = None,
    device_info: str = None
) -> tuple[str, str, int]:
    """
    Create both access and refresh tokens.
    
    Args:
        user_id: The user's ID
        provider: OAuth provider (phone, google, apple)
        provider_expiration: Optional Unix timestamp for provider token expiry
        device_info: Optional device identifier
    
    Returns: (access_token, refresh_token, expires_in_seconds)
    """
    access_exp, refresh_exp = calculate_expiration(provider_expiration)
    
    access_token, expires_in = await create_access_token(user_id, access_exp)
    refresh_token = await create_refresh_token(user_id, refresh_exp, provider, device_info)
    
    return access_token, refresh_token, expires_in


async def verify_google_token(id_token: str) -> dict:
    try:
        decoded = firebase_auth.verify_id_token(id_token)
        return {
            "sub": decoded.get("uid"),  # Firebase UID
            "firebase_uid": decoded.get("uid"),  # Also return as firebase_uid for linking
            "email": decoded.get("email"),
            "name": decoded.get("name"),
            "provider": "google"
        }
    except Exception:
        pass
    
    async with httpx.AsyncClient() as client:
        response = await client.get(f"{GOOGLE_TOKEN_INFO_URL}?id_token={id_token}")
        if response.status_code != 200:
            raise APIError.invalid_token("Invalid Google token")
        data = response.json()
        return {
            "sub": data.get("sub"),  # Google ID (no Firebase UID in this case)
            "firebase_uid": None,
            "email": data.get("email"),
            "name": data.get("name"),
            "provider": "google"
        }


async def verify_apple_token(id_token: str) -> dict:
    try:
        decoded = firebase_auth.verify_id_token(id_token)
        return {
            "sub": decoded.get("uid"),  # Firebase UID
            "firebase_uid": decoded.get("uid"),  # Also return as firebase_uid for linking
            "email": decoded.get("email"),
            "name": decoded.get("name"),
            "provider": "apple"
        }
    except Exception:
        pass
    
    try:
        from jose import jwt as jose_jwt
        unverified = jose_jwt.get_unverified_claims(id_token)
        return {
            "sub": unverified.get("sub"),  # Apple ID (no Firebase UID in this case)
            "firebase_uid": None,
            "email": unverified.get("email"),
            "name": None,
            "provider": "apple"
        }
    except Exception:
        raise APIError.invalid_token("Invalid Apple token")


security = HTTPBearer()


async def verify_firebase_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        token = credentials.credentials
        decoded_token = firebase_auth.verify_id_token(token)
        return decoded_token
    except Exception:
        raise APIError.invalid_token("Invalid Firebase authentication credentials")


@auth_router.post("/phone-login", response_model=Token)
async def phone_login(firebase_user=Depends(verify_firebase_token)):
    firebase_uid = firebase_user["uid"]
    phone_number = firebase_user.get("phone_number")
    # Firebase tokens expire in 1 hour, but we use our default refresh token expiry
    provider_exp = firebase_user.get("exp")
    
    user = await get_user_by_firebase_uid(firebase_uid)
    is_new = False
    
    if not user:
        is_new = True
        user_data = {"firebase_uid": firebase_uid, "phone_number": phone_number, "is_active": True}
        user_id = await database.execute(User.__table__.insert().values(**user_data))
        user = await database.fetch_one(User.__table__.select().where(User.id == user_id))
    
    access_token, refresh_token, expires_in = await create_tokens(
        user_id=user["id"],
        provider="phone",
        provider_expiration=None  # Use default for phone (no long-lived provider token)
    )
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=expires_in,
        is_new_user=is_new
    )


@auth_router.post("/google-login", response_model=Token)
async def google_login(login_data: GoogleLogin):
    token_info = await verify_google_token(login_data.id_token)
    google_id = token_info["sub"]
    firebase_uid = token_info.get("firebase_uid")  # Firebase UID if verified via Firebase
    email = token_info.get("email") or login_data.email
    display_name = token_info.get("name") or login_data.display_name
    
    user = await get_user_by_google_id(google_id)
    is_new = False
    
    # If not found by google_id, try firebase_uid (links phone + Google accounts)
    if not user and firebase_uid:
        user = await get_user_by_firebase_uid(firebase_uid)
        if user:
            # Link Google ID to existing user (found by Firebase UID)
            await database.execute(
                User.__table__.update().where(User.id == user["id"]).values(
                    google_id=google_id,
                    email=email or user["email"]  # Also update email if not set
                )
            )
    
    # If still not found, try by email
    if not user and email:
        user = await get_user_by_email(email)
        if user:
            await database.execute(
                User.__table__.update().where(User.id == user["id"]).values(google_id=google_id)
            )
    
    if not user:
        is_new = True
        user_data = {"google_id": google_id, "email": email, "is_active": True}
        if firebase_uid:
            user_data["firebase_uid"] = firebase_uid
        user_id = await database.execute(User.__table__.insert().values(**user_data))
        user = await database.fetch_one(User.__table__.select().where(User.id == user_id))
        
        if display_name:
            from .rbac_models import UserProfile
            await database.execute(
                UserProfile.__table__.insert().values(user_id=user["id"], display_name=display_name)
            )
    
    access_token, refresh_token, expires_in = await create_tokens(
        user_id=user["id"],
        provider="google",
        provider_expiration=login_data.token_expiration  # FE can send Google token expiry
    )
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=expires_in,
        is_new_user=is_new
    )


@auth_router.post("/apple-login", response_model=Token)
async def apple_login(login_data: AppleLogin):
    token_info = await verify_apple_token(login_data.id_token)
    apple_id = token_info["sub"]
    firebase_uid = token_info.get("firebase_uid")  # Firebase UID if verified via Firebase
    email = token_info.get("email") or login_data.email
    display_name = login_data.display_name
    
    user = await get_user_by_apple_id(apple_id)
    is_new = False
    
    # If not found by apple_id, try firebase_uid (links phone + Apple accounts)
    if not user and firebase_uid:
        user = await get_user_by_firebase_uid(firebase_uid)
        if user:
            # Link Apple ID to existing user (found by Firebase UID)
            await database.execute(
                User.__table__.update().where(User.id == user["id"]).values(
                    apple_id=apple_id,
                    email=email or user["email"]  # Also update email if not set
                )
            )
    
    # If still not found, try by email
    if not user and email:
        user = await get_user_by_email(email)
        if user:
            await database.execute(
                User.__table__.update().where(User.id == user["id"]).values(apple_id=apple_id)
            )
    
    if not user:
        is_new = True
        user_data = {"apple_id": apple_id, "email": email, "is_active": True}
        if firebase_uid:
            user_data["firebase_uid"] = firebase_uid
        user_id = await database.execute(User.__table__.insert().values(**user_data))
        user = await database.fetch_one(User.__table__.select().where(User.id == user_id))
        
        if display_name:
            from .rbac_models import UserProfile
            await database.execute(
                UserProfile.__table__.insert().values(user_id=user["id"], display_name=display_name)
            )
    
    access_token, refresh_token, expires_in = await create_tokens(
        user_id=user["id"],
        provider="apple",
        provider_expiration=login_data.token_expiration  # FE can send Apple token expiry
    )
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=expires_in,
        is_new_user=is_new
    )


# =============================================================================
# REFRESH TOKEN ENDPOINT
# =============================================================================

@auth_router.post("/refresh", response_model=Token)
async def refresh_access_token(request: RefreshTokenRequest):
    """
    Exchange a valid refresh token for a new access token.
    
    The refresh token itself is NOT rotated (to support multiple devices).
    If you want to rotate, call /auth/logout first then re-login.
    """
    # Find the refresh token in database
    query = RefreshToken.__table__.select().where(RefreshToken.token == request.refresh_token)
    token_record = await database.fetch_one(query)
    
    if not token_record:
        raise APIError.invalid_token("Invalid refresh token")
    
    # Check if revoked
    if token_record["revoked_at"] is not None:
        raise APIError.invalid_token("Refresh token has been revoked")
    
    # Check if expired
    now = datetime.now(timezone.utc)
    expires_at = token_record["expires_at"]
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    
    if expires_at <= now:
        raise APIError.session_expired("Refresh token has expired. Please log in again.")
    
    # Verify user still exists and is active
    user_query = User.__table__.select().where(User.id == token_record["user_id"])
    user = await database.fetch_one(user_query)
    
    if not user:
        raise APIError.user_not_found()
    
    if not user["is_active"]:
        raise APIError.forbidden("User account is inactive")
    
    # Create new access token (keep same refresh token)
    access_token, expires_in = await create_access_token(user["id"])
    
    return Token(
        access_token=access_token,
        refresh_token=request.refresh_token,  # Return same refresh token
        token_type="bearer",
        expires_in=expires_in,
        is_new_user=False
    )


# =============================================================================
# LOGOUT ENDPOINT
# =============================================================================

@auth_router.post("/logout")
async def logout(request: LogoutRequest = None):
    """
    Revoke refresh token(s) on logout.
    
    If refresh_token is provided, revokes only that token.
    This allows users to stay logged in on other devices.
    """
    if request and request.refresh_token:
        # Revoke specific refresh token
        now = datetime.now(timezone.utc)
        update_query = (
            RefreshToken.__table__.update()
            .where(RefreshToken.token == request.refresh_token)
            .values(revoked_at=now)
        )
        await database.execute(update_query)
    
    return {"message": "Logged out successfully"}


# =============================================================================
# LEGACY ENDPOINTS (for backwards compatibility)
# =============================================================================

@auth_router.post("/phone")
async def phone_login_legacy(firebase_user=Depends(verify_firebase_token)):
    return await phone_login(firebase_user)


@auth_router.post("/google", response_model=Token)
async def google_login_legacy(login_data: GoogleLogin):
    return await google_login(login_data)


@auth_router.post("/apple", response_model=Token)
async def apple_login_legacy(login_data: AppleLogin):
    return await apple_login(login_data)
