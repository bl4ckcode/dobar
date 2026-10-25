"""
Staff Management Routes - Endpoints for managing bar staff
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from fastapi import Body
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime, timezone, timedelta
import secrets
import json

from ...database import database
from ...auth.rbac_middleware import (
    AuthUser, BarAuthContext, 
    get_current_user, require_bar_role, require_bar_permission,
    add_user_to_bar, remove_user_from_bar, get_user_bars
)
from ...auth.rbac_models import (
    BarRole, Permission, BarStaff, StaffInvitation, UserProfile, get_permissions_for_role
)
from ...auth.auth_models import User
from ...bars_and_restaurants.models.relational_models import Bar
from ...errors import APIError, ErrorCode


def _record_get(record, key, default=None):
    """Safe accessor for databases.Record objects (which lack .get())."""
    try:
        return record[key]
    except (KeyError, IndexError):
        return default


staff_router = APIRouter(prefix="/bars/{bar_id}/staff", tags=["Staff Management"])


# SCHEMAS
class StaffMember(BaseModel):
    id: int
    user_id: int
    bar_id: int
    role: str
    nickname: Optional[str] = None
    employee_id: Optional[str] = None
    is_active: bool
    display_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None

class StaffInviteRequest(BaseModel):
    contact: str  # Email or phone number
    role: str

class StaffUpdateRequest(BaseModel):
    role: Optional[str] = None
    nickname: Optional[str] = None
    is_active: Optional[bool] = None

class StaffInvitationResponse(BaseModel):
    id: int
    bar_id: int
    email: Optional[str]
    phone: Optional[str]
    role: str
    status: str
    invitation_code: str
    expires_at: datetime

class StaffRoleUpdateRequest(BaseModel):
    role: str

class MyBarsResponse(BaseModel):
    bar_id: int
    bar_name: str
    role: str
    permissions: List[str]


class InvitationCodeRequest(BaseModel):
    invitation_code: str


class InvitationPreviewResponse(BaseModel):
    venue_name: str
    venue_address: Optional[str] = None
    venue_image_url: Optional[str] = None
    role: str
    masked_recipient: str
    expires_at: datetime
    permissions: List[str]


class AcceptInvitationResponse(BaseModel):
    bar_id: int
    bar_name: str
    role: str
    permissions: List[str]
    message: str


# ROUTES
@staff_router.get("", response_model=List[StaffMember])
async def list_staff(
    bar_id: int,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.STAFF_VIEW))
):
    """List all staff members for a bar."""
    query = """
        SELECT bs.id, bs.user_id, bs.bar_id, bs.role, bs.nickname, 
               bs.employee_id, bs.is_active, up.display_name, u.email, 
               u.phone_number as phone
        FROM bar_staff bs
        LEFT JOIN user_profiles up ON bs.user_id = up.user_id
        LEFT JOIN users u ON bs.user_id = u.id
        WHERE bs.bar_id = :bar_id AND bs.is_active = true
        ORDER BY bs.role, bs.created_at
    """
    results = await database.fetch_all(query, {"bar_id": bar_id})
    return [StaffMember(**dict(r)) for r in results]


@staff_router.post("/invite", response_model=StaffInvitationResponse)
async def invite_staff(
    bar_id: int,
    invite: StaffInviteRequest,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.STAFF_MANAGE))
):
    """Invite someone to join the bar's staff."""
    # Detect if contact is email or phone
    email = None
    phone = None
    
    if "@" in invite.contact:
        email = invite.contact
    else:
        # Assume phone if no @ (should ideally validate E.164)
        phone = invite.contact
    
    if not email and not phone:
        raise HTTPException(status_code=400, detail="Valid email or phone required")
    
    try:
        role = BarRole(invite.role)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid role: {invite.role}")
    
    if role == BarRole.OWNER and not auth.is_owner():
        raise HTTPException(status_code=403, detail="Only owner can invite another owner")
    
    # Check if user already exists
    existing_user = None
    # Check if user already exists
    existing_user = None
    if email:
        existing_user = await database.fetch_one(
            User.__table__.select().where(User.email == email)
        )
    elif phone:
        existing_user = await database.fetch_one(
            User.__table__.select().where(User.phone_number == phone)
        )
    
    invitation_code = secrets.token_urlsafe(16)
    expires_at = datetime.now(timezone.utc) + timedelta(days=7)
    
    if existing_user:
        existing_staff = await database.fetch_one(
            BarStaff.__table__.select().where(
                (BarStaff.user_id == existing_user["id"]) & (BarStaff.bar_id == bar_id)
            )
        )
        if existing_staff and existing_staff["is_active"]:
            raise HTTPException(status_code=409, detail="User already staff at this bar")
        
        await add_user_to_bar(existing_user["id"], bar_id, role, auth.user.id)
        status_val = "accepted"
    else:
        status_val = "pending"
    
    invitation_data = {
        "bar_id": bar_id,
        "email": email,
        "phone": phone,
        "role": role.value,
        "invitation_code": invitation_code,
        "status": status_val,
        "expires_at": expires_at,
        "invited_by_id": auth.user.id,
    }
    
    inv_id = await database.execute(
        StaffInvitation.__table__.insert().values(**invitation_data)
    )
    
    return StaffInvitationResponse(
        id=inv_id, bar_id=bar_id, email=email, phone=phone,
        role=role.value, status=status_val, invitation_code=invitation_code,
        expires_at=expires_at
    )


