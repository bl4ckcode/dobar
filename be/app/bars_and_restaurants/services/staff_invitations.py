"""
Staff invitation creation shared by every invite endpoint.

Both ``POST /bars/{bar_id}/staff/invite`` and the compatibility route
``POST /staff/invite`` authorize the caller with
``rbac_middleware.authorize_bar_permission`` / ``require_bar_permission``
(role defaults + custom permissions) and then call
``create_staff_invitation`` with the resulting ``BarAuthContext``. Routes do
nothing else: every step below lives here and only here.

1. ``parse_invitation_contact``  – contact validation: classified as email
                                   ("@") or phone (phone-shaped) or rejected,
                                   then validated and canonicalized before it
                                   is stored (same rules as account contacts)
2. ``parse_invitation_role``     – role validation
3. ``ensure_can_invite_role``    – no inviting above your own role
4. ``lock_bar_invitations``      – serialize invitation writes per bar
5. ``ensure_not_active_member``  – reject contacts that are already active
                                   staff at the bar (same matching rules as
                                   invitation acceptance)
6. ``resolve_pending_invitations`` – duplicate / resend policy (below)
7. ``generate_invitation_code``  – the code the invited user receives
8. ``persist_staff_invitation``  – the only inserter into ``staff_invitations``

Duplicate / resend policy (per bar + normalized contact)
--------------------------------------------------------
At most one live (pending, unexpired) invitation exists per bar and contact.
Re-inviting a contact that already has one:

* same role            -> resend: the existing invitation is returned with
                          the same code, its expiry renewed to 7 days from
                          now. No new row. Same 200 response as a new invite.
* different role       -> the old invitation is revoked (its code stops
                          working) and a new one is created, provided the
                          caller could have created the old one themselves
                          (its role is within their rank).
* old role above caller -> 409; the caller cannot override it and learns
                          nothing about it (no code, role or inviter).

Pending invitations that already expired are marked ``expired``. Other
venues' invitations are never looked at or changed.

Invitations are always created ``pending`` for ``auth.bar_id`` (the bar that
was authorized). They never grant access on their own: membership is only
created when the invited, authenticated user accepts via
``POST /me/bars/accept-invitation`` before ``expires_at``.

Error handling
--------------
``sanitized_invitation_errors`` wraps invite creation here and the whole
acceptance flow in ``routes/staff.py`` (preview, pending list, accept).
Unexpected failures are logged with ids and the exception type only and
surface as a generic 500: driver messages can embed row values (e.g.
Postgres ``DETAIL: Key (invitation_code)=(...)``), so neither logs nor
responses ever carry invitation codes or contact details.
"""

import logging
import secrets
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Tuple

from fastapi import HTTPException
from sqlalchemy import select

from ...database import database
from ...auth.auth_models import User
from ...auth.contact_validation import (
    InvalidContact, canonical_email, canonical_phone, classify_contact,
)
from ...auth.rbac_middleware import BarAuthContext
from ...auth.rbac_models import (
    BarRole, BarStaff, Permission, StaffInvitation, role_within_rank,
)
from ...bars_and_restaurants.models.relational_models import Bar
from ...errors import APIError, ErrorCode

logger = logging.getLogger(__name__)


INVITATION_TTL = timedelta(days=7)
INVITATION_PENDING = "pending"
INVITATION_REVOKED = "revoked"
INVITATION_EXPIRED = "expired"

PENDING_CONFLICT_DETAIL = "A pending invitation for this contact already exists"



# ---------------------------------------------------------------------------
# Error sanitization (invite creation and the whole acceptance flow)
# ---------------------------------------------------------------------------

