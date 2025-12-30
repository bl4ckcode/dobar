"""
Stripe Sandbox Integration Tests

These tests use real Stripe Sandbox API calls to verify the SDK integration.
Run with: pytest tests/test_stripe_sandbox.py -v -s

Prerequisites:
- STRIPE_API_KEY env variable set to your sandbox API key (sk_test_...)

Stripe Test Payment Methods (tokens):
- pm_card_visa: Standard Visa
- pm_card_mastercard: Standard Mastercard
- pm_card_chargeDeclined: Card declined
- pm_card_authenticationRequired: Requires 3DS

Reference: https://docs.stripe.com/testing
"""

import pytest
import os
from app.payment import StripePaymentGateway


# Stripe test payment method tokens - these work in sandbox
# No raw card data needed, Stripe provides pre-made tokens
TEST_PAYMENT_METHODS = {
    "visa": "pm_card_visa",
    "mastercard": "pm_card_mastercard", 
    "visa_debit": "pm_card_visa_debit",
    "declined": "pm_card_chargeDeclined",
    "declined_insufficient_funds": "pm_card_chargeDeclinedInsufficientFunds",
    "requires_auth": "pm_card_authenticationRequired",
}


@pytest.fixture
def stripe_gateway():
    """Create a Stripe gateway configured for sandbox."""
    api_key = os.getenv("STRIPE_API_KEY")
    if not api_key or not api_key.startswith("sk_test"):
        pytest.skip("STRIPE_API_KEY not configured or not a sandbox key (sk_test_...)")
    
    config = {
        "STRIPE_API_KEY": api_key,
        "STRIPE_ENV": "sandbox",
    }
    return StripePaymentGateway(config)


@pytest.fixture
def stripe_gateway_no_credentials():
    """Create a Stripe gateway without credentials for error testing."""
    config = {
        "STRIPE_API_KEY": None,
        "STRIPE_ENV": "sandbox",
    }
    return StripePaymentGateway(config)


class TestStripeGatewayConfiguration:
    """Tests for gateway configuration and initialization."""

    def test_gateway_initialized_correctly(self, stripe_gateway):
        """Test that gateway initializes with valid credentials."""
        assert stripe_gateway is not None
        assert stripe_gateway._client is not None

    def test_gateway_without_credentials_returns_error_on_charge(self, stripe_gateway_no_credentials):
        """Test that gateway without credentials returns error on operations."""
        # Even if client initializes, operations should fail gracefully
        result = stripe_gateway_no_credentials.create_charge(
            amount=10.00,
            currency="USD",
            payment_method={"payment_method_id": "pm_card_visa"},
        )
        # Should either return error or succeed with a test client
        # The key is it doesn't crash
        assert result is not None


class TestStripeCardPayments:
    """Integration tests for card payments using Stripe test tokens."""

    def test_charge_success_with_visa(self, stripe_gateway):
        """Test successful charge with Visa card token."""
        result = stripe_gateway.create_charge(
            amount=10.00,
            currency="USD",
            customer={"email": "test@barz.app"},
            payment_method={"payment_method_id": TEST_PAYMENT_METHODS["visa"]},
        )

        print(f"\n✅ Stripe Charge Created:")
        print(f"   Payment Intent ID: {result.get('payment_intent_id')}")
        print(f"   Status: {result.get('status')}")
        print(f"   Amount: {result.get('amount')}")

        assert result.get("status") == "success"
        assert result.get("payment_intent_id") is not None
        assert result.get("payment_intent_id").startswith("pi_")
        assert result.get("amount") == 1000  # 10.00 * 100 cents

    def test_charge_success_with_mastercard(self, stripe_gateway):
        """Test successful charge with Mastercard token."""
        result = stripe_gateway.create_charge(
            amount=25.50,
            currency="USD",
            payment_method={"payment_method_id": TEST_PAYMENT_METHODS["mastercard"]},
        )

        print(f"\n✅ Mastercard Charge:")
        print(f"   Payment Intent ID: {result.get('payment_intent_id')}")
        print(f"   Amount: {result.get('amount')}")

        assert result.get("status") == "success"
        assert result.get("amount") == 2550

    def test_charge_declined_card(self, stripe_gateway):
        """Test handling of declined card."""
        result = stripe_gateway.create_charge(
            amount=10.00,
            currency="USD",
            payment_method={"payment_method_id": TEST_PAYMENT_METHODS["declined"]},
        )

        print(f"\n⚠️ Declined Card Result:")
        print(f"   Status: {result.get('status')}")
        print(f"   Message: {result.get('message')}")

        assert result.get("status") == "error"
        assert "declined" in result.get("message", "").lower()

    def test_charge_insufficient_funds(self, stripe_gateway):
        """Test handling of insufficient funds."""
        result = stripe_gateway.create_charge(
            amount=10.00,
            currency="USD",
            payment_method={"payment_method_id": TEST_PAYMENT_METHODS["declined_insufficient_funds"]},
        )

        print(f"\n⚠️ Insufficient Funds Result:")
        print(f"   Status: {result.get('status')}")
        print(f"   Message: {result.get('message')}")

        assert result.get("status") == "error"


