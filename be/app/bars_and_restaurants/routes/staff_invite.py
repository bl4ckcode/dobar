"""
Compatibility Staff Invite Route.

``POST /staff/invite`` takes the target ``bar_id`` in the request body instead
of the URL. It is otherwise identical to ``POST /bars/{bar_id}/staff/invite``:
both authorize with the shared bar-permission resolver (role defaults + the
membership's custom permissions, ``staff:manage`` required) and both
delegate everything else (contact/role validation, the rule against
inviting above your own role, the existing-member check, code generation and
persistence) to ``create_staff_invitation``.
"""
from fastapi import APIRouter, Depends, Response
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

from ...auth.rbac_middleware import (
    AuthUser, get_current_user, authorize_bar_permission, emit_bar_headers
)
from ...auth.rbac_models import Permission
from ...bars_and_restaurants.services.staff_invitations import create_staff_invitation


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
    response: Response,
    user: AuthUser = Depends(get_current_user),
):
    """Invite someone to join a bar's staff (``bar_id`` in the body).

    The body ``bar_id`` is the only bar considered: it is resolved exactly as
    the ``{bar_id}`` path parameter is on ``/bars/{bar_id}/staff/invite``.
    ``bar_id`` query parameters and the ``X-Bar-Id`` header are deliberately
    ignored, so a caller cannot be authorized at one bar and invite to another.
    """
    auth = await authorize_bar_permission(user, invite.bar_id, Permission.STAFF_MANAGE)
    invitation = await create_staff_invitation(auth, invite.contact, invite.role)
    emit_bar_headers(response, auth)
    return StaffInviteResponse(**invitation)
