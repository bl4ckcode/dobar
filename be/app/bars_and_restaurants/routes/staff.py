"""
Staff Management Routes - Endpoints for managing bar staff
"""

from fastapi import APIRouter, Depends, HTTPException, status
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
from ...errors import APIError


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


@my_bars_router.post("/accept-invitation")
async def accept_invitation(invitation_code: str, user: AuthUser = Depends(get_current_user)):
    """Accept a staff invitation."""
    invitation = await database.fetch_one(
        StaffInvitation.__table__.select().where(
            StaffInvitation.invitation_code == invitation_code
        )
    )
    if not invitation:
        raise APIError.not_found("Invitation")
    if invitation["status"] != "pending":
        raise HTTPException(status_code=400, detail=f"Invitation is {invitation['status']}")
    if invitation["expires_at"] < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="Invitation expired")
    
    role = BarRole(invitation["role"])
    await add_user_to_bar(user.id, invitation["bar_id"], role, invitation["invited_by_id"])
    
    await database.execute(
        StaffInvitation.__table__.update()
        .where(StaffInvitation.id == invitation["id"])
        .values(status="accepted", accepted_at=datetime.now(timezone.utc))
    )
    return {"message": "Invitation accepted", "bar_id": invitation["bar_id"], "role": invitation["role"]}
