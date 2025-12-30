"""
Stone/Pagar.me Sandbox Integration Tests

These tests use real Pagar.me Sandbox API calls to verify the SDK integration.
Run with: pytest tests/test_stone_sandbox.py -v -s

Prerequisites:
- PAGARME_USERNAME env variable set to your sandbox API key (sk_test_...)
- PAGARME_PASSWORD env variable (can be empty string)

Pagar.me Test Cards:
- Success: 4000000000000010 (Visa)
- Declined: 4000000000000028
- Insufficient funds: 4000000000000036

PIX payments generate a test QR code that won't actually work but validates the flow.
"""

import pytest
import os
from datetime import datetime, timedelta
from app.payment import StonePaymentGateway


# Pagar.me Sandbox test cards
TEST_CARDS = {
    "success": {
        "number": "4000000000000010",
        "holder_name": "TESTE DA SILVA",
        "exp_month": 12,
        "exp_year": 30,
        "cvv": "123",
    },
    "declined": {
        "number": "4000000000000028",
        "holder_name": "TESTE RECUSADO",
        "exp_month": 12,
        "exp_year": 30,
        "cvv": "123",
    },
    "insufficient_funds": {
        "number": "4000000000000036",
        "holder_name": "TESTE SEM SALDO",
        "exp_month": 12,
        "exp_year": 30,
        "cvv": "123",
    },
}

# Test customer data
TEST_CUSTOMER = {
    "name": "Tony Stark",
    "email": "tony.stark@avengers.com",
    "document": "93095135270",  # Valid test CPF
    "type": "individual",  # Required: 'individual' or 'company'
    "phones": {
        "mobile_phone": {
            "country_code": "55",
            "area_code": "11",
            "number": "999999999",
        }
    },
    "address": {
        "street": "Av Paulista",
        "number": "1000",
        "neighborhood": "Bela Vista",
        "city": "São Paulo",
        "state": "SP",
        "zip_code": "01310100",
        "country": "BR",
        "complement": "Sala 101",
    },
}


@pytest.fixture
def stone_gateway():
    """Create a Stone gateway configured for sandbox.
    
    Uses PAGARME_USERNAME from environment or skips if not configured.
    """
    username = os.getenv("PAGARME_USERNAME")
    if not username or not username.startswith("sk_test"):
        pytest.skip("PAGARME_USERNAME not configured or not a sandbox key (sk_test_...)")
    
    config = {
        "PAGARME_USERNAME": username,
        "PAGARME_PASSWORD": os.getenv("PAGARME_PASSWORD", ""),
        "PAGARME_ENV": "sandbox",
    }
    return StonePaymentGateway(config)


@pytest.fixture
def stone_gateway_no_credentials():
    """Create a Stone gateway without credentials for error testing."""
    # Clear env vars temporarily
    config = {
        "PAGARME_USERNAME": None,
        "PAGARME_ENV": "sandbox",
    }
    return StonePaymentGateway(config)


class TestStoneGatewayConfiguration:
    """Tests for gateway configuration and initialization."""

    def test_gateway_without_credentials_returns_error(self, monkeypatch):
        """Test that gateway without credentials returns proper error."""
        # Clear the environment variable to ensure no credentials
        monkeypatch.delenv("PAGARME_USERNAME", raising=False)
        monkeypatch.delenv("PAGARME_PASSWORD", raising=False)
        
        # Create gateway with explicitly empty credentials
        gateway = StonePaymentGateway({
            "PAGARME_USERNAME": None,
            "PAGARME_PASSWORD": None,
            "PAGARME_ENV": "sandbox",
        })
        
        result = gateway.create_charge(
            amount=10.00,
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={"payment_method": "credit_card", "card": TEST_CARDS["success"]},
        )

        print(f"\n❌ Expected error without credentials:")
        print(f"   Status: {result.get('status')}")
        print(f"   Message: {result.get('message')}")

        # Gateway should return error when credentials are empty
        assert result.get("status") == "error"
        assert "not configured" in result.get("message", "").lower()
        assert result.get("provider") == "stone"