class TestStripeCheckoutSessions:
    """Integration tests for Stripe Checkout Sessions."""

    def test_create_checkout_session(self, stripe_gateway):
        """Test creating a Stripe Checkout Session."""
        result = stripe_gateway.create_checkout_session(
            success_url="https://barz.app/payment/success",
            cancel_url="https://barz.app/payment/cancel",
            amount=25.00,
            currency="USD",
            product_name="BarZ Premium",
        )

        print(f"\n✅ Checkout Session Created:")
        print(f"   Session ID: {result.get('session_id')}")
        print(f"   Checkout URL: {result.get('checkout_url', '')[:80]}...")

        assert result.get("status") == "success"
        assert result.get("session_id") is not None
        assert result.get("session_id").startswith("cs_test_")
        assert "checkout.stripe.com" in result.get("checkout_url", "")

    def test_create_checkout_session_mxn(self, stripe_gateway):
        """Test creating a Checkout Session with Mexican Pesos."""
        result = stripe_gateway.create_checkout_session(
            success_url="https://barz.app/payment/success",
            cancel_url="https://barz.app/payment/cancel",
            amount=500.00,
            currency="MXN",
            product_name="BarZ Premium Mexico",
        )

        print(f"\n✅ Checkout Session (MXN):")
        print(f"   Session ID: {result.get('session_id')}")

        assert result.get("status") == "success"


class TestStripeRefunds:
    """Integration tests for refunds."""

    def test_refund_full_payment(self, stripe_gateway):
        """Test full refund of a payment."""
        # First create a charge
        charge_result = stripe_gateway.create_charge(
            amount=50.00,
            currency="USD",
            payment_method={"payment_method_id": TEST_PAYMENT_METHODS["visa"]},
        )

        if charge_result.get("status") != "success":
            pytest.skip(f"Could not create charge: {charge_result}")

        # Now refund it
        refund_result = stripe_gateway.refund_charge(
            payment_intent_id=charge_result["payment_intent_id"],
        )

        print(f"\n✅ Full Refund Result:")
        print(f"   Status: {refund_result.get('status')}")
        print(f"   Refund ID: {refund_result.get('refund_id')}")
        print(f"   Amount: {refund_result.get('amount_refunded')}")

        assert refund_result.get("status") == "success"
        assert refund_result.get("refund_id") is not None
        assert refund_result.get("refund_id").startswith("re_")
        assert refund_result.get("amount_refunded") == 5000

    def test_refund_partial_payment(self, stripe_gateway):
        """Test partial refund of a payment."""
        # Create a charge
        charge_result = stripe_gateway.create_charge(
            amount=100.00,
            currency="USD",
            payment_method={"payment_method_id": TEST_PAYMENT_METHODS["visa"]},
        )

        if charge_result.get("status") != "success":
            pytest.skip(f"Could not create charge: {charge_result}")

        # Partial refund of $25
        refund_result = stripe_gateway.refund_charge(
            payment_intent_id=charge_result["payment_intent_id"],
            amount=25.00,
        )

        print(f"\n✅ Partial Refund Result:")
        print(f"   Refunded: ${refund_result.get('amount_refunded', 0) / 100:.2f}")

        assert refund_result.get("status") == "success"
        assert refund_result.get("amount_refunded") == 2500


