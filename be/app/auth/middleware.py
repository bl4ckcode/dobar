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


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> User:
    """
    Dependency to get the current authenticated user from JWT token.
    
    Args:
        credentials: HTTP Authorization credentials containing the Bearer token
        
    Returns:
        User: The authenticated user
        
    Raises:
        APIError: If token is invalid, expired, or user not found
    """
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        
        if user_id is None:
            raise APIError.invalid_token()
            
    except JWTError:
        raise APIError.invalid_token()
    
    # Fetch user from database
    query = User.__table__.select().where(User.id == int(user_id))
    user = await database.fetch_one(query)
    
    if user is None:
        raise APIError.user_not_found()
        
    return user


async def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Dependency to get the current authenticated and active user.
    
    Args:
        current_user: The current user from get_current_user dependency
        
    Returns:
        User: The authenticated and active user
        
    Raises:
        APIError: If user is inactive
    """
    if not current_user["is_active"]:
        raise APIError.forbidden("User account is inactive")
    return current_user


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(
        HTTPBearer(auto_error=False)
    )
) -> Optional[User]:
    """
    Dependency to optionally get the current user.
    Returns None if no valid token is provided.
    Useful for endpoints that have different behavior for authenticated vs anonymous users.
    
    Args:
        credentials: Optional HTTP Authorization credentials
        
    Returns:
        Optional[User]: The authenticated user or None
    """
    if credentials is None:
        return None
    
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        
        if user_id is None:
            return None
            
        # Fetch user from database
        query = User.__table__.select().where(User.id == int(user_id))
        user = await database.fetch_one(query)
        
        return user
        
    except JWTError:
        return None


def verify_user_owns_resource(user: User, resource_user_id: int) -> bool:
    """
    Helper function to verify that a user owns a specific resource.
    
    Args:
        user: The current user
        resource_user_id: The user_id of the resource owner
        
    Returns:
        bool: True if user owns the resource
        
    Raises:
        APIError: If user does not own the resource
    """
    if user["id"] != resource_user_id:
        raise APIError.forbidden("Not authorized to access this resource")
    return True