@asynccontextmanager
async def sanitized_invitation_errors(action: str, *, message: Optional[str] = None, **log_fields):
    """Turn unexpected failures into a generic 500 that carries no data.

    Expected outcomes (``HTTPException`` / ``APIError``) pass through
    untouched. Anything else (typically a database driver error, whose
    message can embed row values such as an invitation code or a contact) is
    logged with ``action``, the given non-sensitive ``log_fields`` (ids only)
    and the exception *type*, never its message or traceback, and re-raised
    as ``APIError(500, message or "Could not {action} the invitation")``. Because
    ``APIError`` is handled by the app, no traceback reaches the server log.
    """
    try:
        yield
    except (HTTPException, APIError):
        raise
    except Exception as exc:
        fields = ", ".join(f"{key}={value}" for key, value in sorted(log_fields.items()))
        logger.error(
            "Staff invitation %s failed (%s, error=%s)",
            action, fields, type(exc).__name__,
        )
        raise APIError(
            500, ErrorCode.UNKNOWN, message or f"Could not {action} the invitation"
        ) from None


# ---------------------------------------------------------------------------
# Contact normalization. Shared with invitation acceptance, so "is this
# contact already a member?" and "is this user the recipient?" agree.
# ---------------------------------------------------------------------------

def normalize_email(value: Optional[str]) -> str:
    return (value or "").strip().lower()


def normalize_phone(value: Optional[str]) -> str:
    return "".join(ch for ch in (value or "") if ch.isdigit())


# ---------------------------------------------------------------------------
# Steps
# ---------------------------------------------------------------------------

def parse_invitation_contact(contact: str) -> Tuple[Optional[str], Optional[str]]:
    """Validate ``contact`` and return ``(email, None)`` or ``(None, phone)``.

    Classification (``classify_contact``) comes first:

    * contains "@"  -> treated as an email, even if malformed; must be a
      valid address ("Invalid email address" otherwise).
    * phone-shaped (only digits and + space - ( ) .) -> treated as a phone;
      must be valid E.164 ("Invalid phone number ..." otherwise).
    * anything else (empty, or text such as "hello" or "1-800-FLOWERS") is
      neither and is rejected; it is never treated as a phone number.

    The returned value is canonical (trimmed/lowercased email, compact E.164
    phone) and is what gets stored, using the same rules that govern account
    contacts, so a stored invitation always names a contact an account can
    have.

    Raises HTTPException(400) for a missing, unrecognized or malformed contact.
    """
    kind = classify_contact(contact)

    if kind == "email":
        try:
            return canonical_email(contact), None
        except InvalidContact:
            raise HTTPException(status_code=400, detail="Invalid email address")

    if kind == "phone":
        try:
            return None, canonical_phone(contact)
        except InvalidContact:
            raise HTTPException(
                status_code=400,
                detail="Invalid phone number. Use international format, e.g. +5531999999999",
            )

    raise HTTPException(status_code=400, detail="Valid email or phone required")


def parse_invitation_role(role_value: str) -> BarRole:
    """Raises HTTPException(400) for an unknown role."""
    try:
        return BarRole(role_value)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid role: {role_value}")


def ensure_can_invite_role(auth: BarAuthContext, role: BarRole) -> None:
    """Nobody can invite someone to a role above their own at this bar.

    Owners can invite owner and below, admins admin and below, managers
    manager and below, and so on. A custom ``staff:manage`` grant lets a
    role invite, but never above itself (e.g. a cashier cannot invite a
    second account of their own as admin). An unknown inviter role ranks
    below every role and can invite nobody.

    Raises HTTPException(403) otherwise.
    """
    if not role_within_rank(auth.role, role):
        raise HTTPException(
            status_code=403,
            detail=f"Cannot invite a {role.value}: role is above your own ({auth.role})",
        )


