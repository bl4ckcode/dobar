"""Verified login-contact (email / phone) change.

Flow (authenticated, server-owned state):
1. POST /me/contact-change              -> pending challenge (10 min, one active per user)
2. client proves ownership of the NEW contact with Firebase (phone OTP, or an
   email-verified Firebase identity such as Google/Apple)
3. POST /me/contact-change/{id}/confirm -> proof validated, contact applied as
   verified, every refresh token revoked, fresh tokens returned for this device
4. POST /me/contact-change/{id}/cancel  -> discards a pending challenge

PUT /me/profile no longer changes email/phone. Name/avatar edits never touch
contact verification.
"""
import re
import secrets
from datetime import datetime, timedelta, timezone
from typing import Literal, Optional

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, EmailStr, TypeAdapter, ValidationError
from sqlalchemy import func

from app.database import database
from app.errors import APIError
from app.rate_limiter import limiter, RateLimits
from .auth_models import RefreshToken, User
from .contact_change_models import ContactChangeRequest
from .rbac_middleware import AuthUser, get_current_user

contact_change_router = APIRouter(prefix="/me/contact-change", tags=["Profile"])

CONTACT_CHANGE_TTL_MINUTES = 10
MAX_CONFIRM_ATTEMPTS = 5
PROOF_MAX_AGE_SECONDS = 300  # provider sign-in must be recent

_PHONE_RE = re.compile(r"^\+[1-9]\d{7,14}$")
_EMAIL = TypeAdapter(EmailStr)


class ContactChangeStart(BaseModel):
    channel: Literal["email", "phone"]
    new_value: str


class ContactChangeStarted(BaseModel):
    request_id: str
    channel: str
    new_value: str
    expires_in: int


class ContactChangeConfirm(BaseModel):
    proof_token: str  # Firebase ID token issued after verifying the NEW contact


class ContactChangeResult(BaseModel):
    channel: str
    email: Optional[str] = None
    phone_number: Optional[str] = None
    email_verified: bool
    phone_verified: bool
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class ContactChangeStatus(BaseModel):
    request_id: str
    status: str


def normalize_contact(channel: str, value: str) -> str:
    value = (value or "").strip()
    if channel == "phone":
        compact = re.sub(r"[\s\-()]", "", value)
        if not _PHONE_RE.match(compact):
            raise APIError.validation_error(
                "Invalid phone number", {"new_value": ["Use international format, e.g. +5531999999999"]}
            )
        return compact
    try:
        return str(_EMAIL.validate_python(value)).lower()
    except ValidationError:
        raise APIError.validation_error("Invalid email", {"new_value": ["Invalid email address"]})


def _aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def verify_contact_proof(proof_token: str) -> dict:
    """Validate the provider proof. Isolated so tests can stub the provider."""
    from firebase_admin import auth as firebase_auth

    try:
        return firebase_auth.verify_id_token(proof_token)
    except Exception:
        raise APIError.invalid_token("Invalid contact verification proof")


async def _contact_in_use(channel: str, value: str, user_id: int) -> bool:
    if channel == "phone":
        cond = User.phone_number == value
    else:
        cond = func.lower(User.email) == value
    row = await database.fetch_one(User.__table__.select().where(cond & (User.id != user_id)))
    return row is not None


async def _load_owned_pending(request_id: str, user_id: int):
    record = await database.fetch_one(
        ContactChangeRequest.__table__.select().where(ContactChangeRequest.request_id == request_id)
    )
    # Unknown and foreign ids are indistinguishable.
    if not record or record["user_id"] != user_id:
        raise APIError.not_found("Contact change request not found")
    return record


async def _set_status(record_id: int, status: str, **extra):
    await database.execute(
        ContactChangeRequest.__table__.update().where(ContactChangeRequest.id == record_id).values(status=status, **extra)
    )


@contact_change_router.post("", response_model=ContactChangeStarted, status_code=201)
@limiter.limit(RateLimits.AUTH)
async def start_contact_change(
    request: Request,
    body: ContactChangeStart,
    current_user: AuthUser = Depends(get_current_user),
):
    new_value = normalize_contact(body.channel, body.new_value)
    user = await database.fetch_one(User.__table__.select().where(User.id == current_user.id))
    if not user:
        raise APIError.user_not_found()

    current = user["phone_number"] if body.channel == "phone" else (user["email"] or "").lower()
    if current and current == new_value:
        raise APIError.conflict("New contact is the same as the current contact")
    if await _contact_in_use(body.channel, new_value, current_user.id):
        raise (APIError.phone_in_use() if body.channel == "phone" else APIError.email_in_use())

    # One active challenge per user and channel: a new start cancels the old one.
    await database.execute(
        ContactChangeRequest.__table__.update()
        .where(
            (ContactChangeRequest.user_id == current_user.id)
            & (ContactChangeRequest.channel == body.channel)
            & (ContactChangeRequest.status == "pending")
        )
        .values(status="cancelled")
    )
    request_id = secrets.token_urlsafe(32)
    now = datetime.now(timezone.utc)
    await database.execute(
        ContactChangeRequest.__table__.insert().values(
            request_id=request_id,
            user_id=current_user.id,
            channel=body.channel,
            new_value=new_value,
            status="pending",
            attempts=0,
            expires_at=now + timedelta(minutes=CONTACT_CHANGE_TTL_MINUTES),
            created_at=now,
        )
    )
    return ContactChangeStarted(
        request_id=request_id,
        channel=body.channel,
        new_value=new_value,
        expires_in=CONTACT_CHANGE_TTL_MINUTES * 60,
    )


