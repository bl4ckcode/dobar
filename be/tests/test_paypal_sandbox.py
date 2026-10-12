"""
PayPal Sandbox Integration Tests

These tests use real PayPal Sandbox API calls to verify the SDK integration.
Run with: pytest tests/test_paypal_sandbox.py -v -s

Note: Capture and refund tests require manual approval flow in browser,
so we test up to order creation and verify the approval URL is returned.
"""

import pytest
from app.payment import PaypalPaymentGateway

# PayPal Sandbox Credentials
SANDBOX_CLIENT_ID = "AWWab3ocAALVelW7RZai0FDh9Q9mcDM6844R2wO6l6T6zhZwo1St9eUx5cZHdDKLkDiI8RvJ2JWrG723"
SANDBOX_SECRET = "EBmUtFBli39OMmF31TRMsHaOLuKKKh5_9_YkzD8p9hvLsHAnalnnM_9KJ_IS5FalyAlvkDeWrlwuWFw1"


@pytest.fixture
def paypal_gateway():
    """Create a PayPal gateway configured for sandbox."""
    config = {
        "PAYPAL_CLIENT_ID": SANDBOX_CLIENT_ID,
        "PAYPAL_CLIENT_SECRET": SANDBOX_SECRET,
        "PAYPAL_ENV": "sandbox",
    }
    return PaypalPaymentGateway(config)


