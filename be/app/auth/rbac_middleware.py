"""
🔐 RBAC Middleware & Dependencies

FastAPI dependencies for role-based access control.
Use these to protect routes based on user roles and permissions.

Usage Examples:

    # Require authenticated user (any type)
    @router.get("/profile")
    async def get_profile(user: AuthUser = Depends(get_current_user)):
        return user

    # Require bar owner or admin
    @router.get("/bars/{bar_id}/settings")
    async def bar_settings(
        bar_id: int,
        user: AuthUser = Depends(get_current_user),
        _: bool = Depends(require_bar_permission(Permission.BAR_EDIT))
    ):
        pass

    # Require specific permission at a bar
    @router.post("/bars/{bar_id}/orders/{order_id}/confirm")
    async def confirm_order(
        bar_id: int,
        order_id: int,
        auth: BarAuthContext = Depends(require_bar_role(BarRole.CASHIER))
    ):
        # auth.user, auth.bar_id, auth.role, auth.permissions available
        pass
"""

from fastapi import Depends, Request, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from typing import Optional, List
from dataclasses import dataclass
from datetime import datetime, timezone
import os
import json

from ..database import database
from .auth_models import User
from .rbac_models import (
    BarStaff, UserProfile, BarRole, Permission,
    UserType, ROLE_PERMISSIONS, get_permissions_for_role
)
from ..errors import APIError


# JWT Settings
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-here")
ALGORITHM = "HS256"


security = HTTPBearer(auto_error=False)


# =============================================================================
# DATA CLASSES
# =============================================================================

@dataclass
class AuthUser:
    """Authenticated user with profile info."""
    id: int
    email: Optional[str]
    phone_number: Optional[str]
    is_active: bool
    user_type: str  # "client" or "business"
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    fcm_token: Optional[str] = None
    subscription_tier: str = "regular"
    country_code: Optional[str] = None
    
    # Bar roles: {bar_id: BarRole}
    bar_roles: dict = None
    
    def __post_init__(self):
        if self.bar_roles is None:
            self.bar_roles = {}
    
    def is_business_user(self) -> bool:
        return self.user_type == UserType.BUSINESS.value
    
    def is_pro(self) -> bool:
        return self.subscription_tier == "pro"
    
    def is_bar_owner(self, bar_id: int) -> bool:
        return self.bar_roles.get(bar_id) == BarRole.OWNER.value
    
    def get_role_at_bar(self, bar_id: int) -> Optional[str]:
        return self.bar_roles.get(bar_id)
    
    def has_any_bar_role(self) -> bool:
        return len(self.bar_roles) > 0


@dataclass
class BarAuthContext:
    """
    Context for bar-specific authorization.
    Includes user, bar_id, their role at that bar, and permissions.
    """
    user: AuthUser
    bar_id: int
    role: str
    permissions: List[str]
    
    def has_permission(self, permission: Permission) -> bool:
        return permission.value in self.permissions
    
    def is_owner(self) -> bool:
        return self.role == BarRole.OWNER.value
    
    def is_admin_or_above(self) -> bool:
        return self.role in [BarRole.OWNER.value, BarRole.ADMIN.value]


# =============================================================================
# CORE DEPENDENCIES
# =============================================================================

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> AuthUser:
    """
    Get the currently authenticated user.
    Returns AuthUser with roles for all bars they're associated with.
    """
    if not credentials:
        raise APIError.unauthorized()
    
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        
        user_id = payload.get("sub")
        if user_id is None:
            raise APIError.invalid_token()
        
        user_id = int(user_id)
        
    except JWTError:
        raise APIError.invalid_token()
    
    # Fetch user from database
    user_query = User.__table__.select().where(User.id == user_id)
    user = await database.fetch_one(user_query)
    
    if not user:
        raise APIError.not_found("User")
    
    if not user["is_active"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled"
        )
    
    # Fetch user profile
    profile_query = UserProfile.__table__.select().where(UserProfile.user_id == user_id)
    profile = await database.fetch_one(profile_query)
    
    # Fetch bar roles
    bar_roles = {}
    staff_query = BarStaff.__table__.select().where(
        (BarStaff.user_id == user_id) & (BarStaff.is_active == True)
    )
    staff_records = await database.fetch_all(staff_query)
    
    for record in staff_records:
        bar_roles[record["bar_id"]] = record["role"]
    
    return AuthUser(
        id=user_id,
        email=user["email"],
        phone_number=user["phone_number"],
        is_active=user["is_active"],
        user_type=profile["user_type"] if profile else UserType.CLIENT.value,
        display_name=profile["display_name"] if profile else None,
        avatar_url=profile["avatar_url"] if profile else None,
        fcm_token=profile["fcm_token"] if profile else None,
        subscription_tier=dict(user).get("subscription_tier", "regular"),
        country_code=user["country_code"] or (profile["country_code"] if profile else None) or "BR",
        bar_roles=bar_roles
    )


