import pytest
from httpx import AsyncClient
from unittest.mock import patch, MagicMock, AsyncMock


@pytest.mark.auth
class TestPhoneAuthentication:
    
    @pytest.mark.asyncio
    async def test_phone_login_creates_new_user(self, client: AsyncClient, mock_firebase_token):
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            
            response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_firebase_token"}
            )
        
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert "expires_in" in data
        assert data["token_type"] == "bearer"
        assert data["is_new_user"] == True
    
    @pytest.mark.asyncio
    async def test_phone_login_returns_existing_user(self, client: AsyncClient, mock_firebase_token):
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            
            response1 = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_firebase_token"}
            )
            
            response2 = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_firebase_token"}
            )
        
        assert response1.status_code == 200
        assert response2.status_code == 200
        assert response1.json()["is_new_user"] == True
        assert response2.json()["is_new_user"] == False
    
    @pytest.mark.asyncio
    async def test_phone_login_invalid_token(self, client: AsyncClient):
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.side_effect = Exception("Invalid token")
            
            response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer invalid_token"}
            )
        
        assert response.status_code == 401


@pytest.mark.auth
class TestGoogleAuthentication:
    
    @pytest.mark.asyncio
    async def test_google_login_success(self, client: AsyncClient, sample_google_login):
        with patch("app.auth.routes.verify_google_token", new_callable=AsyncMock) as mock_verify:
            mock_verify.return_value = {
                "sub": "google_123",
                "email": "google@test.com",
                "name": "Google User",
                "provider": "google"
            }
            
            response = await client.post("/auth/google-login", json=sample_google_login)
        
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert "expires_in" in data
        assert data["token_type"] == "bearer"
    
    @pytest.mark.asyncio
    async def test_google_login_creates_user(self, client: AsyncClient, sample_google_login):
        with patch("app.auth.routes.verify_google_token", new_callable=AsyncMock) as mock_verify:
            mock_verify.return_value = {
                "sub": "google_new_user_456",
                "email": "newgoogle@test.com",
                "name": "New Google User",
                "provider": "google"
            }
            
            response = await client.post("/auth/google-login", json=sample_google_login)
        
        assert response.status_code == 200
        assert response.json()["is_new_user"] == True
    
    @pytest.mark.asyncio
    async def test_google_login_existing_user(self, client: AsyncClient, sample_google_login):
        with patch("app.auth.routes.verify_google_token", new_callable=AsyncMock) as mock_verify:
            mock_verify.return_value = {
                "sub": "google_existing_789",
                "email": "existing@test.com",
                "name": "Existing User",
                "provider": "google"
            }
            
            response1 = await client.post("/auth/google-login", json=sample_google_login)
            response2 = await client.post("/auth/google-login", json=sample_google_login)
        
        assert response1.status_code == 200
        assert response2.status_code == 200
        assert response1.json()["is_new_user"] == True
        assert response2.json()["is_new_user"] == False
    
    @pytest.mark.asyncio
    async def test_google_login_missing_fields(self, client: AsyncClient):
        response = await client.post("/auth/google-login", json={})
        assert response.status_code == 422


@pytest.mark.auth
class TestAppleAuthentication:
    
    @pytest.mark.asyncio
    async def test_apple_login_success(self, client: AsyncClient, sample_apple_login):
        with patch("app.auth.routes.verify_apple_token", new_callable=AsyncMock) as mock_verify:
            mock_verify.return_value = {
                "sub": "apple_123",
                "email": "apple@test.com",
                "name": None,
                "provider": "apple"
            }
            
            response = await client.post("/auth/apple-login", json=sample_apple_login)
        
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert "expires_in" in data
        assert data["token_type"] == "bearer"
    
    @pytest.mark.asyncio
    async def test_apple_login_creates_user(self, client: AsyncClient, sample_apple_login):
        with patch("app.auth.routes.verify_apple_token", new_callable=AsyncMock) as mock_verify:
            mock_verify.return_value = {
                "sub": "apple_new_456",
                "email": "newapple@test.com",
                "name": None,
                "provider": "apple"
            }
            
            response = await client.post("/auth/apple-login", json=sample_apple_login)
        
        assert response.status_code == 200
        assert response.json()["is_new_user"] == True
    
    @pytest.mark.asyncio
    async def test_apple_login_missing_fields(self, client: AsyncClient):
        response = await client.post("/auth/apple-login", json={})
        assert response.status_code == 422