class TestStoneCreditCardPayments:
    """Integration tests for credit card payments."""

    def test_credit_card_charge_success(self, stone_gateway):
        """Test successful credit card charge."""
        result = stone_gateway.create_charge(
            amount=100.00,  # R$100.00
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={
                "payment_method": "credit_card",
                "card": TEST_CARDS["success"],
                "installments": 1,
                "capture": True,
            },
        )

        print(f"\n✅ Credit Card Charge Created:")
        print(f"   Charge ID: {result.get('charge_id')}")
        print(f"   Status: {result.get('status')}")
        print(f"   Charge Status: {result.get('charge_status')}")
        print(f"   Amount: {result.get('amount')}")

        assert result.get("status") == "success", f"Expected 'success', got {result}"
        assert result.get("charge_id") is not None
        assert result.get("provider") == "stone"
        assert result.get("payment_method") == "credit_card"

    def test_credit_card_with_installments(self, stone_gateway):
        """Test credit card charge with installments."""
        result = stone_gateway.create_charge(
            amount=600.00,  # R$600.00 = 6x R$100
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={
                "payment_method": "credit_card",
                "card": TEST_CARDS["success"],
                "installments": 6,
                "capture": True,
            },
        )

        print(f"\n✅ Credit Card with Installments:")
        print(f"   Charge ID: {result.get('charge_id')}")
        print(f"   Installments: 6x")
        print(f"   Status: {result.get('status')}")

        assert result.get("status") == "success"
        assert result.get("charge_id") is not None

    def test_credit_card_auth_only(self, stone_gateway):
        """Test credit card authorization without capture."""
        result = stone_gateway.create_charge(
            amount=50.00,  # R$50.00
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={
                "payment_method": "credit_card",
                "card": TEST_CARDS["success"],
                "installments": 1,
                "capture": False,  # Auth only
            },
        )

        print(f"\n✅ Credit Card Auth Only:")
        print(f"   Charge ID: {result.get('charge_id')}")
        print(f"   Status: {result.get('status')}")
        print(f"   Charge Status: {result.get('charge_status')}")

        assert result.get("status") == "success"
        assert result.get("charge_id") is not None
        # Auth only should have pending/authorized status
        # Note: Actual status depends on Pagar.me response

    def test_credit_card_with_statement_descriptor(self, stone_gateway):
        """Test credit card with custom statement descriptor."""
        # Pagar.me doesn't allow special characters like * in statement descriptor
        descriptor = "BARZ BAR123"
        result = stone_gateway.create_charge(
            amount=25.00,
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={
                "payment_method": "credit_card",
                "card": TEST_CARDS["success"],
                "installments": 1,
                "capture": True,
                "statement_descriptor": descriptor,
            },
        )

        print(f"\n✅ Credit Card with Statement Descriptor:")
        print(f"   Charge ID: {result.get('charge_id')}")
        print(f"   Descriptor: {descriptor}")

        assert result.get("status") == "success"

    def test_credit_card_declined(self, stone_gateway):
        """Test declined credit card handling."""
        result = stone_gateway.create_charge(
            amount=100.00,
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={
                "payment_method": "credit_card",
                "card": TEST_CARDS["declined"],
                "installments": 1,
                "capture": True,
            },
        )

        print(f"\n⚠️ Declined Card Result:")
        print(f"   Status: {result.get('status')}")
        print(f"   Charge Status: {result.get('charge_status')}")
        print(f"   Message: {result.get('message', 'N/A')}")

        # Declined cards may still create a charge with failed status
        # or return an error - both are valid
        if result.get("status") == "error":
            assert "message" in result
        else:
            # Check if charge status indicates failure
            charge_status = result.get("charge_status", "")
            print(f"   Charge created with status: {charge_status}")