async def get_optional_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> Optional[AuthUser]:
    """
    Get current user if authenticated, None otherwise.
    Useful for endpoints that work for both authenticated and anonymous users.
    """
    if not credentials:
        return None
    
    try:
        return await get_current_user(credentials)
    except (APIError, HTTPException):
        return None


# =============================================================================
# BAR-SPECIFIC DEPENDENCIES
# =============================================================================

def require_bar_role(*allowed_roles: BarRole):
    """
    Dependency factory that requires user to have one of the allowed roles at the bar.
    The bar_id must be in the path parameters.
    
    Usage:
        @router.post("/bars/{bar_id}/orders/{order_id}/confirm")
        async def confirm_order(
            bar_id: int,
            order_id: int,
            auth: BarAuthContext = Depends(require_bar_role(BarRole.CASHIER, BarRole.MANAGER))
        ):
            pass
    """
    async def dependency(
        request: Request,
        user: AuthUser = Depends(get_current_user)
    ) -> BarAuthContext:
        # Get bar_id from path or query
        bar_id = request.path_params.get("bar_id") or request.query_params.get("bar_id")
        
        if bar_id is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="bar_id is required in path or query"
            )
        
        try:
            bar_id = int(bar_id)
        except (ValueError, TypeError):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid bar_id format"
            )
        
        # Check if user has a role at this bar
        user_role = user.get_role_at_bar(bar_id)
        if not user_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You don't have access to this bar"
            )
        
        # Check if user's role is in allowed roles
        # Role hierarchy: OWNER > ADMIN > MANAGER > CASHIER > STAFF
        role_hierarchy = {
            BarRole.OWNER.value: 5,
            BarRole.ADMIN.value: 4,
            BarRole.MANAGER.value: 3,
            BarRole.CASHIER.value: 2,
            BarRole.STAFF.value: 1,
        }
        
        user_level = role_hierarchy.get(user_role, 0)
        min_required_level = min(role_hierarchy.get(r.value, 0) for r in allowed_roles)
        
        if user_level < min_required_level:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Insufficient permissions. Required: {', '.join(r.value for r in allowed_roles)}"
            )
        
        # Get permissions for user's role
        try:
            role_enum = BarRole(user_role)
            permissions = [p.value for p in get_permissions_for_role(role_enum)]
        except ValueError:
            permissions = []
        
        # Check for custom permissions
        staff_query = BarStaff.__table__.select().where(
            (BarStaff.user_id == user.id) & 
            (BarStaff.bar_id == bar_id) &
            (BarStaff.is_active == True)
        )
        staff = await database.fetch_one(staff_query)
        
        if staff and staff["custom_permissions"]:
            try:
                custom = json.loads(staff["custom_permissions"])
                permissions.extend(custom)
            except (json.JSONDecodeError, TypeError):
                pass
        
        return BarAuthContext(
            user=user,
            bar_id=bar_id,
            role=user_role,
            permissions=list(set(permissions))
        )
    
    return dependency