@pytest.mark.auth
class TestRefreshTokens:
    
    @pytest.mark.asyncio
    async def test_refresh_token_success(self, client: AsyncClient, mock_firebase_token):
        """Test refreshing an access token with a valid refresh token"""
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            
            # First login to get tokens
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_firebase_token"}
            )
        
        assert login_response.status_code == 200
        original_data = login_response.json()
        refresh_token = original_data["refresh_token"]
        
        # Now use refresh token to get new access token
        refresh_response = await client.post(
            "/auth/refresh",
            json={"refresh_token": refresh_token}
        )
        
        assert refresh_response.status_code == 200
        data = refresh_response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert "expires_in" in data
        # Refresh token should be the same (not rotated)
        assert data["refresh_token"] == refresh_token
    
    @pytest.mark.asyncio
    async def test_refresh_token_invalid(self, client: AsyncClient):
        """Test that invalid refresh token returns 401"""
        response = await client.post(
            "/auth/refresh",
            json={"refresh_token": "invalid_token_123"}
        )
        
        assert response.status_code == 401
    
    @pytest.mark.asyncio
    async def test_logout_revokes_refresh_token(self, client: AsyncClient, mock_firebase_token):
        """Test that logout revokes the refresh token"""
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            
            # First login
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_firebase_token"}
            )
        
        refresh_token = login_response.json()["refresh_token"]
        
        # Logout with refresh token
        logout_response = await client.post(
            "/auth/logout",
            json={"refresh_token": refresh_token}
        )
        
        assert logout_response.status_code == 200
        
        # Try to use the revoked refresh token
        refresh_response = await client.post(
            "/auth/refresh",
            json={"refresh_token": refresh_token}
        )
        
        assert refresh_response.status_code == 401


@pytest.mark.auth
class TestTokenExpiration:
    
    @pytest.mark.asyncio
    async def test_google_login_with_custom_expiration(self, client: AsyncClient):
        """Test that FE can send token_expiration for longer sessions"""
        import time
        
        # Set expiration to 60 days from now
        custom_expiration = int(time.time()) + (60 * 24 * 60 * 60)
        
        with patch("app.auth.routes.verify_google_token", new_callable=AsyncMock) as mock_verify:
            mock_verify.return_value = {
                "sub": "google_custom_exp",
                "email": "custom@test.com",
                "name": "Custom Exp User",
                "provider": "google"
            }
            
            response = await client.post(
                "/auth/google-login",
                json={
                    "id_token": "mock_google_token",
                    "email": "custom@test.com",
                    "token_expiration": custom_expiration
                }
            )
        
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data


@pytest.mark.auth
class TestJWTTokens:
    
    @pytest.mark.asyncio
    async def test_token_contains_user_id(self, client: AsyncClient, sample_google_login):
        from jose import jwt
        import os
        
        with patch("app.auth.routes.verify_google_token", new_callable=AsyncMock) as mock_verify:
            mock_verify.return_value = {
                "sub": "google_jwt_test",
                "email": "jwt@test.com",
                "name": "JWT User",
                "provider": "google"
            }
            
            response = await client.post("/auth/google-login", json=sample_google_login)
        
        token = response.json()["access_token"]
        SECRET_KEY = os.getenv("SECRET_KEY", "fallback-secret-key")
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        
        assert "sub" in payload
        assert "exp" in payload
    
    @pytest.mark.asyncio
    async def test_token_expiration(self, client: AsyncClient, sample_google_login):
        from jose import jwt
        import os
        from datetime import datetime, timezone
        
        with patch("app.auth.routes.verify_google_token", new_callable=AsyncMock) as mock_verify:
            mock_verify.return_value = {
                "sub": "google_exp_test",
                "email": "exp@test.com",
                "name": "Exp User",
                "provider": "google"
            }
            
            response = await client.post("/auth/google-login", json=sample_google_login)
        
        token = response.json()["access_token"]
        SECRET_KEY = os.getenv("SECRET_KEY", "fallback-secret-key")
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        
        exp = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
        now = datetime.now(timezone.utc)
        
        assert exp > now