@staff_router.put("/{staff_id}/role")
async def update_staff_role(
    bar_id: int,
    staff_id: int,
    request: StaffRoleUpdateRequest,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.STAFF_MANAGE))
):
    """Change a staff member's role."""
    try:
        new_role = BarRole(request.role)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid role: {request.role}")
        
    staff = await database.fetch_one(
        BarStaff.__table__.select().where(
            (BarStaff.id == staff_id) & (BarStaff.bar_id == bar_id) & (BarStaff.is_active == True)
        )
    )
    if not staff:
        raise APIError.not_found("Staff member")
        
    # Security checks
    if staff["role"] == BarRole.OWNER.value and not auth.is_owner():
        raise HTTPException(status_code=403, detail="Only owner can change another owner's role")
        
    if new_role == BarRole.OWNER and not auth.is_owner():
        raise HTTPException(status_code=403, detail="Only owner can promote someone to owner")
        
    await database.execute(
        BarStaff.__table__.update()
        .where(BarStaff.id == staff_id)
        .values(role=new_role.value, updated_at=datetime.now(timezone.utc))
    )
    
    return {
        "message": "Role updated successfully",
        "staff_id": str(staff_id),
        "new_role": new_role.value
    }


@staff_router.delete("/{staff_id}")
async def remove_staff(
    bar_id: int,
    staff_id: int,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.STAFF_MANAGE))
):
    """Remove a staff member from the bar."""
    staff = await database.fetch_one(
        BarStaff.__table__.select().where(
            (BarStaff.id == staff_id) & (BarStaff.bar_id == bar_id)
        )
    )
    if not staff:
        raise APIError.not_found("Staff member")
    
    if staff["role"] == BarRole.OWNER.value and not auth.is_owner():
        raise HTTPException(status_code=403, detail="Only owner can remove another owner")
    
    await database.execute(
        BarStaff.__table__.update()
        .where(BarStaff.id == staff_id)
        .values(is_active=False, updated_at=datetime.now(timezone.utc))
    )
    return {"message": "Staff member removed"}


# MY BARS ROUTER
my_bars_router = APIRouter(prefix="/me/bars", tags=["My Bars"])


@my_bars_router.get("", response_model=List[MyBarsResponse])
async def get_my_bars(user: AuthUser = Depends(get_current_user)):
    """Get all bars the current user has access to."""
    bars = await get_user_bars(user.id)
    result = []
    for bar in bars:
        try:
            role_enum = BarRole(bar["role"])
            permissions = [p.value for p in get_permissions_for_role(role_enum)]
        except ValueError:
            permissions = []
        result.append(MyBarsResponse(
            bar_id=bar["bar_id"], bar_name=bar["bar_name"],
            role=bar["role"], permissions=permissions
        ))
    return result


