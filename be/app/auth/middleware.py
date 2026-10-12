"""
Authentication middleware for JWT token verification.
Provides dependencies for protecting routes and getting the current user.
"""

from fastapi import Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from typing import Optional
import os

from app.errors import APIError
from ..database import database
from .auth_models import User

# Security scheme
security = HTTPBearer()

# Load SECRET_KEY from environment variables
SECRET_KEY = os.getenv("SECRET_KEY", "fallback-secret-key")
ALGORITHM = "HS256"


from .rbac_middleware import AuthUser, get_current_user as get_rbac_user, get_optional_user as get_rbac_optional_user

async def get_current_user(
    user: AuthUser = Depends(get_rbac_user)
) -> AuthUser:
    """Re-export rbac_middleware's get_current_user for backward compatibility."""
    return user


async def get_current_active_user(
    current_user: AuthUser = Depends(get_current_user)
) -> AuthUser:
    """
    Dependency to get the current authenticated and active user.
    """
    if not current_user.is_active:
        raise APIError.forbidden("User account is inactive")
    return current_user


async def get_optional_user(
    current_user: Optional[AuthUser] = Depends(get_rbac_optional_user)
) -> Optional[AuthUser]:
    """Dependency to optionally get the current user."""
    return current_user


def verify_user_owns_resource(user: AuthUser, resource_user_id: int) -> bool:
    """
    Helper function to verify that a user owns a specific resource.
    """
    if user.id != resource_user_id:
        raise APIError.forbidden("Not authorized to access this resource")
    return True
