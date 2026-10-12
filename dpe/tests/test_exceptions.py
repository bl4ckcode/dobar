"""Tests for dobar_payment exceptions."""
import pytest
from dobar_payment.exceptions import (
    PaymentException,
    PaymentErrorCode,
    CardDeclinedException,
    InsufficientFundsException,
    GatewayUnavailableException,
    DuplicateTransactionException,
)


class TestPaymentErrorCode:
    """Test PaymentErrorCode enum."""
    
    def test_error_codes_exist(self):
        assert PaymentErrorCode.CARD_DECLINED
        assert PaymentErrorCode.INSUFFICIENT_FUNDS
        assert PaymentErrorCode.GATEWAY_ERROR


class TestPaymentException:
    """Test PaymentException base class."""
    
    def test_create_exception(self):
        exc = PaymentException(
            message="Test error",
            code=PaymentErrorCode.GATEWAY_ERROR,
        )
        assert str(exc) == "Test error"
        assert exc.code == PaymentErrorCode.GATEWAY_ERROR
    
    def test_exception_with_details(self):
        exc = PaymentException(
            message="Test error",
            code=PaymentErrorCode.GATEWAY_ERROR,
            details={"key": "value"},
        )
        assert exc.details == {"key": "value"}


class TestSpecificExceptions:
    """Test specific exception types."""
    
    def test_card_declined_exception(self):
        exc = CardDeclinedException("Card was declined")
        assert isinstance(exc, PaymentException)
        assert exc.code == PaymentErrorCode.CARD_DECLINED
    
    def test_insufficient_funds_exception(self):
        exc = InsufficientFundsException("Not enough funds")
        assert isinstance(exc, PaymentException)
        assert exc.code == PaymentErrorCode.INSUFFICIENT_FUNDS
    
    def test_gateway_unavailable_exception(self):
        exc = GatewayUnavailableException("Gateway down")
        assert isinstance(exc, PaymentException)
        assert exc.code == PaymentErrorCode.GATEWAY_UNAVAILABLE