def _mask_recipient(email, phone):
    if email:
        local, _, domain = email.partition("@")
        if len(local) <= 2:
            masked_local = local[0] + "*" * max(len(local)-1, 1)
        else:
            masked_local = local[0] + "*" * (len(local)-2) + local[-1]
        return f"{masked_local}@{domain}"
    if phone:
        digits = "".join(ch for ch in phone if ch.isdigit())
        if len(digits) <= 4:
            return "*" * len(digits)
        return "*" * (len(digits)-4) + digits[-4:]
    return ""


def _normalize_phone(value):
    return "".join(ch for ch in (value or "") if ch.isdigit())


def _recipient_matches(invitation, user):
    if _record_get(invitation, "email"):
        if not user.email:
            return False
        if _record_get(invitation, "email").strip().lower() != user.email.strip().lower():
            return False
    if _record_get(invitation, "phone"):
        if not user.phone_number:
            return False
        if _normalize_phone(_record_get(invitation, "phone")) != _normalize_phone(user.phone_number):
            return False
    return True


def _require_verified_contact(invitation, user):
    """Fail closed: matching contact must be server-verified on the user."""
    invitation_email = _record_get(invitation, "email")
    invitation_phone = _record_get(invitation, "phone")
    if invitation_email and not user.email_verified:
        raise APIError(
            403, ErrorCode.INVITATION_CONTACT_UNVERIFIED,
            "Invitation recipient email is not verified",
        )
    if invitation_phone and not user.phone_verified:
        raise APIError(
            403, ErrorCode.INVITATION_CONTACT_UNVERIFIED,
            "Invitation recipient phone is not verified",
        )


def _invitation_expired(invitation):
    expires_at = invitation["expires_at"]
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    return expires_at < datetime.now(timezone.utc)


@my_bars_router.post("/invitations/preview", response_model=InvitationPreviewResponse)
async def preview_invitation(payload: InvitationCodeRequest, user: AuthUser = Depends(get_current_user)):
    invitation = await database.fetch_one(
        StaffInvitation.__table__.select().where(
            StaffInvitation.invitation_code == payload.invitation_code
        )
    )
    if not invitation:
        raise APIError(404, ErrorCode.INVITATION_INVALID, "Invitation not found")
    if invitation["status"] == "revoked":
        raise APIError(410, ErrorCode.INVITATION_REVOKED, "Invitation revoked")
    if invitation["status"] == "expired" or _invitation_expired(invitation):
        raise APIError(410, ErrorCode.INVITATION_EXPIRED, "Invitation expired")
    if invitation["status"] == "accepted":
        accepted_by = invitation.get("accepted_by_user_id")
        if accepted_by is not None and accepted_by != user.id:
            raise APIError(409, ErrorCode.INVITATION_ALREADY_USED, "Invitation already used")
        if accepted_by not in (None, user.id):
            raise APIError(410, ErrorCode.BAD_REQUEST, "Invitation already used")
    if not _recipient_matches(invitation, user):
        raise APIError(403, ErrorCode.INVITATION_CONTACT_MISMATCH, "Invitation recipient does not match authenticated user")
    _require_verified_contact(invitation, user)

    bar = await database.fetch_one(
        Bar.__table__.select().where(Bar.id == invitation["bar_id"])
    )
    if not bar:
        raise APIError(404, ErrorCode.NOT_FOUND, "Bar not found")

    role = BarRole(invitation["role"])
    permissions = [p.value for p in get_permissions_for_role(role)]
    expires_at = invitation["expires_at"]
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    return InvitationPreviewResponse(
        venue_name=bar["name"],
        venue_address=_record_get(bar, "address"),
        venue_image_url=_record_get(bar, "logo_url") or _record_get(bar, "cover_url"),
        role=invitation["role"],
        masked_recipient=_mask_recipient(_record_get(invitation, "email"), _record_get(invitation, "phone")),
        expires_at=expires_at,
        permissions=permissions,
    )