async def ensure_not_active_member(
    bar_id: int,
    email: Optional[str],
    phone: Optional[str],
) -> None:
    """Reject the invite if the contact already belongs to active staff.

    Matching uses the same normalization as invitation acceptance
    (trimmed/case-insensitive email, digits-only phone), so an active member
    cannot be re-invited by changing case or phone formatting.

    Raises HTTPException(409) if the contact is already active staff.
    """
    target_email = normalize_email(email) if email else ""
    target_phone = normalize_phone(phone) if phone else ""
    if not target_email and not target_phone:
        return

    # Active staff of one bar is small; match in Python so the rules are
    # identical on every database backend.
    members = await database.fetch_all(
        select(User.email, User.phone_number)
        .join(BarStaff, BarStaff.user_id == User.id)
        .where((BarStaff.bar_id == bar_id) & (BarStaff.is_active == True))  # noqa: E712
    )
    for member in members:
        if target_email and normalize_email(member["email"]) == target_email:
            raise HTTPException(status_code=409, detail="User already staff at this bar")
        if target_phone and normalize_phone(member["phone_number"]) == target_phone:
            raise HTTPException(status_code=409, detail="User already staff at this bar")


async def lock_bar_invitations(bar_id: int) -> None:
    """Serialize invitation writes for one bar within the current transaction.

    PostgreSQL: ``SELECT ... FOR NO KEY UPDATE`` on the bar row, so two
    concurrent invites for the same bar (e.g. a double-click) run one after
    the other and the second one sees the first one's invitation. ``NO KEY``
    keeps inserts that merely reference the bar (orders, staff, ...)
    unblocked. SQLite has no row locks; the clause is omitted there.
    """
    await database.fetch_one(
        select(Bar.id).where(Bar.id == bar_id).with_for_update(key_share=True)
    )


def _same_contact(invitation, email: Optional[str], phone: Optional[str]) -> bool:
    if email:
        return normalize_email(invitation["email"]) == normalize_email(email)
    target = normalize_phone(phone)
    return bool(target) and normalize_phone(invitation["phone"]) == target


def _is_expired(invitation, now: datetime) -> bool:
    expires_at = invitation["expires_at"]
    if expires_at.tzinfo is not None:
        expires_at = expires_at.astimezone(timezone.utc).replace(tzinfo=None)
    return expires_at <= now


async def find_pending_invitations(
    bar_id: int,
    email: Optional[str],
    phone: Optional[str],
) -> Tuple[List, List]:
    """Pending invitations at ``bar_id`` for this contact, as (live, stale).

    Contacts are compared normalized, so rows stored before contacts were
    canonicalized still match. Oldest first.
    """
    rows = await database.fetch_all(
        StaffInvitation.__table__.select()
        .where(
            (StaffInvitation.bar_id == bar_id)
            & (StaffInvitation.status == INVITATION_PENDING)
        )
        .order_by(StaffInvitation.id)
    )
    now = datetime.utcnow()
    live, stale = [], []
    for row in rows:
        if _same_contact(row, email, phone):
            (stale if _is_expired(row, now) else live).append(row)
    return live, stale


async def _set_status(invitation_ids: List[int], status_value: str) -> None:
    if not invitation_ids:
        return
    await database.execute(
        StaffInvitation.__table__.update()
        .where(
            StaffInvitation.id.in_(invitation_ids)
            & (StaffInvitation.status == INVITATION_PENDING)
        )
        .values(status=status_value)
    )


async def _fetch_invitation(invitation_id: int) -> dict:
    row = await database.fetch_one(
        StaffInvitation.__table__.select().where(StaffInvitation.id == invitation_id)
    )
    if row is None:
        raise RuntimeError("Staff invitation was not persisted")
    return dict(row._mapping) if hasattr(row, "_mapping") else dict(row)


async def renew_invitation(invitation_id: int) -> Optional[dict]:
    """Resend: keep the code, restart the 7-day window, return the row.

    Returns None when the invitation is no longer pending (it was accepted,
    revoked or expired after it was looked up), so a resend is never reported
    for an invitation that did not change.
    """
    renewed = await database.fetch_one(
        StaffInvitation.__table__.update()
        .where(
            (StaffInvitation.id == invitation_id)
            & (StaffInvitation.status == INVITATION_PENDING)
        )
        .values(expires_at=datetime.utcnow() + INVITATION_TTL)
        .returning(StaffInvitation.__table__.c.id)
    )
    if renewed is None:
        return None
    return await _fetch_invitation(invitation_id)


