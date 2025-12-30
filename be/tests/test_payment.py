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
        
        with patch("app.payment.get_payment_gateway", return_value=mock_payment_gateway):
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
        
        with patch("app.payment.get_payment_gateway", return_value=MockFailedGateway()):
            response = await client.post("/payments/charge", json=payment_request)
        
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_create_charge_pix_method(self, client: AsyncClient, mock_payment_gateway):
        """Test creating a charge using Pix as payment_method.

        For now this only verifies that the API accepts `payment_method="pix"`
        and that the request flows through to the gateway without validation
        errors. The gateway itself decides how to process Pix (e.g. via
        Pagar.me/Stone or another PSP).
        """

        payment_request = {
            "amount": 10000,
            "currency": "BRL",
            "customer": {
                "name": "Pix User",
                "email": "pix@test.com",
                "document": "12345678901",
            },
            "payment_method": {
                "payment_method": "pix",
                "card": None,
            },
        }

        with patch("app.payment.get_payment_gateway", return_value=mock_payment_gateway):
            response = await client.post("/payments/charge", json=payment_request)

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"


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
        
        with patch("app.payment.get_payment_gateway", return_value=mock_payment_gateway):
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
        
        with patch("app.payment.get_payment_gateway", return_value=mock_payment_gateway):
            response = await client.post("/payments/refund", json=refund_request)
        
        assert response.status_code == 200
    
    @pytest.mark.asyncio
    async def test_refund_without_id(self, client: AsyncClient, mock_payment_gateway):
        """Test refund without charge_id or payment_intent_id."""
        refund_request = {}
        
        with patch("app.payment.get_payment_gateway", return_value=mock_payment_gateway):
            response = await client.post("/payments/refund", json=refund_request)
        
        # Should fail validation
        assert response.status_code == 422


@pytest.mark.payment
class TestPaymentCapture:
    """Test payment capture/confirm endpoint."""

    @pytest.mark.asyncio
    async def test_capture_success(self, client: AsyncClient, mock_payment_gateway):
        """Capture succeeds when gateway returns success."""

        class MockCaptureGateway:
            def capture_charge(self, payment_intent_id: str, amount: float | None = None):
                return {
                    "status": "success",
                    "provider": "paypal",
                    "payment_intent_id": payment_intent_id,
                    "charge_id": "CAPTURE123",
                }

        with patch("app.payment.get_payment_gateway", return_value=MockCaptureGateway()):
            response = await client.post(
                "/payments/capture",
                params={"payment_intent_id": "ORDER123", "amount": 100.0},
            )

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "success"
        assert data["charge_id"] == "CAPTURE123"

    @pytest.mark.asyncio
    async def test_capture_failure_raises_http_error(self, client: AsyncClient):
        """Gateway error during capture should surface as HTTP 400."""

        class MockCaptureFailGateway:
            def capture_charge(self, payment_intent_id: str, amount: float | None = None):
                return {"status": "error", "message": "Failed to capture"}

        with patch("app.payment.get_payment_gateway", return_value=MockCaptureFailGateway()):
            response = await client.post(
                "/payments/capture",
                params={"payment_intent_id": "ORDER123"},
            )

        assert response.status_code == 400