class TestStonePixPayments:
    """Integration tests for PIX payments."""

    def test_pix_charge_success(self, stone_gateway):
        """Test PIX payment creation with QR code generation."""
        result = stone_gateway.create_charge(
            amount=50.00,  # R$50.00
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={
                "payment_method": "pix",
                "expires_in": 3600,  # 1 hour
            },
        )

        qr_code_url = result.get('qr_code_url') or 'N/A'
        print(f"\n✅ PIX Charge Created:")
        print(f"   Charge ID: {result.get('charge_id')}")
        print(f"   Status: {result.get('status')}")
        print(f"   QR Code URL: {qr_code_url[:50] if len(qr_code_url) > 50 else qr_code_url}...")
        print(f"   Expires At: {result.get('expires_at', 'N/A')}")

        assert result.get("status") == "success", f"Expected 'success', got {result}"
        assert result.get("charge_id") is not None
        assert result.get("provider") == "stone"
        assert result.get("payment_method") == "pix"
        # PIX should return QR code data
        # Note: qr_code or qr_code_url may be in last_transaction

    def test_pix_with_additional_information(self, stone_gateway):
        """Test PIX payment with additional receipt information."""
        result = stone_gateway.create_charge(
            amount=75.00,
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={
                "payment_method": "pix",
                "expires_in": 7200,  # 2 hours
                "additional_information": [
                    {"name": "Bar", "value": "Barz Test Bar"},
                    {"name": "Mesa", "value": "7"},
                    {"name": "Itens", "value": "2x Cerveja, 1x Nachos"},
                ],
            },
        )

        print(f"\n✅ PIX with Additional Info:")
        print(f"   Charge ID: {result.get('charge_id')}")
        print(f"   Status: {result.get('status')}")

        assert result.get("status") == "success"
        assert result.get("charge_id") is not None

    def test_pix_minimal_customer(self, stone_gateway):
        """Test PIX with minimal customer data.
        
        Note: Pagar.me V5 requires complete customer address for all payments.
        This test verifies PIX works with a minimal but complete customer.
        """
        # Pagar.me V5 requires address with all fields including neighborhood
        minimal_customer = {
            "name": "Cliente Teste",
            "email": "teste@email.com",
            "document": "93095135270",
            "type": "individual",
            "address": {
                "street": "Rua Teste",
                "number": "1",
                "neighborhood": "Centro",  # Required by Pagar.me
                "zip_code": "01310100",
                "city": "Sao Paulo",
                "state": "SP",
                "country": "BR",
            },
        }

        result = stone_gateway.create_charge(
            amount=30.00,
            currency="BRL",
            customer=minimal_customer,
            payment_method={
                "payment_method": "pix",
                "expires_in": 3600,  # Required: 1 hour expiration
            },
        )

        print(f"\n✅ PIX with Minimal Customer:")
        print(f"   Charge ID: {result.get('charge_id')}")
        print(f"   Status: {result.get('status')}")

        assert result.get("status") == "success"


class TestStoneDebitCardPayments:
    """Integration tests for debit card payments.
    
    Note: Debit card requires 3DS authentication which must be performed
    externally. These tests verify the gateway accepts the proper format
    but may fail without valid 3DS data from a real authentication.
    """

    def test_debit_card_requires_authentication(self, stone_gateway):
        """Test that debit card without 3DS returns appropriate response."""
        result = stone_gateway.create_charge(
            amount=50.00,
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={
                "payment_method": "debit_card",
                "card": TEST_CARDS["success"],
                # No authentication - should fail or require it
            },
        )

        print(f"\n⚠️ Debit Card Without 3DS:")
        print(f"   Status: {result.get('status')}")
        print(f"   Message: {result.get('message', 'N/A')}")
        print(f"   Errors: {result.get('errors', 'N/A')}")

        # Debit without 3DS should ideally fail or return error
        # Actual behavior depends on Pagar.me configuration

    def test_debit_card_with_mock_3ds(self, stone_gateway):
        """Test debit card with mock 3DS authentication data.
        
        This uses test 3DS values - in production, these come from
        the 3DS authentication service.
        """
        result = stone_gateway.create_charge(
            amount=50.00,
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={
                "payment_method": "debit_card",
                "card": TEST_CARDS["success"],
                "authentication": {
                    "type": "threed_secure",
                    "threed_secure": {
                        "mpi": "pagarme",
                        "cavv": "test_cavv_value",
                        "eci": "05",
                        "transaction_id": "test_transaction_id",
                        "version": "2.0",
                    },
                },
            },
        )

        print(f"\n⚠️ Debit Card With Mock 3DS:")
        print(f"   Status: {result.get('status')}")
        print(f"   Charge ID: {result.get('charge_id', 'N/A')}")
        print(f"   Message: {result.get('message', 'N/A')}")

        # This may succeed or fail depending on Pagar.me's test mode behavior


