from fastapi import APIRouter
from datetime import datetime, timedelta, timezone
from jose import jwt
from .auth_models import User
from ..database import database
from .schemas import PhoneLogin, GoogleLogin, AppleLogin, FacebookLogin, Token
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth
import os

auth_router = APIRouter(prefix="/auth", tags=["Auth"])

# Load SECRET_KEY from environment variables
SECRET_KEY = os.getenv("SECRET_KEY", "fallback-secret-key")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 360

# Helper functions
async def get_user_by_firebase_uid(firebase_uid: str):
    query = User.__table__.select().where(User.firebase_uid == firebase_uid)
    return await database.fetch_one(query)

async def get_user_by_google_id(google_id: str):
    query = User.__table__.select().where(User.google_id == google_id)
    return await database.fetch_one(query)

async def get_user_by_apple_id(apple_id: str):
    query = User.__table__.select().where(User.apple_id == apple_id)
    return await database.fetch_one(query)

async def get_user_by_facebook_id(facebook_id: str):
    query = User.__table__.select().where(User.facebook_id == facebook_id)
    return await database.fetch_one(query)

async def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def create_or_login_user(user_data: dict):
    # Check if user already exists
    user = None
    if "firebase_uid" in user_data:
        user = await get_user_by_firebase_uid(user_data["firebase_uid"])
    elif "google_id" in user_data:
        user = await get_user_by_google_id(user_data["google_id"])
    elif "apple_id" in user_data:
        user = await get_user_by_apple_id(user_data["apple_id"])
    elif "facebook_id" in user_data:
        user = await get_user_by_facebook_id(user_data["facebook_id"])

    if not user:
        # If user doesn't exist, create a new user
        query = User.__table__.insert().values(**user_data)
        user_id = await database.execute(query)
        user = await database.fetch_one(User.__table__.select().where(User.id == user_id))

    # Generate token
    access_token = await create_access_token(data={"sub": str(user["id"])})
    return {"access_token": access_token, "token_type": "bearer"}

security = HTTPBearer()

async def verify_firebase_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        token = credentials.credentials
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

# Routes
@auth_router.post("/phone", response_model=Token)
async def phone_login(login_data: PhoneLogin):
    user_data = {
        "firebase_uid": login_data.firebase_uid,
        "phone_number": login_data.phone_number,
    }
    return await create_or_login_user(user_data)

@auth_router.post("/google", response_model=Token)
async def google_login(login_data: GoogleLogin):
    user_data = {
        "email": login_data.email,
        "google_id": login_data.google_id,
    }
    return await create_or_login_user(user_data)

@auth_router.post("/apple", response_model=Token)
async def apple_login(login_data: AppleLogin):
    user_data = {
        "email": login_data.email,
        "apple_id": login_data.apple_id,
    }
    return await create_or_login_user(user_data)

@auth_router.post("/facebook", response_model=Token)
async def facebook_login(login_data: FacebookLogin):
    user_data = {
        "email": login_data.email,
        "facebook_id": login_data.facebook_id,
    }
    return await create_or_login_user(user_data)