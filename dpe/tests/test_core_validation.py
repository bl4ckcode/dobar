"""Tests for transaction validation module."""

import pytest
from datetime import datetime

from dobar_payment.core.validation import (
    TransactionValidator,
    ValidationResult,
    ValidationIssue,
    ValidationSeverity,
    AmountValidationRule,
    CurrencyValidationRule,
    CustomerValidationRule,
    PaymentMethodValidationRule,
)


class TestValidationResult:
    """Tests for ValidationResult."""
    
    def test_empty_result_is_valid(self):
        """Test that empty result is valid."""
        result = ValidationResult()
        assert result.is_valid
        assert len(result.errors) == 0
    
    def test_add_error_makes_invalid(self):
        """Test adding an error makes result invalid."""
        result = ValidationResult()
        result.add_error("TEST_ERROR", "Test error message")
        
        assert not result.is_valid
        assert len(result.errors) == 1
    
    def test_add_warning_keeps_valid(self):
        """Test adding a warning keeps result valid."""
        result = ValidationResult()
        result.add_warning("TEST_WARNING", "Test warning")
        
        assert result.is_valid
        assert len(result.warnings) == 1
    
    def test_merge_results(self):
        """Test merging validation results."""
        result1 = ValidationResult()
        result1.add_error("ERROR_1", "Error 1")
        
        result2 = ValidationResult()
        result2.add_warning("WARNING_1", "Warning 1")
        
        result1.merge(result2)
        
        assert len(result1.errors) == 1
        assert len(result1.warnings) == 1
    
    def test_to_dict(self):
        """Test serialization to dict."""
        result = ValidationResult()
        result.add_error("TEST", "Test error", field="test_field")
        
        data = result.to_dict()
        assert data["is_valid"] is False
        assert data["error_count"] == 1
        assert data["warning_count"] == 0


class TestAmountValidationRule:
    """Tests for AmountValidationRule."""
    
    def test_valid_amount(self):
        """Test valid amount passes."""
        rule = AmountValidationRule()
        result = rule.validate(100.00, "BRL", None, None)
        
        assert result.is_valid
    
    def test_missing_amount(self):
        """Test missing amount fails."""
        rule = AmountValidationRule()
        result = rule.validate(None, "BRL", None, None)
        
        assert not result.is_valid
        assert any(e.code == "AMOUNT_REQUIRED" for e in result.errors)
    
    def test_negative_amount(self):
        """Test negative amount fails."""
        rule = AmountValidationRule()
        result = rule.validate(-10.00, "BRL", None, None)
        
        assert not result.is_valid
        assert any(e.code == "AMOUNT_INVALID" for e in result.errors)
    
    def test_zero_amount(self):
        """Test zero amount fails."""
        rule = AmountValidationRule()
        result = rule.validate(0, "BRL", None, None)
        
        assert not result.is_valid
    
    def test_amount_too_low(self):
        """Test amount below minimum fails."""
        rule = AmountValidationRule(min_amount=10.00)
        result = rule.validate(5.00, "BRL", None, None)
        
        assert not result.is_valid
        assert any(e.code == "AMOUNT_TOO_LOW" for e in result.errors)
    
    def test_amount_too_high(self):
        """Test amount above maximum fails."""
        rule = AmountValidationRule(max_amount=100.00)
        result = rule.validate(200.00, "BRL", None, None)
        
        assert not result.is_valid
        assert any(e.code == "AMOUNT_TOO_HIGH" for e in result.errors)


class TestCurrencyValidationRule:
    """Tests for CurrencyValidationRule."""
    
    def test_valid_currency(self):
        """Test valid currency passes."""
        rule = CurrencyValidationRule()
        result = rule.validate(100, "BRL", None, None)
        
        assert result.is_valid
    
    def test_missing_currency(self):
        """Test missing currency fails."""
        rule = CurrencyValidationRule()
        result = rule.validate(100, None, None, None)
        
        assert not result.is_valid
        assert any(e.code == "CURRENCY_REQUIRED" for e in result.errors)
    
    def test_invalid_format(self):
        """Test invalid currency format fails."""
        rule = CurrencyValidationRule()
        result = rule.validate(100, "INVALID", None, None)
        
        assert not result.is_valid
        assert any(e.code == "CURRENCY_INVALID_FORMAT" for e in result.errors)
    
    def test_unsupported_currency(self):
        """Test unsupported currency fails."""
        rule = CurrencyValidationRule(supported_currencies={"BRL", "USD"})
        result = rule.validate(100, "EUR", None, None)
        
        assert not result.is_valid
        assert any(e.code == "CURRENCY_NOT_SUPPORTED" for e in result.errors)