@contact_change_router.post("/{request_id}/confirm", response_model=ContactChangeResult)
@limiter.limit(RateLimits.AUTH)
async def confirm_contact_change(
    request: Request,
    request_id: str,
    body: ContactChangeConfirm,
    current_user: AuthUser = Depends(get_current_user),
):
    from .routes import create_tokens

    record = await _load_owned_pending(request_id, current_user.id)
    if record["status"] != "pending":
        # completed / cancelled / expired challenges can never be replayed
        raise APIError.invalid_token("Contact change request is no longer valid")

    now = datetime.now(timezone.utc)
    if _aware(record["expires_at"]) <= now:
        await _set_status(record["id"], "expired")
        raise APIError.session_expired("Contact change request has expired")

    if record["attempts"] >= MAX_CONFIRM_ATTEMPTS:
        await _set_status(record["id"], "cancelled")
        raise APIError.rate_limited("Too many verification attempts")
    await database.execute(
        ContactChangeRequest.__table__.update()
        .where(ContactChangeRequest.id == record["id"])
        .values(attempts=ContactChangeRequest.attempts + 1)
    )

    claims = verify_contact_proof(body.proof_token)
    auth_time = claims.get("auth_time") or claims.get("iat")
    if not auth_time or now.timestamp() - float(auth_time) > PROOF_MAX_AGE_SECONDS:
        raise APIError.invalid_token("Verification proof is too old; verify again")

    channel, new_value = record["channel"], record["new_value"]
    firebase_uid = claims.get("uid") or claims.get("user_id") or claims.get("sub")
    if channel == "phone":
        proven = claims.get("phone_number")
        proven = re.sub(r"[\s\-()]", "", proven) if proven else None
    else:
        proven = (claims.get("email") or "").lower() or None
        if not claims.get("email_verified"):
            proven = None
    if not proven or proven != new_value:
        raise APIError.invalid_token("Verification proof does not match the requested contact")

    if await _contact_in_use(channel, new_value, current_user.id):
        await _set_status(record["id"], "cancelled")
        raise (APIError.phone_in_use() if channel == "phone" else APIError.email_in_use())

    values = {"phone_number": new_value, "phone_verified": True} if channel == "phone" else {
        "email": new_value,
        "email_verified": True,
    }
    if channel == "phone" and firebase_uid:
        # Phone login resolves users by Firebase uid; bind the new number's uid
        # so signing in with it reaches this account instead of creating one.
        owner = await database.fetch_one(User.__table__.select().where(User.firebase_uid == firebase_uid))
        if owner and owner["id"] != current_user.id:
            await _set_status(record["id"], "cancelled")
            raise APIError.conflict("This phone identity belongs to another account")
        values["firebase_uid"] = firebase_uid

    async with database.transaction():
        # Claim the challenge atomically so a concurrent replay cannot also apply.
        claimed = await database.fetch_one(
            ContactChangeRequest.__table__.update()
            .where((ContactChangeRequest.id == record["id"]) & (ContactChangeRequest.status == "pending"))
            .values(status="completed", completed_at=now)
            .returning(ContactChangeRequest.id)
        )
        if not claimed:
            raise APIError.invalid_token("Contact change request is no longer valid")
        await database.execute(User.__table__.update().where(User.id == current_user.id).values(**values))
        # Session effect: every existing session must re-authenticate.
        await database.execute(
            RefreshToken.__table__.update()
            .where((RefreshToken.user_id == current_user.id) & (RefreshToken.revoked_at.is_(None)))
            .values(revoked_at=now)
        )

    access_token, refresh_token, expires_in = await create_tokens(user_id=current_user.id, provider=channel)
    user = await database.fetch_one(User.__table__.select().where(User.id == current_user.id))
    return ContactChangeResult(
        channel=channel,
        email=user["email"],
        phone_number=user["phone_number"],
        email_verified=bool(user["email_verified"]),
        phone_verified=bool(user["phone_verified"]),
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=expires_in,
    )


@contact_change_router.post("/{request_id}/cancel", response_model=ContactChangeStatus)
@limiter.limit(RateLimits.AUTH)
async def cancel_contact_change(
    request: Request,
    request_id: str,
    current_user: AuthUser = Depends(get_current_user),
):
    record = await _load_owned_pending(request_id, current_user.id)
    if record["status"] == "completed":
        raise APIError.conflict("Contact change already completed")
    if record["status"] == "pending":
        await _set_status(record["id"], "cancelled")
        return ContactChangeStatus(request_id=request_id, status="cancelled")
    return ContactChangeStatus(request_id=request_id, status=record["status"])
