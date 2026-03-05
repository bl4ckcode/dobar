import pytest
import hmac
import hashlib
import json
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from unittest.mock import patch, AsyncMock

from dobar_payment.api.app import create_app

@pytest.fixture
def client_noauth():
    app = create_app(enable_auth=False)
    return TestClient(app)

def test_stone_webhook_valid_signature_success(client_noauth):
    payload = {
        "id": "wh_123",
        "type": "charge.paid",
        "created_at": "2026-03-05T00:00:00Z",
        "data": {
            "id": "ch_456",
            "amount": 1000,
            "status": "paid",
            "order": {
                "code": "order_789"
            }
        }
    }
    
    payload_bytes = json.dumps(payload).encode()
    
    secret = "my_stone_secret"
    signature = hmac.new(
        secret.encode(),
        payload_bytes,
        hashlib.sha256
    ).hexdigest()
    
    headers = {
        "x-hub-signature": f"sha256={signature}"
    }

    with patch('os.getenv', side_effect=lambda k, d=None: "my_stone_secret" if "PAGARME" in k else d):
        with patch('httpx.AsyncClient.post', new_callable=AsyncMock) as mock_post:
            mock_post.return_value.status_code = 200
            
            response = client_noauth.post(
                "/webhooks/stone",
                content=payload_bytes,
                headers=headers
            )
            
            assert response.status_code == 200
            assert response.json()["status"] == "processed"
            
            # Check if backend was called properly
            mock_post.assert_called_once()
            called_url = mock_post.call_args[0][0]
            called_json = mock_post.call_args[1]["json"]
            
            assert called_url.endswith("/payments/webhook")
            assert called_json["event"] == "charge.paid"
            assert called_json["status"] == "succeeded"
            assert called_json["amount_cents"] == 1000
            assert called_json["order_id"] == "order_789"
            assert called_json["payment_id"] == "ch_456"

def test_stone_webhook_invalid_signature_fails(client_noauth):
    payload = {"type": "charge.paid"}
    payload_bytes = json.dumps(payload).encode()
    
    headers = {
        "x-hub-signature": "sha256=invalid_signature_123"
    }
    
    with patch('os.getenv', side_effect=lambda k, d=None: "my_stone_secret" if "PAGARME" in k else d):
        response = client_noauth.post(
            "/webhooks/stone",
            content=payload_bytes,
            headers=headers
        )
        
        assert response.status_code == 401
        assert response.json()["error_code"] == "UNAUTHORIZED"
