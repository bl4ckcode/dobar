"""
Simplified Staff Invite Route - avoids complex middleware chain for reliability.

This is an alternative invite endpoint that uses simpler auth patterns
to avoid issues with BaseHTTPMiddleware on Fly.io deployments.
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime, timezone, timedelta
import secrets

from ...database import database
from ...auth.rbac_middleware import (
    AuthUser, get_current_user, add_user_to_bar
)
from ...auth.rbac_models import (
    BarRole, BarStaff, StaffInvitation, UserProfile
)
from ...auth.auth_models import User
from ...errors import APIError


invite_router = APIRouter(prefix="/staff", tags=["Staff Management"])


class StaffInviteRequest(BaseModel):
    bar_id: int = Field(..., description="Bar ID to invite to")
    contact: str = Field(..., description="Email or phone number")
    role: str = Field(..., description="admin, manager, cashier, or staff")


class StaffInviteResponse(BaseModel):
    id: int
    bar_id: int
    email: Optional[str] = None
    phone: Optional[str] = None
    role: str
    status: str
    invitation_code: str
    expires_at: datetime


@invite_router.post("/invite")
async def invite_staff_simple(
    invite: StaffInviteRequest,
    user: AuthUser = Depends(get_current_user),
):
    """Invite someone to join a bar's staff. Simpler auth chain for reliability."""
    # Check if user has permission at this bar
    user_role = user.get_role_at_bar(invite.bar_id)
    if not user_role:
        raise HTTPException(status_code=403, detail="You don't have access to this bar")
    
    # Check permission level
    role_hierarchy = {
        "owner": 5,
        "admin": 4,
        "manager": 3,
        "cashier": 2,
        "staff": 1,
    }
    
    inviter_level = role_hierarchy.get(user_role, 0)
    if inviter_level < 3:  # Manager or above can invite
        raise HTTPException(
            status_code=403,
            detail="Insufficient permissions. Manager role or above required to invite staff."
        )
    
    # Detect if contact is email or phone
    email = None
    phone = None
    if "@" in invite.contact:
        email = invite.contact
    else:
        phone = invite.contact
    
    if not email and not phone:
        raise HTTPException(status_code=400, detail="Valid email or phone required")
    
    # Validate role
    try:
        role = BarRole(invite.role)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid role: {invite.role}")
    
    # Only owner can invite another owner
    if role == BarRole.OWNER and not user.is_bar_owner(invite.bar_id):
        raise HTTPException(status_code=403, detail="Only owner can invite another owner")
    
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
        # Check if already a staff member
        existing_staff = await database.fetch_one(
            BarStaff.__table__.select().where(
                (BarStaff.user_id == existing_user["id"]) & 
                (BarStaff.bar_id == invite.bar_id)
            )
        )
        if existing_staff and existing_staff["is_active"]:
            raise HTTPException(status_code=409, detail="User already staff at this bar")
        
        # Add to bar directly
        await add_user_to_bar(existing_user["id"], invite.bar_id, role, user.id)
        status_val = "accepted"
    else:
        status_val = "pending"
    
    # Create invitation record
    invitation_data = {
        "bar_id": invite.bar_id,
        "email": email,
        "phone": phone,
        "role": role.value,
        "invitation_code": invitation_code,
        "status": status_val,
        "expires_at": expires_at,
        "invited_by_id": user.id,
    }
    
    inv_id = await database.execute(
        StaffInvitation.__table__.insert().values(**invitation_data)
    )
    
    return StaffInviteResponse(
        id=inv_id,
        bar_id=invite.bar_id,
        email=email,
        phone=phone,
        role=role.value,
        status=status_val,
        invitation_code=invitation_code,
        expires_at=expires_at,
    )