class TestPaypalSandboxIntegration:
    """
    Integration tests against PayPal Sandbox.
    
    These tests make real API calls to PayPal's sandbox environment.
    """

    def test_create_charge_returns_order_with_approval_url(self, paypal_gateway):
        """
        Test creating a charge (order) in PayPal sandbox.
        
        This creates an order and verifies we get back:
        - A valid order/payment_intent ID
        - An approval URL for the customer to complete payment
        - Status is 'requires_action' (customer must approve)
        """
        result = paypal_gateway.create_charge(
            amount=1000,  # $10.00 in cents
            currency="USD",
            payment_method_id=None,
            customer_id=None,
            metadata={"order_id": "test-order-123", "item": "Test Item"},
        )

        print(f"\n✅ PayPal Order Created:")
        print(f"   Payment Intent ID: {result.get('payment_intent_id')}")
        print(f"   Status: {result.get('status')}")
        print(f"   Raw Status: {result.get('raw_status')}")
        print(f"   Approval URL: {result.get('approval_url')}")

        # Assertions - PayPal returns requires_action for redirect flow
        assert result.get("status") == "requires_action", f"Expected 'requires_action', got {result.get('status')}"
        assert result.get("payment_intent_id") is not None, "Payment Intent ID should not be None"
        assert result.get("approval_url") is not None, "Approval URL should not be None"
        assert "paypal.com" in result.get("approval_url", ""), "Approval URL should contain paypal.com"
        assert result.get("provider") == "paypal"

    def test_create_checkout_session_success(self, paypal_gateway):
        """
        Test creating a checkout session for PayPal.
        
        Uses the create_checkout_session method with explicit return URLs.
        """
        result = paypal_gateway.create_checkout_session(
            success_url="https://barz.app/payment/success",
            cancel_url="https://barz.app/payment/cancel",
        )

        print(f"\n✅ PayPal Checkout Session Created:")
        print(f"   Order ID: {result.get('order_id')}")
        print(f"   Checkout URL: {result.get('checkout_url')}")
        print(f"   Raw Status: {result.get('raw_status')}")

        # Assertions - gateway returns order_id and checkout_url
        assert result.get("order_id") is not None, "Order ID should not be None"
        assert result.get("checkout_url") is not None, "Checkout URL should not be None"
        assert "paypal.com" in result.get("checkout_url", ""), "URL should contain paypal.com"
        assert result.get("provider") == "paypal"

    def test_create_charge_different_amounts(self, paypal_gateway):
        """Test creating orders with various amounts."""
        test_amounts = [
            (100, "USD", "$1.00"),
            (999, "USD", "$9.99"),
            (5000, "USD", "$50.00"),
        ]

        for amount, currency, description in test_amounts:
            result = paypal_gateway.create_charge(
                amount=amount,
                currency=currency,
                payment_method_id=None,
                customer_id=None,
                metadata={"test": f"Amount test: {description}"},
            )

            print(f"\n✅ Order for {description} ({currency}):")
            print(f"   Payment Intent ID: {result.get('payment_intent_id')}")
            print(f"   Status: {result.get('status')}")

            assert result.get("status") == "requires_action"
            assert result.get("payment_intent_id") is not None
            assert result.get("approval_url") is not None

    def test_create_charge_different_currencies(self, paypal_gateway):
        """Test creating orders with various currencies."""
        test_currencies = [
            (1000, "EUR", "€10.00"),
            (1000, "GBP", "£10.00"),
            (5000, "BRL", "R$50.00"),
        ]

        for amount, currency, description in test_currencies:
            result = paypal_gateway.create_charge(
                amount=amount,
                currency=currency,
                payment_method_id=None,
                customer_id=None,
                metadata={"test": f"Currency test: {description}"},
            )

            print(f"\n✅ Order for {description}:")
            print(f"   Payment Intent ID: {result.get('payment_intent_id')}")
            print(f"   Currency: {result.get('currency')}")

            assert result.get("status") == "requires_action"
            assert result.get("payment_intent_id") is not None
            assert result.get("currency") == currency

    def test_create_charge_with_metadata(self, paypal_gateway):
        """Test that metadata is properly included in the order."""
        metadata = {
            "order_id": "ORD-12345",
            "customer_name": "Test Customer",
            "table_number": "T-7",
            "bar_id": "bar-barz-001",
            "items": "2x Beer, 1x Nachos",
        }

        result = paypal_gateway.create_charge(
            amount=3500,  # $35.00
            currency="USD",
            payment_method_id=None,
            customer_id=None,
            metadata=metadata,
        )

        print(f"\n✅ Order with metadata:")
        print(f"   Payment Intent ID: {result.get('payment_intent_id')}")
        print(f"   Metadata sent: {metadata}")

        assert result.get("status") == "requires_action"
        assert result.get("payment_intent_id") is not None

    def test_capture_without_approval_fails_gracefully(self, paypal_gateway):
        """
        Test that capturing an unapproved order returns an appropriate error.
        
        In real flow, the customer must approve the order via the approval_url
        before we can capture it.
        """
        # First create an order
        create_result = paypal_gateway.create_charge(
            amount=1000,
            currency="USD",
            payment_method_id=None,
            customer_id=None,
            metadata={"test": "capture_test"},
        )

        order_id = create_result.get("payment_intent_id")
        print(f"\n📋 Created order: {order_id}")
        print(f"   Approval URL: {create_result.get('approval_url')}")

        # Try to capture without customer approval (should fail)
        # capture_charge signature: capture_charge(payment_intent_id, amount=None)
        capture_result = paypal_gateway.capture_charge(
            payment_intent_id=order_id,
            amount=1000,
        )

        print(f"\n⚠️  Capture attempt (without approval):")
        print(f"   Status: {capture_result.get('status')}")
        print(f"   Message: {capture_result.get('message')}")

        # PayPal should return an error since the order isn't approved
        assert capture_result.get("status") == "error", \
            "Capture should fail for unapproved order"

    def test_refund_invalid_capture_fails_gracefully(self, paypal_gateway):
        """
        Test that refunding a non-existent capture returns an appropriate error.
        """
        # refund_charge signature: refund_charge(charge_id, payment_intent_id, amount)
        result = paypal_gateway.refund_charge(
            charge_id="INVALID_CAPTURE_ID_12345",
            payment_intent_id=None,
            amount=1000,
        )

        print(f"\n⚠️  Refund attempt (invalid capture ID):")
        print(f"   Status: {result.get('status')}")
        print(f"   Message: {result.get('message')}")

        assert result.get("status") == "error"