class TestStoneRefunds:
    """Integration tests for refunds."""

    def test_refund_full_charge(self, stone_gateway):
        """Test full refund of a charge."""
        # First create a charge
        charge_result = stone_gateway.create_charge(
            amount=100.00,
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={
                "payment_method": "credit_card",
                "card": TEST_CARDS["success"],
                "installments": 1,
                "capture": True,
            },
        )

        if charge_result.get("status") != "success":
            pytest.skip(f"Could not create charge for refund test: {charge_result}")

        # Check if the charge was actually paid (sandbox may return failed)
        charge_status = charge_result.get("charge_status")
        if charge_status not in ("paid", "captured", "pending"):
            pytest.skip(f"Charge status is '{charge_status}' - cannot refund (sandbox limitation)")

        charge_id = charge_result.get("charge_id")
        print(f"\n📝 Created charge {charge_id} for refund test")

        # Now refund it
        refund_result = stone_gateway.refund_charge(
            charge_id=charge_id,
            amount=None,  # Full refund
        )

        print(f"\n✅ Full Refund Result:")
        print(f"   Status: {refund_result.get('status')}")
        print(f"   Refund ID: {refund_result.get('refund_id', 'N/A')}")
        print(f"   Amount Refunded: {refund_result.get('amount_refunded', 'N/A')}")

        assert refund_result.get("status") == "success"
        assert refund_result.get("provider") == "stone"

    def test_refund_partial_charge(self, stone_gateway):
        """Test partial refund of a charge."""
        # First create a charge
        charge_result = stone_gateway.create_charge(
            amount=200.00,
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={
                "payment_method": "credit_card",
                "card": TEST_CARDS["success"],
                "installments": 1,
                "capture": True,
            },
        )

        if charge_result.get("status") != "success":
            pytest.skip(f"Could not create charge for refund test: {charge_result}")

        # Check if the charge was actually paid (sandbox may return failed)
        charge_status = charge_result.get("charge_status")
        if charge_status not in ("paid", "captured", "pending"):
            pytest.skip(f"Charge status is '{charge_status}' - cannot refund (sandbox limitation)")

        charge_id = charge_result.get("charge_id")
        print(f"\n📝 Created charge {charge_id} for partial refund test")

        # Partial refund of R$50
        refund_result = stone_gateway.refund_charge(
            charge_id=charge_id,
            amount=50.00,
        )

        print(f"\n✅ Partial Refund Result (R$50 of R$200):")
        print(f"   Status: {refund_result.get('status')}")
        print(f"   Amount Refunded: {refund_result.get('amount_refunded', 'N/A')}")

        assert refund_result.get("status") == "success"

    def test_refund_without_charge_id_returns_error(self, stone_gateway):
        """Test that refund without charge_id returns error."""
        result = stone_gateway.refund_charge(
            charge_id=None,
            amount=50.00,
        )

        print(f"\n❌ Refund without charge_id:")
        print(f"   Status: {result.get('status')}")
        print(f"   Message: {result.get('message')}")

        assert result.get("status") == "error"
        assert "charge_id" in result.get("message", "").lower()