def require_bar_permission(permission: Permission):
    """
    Dependency factory that requires user to have a specific permission at the bar.
    
    Usage:
        @router.delete("/bars/{bar_id}/menus/{menu_id}")
        async def delete_menu(
            bar_id: int,
            menu_id: int,
            auth: BarAuthContext = Depends(require_bar_permission(Permission.MENU_DELETE))
        ):
            pass
    """
    async def dependency(
        request: Request,
        user: AuthUser = Depends(get_current_user)
    ) -> BarAuthContext:
        bar_id = request.path_params.get("bar_id") or request.query_params.get("bar_id")
        
        if bar_id is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="bar_id is required in path or query"
            )
        
        try:
            bar_id = int(bar_id)
        except (ValueError, TypeError):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid bar_id format"
            )
        user_role = user.get_role_at_bar(bar_id)
        
        if not user_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You don't have access to this bar"
            )
        
        # Get role's permissions
        try:
            role_enum = BarRole(user_role)
            permissions = [p.value for p in get_permissions_for_role(role_enum)]
        except ValueError:
            permissions = []
        
        # Check custom permissions
        staff_query = BarStaff.__table__.select().where(
            (BarStaff.user_id == user.id) & 
            (BarStaff.bar_id == bar_id) &
            (BarStaff.is_active == True)
        )
        staff = await database.fetch_one(staff_query)
        
        if staff and staff["custom_permissions"]:
            try:
                custom = json.loads(staff["custom_permissions"])
                permissions.extend(custom)
            except (json.JSONDecodeError, TypeError):
                pass
        
        permissions = list(set(permissions))
        
        # Check if required permission is present
        if permission.value not in permissions:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Missing permission: {permission.value}"
            )
        
        return BarAuthContext(
            user=user,
            bar_id=bar_id,
            role=user_role,
            permissions=permissions
        )
    
    return dependency


def require_bar_owner():
    """Shortcut for requiring OWNER role."""
    return require_bar_role(BarRole.OWNER)


def require_bar_admin_or_above():
    """Shortcut for requiring ADMIN or OWNER role."""
    return require_bar_role(BarRole.ADMIN, BarRole.OWNER)


def require_cashier_or_above():
    """Shortcut for requiring CASHIER or higher role."""
    return require_bar_role(BarRole.CASHIER, BarRole.MANAGER, BarRole.ADMIN, BarRole.OWNER)


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

async def get_user_bars(user_id: int) -> list:
    """Get all bars a user has access to with their roles."""
    from ..bars_and_restaurants.models.relational_models import Bar
    
    staff_query = """
        SELECT bs.bar_id, bs.role, bs.is_active, b.name as bar_name
        FROM bar_staff bs
        JOIN bars b ON bs.bar_id = b.id
        WHERE bs.user_id = :user_id AND bs.is_active = true
    """
    
    results = await database.fetch_all(staff_query, {"user_id": user_id})
    
    return [
        {
            "bar_id": r["bar_id"],
            "bar_name": r["bar_name"],
            "role": r["role"],
        }
        for r in results
    ]


async def add_user_to_bar(
    user_id: int, 
    bar_id: int, 
    role: BarRole,
    invited_by_id: int = None
) -> dict:
    """Add a user to a bar's staff with the specified role."""
    # Check if already exists
    existing = await database.fetch_one(
        BarStaff.__table__.select().where(
            (BarStaff.user_id == user_id) & (BarStaff.bar_id == bar_id)
        )
    )
    
    if existing:
        # Update existing record
        await database.execute(
            BarStaff.__table__.update()
            .where(BarStaff.id == existing["id"])
            .values(role=role.value, is_active=True, updated_at=datetime.now(timezone.utc))
        )
        return {"action": "updated", "role": role.value}
    
    # Create new record
    staff_data = {
        "user_id": user_id,
        "bar_id": bar_id,
        "role": role.value,
        "is_active": True,
        "invited_by_id": invited_by_id,
        "accepted_at": datetime.now(timezone.utc),
    }
    
    await database.execute(BarStaff.__table__.insert().values(**staff_data))
    
    # Update user profile to business type if not already
    profile = await database.fetch_one(
        UserProfile.__table__.select().where(UserProfile.user_id == user_id)
    )
    
    if profile:
        if profile["user_type"] != UserType.BUSINESS.value:
            await database.execute(
                UserProfile.__table__.update()
                .where(UserProfile.user_id == user_id)
                .values(user_type=UserType.BUSINESS.value)
            )
    else:
        # Create profile
        await database.execute(
            UserProfile.__table__.insert().values(
                user_id=user_id,
                user_type=UserType.BUSINESS.value
            )
        )
    
    return {"action": "created", "role": role.value}


async def remove_user_from_bar(user_id: int, bar_id: int) -> bool:
    """Remove a user from a bar's staff."""
    result = await database.execute(
        BarStaff.__table__.update()
        .where((BarStaff.user_id == user_id) & (BarStaff.bar_id == bar_id))
        .values(is_active=False, updated_at=datetime.now(timezone.utc))
    )
    return result > 0