async def resolve_pending_invitations(
    auth: BarAuthContext,
    role: BarRole,
    email: Optional[str],
    phone: Optional[str],
) -> Optional[dict]:
    """Apply the duplicate / resend policy (see module docstring).

    Returns the invitation to resend, or None if a new one must be created.
    Raises HTTPException(409) if a live invitation ranked above the caller
    exists; nothing about that invitation is disclosed.
    """
    live, stale = await find_pending_invitations(auth.bar_id, email, phone)
    await _set_status([row["id"] for row in stale], INVITATION_EXPIRED)

    if any(not role_within_rank(auth.role, row["role"]) for row in live):
        raise HTTPException(status_code=409, detail=PENDING_CONFLICT_DETAIL)

    same_role = [row for row in live if row["role"] == role.value]
    keep = same_role[-1] if same_role else None
    await _set_status(
        [row["id"] for row in live if keep is None or row["id"] != keep["id"]],
        INVITATION_REVOKED,
    )
    if keep is not None:
        renewed = await renew_invitation(keep["id"])
        if renewed is not None:
            return renewed
        # The invitation stopped being pending while we worked on it. If the
        # recipient became an active member (accepted), this is a conflict,
        # not a resend; otherwise fall through and issue a fresh invitation.
        await ensure_not_active_member(auth.bar_id, email, phone)
    return None


def generate_invitation_code() -> str:
    """The code the invited user receives and presents to accept.

    128 bits of randomness, URL-safe. Unique per invitation
    (``staff_invitations.invitation_code`` has a unique constraint).
    """
    return secrets.token_urlsafe(16)


async def persist_staff_invitation(invitation_data: dict) -> dict:
    """Insert the invitation and return the row as stored.

    The insert and read-back run in one transaction: either the invitation is
    stored and the stored values (including the code the invitee will use)
    are returned, or nothing is stored and an error is raised. Callers never
    hand out a code that is not persisted.
    """
    async with database.transaction():
        inv_id = await database.execute(
            StaffInvitation.__table__.insert().values(**invitation_data)
        )
        return await _fetch_invitation(inv_id)


# ---------------------------------------------------------------------------
# Entry point used by both invite routes
# ---------------------------------------------------------------------------

async def create_staff_invitation(
    auth: BarAuthContext,
    contact: str,
    role_value: str,
) -> dict:
    """Validate, authorize and persist a pending invitation for ``auth.bar_id``.

    ``auth`` must come from the shared bar-permission resolver. The
    ``staff:manage`` check is repeated here so a caller that forgets to
    authorize fails closed instead of creating an invitation.

    Returns the invitation row as persisted (new, or resent per the
    duplicate / resend policy).
    """
    if not auth.has_permission(Permission.STAFF_MANAGE):
        raise HTTPException(
            status_code=403,
            detail=f"Missing permission: {Permission.STAFF_MANAGE.value}",
        )

    email, phone = parse_invitation_contact(contact)
    role = parse_invitation_role(role_value)
    ensure_can_invite_role(auth, role)

    async with sanitized_invitation_errors("create", bar_id=auth.bar_id):
        async with database.transaction():
            await lock_bar_invitations(auth.bar_id)
            await ensure_not_active_member(auth.bar_id, email, phone)

            resent = await resolve_pending_invitations(auth, role, email, phone)
            if resent is not None:
                return resent

            # All invitations start pending, with no auto-accept, even for
            # existing users or previously removed staff. Only the invited
            # user can accept. Naive UTC: expires_at is timezone=False.
            return await persist_staff_invitation({
                "bar_id": auth.bar_id,
                "email": email,
                "phone": phone,
                "role": role.value,
                "invitation_code": generate_invitation_code(),
                "status": INVITATION_PENDING,
                "expires_at": datetime.utcnow() + INVITATION_TTL,
                "invited_by_id": auth.user.id,
            })
