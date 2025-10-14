import pytest
from httpx import AsyncClient
from unittest.mock import patch, MagicMock


@pytest.mark.auth
class TestPhoneAuthentication:
    """Test phone authentication endpoints."""
    
    @pytest.mark.asyncio
    async def test_phone_login_creates_new_user(self, client: AsyncClient, mock_firebase_token):
        """Test that phone login creates a new user if doesn't exist."""
        # Mock Firebase token verification
        with patch("app.auth.routes.auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            
            response = await client.post(
                "/auth/phone",
                headers={"Authorization": "Bearer mock_firebase_token"}
            )
        
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
    
    @pytest.mark.asyncio
    async def test_phone_login_returns_existing_user(self, client: AsyncClient, mock_firebase_token):
        """Test that phone login returns existing user if already exists."""
        # Mock Firebase token verification
        with patch("app.auth.routes.auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            
            # First login - creates user
            response1 = await client.post(
                "/auth/phone",
                headers={"Authorization": "Bearer mock_firebase_token"}
            )
            
            # Second login - returns same user
            response2 = await client.post(
                "/auth/phone",
                headers={"Authorization": "Bearer mock_firebase_token"}
            )
        
        assert response1.status_code == 200
        assert response2.status_code == 200
        
        # Both should return valid tokens
        assert "access_token" in response1.json()
        assert "access_token" in response2.json()
    
    @pytest.mark.asyncio
    async def test_phone_login_invalid_token(self, client: AsyncClient):
        """Test that phone login fails with invalid Firebase token."""
        with patch("app.auth.routes.auth.verify_id_token") as mock_verify:
            mock_verify.side_effect = Exception("Invalid token")
            
            response = await client.post(
                "/auth/phone",
                headers={"Authorization": "Bearer invalid_token"}
            )
        
        assert response.status_code == 401


@pytest.mark.auth
class TestGoogleAuthentication:
    """Test Google OAuth authentication."""
    
    @pytest.mark.asyncio
    async def test_google_login_success(self, client: AsyncClient, sample_google_login):
        """Test successful Google login."""
        response = await client.post("/auth/google", json=sample_google_login)
        
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
    
    @pytest.mark.asyncio
    async def test_google_login_creates_user(self, client: AsyncClient, sample_google_login):
        """Test that Google login creates a new user."""
        response = await client.post("/auth/google", json=sample_google_login)
        
        assert response.status_code == 200
        # User should be created in database
    
    @pytest.mark.asyncio
    async def test_google_login_existing_user(self, client: AsyncClient, sample_google_login):
        """Test Google login with existing user."""
        # First login
        response1 = await client.post("/auth/google", json=sample_google_login)
        token1 = response1.json()["access_token"]
        
        # Second login
        response2 = await client.post("/auth/google", json=sample_google_login)
        token2 = response2.json()["access_token"]
        
        assert response1.status_code == 200
        assert response2.status_code == 200
        # Both should return valid tokens (may be different)
        assert token1
        assert token2
    
    @pytest.mark.asyncio
    async def test_google_login_missing_fields(self, client: AsyncClient):
        """Test Google login with missing required fields."""
        response = await client.post("/auth/google", json={})
        
        assert response.status_code == 422  # Validation error


@pytest.mark.auth
class TestAppleAuthentication:
    """Test Apple Sign-In authentication."""
    
    @pytest.mark.asyncio
    async def test_apple_login_success(self, client: AsyncClient, sample_apple_login):
        """Test successful Apple login."""
        response = await client.post("/auth/apple", json=sample_apple_login)
        
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
    
    @pytest.mark.asyncio
    async def test_apple_login_creates_user(self, client: AsyncClient, sample_apple_login):
        """Test that Apple login creates a new user."""
        response = await client.post("/auth/apple", json=sample_apple_login)
        
        assert response.status_code == 200
    
    @pytest.mark.asyncio
    async def test_apple_login_missing_fields(self, client: AsyncClient):
        """Test Apple login with missing required fields."""
        response = await client.post("/auth/apple", json={})
        
        assert response.status_code == 422  # Validation error


@pytest.mark.auth
class TestFacebookAuthentication:
    """Test Facebook OAuth authentication."""
    
    @pytest.mark.asyncio
    async def test_facebook_login_success(self, client: AsyncClient, sample_facebook_login):
        """Test successful Facebook login."""
        response = await client.post("/auth/facebook", json=sample_facebook_login)
        
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
    
    @pytest.mark.asyncio
    async def test_facebook_login_creates_user(self, client: AsyncClient, sample_facebook_login):
        """Test that Facebook login creates a new user."""
        response = await client.post("/auth/facebook", json=sample_facebook_login)
        
        assert response.status_code == 200
    
    @pytest.mark.asyncio
    async def test_facebook_login_missing_fields(self, client: AsyncClient):
        """Test Facebook login with missing required fields."""
        response = await client.post("/auth/facebook", json={})
        
        assert response.status_code == 422  # Validation error


@pytest.mark.auth
class TestJWTTokens:
    """Test JWT token generation and validation."""
    
    @pytest.mark.asyncio
    async def test_token_contains_user_id(self, client: AsyncClient, sample_google_login):
        """Test that generated token contains user ID."""
        from jose import jwt
        import os
        
        response = await client.post("/auth/google", json=sample_google_login)
        token = response.json()["access_token"]
        
        # Decode token
        SECRET_KEY = os.getenv("SECRET_KEY", "fallback-secret-key")
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        
        assert "sub" in payload  # User ID
        assert "exp" in payload  # Expiration
    
    @pytest.mark.asyncio
    async def test_token_expiration(self, client: AsyncClient, sample_google_login):
        """Test that token has proper expiration."""
        from jose import jwt
        import os
        from datetime import datetime, timezone
        
        response = await client.post("/auth/google", json=sample_google_login)
        token = response.json()["access_token"]
        
        # Decode token
        SECRET_KEY = os.getenv("SECRET_KEY", "fallback-secret-key")
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        
        exp = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
        now = datetime.now(timezone.utc)
        
        # Token should expire in the future
        assert exp > now
