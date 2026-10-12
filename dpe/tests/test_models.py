"""Tests for dobar_payment models."""
import pytest
from dobar_payment.models import (
    PaymentStatus,
    PaymentMethodType,
    Currency,
    Customer,
    Address,
    Card,
    ChargeRequest,
    TransactionResponse,
)


class TestPaymentStatus:
    """Test PaymentStatus enum."""
    
    def test_status_values(self):
        assert PaymentStatus.PENDING.value == "pending"
        assert PaymentStatus.PAID.value == "paid"
        assert PaymentStatus.FAILED.value == "failed"
        assert PaymentStatus.REFUNDED.value == "refunded"


class TestCurrency:
    """Test Currency enum."""
    
    def test_brl_currency(self):
        assert Currency.BRL.value == "BRL"
    
    def test_usd_currency(self):
        assert Currency.USD.value == "USD"


class TestAddress:
    """Test Address model."""
    
    def test_create_address(self):
        addr = Address(
            street="Av Paulista",
            number="1000",
            city="Sao Paulo",
            state="SP",
            zip_code="01310100",
        )
        assert addr.street == "Av Paulista"
        assert addr.country == "BR"  # Default
    
    def test_address_to_line(self):
        addr = Address(
            street="Av Paulista",
            number="1000",
            neighborhood="Bela Vista",
            city="Sao Paulo",
            state="SP",
            zip_code="01310100",
        )
        line = addr.to_line()
        assert "1000" in line
        assert "Av Paulista" in line


class TestCustomer:
    """Test Customer model."""
    
    def test_create_customer(self):
        customer = Customer(
            name="Tony Stark",
            email="tony@avengers.com",
            document="93095135270",
        )
        assert customer.name == "Tony Stark"
        assert customer.document == "93095135270"
    
    def test_document_cleaning(self):
        customer = Customer(
            name="Test User",
            email="test@test.com",
            document="930.951.352-70",
        )
        assert customer.document == "93095135270"


class TestCard:
    """Test Card model."""
    
    def test_card_last_four(self):
        card = Card(
            number="4000000000000010",
            holder_name="TEST USER",
            exp_month=12,
            exp_year=2030,
            cvv="123",
        )
        assert card.last_four == "0010"
    
    def test_card_masked_number(self):
        card = Card(
            number="4000000000000010",
            holder_name="TEST USER",
            exp_month=12,
            exp_year=2030,
            cvv="123",
        )
        assert card.masked_number == "****0010"


class TestTransactionResponse:
    """Test TransactionResponse model."""
    
    def test_success_response(self):
        response = TransactionResponse(
            success=True,
            transaction_id="tx_123",
            status=PaymentStatus.PAID,
            gateway="stripe",
            amount=100.00,
            currency=Currency.BRL,
        )
        assert response.success is True
        assert response.transaction_id == "tx_123"