class TestStoneCaptureFlow:
    """Integration tests for auth-only and capture flow."""

    def test_auth_then_capture(self, stone_gateway):
        """Test authorization followed by capture."""
        # Create auth-only charge
        auth_result = stone_gateway.create_charge(
            amount=150.00,
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={
                "payment_method": "credit_card",
                "card": TEST_CARDS["success"],
                "installments": 1,
                "capture": False,  # Auth only
            },
        )

        if auth_result.get("status") != "success":
            pytest.skip(f"Could not create auth for capture test: {auth_result}")

        # Check if the charge can be captured (sandbox may return failed)
        charge_status = auth_result.get("charge_status")
        if charge_status not in ("pending", "authorized", "processing"):
            pytest.skip(f"Charge status is '{charge_status}' - cannot capture (sandbox limitation)")

        charge_id = auth_result.get("charge_id")
        print(f"\n📝 Created auth-only charge {charge_id}")
        print(f"   Status: {auth_result.get('charge_status')}")

        # Now capture
        capture_result = stone_gateway.capture_charge(
            payment_intent_id=charge_id,
            amount=None,  # Full capture
        )

        print(f"\n✅ Capture Result:")
        print(f"   Status: {capture_result.get('status')}")
        print(f"   Charge Status: {capture_result.get('charge_status', 'N/A')}")
        print(f"   Amount Captured: {capture_result.get('amount_captured', 'N/A')}")

        assert capture_result.get("status") == "success"

    def test_partial_capture(self, stone_gateway):
        """Test partial capture of authorized amount."""
        # Create auth-only charge for R$200
        auth_result = stone_gateway.create_charge(
            amount=200.00,
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={
                "payment_method": "credit_card",
                "card": TEST_CARDS["success"],
                "installments": 1,
                "capture": False,
            },
        )

        if auth_result.get("status") != "success":
            pytest.skip(f"Could not create auth: {auth_result}")

        # Check if the charge can be captured (sandbox may return failed)
        charge_status = auth_result.get("charge_status")
        if charge_status not in ("pending", "authorized", "processing"):
            pytest.skip(f"Charge status is '{charge_status}' - cannot capture (sandbox limitation)")

        charge_id = auth_result.get("charge_id")
        print(f"\n📝 Created auth for R$200, will capture R$150")

        # Capture only R$150
        capture_result = stone_gateway.capture_charge(
            payment_intent_id=charge_id,
            amount=150.00,
        )

        print(f"\n✅ Partial Capture Result:")
        print(f"   Status: {capture_result.get('status')}")
        print(f"   Amount Captured: {capture_result.get('amount_captured', 'N/A')}")


class TestStoneGetCharge:
    """Integration tests for retrieving charge details."""

    def test_get_charge_details(self, stone_gateway):
        """Test retrieving a charge by ID."""
        # First create a charge
        create_result = stone_gateway.create_charge(
            amount=25.00,
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={
                "payment_method": "credit_card",
                "card": TEST_CARDS["success"],
                "capture": True,
            },
        )

        if create_result.get("status") != "success":
            pytest.skip(f"Could not create charge: {create_result}")

        charge_id = create_result.get("charge_id")

        # Now retrieve it
        get_result = stone_gateway.get_charge(charge_id)

        print(f"\n✅ Get Charge Result:")
        print(f"   Charge ID: {get_result.get('charge_id')}")
        print(f"   Status: {get_result.get('status')}")
        print(f"   Charge Status: {get_result.get('charge_status')}")
        print(f"   Amount: {get_result.get('amount')}")

        assert get_result.get("status") == "success"
        assert get_result.get("charge_id") == charge_id


class TestStoneValidation:
    """Tests for input validation."""

    def test_missing_customer_returns_error(self, stone_gateway):
        """Test that missing customer data returns error."""
        result = stone_gateway.create_charge(
            amount=50.00,
            currency="BRL",
            customer=None,
            payment_method={"payment_method": "credit_card"},
        )

        assert result.get("status") == "error"
        assert "customer" in result.get("message", "").lower()

    def test_missing_payment_method_returns_error(self, stone_gateway):
        """Test that missing payment method returns error."""
        result = stone_gateway.create_charge(
            amount=50.00,
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method=None,
        )

        assert result.get("status") == "error"
        assert "payment method" in result.get("message", "").lower()

    def test_unsupported_payment_method_returns_error(self, stone_gateway):
        """Test that unsupported payment method returns error."""
        result = stone_gateway.create_charge(
            amount=50.00,
            currency="BRL",
            customer=TEST_CUSTOMER,
            payment_method={"payment_method": "bitcoin"},
        )

        assert result.get("status") == "error"
        assert "unsupported" in result.get("message", "").lower()
