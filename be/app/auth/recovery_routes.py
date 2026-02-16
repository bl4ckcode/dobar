from fastapi import APIRouter, Request
from datetime import datetime, timedelta, timezone
from app.database import database
from app.errors import APIError
from app.rate_limiter import limiter, RateLimits
from .auth_models import User
from .recovery_models import RecoveryToken
from .routes import create_tokens
from .schemas import Token
from pydantic import BaseModel
from typing import Optional, List
import secrets

recovery_router = APIRouter(prefix="/auth/recovery", tags=["Account Recovery"])

RECOVERY_TOKEN_EXPIRE_MINUTES = 30


class RecoveryInitiateRequest(BaseModel):
    email: Optional[str] = None
    phone_number: Optional[str] = None


class RecoveryInitiateResponse(BaseModel):
    recovery_token: str
    available_methods: List[str]
    expires_in: int


class RecoveryVerifyRequest(BaseModel):
    recovery_token: str
    method: str
    firebase_id_token: str


@recovery_router.post("/initiate", response_model=RecoveryInitiateResponse)
@limiter.limit(RateLimits.RECOVERY)
async def initiate_recovery(request: Request, body: RecoveryInitiateRequest):
    user = None

    if body.email:
        query = User.__table__.select().where(User.email == body.email)
        user = await database.fetch_one(query)
    elif body.phone_number:
        query = User.__table__.select().where(User.phone_number == body.phone_number)
        user = await database.fetch_one(query)

    if not user:
        raise APIError.not_found("No account found with the provided information")

    methods = []
    if user["phone_number"]:
        methods.append("phone")
    if user["google_id"]:
        methods.append("google")
    if user["apple_id"]:
        methods.append("apple")

    if not methods:
        raise APIError(400, "NO_RECOVERY_METHODS", "No alternative authentication methods available")

    token = secrets.token_urlsafe(48)
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=RECOVERY_TOKEN_EXPIRE_MINUTES)

    await database.execute(
        RecoveryToken.__table__.insert().values(
            user_id=user["id"],
            token=token,
            method="pending",
            expires_at=expires_at,
        )
    )

    return RecoveryInitiateResponse(
        recovery_token=token,
        available_methods=methods,
        expires_in=RECOVERY_TOKEN_EXPIRE_MINUTES * 60,
    )


@recovery_router.post("/verify", response_model=Token)
@limiter.limit(RateLimits.RECOVERY)
async def verify_recovery(request: Request, body: RecoveryVerifyRequest):
    query = RecoveryToken.__table__.select().where(RecoveryToken.token == body.recovery_token)
    record = await database.fetch_one(query)

    if not record:
        raise APIError.invalid_token("Invalid recovery token")

    if record["used_at"] is not None:
        raise APIError.invalid_token("Recovery token has already been used")

    now = datetime.now(timezone.utc)
    expires_at = record["expires_at"]
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    if expires_at <= now:
        raise APIError.session_expired("Recovery token has expired")

    user_query = User.__table__.select().where(User.id == record["user_id"])
    user = await database.fetch_one(user_query)

    if not user:
        raise APIError.user_not_found()

    if body.method == "google" and not user["google_id"]:
        raise APIError(400, "INVALID_RECOVERY_METHOD", "Google is not linked to this account")
    elif body.method == "apple" and not user["apple_id"]:
        raise APIError(400, "INVALID_RECOVERY_METHOD", "Apple is not linked to this account")
    elif body.method == "phone" and not user["phone_number"]:
        raise APIError(400, "INVALID_RECOVERY_METHOD", "Phone is not linked to this account")

    from firebase_admin import auth as firebase_auth
    try:
        decoded = firebase_auth.verify_id_token(body.firebase_id_token)
    except Exception:
        raise APIError.invalid_token("Invalid Firebase token for recovery verification")

    firebase_uid = decoded.get("uid")
    if user["firebase_uid"] and user["firebase_uid"] != firebase_uid:
        email_from_token = decoded.get("email")
        if not email_from_token or email_from_token != user.get("email"):
            raise APIError.forbidden("Firebase identity does not match the account being recovered")

    await database.execute(
        RecoveryToken.__table__.update()
        .where(RecoveryToken.id == record["id"])
        .values(used_at=now, method=body.method)
    )

    access_token, refresh_token, expires_in = await create_tokens(
        user_id=user["id"],
        provider=f"recovery_{body.method}",
    )

    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=expires_in,
    )