@pytest.mark.auth
class TestProfileEndpoints:
    """
    Tests for /me/profile endpoints.
    These tests verify that the profile CRUD operations work correctly.
    """
    
    @pytest.mark.asyncio
    async def test_get_profile(self, client: AsyncClient, mock_firebase_token):
        """Test getting user profile after login."""
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )
        
        assert login_response.status_code == 200
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        response = await client.get("/me/profile", headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert "display_name" in data
        assert "terms_accepted" in data
        assert "privacy_accepted" in data
        assert "user_type" in data
    
    @pytest.mark.asyncio
    async def test_update_profile(self, client: AsyncClient, mock_firebase_token):
        """Test updating user profile display name."""
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )
        
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        response = await client.put(
            "/me/profile",
            headers=headers,
            json={"display_name": "Updated Name"}
        )
        
        assert response.status_code == 200
        assert response.json()["display_name"] == "Updated Name"
    
    @pytest.mark.asyncio
    async def test_accept_terms(self, client: AsyncClient, mock_firebase_token):
        """Test accepting terms of service."""
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )
        
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        response = await client.post("/me/accept-terms", headers=headers)
        
        assert response.status_code == 200
        assert response.json()["terms_accepted"] == True
    
    @pytest.mark.asyncio
    async def test_accept_privacy(self, client: AsyncClient, mock_firebase_token):
        """Test accepting privacy policy."""
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )
        
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        response = await client.post("/me/accept-privacy", headers=headers)
        
        assert response.status_code == 200
        assert response.json()["privacy_accepted"] == True

    @pytest.mark.asyncio
    async def test_onboarding_client_brazil(self, client: AsyncClient, mock_firebase_token):
        """Test onboarding as a client in Brazil."""
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )
        
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        response = await client.post(
            "/me/onboarding",
            headers=headers,
            json={"user_type": "client", "country_code": "BR"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["user_type"] == "client"
        assert data["country_code"] == "BR"
    
    @pytest.mark.asyncio
    async def test_onboarding_business_argentina(self, client: AsyncClient, mock_firebase_token):
        """Test onboarding as a business owner in Argentina."""
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = {
                **mock_firebase_token,
                "uid": "ar_business_owner_uid",
                "phone_number": "+5491139865103"
            }
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )
        
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        response = await client.post(
            "/me/onboarding",
            headers=headers,
            json={"user_type": "business", "country_code": "AR"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["user_type"] == "business"
        assert data["country_code"] == "AR"
    
    @pytest.mark.asyncio
    async def test_onboarding_business_usa(self, client: AsyncClient, mock_firebase_token):
        """Test onboarding as a business owner in USA."""
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = {
                **mock_firebase_token,
                "uid": "us_business_owner_uid",
                "phone_number": "+16143752923"
            }
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )
        
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        response = await client.post(
            "/me/onboarding",
            headers=headers,
            json={"user_type": "business", "country_code": "US"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["user_type"] == "business"
        assert data["country_code"] == "US"
    
    @pytest.mark.asyncio
    async def test_onboarding_invalid_country(self, client: AsyncClient, mock_firebase_token):
        """Test onboarding with unsupported country code."""
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )
        
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # ZZ is not a valid country code
        response = await client.post(
            "/me/onboarding",
            headers=headers,
            json={"user_type": "client", "country_code": "ZZ"}
        )
        
        assert response.status_code == 422  # Validation error
    
    @pytest.mark.asyncio
    async def test_get_available_countries(self, client: AsyncClient):
        """Test getting list of available countries (public endpoint)."""
        response = await client.get("/me/available-countries")
        
        assert response.status_code == 200
        data = response.json()
        assert "enabled_countries" in data
        assert "countries" in data
        assert "BR" in data["enabled_countries"]  # Brazil always enabled
        assert len(data["countries"]) > 0
    
    @pytest.mark.asyncio
    async def test_get_payment_gateway_brazil(self, client: AsyncClient, mock_firebase_token):
        """Test getting payment gateway for Brazil user."""
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )
        
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # First set country
        await client.post(
            "/me/onboarding",
            headers=headers,
            json={"user_type": "client", "country_code": "BR"}
        )
        
        response = await client.get("/me/payment-gateway", headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert data["gateway"] == "stone"
        assert data["country_code"] == "BR"
        assert "pix" in data["payment_methods"]


@pytest.mark.auth
class TestProfileSettingsEndpoints:

    @pytest.mark.asyncio
    async def test_update_profile_phone_and_avatar(self, client: AsyncClient, mock_firebase_token):
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )

        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        response = await client.put(
            "/me/profile",
            headers=headers,
            json={
                "phone_number": "+5531999990000",
                "avatar_url": "https://example.com/avatar.jpg"
            }
        )

        assert response.status_code == 200
        data = response.json()
        assert data["phone_number"] == "+5531999990000"
        assert data["avatar_url"] == "https://example.com/avatar.jpg"

    @pytest.mark.asyncio
    async def test_update_profile_phone_conflict(self, client: AsyncClient, mock_firebase_token):
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            login1 = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )

        token1 = login1.json()["access_token"]
        headers1 = {"Authorization": f"Bearer {token1}"}

        await client.put(
            "/me/profile",
            headers=headers1,
            json={"phone_number": "+5531888880000"}
        )

        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = {
                "uid": "second_user_uid",
                "phone_number": "+9999999999",
                "email": "second@example.com"
            }
            login2 = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )

        token2 = login2.json()["access_token"]
        headers2 = {"Authorization": f"Bearer {token2}"}

        response = await client.put(
            "/me/profile",
            headers=headers2,
            json={"phone_number": "+5531888880000"}
        )

        assert response.status_code == 409

    @pytest.mark.asyncio
    async def test_get_notification_preferences_defaults(self, client: AsyncClient, mock_firebase_token):
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )

        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        response = await client.get("/me/notification-preferences", headers=headers)

        assert response.status_code == 200
        data = response.json()
        assert data["push_notifications_enabled"] is True
        assert data["order_updates_enabled"] is True
        assert data["promotions_enabled"] is True

    @pytest.mark.asyncio
    async def test_update_notification_preferences(self, client: AsyncClient, mock_firebase_token):
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )

        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        response = await client.put(
            "/me/notification-preferences",
            headers=headers,
            json={
                "push_notifications_enabled": True,
                "order_updates_enabled": False,
                "promotions_enabled": False
            }
        )

        assert response.status_code == 200
        data = response.json()
        assert data["push_notifications_enabled"] is True
        assert data["order_updates_enabled"] is False
        assert data["promotions_enabled"] is False

        get_response = await client.get("/me/notification-preferences", headers=headers)
        assert get_response.json()["order_updates_enabled"] is False

    @pytest.mark.asyncio
    async def test_get_privacy_settings_defaults(self, client: AsyncClient, mock_firebase_token):
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )

        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        response = await client.get("/me/privacy-settings", headers=headers)

        assert response.status_code == 200
        data = response.json()
        assert data["data_sharing_enabled"] is False
        assert data["location_enabled"] is False

    @pytest.mark.asyncio
    async def test_update_privacy_settings(self, client: AsyncClient, mock_firebase_token):
        with patch("app.auth.routes.firebase_auth.verify_id_token") as mock_verify:
            mock_verify.return_value = mock_firebase_token
            login_response = await client.post(
                "/auth/phone-login",
                headers={"Authorization": "Bearer mock_token"}
            )

        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        response = await client.put(
            "/me/privacy-settings",
            headers=headers,
            json={
                "data_sharing_enabled": True,
                "location_enabled": True
            }
        )

        assert response.status_code == 200
        data = response.json()
        assert data["data_sharing_enabled"] is True
        assert data["location_enabled"] is True

        get_response = await client.get("/me/privacy-settings", headers=headers)
        assert get_response.json()["data_sharing_enabled"] is True

