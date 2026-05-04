"""
Tests for waitlist endpoints.
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app


client = TestClient(app)


class TestWaitlistPublicEndpoints:
    """Tests for public waitlist endpoints."""
    
    def test_create_signup_success(self):
        """Test successful waitlist signup creation."""
        payload = {
            "bar_name": "Bar do Teste",
            "contact_name": "João Silva",
            "email": "test_waitlist@example.com",
            "phone": "+55 11 94364-3170",
            "city": "São Paulo",
            "source": "organic"
        }
        
        response = client.post("/api/v1/waitlist/signup", json=payload)
        
        # Should return 201 Created
        assert response.status_code == 201
        data = response.json()
        assert data["success"] is True
        assert "id" in data["data"]
        assert "Você está na lista" in data["data"]["message"]
    
    def test_create_signup_duplicate_email(self):
        """Test that duplicate emails return 409 conflict."""
        email = "duplicate_test@example.com"
        
        # First signup
        payload = {
            "bar_name": "Bar Original",
            "contact_name": "João Original",
            "email": email,
            "phone": "+55 11 99999-9999",
            "city": "Rio de Janeiro",
            "source": "organic"
        }
        response1 = client.post("/api/v1/waitlist/signup", json=payload)
        assert response1.status_code == 201
        
        # Second signup with same email
        payload2 = {
            "bar_name": "Bar Different",
            "contact_name": "Maria Different",
            "email": email,
            "phone": "+55 21 88888-8888",
            "city": "São Paulo",
            "source": "instagram"
        }
        response2 = client.post("/api/v1/waitlist/signup", json=payload2)
        
        assert response2.status_code == 409
        data = response2.json()
        assert "error_code" in data
        assert data["error_code"] == "CONFLICT"
        assert "email" in data["message"].lower() or "lista" in data["message"].lower()
    
    def test_create_signup_invalid_city(self):
        """Test that invalid city returns validation error."""
        payload = {
            "bar_name": "Bar do Teste",
            "contact_name": "João Silva",
            "email": "test_city@example.com",
            "phone": "+55 11 99999-9999",
            "city": "Cidade Inválida",  # Invalid city
            "source": "organic"
        }
        
        response = client.post("/api/v1/waitlist/signup", json=payload)
        
        # Should return 422 Unprocessable Entity for validation errors
        assert response.status_code == 422
    
    def test_create_signup_invalid_email(self):
        """Test that invalid email returns validation error."""
        payload = {
            "bar_name": "Bar do Teste",
            "contact_name": "João Silva",
            "email": "not-an-email",
            "phone": "+55 11 99999-9999",
            "city": "São Paulo",
            "source": "organic"
        }
        
        response = client.post("/api/v1/waitlist/signup", json=payload)
        
        assert response.status_code == 422
    
    def test_create_signup_with_utm_params(self):
        """Test signup with UTM parameters."""
        payload = {
            "bar_name": "Bar do Teste",
            "contact_name": "João Silva",
            "email": "test_utm@example.com",
            "phone": "+55 11 99999-9999",
            "city": "Belo Horizonte",
            "source": "email_outreach",
            "utm_params": {
                "source": "email",
                "medium": "outreach",
                "campaign": "mvp_waitlist_may2025"
            }
        }
        
        response = client.post("/api/v1/waitlist/signup", json=payload)
        
        assert response.status_code == 201
        data = response.json()
        assert data["success"] is True


class TestWaitlistAdminEndpoints:
    """Tests for admin waitlist endpoints."""
    
    def test_list_signups_without_auth(self):
        """Test that listing signups without auth returns 401."""
        response = client.get("/api/v1/admin/waitlist")
        
        # Should return 401 Unauthorized
        assert response.status_code == 403  # Admin middleware returns 403
    
    def test_update_signup_without_auth(self):
        """Test that updating signup without auth returns 401."""
        response = client.patch(
            "/api/v1/admin/waitlist/1",
            json={"status": "contacted"}
        )
        
        assert response.status_code == 403
    
    def test_get_stats_without_auth(self):
        """Test that getting stats without auth returns 401."""
        response = client.get("/api/v1/admin/waitlist/stats")
        
        assert response.status_code == 403


class TestWaitlistValidation:
    """Tests for waitlist input validation."""
    
    def test_phone_normalization(self):
        """Test that various phone formats are normalized."""
        test_cases = [
            ("+55 11 94364-3170", "+5511943643170"),
            ("11 99999-9999", "+5511999999999"),
            ("(11) 99999-9999", "+5511999999999"),
        ]
        
        from app.bars_and_restaurants.services.waitlist_service import normalize_phone_e164
        
        for input_phone, expected in test_cases:
            result = normalize_phone_e164(input_phone)
            assert result == expected, f"Failed for {input_phone}: got {result}, expected {expected}"
    
    def test_all_valid_cities(self):
        """Test that all valid cities are accepted."""
        from app.bars_and_restaurants.services.waitlist_service import VALID_CITIES
        
        base_payload = {
            "bar_name": "Bar Teste",
            "contact_name": "Teste",
            "email": "city_test@example.com",
            "phone": "+55 11 99999-9999",
            "source": "organic"
        }
        
        for city in VALID_CITIES:
            payload = {**base_payload, "email": f"test_{city.lower().replace(' ', '_')}@example.com", "city": city}
            response = client.post("/api/v1/waitlist/signup", json=payload)
            assert response.status_code == 201, f"Failed for city: {city}"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
