import pytest
from httpx import AsyncClient
from unittest.mock import patch


@pytest.mark.payment
class TestPaymentCharge:
    """Test payment charge endpoints."""
    
    @pytest.mark.asyncio
    async def test_create_charge_success(self, client: AsyncClient, mock_payment_gateway):
        """Test successful charge creation."""
        payment_request = {
            "amount": 10000,  # $100.00
            "currency": "BRL",
            "customer": {
                "name": "Test Customer",
                "email": "customer@test.com",
                "document": "12345678901"
            },
            "payment_method": {
                "payment_method": "credit_card",
                "card": {
                    "number": "4111111111111111",
                    "holder_name": "TEST USER",
                    "exp_month": 12,
                    "exp_year": 2025,
                    "cvv": "123"
                }
            }
        }
        
        with patch("app.payment.core.factory.get_payment_gateway", return_value=mock_payment_gateway):
            response = await client.post("/payments/charge", json=payment_request)
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert "payment_intent_id" in data
    
    @pytest.mark.asyncio
    async def test_create_charge_validation_error(self, client: AsyncClient):
        """Test charge creation with validation error."""
        invalid_request = {
            "amount": 10000,
            "currency": "BRL"
            # Missing customer and payment_method
        }
        
        response = await client.post("/payments/charge", json=invalid_request)
        
        assert response.status_code == 422  # Validation error
    
    @pytest.mark.asyncio
    async def test_create_charge_payment_failure(self, client: AsyncClient):
        """Test charge creation with payment failure."""
        payment_request = {
            "amount": 10000,
            "currency": "BRL",
            "customer": {
                "name": "Test Customer",
                "email": "customer@test.com",
                "document": "12345678901"
            },
            "payment_method": {
                "payment_method": "credit_card",
                "card": {
                    "number": "4111111111111111",
                    "holder_name": "TEST USER",
                    "exp_month": 12,
                    "exp_year": 2025,
                    "cvv": "123"
                }
            }
        }
        
        # Mock gateway that returns error
        class MockFailedGateway:
            def create_charge(self, **kwargs):
                return {"status": "error", "message": "Card declined"}
        
        with patch("app.payment.core.factory.get_payment_gateway", return_value=MockFailedGateway()):
            response = await client.post("/payments/charge", json=payment_request)
        
        assert response.status_code == 400


@pytest.mark.payment
class TestPaymentRefund:
    """Test payment refund endpoints."""
    
    @pytest.mark.asyncio
    async def test_refund_charge_success(self, client: AsyncClient, mock_payment_gateway):
        """Test successful refund."""
        refund_request = {
            "charge_id": "test_charge_123",
            "amount": 5000  # Partial refund
        }
        
        with patch("app.payment.core.factory.get_payment_gateway", return_value=mock_payment_gateway):
            response = await client.post("/payments/refund", json=refund_request)
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert "refund_id" in data
    
    @pytest.mark.asyncio
    async def test_refund_with_payment_intent_id(self, client: AsyncClient, mock_payment_gateway):
        """Test refund using payment_intent_id."""
        refund_request = {
            "payment_intent_id": "test_intent_123"
        }
        
        with patch("app.payment.core.factory.get_payment_gateway", return_value=mock_payment_gateway):
            response = await client.post("/payments/refund", json=refund_request)
        
        assert response.status_code == 200
    
    @pytest.mark.asyncio
    async def test_refund_without_id(self, client: AsyncClient, mock_payment_gateway):
        """Test refund without charge_id or payment_intent_id."""
        refund_request = {}
        
        with patch("app.payment.core.factory.get_payment_gateway", return_value=mock_payment_gateway):
            response = await client.post("/payments/refund", json=refund_request)
        
        # Should fail validation
        assert response.status_code == 422


@pytest.mark.payment
class TestPaymentCheckout:
    """Test payment checkout endpoints."""
    
    @pytest.mark.asyncio
    async def test_create_checkout_session(self, client: AsyncClient):
        """Test checkout session creation."""
        # Mock gateway with checkout support
        class MockCheckoutGateway:
            def create_checkout_session(self, success_url, cancel_url):
                return {
                    "status": "success",
                    "checkout_url": "https://checkout.stripe.com/test"
                }
        
        with patch("app.payment.core.factory.get_payment_gateway", return_value=MockCheckoutGateway()):
            response = await client.post(
                "/payments/checkout",
                params={
                    "success_url": "https://app.com/success",
                    "cancel_url": "https://app.com/cancel"
                }
            )
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert "checkout_url" in data
    
    @pytest.mark.asyncio
    async def test_create_checkout_unsupported_gateway(self, client: AsyncClient, mock_payment_gateway):
        """Test checkout with gateway that doesn't support it."""
        with patch("app.payment.core.factory.get_payment_gateway", return_value=mock_payment_gateway):
            response = await client.post(
                "/payments/checkout",
                params={
                    "success_url": "https://app.com/success",
                    "cancel_url": "https://app.com/cancel"
                }
            )
        
        assert response.status_code == 400


@pytest.mark.payment
class TestPaymentSetup:
    """Test payment setup intent endpoints."""
    
    @pytest.mark.asyncio
    async def test_create_setup_intent(self, client: AsyncClient):
        """Test setup intent creation."""
        class MockSetupGateway:
            def create_setup_intent(self, customer_id):
                return {
                    "status": "success",
                    "setup_intent_id": "test_setup_123",
                    "client_secret": "test_secret"
                }
        
        with patch("app.payment.core.factory.get_payment_gateway", return_value=MockSetupGateway()):
            response = await client.post(
                "/payments/setup",
                params={"customer_id": "test_customer_123"}
            )
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert "setup_intent_id" in data


@pytest.mark.payment
@pytest.mark.unit
class TestPaymentGatewayFactory:
    """Test payment gateway factory."""
    
    def test_get_stripe_gateway(self):
        """Test getting Stripe gateway."""
        import os
        os.environ["PAYMENT_GATEWAY"] = "stripe"
        os.environ["STRIPE_API_KEY"] = "test_key"
        
        from app.payment.core.factory import get_payment_gateway
        from app.payment.core.gateways._stripe_payment_gateway import StripePaymentGateway
        
        gateway = get_payment_gateway()
        assert isinstance(gateway, StripePaymentGateway)
    
    def test_get_stone_gateway(self):
        """Test getting Stone gateway."""
        import os
        os.environ["PAYMENT_GATEWAY"] = "stone"
        
        from app.payment.core.factory import get_payment_gateway
        from app.payment.core.gateways._stone_payment_gateway import StonePaymentGateway
        
        gateway = get_payment_gateway()
        assert isinstance(gateway, StonePaymentGateway)
    
    def test_unknown_gateway(self):
        """Test with unknown gateway."""
        import os
        os.environ["PAYMENT_GATEWAY"] = "unknown"
        
        from app.payment.core.factory import get_payment_gateway
        
        with pytest.raises(ValueError):
            get_payment_gateway()
