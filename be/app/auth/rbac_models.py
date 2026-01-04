"""
🔐 Role-Based Access Control (RBAC) Models

This module defines the role and permission system for BARZ.
It supports two main user experiences in ONE app:

1. BAR CLIENTS (Regular Users)
   - Browse bars, order drinks, track orders, earn cashback

2. BAR OWNERS & STAFF
   - Owner: Full control over their bar(s)
   - Admin: Manage menus, staff, billing, promotions
   - Cashier: Process orders, manage queue
   - Staff: Limited access (view-only)

Architecture:
- Users can have MULTIPLE roles (e.g., owner of Bar A, cashier at Bar B)
- Roles are BAR-SPECIFIC (a user's role at one bar doesn't affect another)
- Permissions are granular and role-based
"""

from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime, Enum, Table
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from ..database import Base


# =============================================================================
# ENUMS
# =============================================================================

class UserType(str, enum.Enum):
    """High-level user type for quick differentiation."""
    CLIENT = "client"           # Regular bar-goer
    BUSINESS = "business"       # Bar owner/staff


class BarRole(str, enum.Enum):
    """
    Roles a user can have at a specific bar.
    Hierarchy: OWNER > ADMIN > MANAGER > CASHIER > STAFF
    """
    OWNER = "owner"         # Full control, can delete bar
    ADMIN = "admin"         # Full control except ownership transfer
    MANAGER = "manager"     # Manage orders, staff schedules, inventory
    CASHIER = "cashier"     # Process orders, handle payments
    STAFF = "staff"         # View-only, receive notifications


class Permission(str, enum.Enum):
    """
    Granular permissions for bar operations.
    Used to check specific actions regardless of role.
    """
    # Bar Management
    BAR_VIEW = "bar:view"
    BAR_EDIT = "bar:edit"
    BAR_DELETE = "bar:delete"
    
    # Menu Management
    MENU_VIEW = "menu:view"
    MENU_EDIT = "menu:edit"
    MENU_CREATE = "menu:create"
    MENU_DELETE = "menu:delete"
    
    # Order Management
    ORDER_VIEW = "order:view"
    ORDER_PROCESS = "order:process"      # Confirm, prepare, ready
    ORDER_CANCEL = "order:cancel"
    ORDER_REFUND = "order:refund"
    
    # Staff Management
    STAFF_VIEW = "staff:view"
    STAFF_MANAGE = "staff:manage"        # Add/remove/edit staff
    
    # Financial
    BILLING_VIEW = "billing:view"
    BILLING_MANAGE = "billing:manage"
    PAYOUT_REQUEST = "payout:request"
    
    # Promotions
    PROMO_VIEW = "promo:view"
    PROMO_MANAGE = "promo:manage"
    
    # Analytics
    ANALYTICS_VIEW = "analytics:view"
    ANALYTICS_EXPORT = "analytics:export"
    
    # Advertising
    ADS_VIEW = "ads:view"
    ADS_MANAGE = "ads:manage"


# Role -> Permissions mapping
ROLE_PERMISSIONS = {
    BarRole.OWNER: [p for p in Permission],  # All permissions
    BarRole.ADMIN: [
        Permission.BAR_VIEW, Permission.BAR_EDIT,
        Permission.MENU_VIEW, Permission.MENU_EDIT, Permission.MENU_CREATE, Permission.MENU_DELETE,
        Permission.ORDER_VIEW, Permission.ORDER_PROCESS, Permission.ORDER_CANCEL, Permission.ORDER_REFUND,
        Permission.STAFF_VIEW, Permission.STAFF_MANAGE,
        Permission.BILLING_VIEW, Permission.BILLING_MANAGE,
        Permission.PROMO_VIEW, Permission.PROMO_MANAGE,
        Permission.ANALYTICS_VIEW, Permission.ANALYTICS_EXPORT,
        Permission.ADS_VIEW, Permission.ADS_MANAGE,
    ],
    BarRole.MANAGER: [
        Permission.BAR_VIEW,
        Permission.MENU_VIEW, Permission.MENU_EDIT,
        Permission.ORDER_VIEW, Permission.ORDER_PROCESS, Permission.ORDER_CANCEL,
        Permission.STAFF_VIEW,
        Permission.PROMO_VIEW,
        Permission.ANALYTICS_VIEW,
    ],
    BarRole.CASHIER: [
        Permission.BAR_VIEW,
        Permission.MENU_VIEW,
        Permission.ORDER_VIEW, Permission.ORDER_PROCESS,
        Permission.PROMO_VIEW,
    ],
    BarRole.STAFF: [
        Permission.BAR_VIEW,
        Permission.MENU_VIEW,
        Permission.ORDER_VIEW,
        Permission.PROMO_VIEW,
    ],
}


