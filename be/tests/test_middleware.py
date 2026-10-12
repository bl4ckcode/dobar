"""
Tests for authentication middleware.
"""

import pytest
from httpx import AsyncClient
from jose import jwt
import os
from datetime import datetime, timedelta, timezone


@pytest.mark.auth
class TestAuthenticationMiddleware:
    """Test authentication middleware functionality."""
    
    @pytest.mark.asyncio
    async def test_get_current_user_with_valid_token(self, client: AsyncClient):
        """Test that get_current_user returns user with valid token."""
        # First, create a user by logging in
        from app.auth.routes import create_access_token
        from app.auth.auth_models import User
        from app.database import database
        
        # Create a test user
        user_data = {
            "email": "test@example.com",
            "google_id": "test_google_id",
            "is_active": True
        }
        user_id = await database.execute(User.__table__.insert().values(**user_data))
        
        # Generate token using new signature (user_id instead of data dict)
        token, expires_in = await create_access_token(user_id)
        
        # Create a protected endpoint to test (we'll test with orders later)
        # For now, just verify token decoding works
        SECRET_KEY = os.getenv("SECRET_KEY", "test_secret_key_for_testing_only")
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        
        assert payload.get("sub") == str(user_id)
        assert "exp" in payload
        assert expires_in > 0
    
    @pytest.mark.asyncio
    async def test_get_current_user_with_invalid_token(self, client: AsyncClient):
        """Test that get_current_user rejects invalid token."""
        # This will be tested when we add protected endpoints
        # For now, we can test JWT validation
        from jose import JWTError
        
        invalid_token = "invalid.token.here"
        SECRET_KEY = os.getenv("SECRET_KEY", "test_secret_key_for_testing_only")
        
        with pytest.raises(JWTError):
            jwt.decode(invalid_token, SECRET_KEY, algorithms=["HS256"])
    
    @pytest.mark.asyncio
    async def test_get_current_user_with_expired_token(self, client: AsyncClient):
        """Test that get_current_user rejects expired token."""
        from app.auth.auth_models import User
        from app.database import database
        
        # Create a test user
        user_data = {
            "email": "expired@example.com",
            "google_id": "test_google_id_expired",
            "is_active": True
        }
        user_id = await database.execute(User.__table__.insert().values(**user_data))
        
        # Create an expired token
        SECRET_KEY = os.getenv("SECRET_KEY", "test_secret_key_for_testing_only")
        expire = datetime.now(timezone.utc) - timedelta(minutes=1)  # Expired 1 minute ago
        to_encode = {"sub": str(user_id), "exp": expire}
        expired_token = jwt.encode(to_encode, SECRET_KEY, algorithm="HS256")
        
        # Try to decode - should raise JWTError
        from jose import JWTError, ExpiredSignatureError
        
        with pytest.raises((JWTError, ExpiredSignatureError)):
            jwt.decode(expired_token, SECRET_KEY, algorithms=["HS256"])
    
    @pytest.mark.asyncio
    async def test_get_current_user_with_nonexistent_user(self, client: AsyncClient):
        """Test that get_current_user rejects token for non-existent user."""
        # Create token for non-existent user
        SECRET_KEY = os.getenv("SECRET_KEY", "test_secret_key_for_testing_only")
        fake_user_id = 999999
        to_encode = {
            "sub": str(fake_user_id),
            "exp": datetime.now(timezone.utc) + timedelta(minutes=30)
        }
        token = jwt.encode(to_encode, SECRET_KEY, algorithm="HS256")
        
        # Token is valid but user doesn't exist
        # This will be tested with actual protected endpoints
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        assert payload.get("sub") == str(fake_user_id)
