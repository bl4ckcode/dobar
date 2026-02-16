from fastapi import APIRouter, Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.database import database
from app.errors import APIError
from app.rate_limiter import limiter, RateLimits
from .auth_models import User
from .mfa_models import MFASecret
from .mfa_schemas import (
    MFASetupResponse,
    MFAVerifyRequest,
    MFAChallengeRequest,
    MFAChallengeResponse,
    MFAStatusResponse,
)
from . import mfa_service
from .dependencies import get_current_user
from .routes import create_tokens

mfa_router = APIRouter(prefix="/auth/mfa", tags=["MFA"])
mfa_security = HTTPBearer()


async def _get_mfa_record(user_id: int):
    query = MFASecret.__table__.select().where(MFASecret.user_id == user_id)
    return await database.fetch_one(query)


@mfa_router.get("/status", response_model=MFAStatusResponse)
async def mfa_status(current_user=Depends(get_current_user)):
    record = await _get_mfa_record(current_user["id"])
    if not record or not record["is_enabled"]:
        return MFAStatusResponse(is_enabled=False, phone_fallback_enabled=False)
    return MFAStatusResponse(
        is_enabled=True,
        phone_fallback_enabled=record["phone_fallback_enabled"],
    )


@mfa_router.post("/setup", response_model=MFASetupResponse)
async def mfa_setup(current_user=Depends(get_current_user)):
    existing = await _get_mfa_record(current_user["id"])
    if existing and existing["is_enabled"]:
        raise APIError.conflict("MFA is already enabled")

    secret = mfa_service.generate_secret()
    email = current_user.get("email", "") or ""
    qr_uri = mfa_service.generate_qr_uri(secret, email)
    backup_codes = mfa_service.generate_backup_codes()

    if existing:
        await database.execute(
            MFASecret.__table__.update()
            .where(MFASecret.user_id == current_user["id"])
            .values(
                secret=secret,
                backup_codes=mfa_service.serialize_backup_codes(backup_codes),
                is_enabled=False,
            )
        )
    else:
        await database.execute(
            MFASecret.__table__.insert().values(
                user_id=current_user["id"],
                secret=secret,
                backup_codes=mfa_service.serialize_backup_codes(backup_codes),
                is_enabled=False,
            )
        )

    return MFASetupResponse(
        secret=secret,
        qr_code_uri=qr_uri,
        backup_codes=backup_codes,
    )


@mfa_router.post("/verify")
async def mfa_verify(body: MFAVerifyRequest, current_user=Depends(get_current_user)):
    record = await _get_mfa_record(current_user["id"])
    if not record:
        raise APIError.not_found("MFA not set up")

    if not mfa_service.verify_totp(record["secret"], body.totp_code):
        raise APIError(401, "MFA_INVALID", "Invalid TOTP code")

    await database.execute(
        MFASecret.__table__.update()
        .where(MFASecret.user_id == current_user["id"])
        .values(is_enabled=True)
    )

    return {"message": "MFA enabled successfully"}


@mfa_router.post("/disable")
async def mfa_disable(body: MFAVerifyRequest, current_user=Depends(get_current_user)):
    record = await _get_mfa_record(current_user["id"])
    if not record or not record["is_enabled"]:
        raise APIError.not_found("MFA is not enabled")

    if not mfa_service.verify_totp(record["secret"], body.totp_code):
        raise APIError(401, "MFA_INVALID", "Invalid TOTP code")

    await database.execute(
        MFASecret.__table__.delete().where(MFASecret.user_id == current_user["id"])
    )

    return {"message": "MFA disabled successfully"}


@mfa_router.post("/challenge", response_model=MFAChallengeResponse)
@limiter.limit(RateLimits.MFA_CHALLENGE)
async def mfa_challenge(
    request: Request,
    body: MFAChallengeRequest,
    credentials: HTTPAuthorizationCredentials = Depends(mfa_security),
):
    mfa_token = credentials.credentials
    user_id = mfa_service.verify_mfa_token(mfa_token)
    if user_id is None:
        raise APIError.invalid_token("Invalid or expired MFA token")

    record = await _get_mfa_record(user_id)
    if not record or not record["is_enabled"]:
        raise APIError.not_found("MFA is not enabled for this account")

    verified = False

    if body.totp_code:
        verified = mfa_service.verify_totp(record["secret"], body.totp_code)

    if not verified and body.backup_code:
        stored = mfa_service.deserialize_backup_codes(record["backup_codes"])
        verified, remaining = mfa_service.use_backup_code(stored, body.backup_code)
        if verified:
            await database.execute(
                MFASecret.__table__.update()
                .where(MFASecret.user_id == user_id)
                .values(backup_codes=mfa_service.serialize_backup_codes(remaining))
            )

    if not verified:
        raise APIError(401, "MFA_INVALID", "Invalid MFA code")

    access_token, refresh_token, expires_in = await create_tokens(
        user_id=user_id,
        provider="mfa",
    )

    return MFAChallengeResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=expires_in,
    )