# =============================================================================
# MODELS
# =============================================================================

class UserProfile(Base):
    __tablename__ = "user_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, index=True)
    
    display_name = Column(String(100), nullable=True)
    avatar_url = Column(String(500), nullable=True)
    
    user_type = Column(String(20), default=UserType.CLIENT.value, index=True)
    
    business_name = Column(String(200), nullable=True)
    business_email = Column(String(255), nullable=True)
    business_phone = Column(String(20), nullable=True)
    tax_id = Column(String(20), nullable=True)
    
    preferred_language = Column(String(5), default="pt-BR")
    notification_enabled = Column(Boolean, default=True)
    
    terms_accepted = Column(Boolean, default=False)
    terms_accepted_at = Column(DateTime, nullable=True)
    privacy_accepted = Column(Boolean, default=False)
    privacy_accepted_at = Column(DateTime, nullable=True)
    
    fcm_token = Column(String(500), nullable=True)
    fcm_token_updated_at = Column(DateTime, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class BarStaff(Base):
    """
    Represents a user's role at a specific bar.
    A user can have different roles at different bars.
    
    Example:
    - João is OWNER of "Bar do Zé"
    - João is also CASHIER at his friend's "Boteco da Esquina"
    """
    __tablename__ = "bar_staff"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    bar_id = Column(Integer, ForeignKey("bars.id"), index=True)
    
    # Role at this bar
    role = Column(String(20), nullable=False, index=True)
    
    # Custom permissions (override role defaults)
    custom_permissions = Column(String(1000), nullable=True)  # JSON array of Permission values
    
    # Staff info
    nickname = Column(String(50), nullable=True)  # Display name at this bar
    employee_id = Column(String(50), nullable=True)  # Internal employee ID
    
    # Status
    is_active = Column(Boolean, default=True, index=True)
    invited_at = Column(DateTime, default=datetime.utcnow)
    accepted_at = Column(DateTime, nullable=True)
    
    # Who invited this person
    invited_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class StaffInvitation(Base):
    """
    Pending invitation for someone to join a bar's staff.
    Can be sent via email or phone.
    """
    __tablename__ = "staff_invitations"

    id = Column(Integer, primary_key=True, index=True)
    bar_id = Column(Integer, ForeignKey("bars.id"), index=True)
    
    # Invitation target
    email = Column(String(255), nullable=True, index=True)
    phone = Column(String(20), nullable=True, index=True)
    
    # Role being offered
    role = Column(String(20), nullable=False)
    
    # Invitation code (for accepting)
    invitation_code = Column(String(50), unique=True, index=True)
    
    # Status
    status = Column(String(20), default="pending", index=True)  # pending, accepted, expired, revoked
    expires_at = Column(DateTime, nullable=False)
    
    # Who sent it
    invited_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    accepted_at = Column(DateTime, nullable=True)


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def get_permissions_for_role(role: BarRole) -> list[Permission]:
    """Get all permissions for a given role."""
    return ROLE_PERMISSIONS.get(role, [])


def has_permission(role: BarRole, permission: Permission, custom_permissions: list = None) -> bool:
    """
    Check if a role has a specific permission.
    Custom permissions can override role defaults.
    """
    if custom_permissions and permission.value in custom_permissions:
        return True
    return permission in ROLE_PERMISSIONS.get(role, [])


def is_bar_owner_or_admin(role: BarRole) -> bool:
    """Check if role has full management access."""
    return role in [BarRole.OWNER, BarRole.ADMIN]


def can_manage_staff(role: BarRole) -> bool:
    """Check if role can add/remove staff."""
    return role in [BarRole.OWNER, BarRole.ADMIN]


def can_process_orders(role: BarRole) -> bool:
    """Check if role can process orders (cashier view)."""
    return role in [BarRole.OWNER, BarRole.ADMIN, BarRole.MANAGER, BarRole.CASHIER]