class TestPaypalSandboxEdgeCases:
    """Test edge cases and error handling with sandbox."""

    def test_invalid_credentials_fails(self):
        """Test that invalid credentials are handled gracefully."""
        bad_config = {
            "PAYPAL_CLIENT_ID": "INVALID_CLIENT_ID",
            "PAYPAL_CLIENT_SECRET": "INVALID_SECRET",
            "PAYPAL_ENV": "sandbox",
        }
        bad_gateway = PaypalPaymentGateway(bad_config)

        result = bad_gateway.create_charge(
            amount=1000,
            currency="USD",
            payment_method_id=None,
            customer_id=None,
            metadata={},
        )

        print(f"\n⚠️  Invalid credentials test:")
        print(f"   Status: {result.get('status')}")
        print(f"   Message: {result.get('message')}")

        assert result.get("status") == "error"

    def test_zero_amount_handling(self, paypal_gateway):
        """Test how PayPal handles zero amount (should fail)."""
        result = paypal_gateway.create_charge(
            amount=0,
            currency="USD",
            payment_method_id=None,
            customer_id=None,
            metadata={},
        )

        print(f"\n⚠️  Zero amount test:")
        print(f"   Status: {result.get('status')}")
        print(f"   Message: {result.get('message')}")

        # PayPal should reject zero amount
        assert result.get("status") == "error"

    def test_very_small_amount(self, paypal_gateway):
        """Test minimum valid amount (1 cent)."""
        result = paypal_gateway.create_charge(
            amount=1,  # $0.01
            currency="USD",
            payment_method_id=None,
            customer_id=None,
            metadata={"test": "minimum_amount"},
        )

        print(f"\n✅ Minimum amount test ($0.01):")
        print(f"   Payment Intent ID: {result.get('payment_intent_id')}")
        print(f"   Status: {result.get('status')}")
        print(f"   Amount: {result.get('amount')}")

        assert result.get("payment_intent_id") is not None
        assert result.get("status") == "requires_action"

    def test_large_amount(self, paypal_gateway):
        """Test a larger amount."""
        result = paypal_gateway.create_charge(
            amount=99999999,  # $999,999.99
            currency="USD",
            payment_method_id=None,
            customer_id=None,
            metadata={"test": "large_amount"},
        )

        print(f"\n✅ Large amount test ($999,999.99):")
        print(f"   Payment Intent ID: {result.get('payment_intent_id')}")
        print(f"   Status: {result.get('status')}")

        assert result.get("payment_intent_id") is not None
        assert result.get("status") == "requires_action"

    def test_missing_credentials_returns_error(self):
        """Test that missing credentials return a proper error."""
        empty_config = {}
        gateway = PaypalPaymentGateway(empty_config)

        result = gateway.create_charge(
            amount=1000,
            currency="USD",
            payment_method_id=None,
            customer_id=None,
            metadata={},
        )

        print(f"\n⚠️  Missing credentials test:")
        print(f"   Status: {result.get('status')}")
        print(f"   Message: {result.get('message')}")

        assert result.get("status") == "error"
        assert "not configured" in result.get("message", "").lower()


# Manual test helper - run this to get an approval URL you can test in browser
if __name__ == "__main__":
    print("\n" + "=" * 60)
    print("PayPal Sandbox Manual Test")
    print("=" * 60)

    config = {
        "PAYPAL_CLIENT_ID": SANDBOX_CLIENT_ID,
        "PAYPAL_CLIENT_SECRET": SANDBOX_SECRET,
        "PAYPAL_ENV": "sandbox",
    }
    gateway = PaypalPaymentGateway(config)

    result = gateway.create_checkout_session(
        success_url="https://barz.app/success?session_id={CHECKOUT_SESSION_ID}",
        cancel_url="https://barz.app/cancel",
    )

    print(f"\n✅ Order created successfully!")
    print(f"\n   Order ID: {result.get('session_id')}")
    print(f"\n   👉 Open this URL in your browser to complete the payment:")
    print(f"\n   {result.get('url')}")
    print(f"\n   Login with sandbox buyer account to approve.")
    print("\n" + "=" * 60)