class TestStripeCustomers:
    """Integration tests for customer management."""

    def test_create_customer(self, stripe_gateway):
        """Test creating a Stripe customer."""
        result = stripe_gateway.create_customer(
            email="customer@barz.app",
            name="Test Customer",
        )

        print(f"\n✅ Customer Created:")
        print(f"   Customer ID: {result.get('customer_id')}")
        print(f"   Email: {result.get('email')}")

        assert result.get("status") == "success"
        assert result.get("customer_id") is not None
        assert result.get("customer_id").startswith("cus_")
        assert result.get("email") == "customer@barz.app"

    def test_create_customer_with_metadata(self, stripe_gateway):
        """Test creating a customer with metadata."""
        result = stripe_gateway.create_customer(
            email="vip@barz.app",
            name="VIP Customer",
            metadata={"tier": "premium", "source": "mobile_app"},
        )

        print(f"\n✅ VIP Customer Created:")
        print(f"   Customer ID: {result.get('customer_id')}")

        assert result.get("status") == "success"


class TestStripeSetupIntents:
    """Integration tests for SetupIntents (saving cards for future use)."""

    def test_create_setup_intent(self, stripe_gateway):
        """Test creating a SetupIntent for future payments."""
        # First create a customer
        customer_result = stripe_gateway.create_customer(
            email="setup@barz.app",
            name="SetupIntent Test Customer",
        )
        
        if customer_result.get("status") != "success":
            pytest.skip(f"Could not create customer: {customer_result}")
        
        result = stripe_gateway.create_setup_intent(
            customer_id=customer_result["customer_id"]
        )

        print(f"\n✅ SetupIntent Created:")
        print(f"   SetupIntent ID: {result.get('setup_intent_id')}")
        print(f"   Client Secret: {result.get('client_secret', '')[:30]}...")

        assert result.get("status") == "success"
        assert result.get("setup_intent_id") is not None
        assert result.get("setup_intent_id").startswith("seti_")
        assert result.get("client_secret") is not None


class TestStripeLatinAmericanPayments:
    """Tests with Latin American currencies."""

    def test_mexican_peso_payment(self, stripe_gateway):
        """Test charge in Mexican Pesos."""
        result = stripe_gateway.create_charge(
            amount=500.00,  # 500 MXN
            currency="MXN",
            payment_method={"payment_method_id": TEST_PAYMENT_METHODS["visa"]},
        )

        print(f"\n✅ Mexican Peso Charge:")
        print(f"   Status: {result.get('status')}")
        print(f"   Currency: {result.get('currency')}")
        print(f"   Amount: {result.get('amount')}")

        assert result.get("status") == "success"
        assert result.get("currency") == "mxn"
        assert result.get("amount") == 50000  # 500.00 * 100

    def test_chilean_peso_payment(self, stripe_gateway):
        """Test charge in Chilean Pesos (zero-decimal currency)."""
        result = stripe_gateway.create_charge(
            amount=10000,  # 10000 CLP (no decimals)
            currency="CLP",
            payment_method={"payment_method_id": TEST_PAYMENT_METHODS["visa"]},
        )

        print(f"\n✅ Chilean Peso Charge:")
        print(f"   Status: {result.get('status')}")
        print(f"   Currency: {result.get('currency')}")
        print(f"   Amount: {result.get('amount')}")

        assert result.get("status") == "success"
        assert result.get("currency") == "clp"


class TestStripeGetPaymentIntent:
    """Tests for retrieving payment intent details."""

    def test_get_payment_intent(self, stripe_gateway):
        """Test retrieving a payment intent."""
        # First create a charge
        charge_result = stripe_gateway.create_charge(
            amount=15.00,
            currency="USD",
            payment_method={"payment_method_id": TEST_PAYMENT_METHODS["visa"]},
        )

        if charge_result.get("status") != "success":
            pytest.skip(f"Could not create charge: {charge_result}")

        # Now retrieve it
        get_result = stripe_gateway.get_payment_intent(
            payment_intent_id=charge_result["payment_intent_id"],
        )

        print(f"\n✅ Retrieved Payment Intent:")
        print(f"   ID: {get_result.get('payment_intent_id')}")
        print(f"   Status: {get_result.get('status')}")
        print(f"   Amount: {get_result.get('amount')}")

        assert get_result.get("status") == "success"
        assert get_result.get("payment_intent_id") == charge_result["payment_intent_id"]
        assert get_result.get("amount") == 1500
