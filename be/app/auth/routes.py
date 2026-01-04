from fastapi import APIRouter, Depends
from datetime import datetime, timedelta, timezone
from jose import jwt
from .auth_models import User
from app.database import database
from .schemas import GoogleLogin, AppleLogin, Token
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth as firebase_auth
from app.errors import APIError
import os
import httpx

auth_router = APIRouter(prefix="/auth", tags=["Auth"])

SECRET_KEY = os.getenv("SECRET_KEY", "fallback-secret-key")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 360

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


async def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


async def verify_google_token(id_token: str) -> dict:
    try:
        decoded = firebase_auth.verify_id_token(id_token)
        return {
            "sub": decoded.get("uid"),
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
            "sub": data.get("sub"),
            "email": data.get("email"),
            "name": data.get("name"),
            "provider": "google"
        }


async def verify_apple_token(id_token: str) -> dict:
    try:
        decoded = firebase_auth.verify_id_token(id_token)
        return {
            "sub": decoded.get("uid"),
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
            "sub": unverified.get("sub"),
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
    
    user = await get_user_by_firebase_uid(firebase_uid)
    is_new = False
    
    if not user:
        is_new = True
        user_data = {"firebase_uid": firebase_uid, "phone_number": phone_number, "is_active": True}
        user_id = await database.execute(User.__table__.insert().values(**user_data))
        user = await database.fetch_one(User.__table__.select().where(User.id == user_id))
    
    access_token = await create_access_token(data={"sub": str(user["id"])})
    return Token(access_token=access_token, token_type="bearer", is_new_user=is_new)


@auth_router.post("/google-login", response_model=Token)
async def google_login(login_data: GoogleLogin):
    token_info = await verify_google_token(login_data.id_token)
    google_id = token_info["sub"]
    email = token_info.get("email") or login_data.email
    display_name = token_info.get("name") or login_data.display_name
    
    user = await get_user_by_google_id(google_id)
    is_new = False
    
    if not user and email:
        user = await get_user_by_email(email)
        if user:
            await database.execute(
                User.__table__.update().where(User.id == user["id"]).values(google_id=google_id)
            )
    
    if not user:
        is_new = True
        user_data = {"google_id": google_id, "email": email, "is_active": True}
        user_id = await database.execute(User.__table__.insert().values(**user_data))
        user = await database.fetch_one(User.__table__.select().where(User.id == user_id))
        
        if display_name:
            from .rbac_models import UserProfile
            await database.execute(
                UserProfile.__table__.insert().values(user_id=user["id"], display_name=display_name)
            )
    
    access_token = await create_access_token(data={"sub": str(user["id"])})
    return Token(access_token=access_token, token_type="bearer", is_new_user=is_new)


@auth_router.post("/apple-login", response_model=Token)
async def apple_login(login_data: AppleLogin):
    token_info = await verify_apple_token(login_data.id_token)
    apple_id = token_info["sub"]
    email = token_info.get("email") or login_data.email
    display_name = login_data.display_name
    
    user = await get_user_by_apple_id(apple_id)
    is_new = False
    
    if not user and email:
        user = await get_user_by_email(email)
        if user:
            await database.execute(
                User.__table__.update().where(User.id == user["id"]).values(apple_id=apple_id)
            )
    
    if not user:
        is_new = True
        user_data = {"apple_id": apple_id, "email": email, "is_active": True}
        user_id = await database.execute(User.__table__.insert().values(**user_data))
        user = await database.fetch_one(User.__table__.select().where(User.id == user_id))
        
        if display_name:
            from .rbac_models import UserProfile
            await database.execute(
                UserProfile.__table__.insert().values(user_id=user["id"], display_name=display_name)
            )
    
    access_token = await create_access_token(data={"sub": str(user["id"])})
    return Token(access_token=access_token, token_type="bearer", is_new_user=is_new)


@auth_router.post("/phone")
async def phone_login_legacy(firebase_user=Depends(verify_firebase_token)):
    return await phone_login(firebase_user)


@auth_router.post("/google", response_model=Token)
async def google_login_legacy(login_data: GoogleLogin):
    return await google_login(login_data)


@auth_router.post("/apple", response_model=Token)
async def apple_login_legacy(login_data: AppleLogin):
    return await apple_login(login_data)
