import pytest
import sys
import os
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock
import uuid
import importlib.util

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def load_module(module_name, file_path):
    spec = importlib.util.spec_from_file_location(module_name, file_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module

schemas = load_module("api_schemas", os.path.join(BASE_DIR, "dobar_payment/api/schemas.py"))
middleware = load_module("api_middleware", os.path.join(BASE_DIR, "dobar_payment/api/middleware.py"))
dependencies = load_module("api_dependencies", os.path.join(BASE_DIR, "dobar_payment/api/dependencies.py"))


class TestAPISchemas:
    
    def test_charge_request_validation(self):
        request = schemas.ChargeRequestAPI(
            order_id="order_12345",
            user_id="user_67890",
            bar_id="bar_111",
            amount_cents=4550,
            currency="BRL",
            country="BR",
            payment_method=schemas.PaymentMethodAPI(
                type=schemas.PaymentMethodTypeAPI.CARD,
                token="tok_xxx",
            ),
            idempotency_key=str(uuid.uuid4()),
        )
        
        assert request.amount_cents == 4550
        assert request.currency == "BRL"
        assert request.payment_method.type == schemas.PaymentMethodTypeAPI.CARD
    
    def test_charge_request_invalid_amount(self):
        from pydantic import ValidationError
        
        with pytest.raises(ValidationError):
            schemas.ChargeRequestAPI(
                order_id="order_12345",
                user_id="user_67890",
                bar_id="bar_111",
                amount_cents=-10,
                currency="BRL",
                country="BR",
                payment_method=schemas.PaymentMethodAPI(type=schemas.PaymentMethodTypeAPI.CARD),
                idempotency_key="test",
            )
    
    def test_pix_generate_request(self):
        request = schemas.PixGenerateRequest(
            order_id="order_12345",
            amount_cents=10000,
            description="Mesa 5 - Bar do Zé",
        )
        
        assert request.amount_cents == 10000
        assert request.expiration_seconds == 3600
    
    def test_refund_request_validation(self):
        request = schemas.RefundRequestAPI(
            payment_id="pay_123",
            amount_cents=2500,
            reason="order_cancelled",
            idempotency_key=str(uuid.uuid4()),
        )
        
        assert request.payment_id == "pay_123"
        assert request.amount_cents == 2500


class TestAPIMiddleware:
    
    def test_request_context(self):
        ctx = middleware.RequestContext(
            request_id="req_123",
            api_version="2026-01-16",
            authenticated=True,
            service_name="barz-backend",
        )
        
        middleware.RequestContext.set_current(ctx)
        current = middleware.RequestContext.get_current()
        
        assert current is not None
        assert current.request_id == "req_123"
        assert current.authenticated is True
        
        middleware.RequestContext.clear()
        assert middleware.RequestContext.get_current() is None
    
    def test_error_code_mapping(self):
        assert middleware.error_code_to_http_status("PAYMENT_DECLINED") == 402
        assert middleware.error_code_to_http_status("INVALID_CARD") == 400
        assert middleware.error_code_to_http_status("NOT_FOUND") == 404
        assert middleware.error_code_to_http_status("RATE_LIMITED") == 429
        assert middleware.error_code_to_http_status("UNKNOWN_CODE") == 500
    
    def test_service_auth_missing(self):
        authenticated, service = middleware.verify_service_auth({})
        assert authenticated is False
        assert service is None
    
    def test_service_auth_valid(self):
        os.environ["DPE_SERVICE_SECRET"] = "test_secret"
        
        authenticated, service = middleware.verify_service_auth({"x-service-auth": "test_secret"})
        assert authenticated is True
        assert service == "barz-backend"
        
        del os.environ["DPE_SERVICE_SECRET"]
    
    def test_get_request_id(self):
        headers_with_id = {"x-request-id": "custom-id-123"}
        assert middleware.get_request_id(headers_with_id) == "custom-id-123"
        
        headers_without_id = {}
        request_id = middleware.get_request_id(headers_without_id)
        assert len(request_id) == 36
    
    def test_create_response_headers(self):
        ctx = middleware.RequestContext(
            request_id="req_456",
            api_version="2026-01-16",
        )
        
        headers = middleware.create_response_headers(ctx)
        
        assert headers["X-Request-ID"] == "req_456"
        assert headers["X-DPE-Version"] == "2026-01-16"
        assert "X-DPE-Engine-Version" in headers


class TestAPIDependencies:
    
    def test_payment_store_operations(self):
        store = dependencies.InMemoryPaymentStore()
        
        store.store_payment("pay_123", {
            "status": "succeeded",
            "amount_cents": 10000,
        })
        
        payment = store.get_payment("pay_123")
        assert payment is not None
        assert payment["status"] == "succeeded"
        
        store.update_payment("pay_123", {"status": "refunded"})
        payment = store.get_payment("pay_123")
        assert payment["status"] == "refunded"
        
        assert store.get_payment("nonexistent") is None
    
    def test_idempotency_store(self):
        store = dependencies.InMemoryPaymentStore()
        key = "idem_123"
        
        assert store.check_idempotency(key) is None
        
        store.store_idempotency(key, {"payment_id": "pay_456"})
        
        cached = store.check_idempotency(key)
        assert cached is not None
        assert cached["payment_id"] == "pay_456"
    
    def test_pix_store_operations(self):
        store = dependencies.InMemoryPaymentStore()
        
        store.store_pix("pix_123", {
            "status": "pending",
            "amount_cents": 5000,
            "brcode": "00020126...",
        })
        
        pix = store.get_pix("pix_123")
        assert pix is not None
        assert pix["status"] == "pending"
        
        store.update_pix("pix_123", {"status": "paid"})
        pix = store.get_pix("pix_123")
        assert pix["status"] == "paid"
    
    def test_gateway_registry(self):
        registry = dependencies.GatewayRegistry()
        mock_gateway = MagicMock()
        
        registry.register("stone", mock_gateway)
        
        assert registry.get("stone") is mock_gateway
        assert registry.get("unknown") is None
        
        result = registry.get_for_country("BR")
        assert result is not None
        assert result[0] == "stone"
    
    def test_gateway_country_mapping(self):
        registry = dependencies.GatewayRegistry()
        stone = MagicMock()
        stripe = MagicMock()
        paypal = MagicMock()
        
        registry.register("stone", stone)
        registry.register("stripe", stripe)
        registry.register("paypal", paypal)
        
        assert registry.get_for_country("BR")[0] == "stone"
        assert registry.get_for_country("MX")[0] == "stripe"
        assert registry.get_for_country("US")[0] == "paypal"
        assert registry.get_for_country("DE")[0] == "paypal"
    
    def test_gateway_health_status(self):
        registry = dependencies.GatewayRegistry()
        registry.register("stone", MagicMock())
        
        registry.set_health("stone", True)
        status = registry.get_health_status()
        assert status["stone"] is True
        
        registry.set_health("stone", False)
        status = registry.get_health_status()
        assert status["stone"] is False
    
    def test_generate_ids(self):
        payment_id = dependencies.generate_payment_id()
        assert payment_id.startswith("pay_")
        assert len(payment_id) == 20
        
        refund_id = dependencies.generate_refund_id()
        assert refund_id.startswith("ref_")
        assert len(refund_id) == 20
        
        pix_id = dependencies.generate_pix_id()
        assert pix_id.startswith("pix_")
        assert len(pix_id) == 20


class TestErrorResponse:
    
    def test_error_response_model(self):
        error = schemas.ErrorResponse(
            error_code="PAYMENT_DECLINED",
            message="Card declined by issuer",
            details={"gateway": "stone", "gateway_code": "insufficient_funds"},
            request_id="req_123",
        )
        
        assert error.error_code == "PAYMENT_DECLINED"
        assert error.message == "Card declined by issuer"
        assert error.details["gateway"] == "stone"
        assert error.request_id == "req_123"


class TestHealthResponse:
    
    def test_health_response_model(self):
        health = schemas.HealthResponse(
            status="healthy",
            version="2.0.0",
            gateways={"stone": "healthy", "stripe": "healthy"},
        )
        
        assert health.status == "healthy"
        assert health.gateways["stone"] == "healthy"
        assert health.version == "2.0.0"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