class TestCustomerValidationRule:
    """Tests for CustomerValidationRule."""
    
    def test_valid_customer(self):
        """Test valid customer passes."""
        rule = CustomerValidationRule()
        customer = {
            "name": "Test Customer",
            "email": "test@example.com",
        }
        result = rule.validate(100, "BRL", customer, None)
        
        assert result.is_valid
    
    def test_missing_customer(self):
        """Test missing customer fails."""
        rule = CustomerValidationRule()
        result = rule.validate(100, "BRL", None, None)
        
        assert not result.is_valid
        assert any(e.code == "CUSTOMER_REQUIRED" for e in result.errors)
    
    def test_missing_name(self):
        """Test missing name fails."""
        rule = CustomerValidationRule()
        result = rule.validate(100, "BRL", {"email": "test@example.com"}, None)
        
        assert not result.is_valid
        assert any(e.code == "CUSTOMER_NAME_REQUIRED" for e in result.errors)
    
    def test_invalid_email(self):
        """Test invalid email fails."""
        rule = CustomerValidationRule()
        customer = {
            "name": "Test",
            "email": "invalid-email",
        }
        result = rule.validate(100, "BRL", customer, None)
        
        assert not result.is_valid
        assert any(e.code == "CUSTOMER_EMAIL_INVALID" for e in result.errors)
    
    def test_valid_cpf(self):
        """Test valid CPF passes."""
        rule = CustomerValidationRule(require_document=True)
        customer = {
            "name": "Test",
            "email": "test@example.com",
            "document": "52998224725",  # Valid CPF
        }
        result = rule.validate(100, "BRL", customer, None)
        
        # Should pass (document is valid)
        assert not any(e.code == "CUSTOMER_CPF_INVALID" for e in result.errors)
    
    def test_invalid_cpf(self):
        """Test invalid CPF fails."""
        rule = CustomerValidationRule(require_document=True)
        customer = {
            "name": "Test",
            "email": "test@example.com",
            "document": "11111111111",  # Invalid CPF
        }
        result = rule.validate(100, "BRL", customer, None)
        
        assert any(e.code == "CUSTOMER_CPF_INVALID" for e in result.errors)


class TestPaymentMethodValidationRule:
    """Tests for PaymentMethodValidationRule."""
    
    def test_valid_card(self):
        """Test valid card passes."""
        rule = PaymentMethodValidationRule()
        payment_method = {
            "payment_method": "credit_card",
            "card": {
                "number": "4111111111111111",
                "holder_name": "Test User",
                "exp_month": 12,
                "exp_year": 2030,
                "cvv": "123",
            },
        }
        result = rule.validate(100, "BRL", None, payment_method)
        
        assert result.is_valid
    
    def test_missing_payment_method(self):
        """Test missing payment method fails."""
        rule = PaymentMethodValidationRule()
        result = rule.validate(100, "BRL", None, None)
        
        assert not result.is_valid
        assert any(e.code == "PAYMENT_METHOD_REQUIRED" for e in result.errors)
    
    def test_invalid_type(self):
        """Test invalid payment method type fails."""
        rule = PaymentMethodValidationRule()
        result = rule.validate(100, "BRL", None, {"payment_method": "bitcoin"})
        
        assert not result.is_valid
        assert any(e.code == "PAYMENT_METHOD_TYPE_INVALID" for e in result.errors)
    
    def test_luhn_validation(self):
        """Test Luhn algorithm validation."""
        rule = PaymentMethodValidationRule()
        payment_method = {
            "payment_method": "credit_card",
            "card": {
                "number": "1234567890123456",  # Invalid Luhn
                "holder_name": "Test",
                "exp_month": 12,
                "exp_year": 2030,
                "cvv": "123",
            },
        }
        result = rule.validate(100, "BRL", None, payment_method)
        
        assert any(e.code == "CARD_NUMBER_INVALID" for e in result.errors)
    
    def test_expired_card(self):
        """Test expired card fails."""
        rule = PaymentMethodValidationRule()
        payment_method = {
            "payment_method": "credit_card",
            "card": {
                "number": "4111111111111111",
                "holder_name": "Test",
                "exp_month": 1,
                "exp_year": 2020,  # Expired
                "cvv": "123",
            },
        }
        result = rule.validate(100, "BRL", None, payment_method)
        
        assert any(e.code == "CARD_EXPIRED" for e in result.errors)
    
    def test_pix_method(self):
        """Test PIX payment method passes."""
        rule = PaymentMethodValidationRule()
        payment_method = {"payment_method": "pix"}
        result = rule.validate(100, "BRL", None, payment_method)
        
        assert result.is_valid


class TestTransactionValidator:
    """Tests for TransactionValidator."""
    
    def test_default_validator(self):
        """Test default validator with valid data."""
        validator = TransactionValidator()
        
        result = validator.validate(
            amount=100.00,
            currency="BRL",
            customer={"name": "Test", "email": "test@example.com"},
            payment_method={
                "payment_method": "credit_card",
                "card": {
                    "number": "4111111111111111",
                    "holder_name": "Test",
                    "exp_month": 12,
                    "exp_year": 2030,
                    "cvv": "123",
                },
            },
        )
        
        assert result.is_valid
    
    def test_strict_validator(self):
        """Test strict validator requires more fields."""
        validator = TransactionValidator.strict()
        
        result = validator.validate(
            amount=100.00,
            currency="BRL",
            customer={"name": "Test"},  # Missing document and address
            payment_method={"payment_method": "pix"},
        )
        
        assert not result.is_valid
    
    def test_lenient_validator(self):
        """Test lenient validator with minimal data."""
        validator = TransactionValidator.lenient()
        
        result = validator.validate(
            amount=100.00,
            currency="BRL",
        )
        
        assert result.is_valid
    
    def test_validate_or_raise(self):
        """Test validate_or_raise raises on invalid."""
        validator = TransactionValidator()
        
        with pytest.raises(ValueError):
            validator.validate_or_raise(amount=-10.00)