@pytest.mark.payment
@pytest.mark.unit
class TestPaypalGatewayUnit:
    """Unit tests for the PayPal payment gateway using SDK mocks."""

    def _create_mock_client(self):
        """Create a mock PayPal SDK client for testing."""
        from unittest.mock import MagicMock
        return MagicMock()

    def test_capture_charge_success(self, monkeypatch):
        """capture_charge should normalize a successful PayPal capture response."""
        from unittest.mock import MagicMock
        from app.payment import PaypalPaymentGateway

        # Create mock API response
        mock_capture = MagicMock()
        mock_capture.id = "CAPTURE123"
        mock_capture.status = "COMPLETED"
        mock_capture.amount = MagicMock()
        mock_capture.amount.currency_code = "USD"
        mock_capture.amount.value = "100.00"

        mock_payments = MagicMock()
        mock_payments.captures = [mock_capture]

        mock_unit = MagicMock()
        mock_unit.payments = mock_payments

        mock_order = MagicMock()
        mock_order.status = "COMPLETED"
        mock_order.purchase_units = [mock_unit]

        mock_result = MagicMock()
        mock_result.is_success.return_value = True
        mock_result.body = mock_order

        # Mock the SDK client
        mock_client = MagicMock()
        mock_client.orders.capture_order.return_value = mock_result

        gateway = PaypalPaymentGateway({"PAYPAL_CLIENT_ID": "id", "PAYPAL_CLIENT_SECRET": "secret"})
        gateway._client = mock_client

        result = gateway.capture_charge(payment_intent_id="ORDER123", amount=None)

        assert result["status"] == "success"
        assert result["charge_id"] == "CAPTURE123"
        assert result["currency"] == "USD"
        assert result["amount"] == 100.0

    def test_capture_charge_http_error(self, monkeypatch):
        """SDK error from PayPal capture should surface as status=error."""
        from unittest.mock import MagicMock
        from app.payment import PaypalPaymentGateway

        mock_result = MagicMock()
        mock_result.is_success.return_value = False
        mock_result.errors = [{"name": "UNPROCESSABLE_ENTITY", "message": "Invalid order"}]

        mock_client = MagicMock()
        mock_client.orders.capture_order.return_value = mock_result

        gateway = PaypalPaymentGateway({"PAYPAL_CLIENT_ID": "id", "PAYPAL_CLIENT_SECRET": "secret"})
        gateway._client = mock_client

        result = gateway.capture_charge(payment_intent_id="ORDER_BAD", amount=None)

        assert result["status"] == "error"
        assert "Failed to capture" in result["message"]

    def test_refund_charge_success(self, monkeypatch):
        """refund_charge should call captures refund and normalize success."""
        from unittest.mock import MagicMock
        from app.payment import PaypalPaymentGateway

        mock_refund = MagicMock()
        mock_refund.id = "REFUND123"
        mock_refund.amount = MagicMock()
        mock_refund.amount.currency_code = "USD"
        mock_refund.amount.value = "50.00"

        mock_result = MagicMock()
        mock_result.is_success.return_value = True
        mock_result.body = mock_refund

        mock_client = MagicMock()
        mock_client.payments.refund_captured_payment.return_value = mock_result

        gateway = PaypalPaymentGateway({"PAYPAL_CLIENT_ID": "id", "PAYPAL_CLIENT_SECRET": "secret"})
        gateway._client = mock_client

        result = gateway.refund_charge(charge_id="CAPTURE123", amount=50.0)

        assert result["status"] == "success"
        assert result["refund_id"] == "REFUND123"
        assert result["amount_refunded"] == 50.0
        assert result["currency"] == "USD"

    def test_refund_charge_missing_ids(self):
        """refund_charge should error if no identifiers are provided."""
        from app.payment import PaypalPaymentGateway

        gateway = PaypalPaymentGateway({"PAYPAL_CLIENT_ID": "id", "PAYPAL_CLIENT_SECRET": "secret"})
        result = gateway.refund_charge()

        assert result["status"] == "error"
        assert "Either charge_id or payment_intent_id is required" in result["message"]

    def test_create_checkout_session_success(self, monkeypatch):
        """create_checkout_session should return a checkout_url on success."""
        from unittest.mock import MagicMock
        from app.payment import PaypalPaymentGateway

        mock_link = MagicMock()
        mock_link.rel = "approve"
        mock_link.href = "https://www.paypal.com/checkoutnow?token=ORDER123"

        mock_order = MagicMock()
        mock_order.id = "ORDER123"
        mock_order.status = "PAYER_ACTION_REQUIRED"
        mock_order.links = [mock_link]

        mock_result = MagicMock()
        mock_result.is_success.return_value = True
        mock_result.body = mock_order

        mock_client = MagicMock()
        mock_client.orders.create_order.return_value = mock_result

        gateway = PaypalPaymentGateway({"PAYPAL_CLIENT_ID": "id", "PAYPAL_CLIENT_SECRET": "secret"})
        gateway._client = mock_client

        result = gateway.create_checkout_session(
            success_url="https://barz.app/paypal/success",
            cancel_url="https://barz.app/paypal/cancel",
        )

        assert result["status"] == "success"
        assert result["checkout_url"].startswith("https://www.paypal.com/checkoutnow")
        assert result["order_id"] == "ORDER123"

    def test_create_checkout_session_missing_approval_link(self, monkeypatch):
        """If PayPal does not return an approval link, treat as error."""
        from unittest.mock import MagicMock
        from app.payment import PaypalPaymentGateway

        mock_order = MagicMock()
        mock_order.id = "ORDER_NO_LINK"
        mock_order.status = "CREATED"
        mock_order.links = []

        mock_result = MagicMock()
        mock_result.is_success.return_value = True
        mock_result.body = mock_order

        mock_client = MagicMock()
        mock_client.orders.create_order.return_value = mock_result

        gateway = PaypalPaymentGateway({"PAYPAL_CLIENT_ID": "id", "PAYPAL_CLIENT_SECRET": "secret"})
        gateway._client = mock_client

        result = gateway.create_checkout_session(
            success_url="https://barz.app/paypal/success",
            cancel_url="https://barz.app/paypal/cancel",
        )

        assert result["status"] == "error"
        assert "approval URL" in result["message"]

    def test_create_charge_success(self, monkeypatch):
        """create_charge should return normalized order data on success."""
        from unittest.mock import MagicMock
        from app.payment import PaypalPaymentGateway

        mock_link = MagicMock()
        mock_link.rel = "approve"
        mock_link.href = "https://www.paypal.com/checkoutnow?token=ORDER456"

        mock_order = MagicMock()
        mock_order.id = "ORDER456"
        mock_order.status = "CREATED"
        mock_order.links = [mock_link]

        mock_result = MagicMock()
        mock_result.is_success.return_value = True
        mock_result.body = mock_order

        mock_client = MagicMock()
        mock_client.orders.create_order.return_value = mock_result

        gateway = PaypalPaymentGateway({"PAYPAL_CLIENT_ID": "id", "PAYPAL_CLIENT_SECRET": "secret"})
        gateway._client = mock_client

        result = gateway.create_charge(amount=100.0, currency="USD")

        assert result["status"] == "requires_action"
        assert result["payment_intent_id"] == "ORDER456"
        assert result["approval_url"] == "https://www.paypal.com/checkoutnow?token=ORDER456"
        assert result["amount"] == 100.0

    def test_create_charge_no_credentials(self):
        """create_charge should error if credentials are not configured."""
        from app.payment import PaypalPaymentGateway

        gateway = PaypalPaymentGateway({})
        result = gateway.create_charge(amount=100.0, currency="USD")

        assert result["status"] == "error"
        assert "credentials not configured" in result["message"]


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
        
        with patch("app.payment.get_payment_gateway", return_value=MockCheckoutGateway()):
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
        with patch("app.payment.get_payment_gateway", return_value=mock_payment_gateway):
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
        
        with patch("app.payment.get_payment_gateway", return_value=MockSetupGateway()):
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
        
        from app.payment import get_payment_gateway
        from app.payment import StripePaymentGateway
        
        gateway = get_payment_gateway()
        assert isinstance(gateway, StripePaymentGateway)
    
    def test_get_stone_gateway(self):
        """Test getting Stone gateway."""
        import os
        os.environ["PAYMENT_GATEWAY"] = "stone"
        
        from app.payment import get_payment_gateway
        from app.payment import StonePaymentGateway
        
        gateway = get_payment_gateway()
        assert isinstance(gateway, StonePaymentGateway)

    def test_stone_gateway_builds_pix_payment_model(self, monkeypatch):
        """Ensure Stone gateway builds a Pix payment model when requested.

        This is a focused unit test that checks we branch to the Pix
        payment path without actually calling the remote Pagar.me API.
        """
        from app.payment import _stone_payment_gateway as stone_module
        from app.payment import StonePaymentGateway

        class DummyClient:
            class charges:
                @staticmethod
                def create_charge(charge_request):
                    return {
                        "status": "success",
                        "payment_method": charge_request.payment.payment_method,
                    }

        # Avoid hitting real Pagar.me credentials by monkeypatching the
        # factory used in StonePaymentGateway.__init__
        monkeypatch.setattr(stone_module, "get_pagarme_client", lambda: DummyClient())
        gateway = StonePaymentGateway(config={})

        customer = {
            "name": "Pix User",
            "email": "pix@test.com",
            "document": "12345678901",
        }
        payment_method = {"payment_method": "pix"}

        response = gateway.create_charge(amount=10000, currency="BRL", customer=customer, payment_method=payment_method)

        assert response["status"] == "success"
        assert response["payment_method"] == "pix"
    
    def test_unknown_gateway(self):
        """Test with unknown gateway."""
        import os
        os.environ["PAYMENT_GATEWAY"] = "unknown"
        
        from app.payment import get_payment_gateway
        
        with pytest.raises(ValueError):
            get_payment_gateway()

    def test_get_paypal_gateway(self):
        """Test getting PayPal gateway from factory."""
        import os
        os.environ["PAYMENT_GATEWAY"] = "paypal"
        os.environ["PAYPAL_CLIENT_ID"] = "test_client_id"
        os.environ["PAYPAL_CLIENT_SECRET"] = "test_client_secret"

        from app.payment import get_payment_gateway
        from app.payment import PaypalPaymentGateway

        gateway = get_payment_gateway()
        assert isinstance(gateway, PaypalPaymentGateway)