@my_bars_router.post("/accept-invitation", response_model=AcceptInvitationResponse)
async def accept_invitation(
    payload: Optional[InvitationCodeRequest] = Body(None),
    invitation_code: Optional[str] = Query(None),
    user: AuthUser = Depends(get_current_user),
):
    if payload is not None and invitation_code is not None and payload.invitation_code != invitation_code:
        raise APIError(400, ErrorCode.BAD_REQUEST, "Conflicting invitation_code values")
    code = payload.invitation_code if payload is not None else invitation_code
    if not code:
        raise APIError(400, ErrorCode.VALIDATION_ERROR, "invitation_code is required")

    invitation = await database.fetch_one(
        StaffInvitation.__table__.select().where(
            StaffInvitation.invitation_code == code
        )
    )
    if not invitation:
        raise APIError(404, ErrorCode.INVITATION_INVALID, "Invitation not found")
    if invitation["status"] == "revoked":
        raise APIError(410, ErrorCode.INVITATION_REVOKED, "Invitation revoked")
    if invitation["status"] == "expired" or _invitation_expired(invitation):
        raise APIError(410, ErrorCode.INVITATION_EXPIRED, "Invitation expired")
    if not _recipient_matches(invitation, user):
        raise APIError(403, ErrorCode.INVITATION_CONTACT_MISMATCH, "Invitation recipient does not match authenticated user")
    _require_verified_contact(invitation, user)

    accepted_by = _record_get(invitation, "accepted_by_user_id")
    if invitation["status"] == "accepted":
        if accepted_by is not None and accepted_by != user.id:
            raise APIError(409, ErrorCode.INVITATION_ALREADY_USED, "Invitation already used by another user")
        # Replay: return current active membership, never restore removed access.
        current_staff = await database.fetch_one(
            BarStaff.__table__.select().where(
                (BarStaff.user_id == user.id) &
                (BarStaff.bar_id == invitation["bar_id"]) &
                (BarStaff.is_active == True)
            )
        )
        bar = await database.fetch_one(Bar.__table__.select().where(Bar.id == invitation["bar_id"]))
        if current_staff:
            current_role = BarRole(current_staff["role"])
            current_permissions = [p.value for p in get_permissions_for_role(current_role)]
            return AcceptInvitationResponse(
                bar_id=invitation["bar_id"],
                bar_name=bar["name"] if bar else "",
                role=current_role.value,
                permissions=current_permissions,
                message="Invitation already accepted",
            )
        raise APIError(403, ErrorCode.INVITATION_ALREADY_USED, "Invitation already accepted; no active membership")

    if invitation["status"] != "pending":
        raise APIError(410, ErrorCode.INVITATION_ALREADY_USED, "Invitation is not pending")

    role = BarRole(invitation["role"])
    bar = await database.fetch_one(Bar.__table__.select().where(Bar.id == invitation["bar_id"]))
    if not bar:
        raise APIError(404, ErrorCode.NOT_FOUND, "Bar not found")

    async with database.transaction():
        await add_user_to_bar(user.id, invitation["bar_id"], role, invitation["invited_by_id"])
        result = await database.execute(
            StaffInvitation.__table__.update()
            .where(
                (StaffInvitation.id == invitation["id"]) &
                (StaffInvitation.status == "pending")
            )
            .values(
                status="accepted",
                accepted_at=datetime.now(timezone.utc),
                accepted_by_user_id=user.id,
            )
            .returning(StaffInvitation.c.id)
        )
        if not result:
            raise APIError(409, ErrorCode.CONFLICT, "Invitation already used")

    permissions = [p.value for p in get_permissions_for_role(role)]
    return AcceptInvitationResponse(
        bar_id=invitation["bar_id"],
        bar_name=bar["name"],
        role=invitation["role"],
        permissions=permissions,
        message="Invitation accepted",
    )
