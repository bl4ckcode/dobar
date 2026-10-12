"""
dobar-payment-engine: Transaction Validation

Scientific-based validation layer for payment transactions.

Problem Solved:
- Catching invalid transactions before gateway submission
- Preventing fraud patterns
- Ensuring data quality
- Reducing gateway errors and fees

Validation Approach:
- Rule-based validation with composable rules
- Early fail-fast pattern
- Detailed error reporting
- Extensible for custom business rules

References:
- Domain-Driven Design validation patterns
- Railway Oriented Programming for error handling
"""

from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, List, Set, Tuple
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime
import re
import logging

logger = logging.getLogger("dobar.payment.validation")


class ValidationSeverity(str, Enum):
    """Severity level for validation issues."""
    ERROR = "error"      # Blocks transaction
    WARNING = "warning"  # Allows but flags for review
    INFO = "info"        # Informational only


@dataclass
class ValidationIssue:
    """A single validation issue."""
    code: str
    message: str
    field_name: Optional[str] = None
    severity: ValidationSeverity = ValidationSeverity.ERROR
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "code": self.code,
            "message": self.message,
            "field": self.field_name,
            "severity": self.severity.value,
            "metadata": self.metadata,
        }


@dataclass
class ValidationResult:
    """Result of validation containing all issues."""
    issues: List[ValidationIssue] = field(default_factory=list)
    
    @property
    def is_valid(self) -> bool:
        """Check if validation passed (no errors)."""
        return not any(i.severity == ValidationSeverity.ERROR for i in self.issues)
    
    @property
    def errors(self) -> List[ValidationIssue]:
        """Get all error-level issues."""
        return [i for i in self.issues if i.severity == ValidationSeverity.ERROR]
    
    @property
    def warnings(self) -> List[ValidationIssue]:
        """Get all warning-level issues."""
        return [i for i in self.issues if i.severity == ValidationSeverity.WARNING]
    
    def add_error(
        self,
        code: str,
        message: str,
        field: Optional[str] = None,
        **metadata,
    ) -> "ValidationResult":
        """Add an error issue."""
        self.issues.append(ValidationIssue(
            code=code,
            message=message,
            field_name=field,
            severity=ValidationSeverity.ERROR,
            metadata=metadata,
        ))
        return self
    
    def add_warning(
        self,
        code: str,
        message: str,
        field: Optional[str] = None,
        **metadata,
    ) -> "ValidationResult":
        """Add a warning issue."""
        self.issues.append(ValidationIssue(
            code=code,
            message=message,
            field_name=field,
            severity=ValidationSeverity.WARNING,
            metadata=metadata,
        ))
        return self
    
    def merge(self, other: "ValidationResult") -> "ValidationResult":
        """Merge another validation result into this one."""
        self.issues.extend(other.issues)
        return self
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "is_valid": self.is_valid,
            "error_count": len(self.errors),
            "warning_count": len(self.warnings),
            "issues": [i.to_dict() for i in self.issues],
        }


class ValidationRule(ABC):
    """
    Abstract base class for validation rules.
    
    Each rule validates a specific aspect of a transaction.
    Rules are composable and can be combined into validators.
    """
    
    @property
    @abstractmethod
    def name(self) -> str:
        """Unique name for this rule."""
        pass
    
    @abstractmethod
    def validate(
        self,
        amount: Optional[float],
        currency: Optional[str],
        customer: Optional[Dict[str, Any]],
        payment_method: Optional[Dict[str, Any]],
        **kwargs,
    ) -> ValidationResult:
        """
        Validate transaction parameters.
        
        Returns:
            ValidationResult with any issues found
        """
        pass


class AmountValidationRule(ValidationRule):
    """
    Validates transaction amount.
    
    Checks:
    - Amount is positive
    - Amount is within gateway limits
    - Amount precision is valid for currency
    """
    
    # Currency-specific decimal places
    CURRENCY_DECIMALS: Dict[str, int] = {
        "BRL": 2,
        "USD": 2,
        "EUR": 2,
        "JPY": 0,  # No decimal places
        "BTC": 8,
    }
    
    # Default limits (can be overridden)
    MIN_AMOUNT: float = 0.01
    MAX_AMOUNT: float = 1_000_000.00
    
    def __init__(
        self,
        min_amount: Optional[float] = None,
        max_amount: Optional[float] = None,
    ):
        self._min = min_amount or self.MIN_AMOUNT
        self._max = max_amount or self.MAX_AMOUNT
    
    @property
    def name(self) -> str:
        return "amount_validation"
    
    def validate(
        self,
        amount: Optional[float],
        currency: Optional[str],
        customer: Optional[Dict[str, Any]],
        payment_method: Optional[Dict[str, Any]],
        **kwargs,
    ) -> ValidationResult:
        result = ValidationResult()
        
        if amount is None:
            result.add_error(
                "AMOUNT_REQUIRED",
                "Amount is required",
                field="amount",
            )
            return result
        
        # Check positive
        if amount <= 0:
            result.add_error(
                "AMOUNT_INVALID",
                "Amount must be positive",
                field="amount",
                value=amount,
            )
            return result
        
        # Check minimum
        if amount < self._min:
            result.add_error(
                "AMOUNT_TOO_LOW",
                f"Amount must be at least {self._min}",
                field="amount",
                value=amount,
                minimum=self._min,
            )
        
        # Check maximum
        if amount > self._max:
            result.add_error(
                "AMOUNT_TOO_HIGH",
                f"Amount cannot exceed {self._max}",
                field="amount",
                value=amount,
                maximum=self._max,
            )
        
        # Check precision for currency
        if currency:
            decimals = self.CURRENCY_DECIMALS.get(currency.upper(), 2)
            multiplier = 10 ** decimals
            if round(amount * multiplier) != amount * multiplier:
                result.add_warning(
                    "AMOUNT_PRECISION",
                    f"Amount has too many decimal places for {currency}",
                    field="amount",
                    value=amount,
                    expected_decimals=decimals,
                )
        
        return result


class CurrencyValidationRule(ValidationRule):
    """
    Validates currency code.
    
    Checks:
    - Currency is provided
    - Currency is valid ISO 4217 code
    - Currency is supported by gateway
    """
    
    # Common currencies
    VALID_CURRENCIES: Set[str] = {
        "BRL", "USD", "EUR", "GBP", "CAD", "AUD",
        "JPY", "CNY", "MXN", "ARS", "CLP", "COP",
    }
    
    def __init__(self, supported_currencies: Optional[Set[str]] = None):
        self._supported = supported_currencies
    
    @property
    def name(self) -> str:
        return "currency_validation"
    
    def validate(
        self,
        amount: Optional[float],
        currency: Optional[str],
        customer: Optional[Dict[str, Any]],
        payment_method: Optional[Dict[str, Any]],
        **kwargs,
    ) -> ValidationResult:
        result = ValidationResult()
        
        if not currency:
            result.add_error(
                "CURRENCY_REQUIRED",
                "Currency is required",
                field="currency",
            )
            return result
        
        currency_upper = currency.upper()
        
        # Check ISO 4217 format (3 letters)
        if not re.match(r"^[A-Z]{3}$", currency_upper):
            result.add_error(
                "CURRENCY_INVALID_FORMAT",
                "Currency must be a 3-letter ISO 4217 code",
                field="currency",
                value=currency,
            )
            return result
        
        # Check if recognized
        if currency_upper not in self.VALID_CURRENCIES:
            result.add_warning(
                "CURRENCY_UNRECOGNIZED",
                f"Currency {currency} may not be supported",
                field="currency",
                value=currency,
            )
        
        # Check if supported by gateway
        if self._supported and currency_upper not in self._supported:
            result.add_error(
                "CURRENCY_NOT_SUPPORTED",
                f"Currency {currency} is not supported",
                field="currency",
                value=currency,
                supported=list(self._supported),
            )
        
        return result


class CustomerValidationRule(ValidationRule):
    """
    Validates customer data.
    
    Checks:
    - Required fields present
    - Email format
    - Document format (CPF/CNPJ for Brazil)
    - Phone format
    """
    
    # Email regex pattern
    EMAIL_PATTERN = re.compile(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$")
    
    # Brazilian document patterns
    CPF_PATTERN = re.compile(r"^\d{11}$")
    CNPJ_PATTERN = re.compile(r"^\d{14}$")
    
    def __init__(self, require_document: bool = False, require_address: bool = False):
        self._require_document = require_document
        self._require_address = require_address
    
    @property
    def name(self) -> str:
        return "customer_validation"
    
    def validate(
        self,
        amount: Optional[float],
        currency: Optional[str],
        customer: Optional[Dict[str, Any]],
        payment_method: Optional[Dict[str, Any]],
        **kwargs,
    ) -> ValidationResult:
        result = ValidationResult()
        
        if not customer:
            result.add_error(
                "CUSTOMER_REQUIRED",
                "Customer information is required",
                field="customer",
            )
            return result
        
        # Check name
        name = customer.get("name")
        if not name or len(name.strip()) < 2:
            result.add_error(
                "CUSTOMER_NAME_REQUIRED",
                "Customer name is required",
                field="customer.name",
            )
        
        # Check email
        email = customer.get("email")
        if email:
            if not self.EMAIL_PATTERN.match(email):
                result.add_error(
                    "CUSTOMER_EMAIL_INVALID",
                    "Invalid email format",
                    field="customer.email",
                    value=email,
                )
        else:
            result.add_warning(
                "CUSTOMER_EMAIL_MISSING",
                "Customer email is recommended",
                field="customer.email",
            )
        
        # Check document
        document = customer.get("document")
        if document:
            # Strip non-digits
            doc_clean = re.sub(r"\D", "", document)
            
            if len(doc_clean) == 11:
                if not self._validate_cpf(doc_clean):
                    result.add_error(
                        "CUSTOMER_CPF_INVALID",
                        "Invalid CPF",
                        field="customer.document",
                    )
            elif len(doc_clean) == 14:
                if not self._validate_cnpj(doc_clean):
                    result.add_error(
                        "CUSTOMER_CNPJ_INVALID",
                        "Invalid CNPJ",
                        field="customer.document",
                    )
            else:
                result.add_warning(
                    "CUSTOMER_DOCUMENT_FORMAT",
                    "Document format not recognized",
                    field="customer.document",
                )
        elif self._require_document:
            result.add_error(
                "CUSTOMER_DOCUMENT_REQUIRED",
                "Customer document is required",
                field="customer.document",
            )
        
        # Check address if required
        if self._require_address:
            address = customer.get("address")
            if not address:
                result.add_error(
                    "CUSTOMER_ADDRESS_REQUIRED",
                    "Customer address is required",
                    field="customer.address",
                )
            else:
                # Validate address fields
                required_fields = ["street", "city", "state", "zip_code", "country"]
                for field_name in required_fields:
                    if not address.get(field_name):
                        result.add_error(
                            f"ADDRESS_{field_name.upper()}_REQUIRED",
                            f"Address {field_name} is required",
                            field=f"customer.address.{field_name}",
                        )
        
        return result
    
    def _validate_cpf(self, cpf: str) -> bool:
        """Validate Brazilian CPF using check digits."""
        if len(cpf) != 11 or cpf == cpf[0] * 11:
            return False
        
        # Calculate first check digit
        sum1 = sum(int(cpf[i]) * (10 - i) for i in range(9))
        d1 = (sum1 * 10 % 11) % 10
        
        # Calculate second check digit
        sum2 = sum(int(cpf[i]) * (11 - i) for i in range(10))
        d2 = (sum2 * 10 % 11) % 10
        
        return cpf[-2:] == f"{d1}{d2}"
    
    def _validate_cnpj(self, cnpj: str) -> bool:
        """Validate Brazilian CNPJ using check digits."""
        if len(cnpj) != 14 or cnpj == cnpj[0] * 14:
            return False
        
        # First check digit
        weights1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
        sum1 = sum(int(cnpj[i]) * weights1[i] for i in range(12))
        d1 = 11 - (sum1 % 11)
        d1 = 0 if d1 >= 10 else d1
        
        # Second check digit
        weights2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
        sum2 = sum(int(cnpj[i]) * weights2[i] for i in range(13))
        d2 = 11 - (sum2 % 11)
        d2 = 0 if d2 >= 10 else d2
        
        return cnpj[-2:] == f"{d1}{d2}"


class PaymentMethodValidationRule(ValidationRule):
    """
    Validates payment method data.
    
    Checks:
    - Payment method type is valid
    - Card number format (Luhn algorithm)
    - Expiration date
    - CVV format
    """
    
    VALID_METHODS: Set[str] = {
        "credit_card", "debit_card", "pix", "boleto",
        "paypal", "apple_pay", "google_pay",
    }
    
    @property
    def name(self) -> str:
        return "payment_method_validation"
    
    def validate(
        self,
        amount: Optional[float],
        currency: Optional[str],
        customer: Optional[Dict[str, Any]],
        payment_method: Optional[Dict[str, Any]],
        **kwargs,
    ) -> ValidationResult:
        result = ValidationResult()
        
        if not payment_method:
            result.add_error(
                "PAYMENT_METHOD_REQUIRED",
                "Payment method is required",
                field="payment_method",
            )
            return result
        
        method_type = payment_method.get("payment_method", payment_method.get("type"))
        
        if not method_type:
            result.add_error(
                "PAYMENT_METHOD_TYPE_REQUIRED",
                "Payment method type is required",
                field="payment_method.type",
            )
            return result
        
        if method_type not in self.VALID_METHODS:
            result.add_error(
                "PAYMENT_METHOD_TYPE_INVALID",
                f"Invalid payment method type: {method_type}",
                field="payment_method.type",
                value=method_type,
                valid_types=list(self.VALID_METHODS),
            )
            return result
        
        # Card-specific validation
        if method_type in ("credit_card", "debit_card"):
            card = payment_method.get("card", {})
            result.merge(self._validate_card(card))
        
        return result
    
    def _validate_card(self, card: Dict[str, Any]) -> ValidationResult:
        """Validate card details."""
        result = ValidationResult()
        
        # Card number
        number = card.get("number", "")
        number_clean = re.sub(r"\D", "", number)
        
        if not number_clean:
            result.add_error(
                "CARD_NUMBER_REQUIRED",
                "Card number is required",
                field="payment_method.card.number",
            )
        elif len(number_clean) < 13 or len(number_clean) > 19:
            result.add_error(
                "CARD_NUMBER_LENGTH",
                "Card number must be 13-19 digits",
                field="payment_method.card.number",
            )
        elif not self._luhn_check(number_clean):
            result.add_error(
                "CARD_NUMBER_INVALID",
                "Invalid card number",
                field="payment_method.card.number",
            )
        
        # Holder name
        holder = card.get("holder_name", "")
        if not holder or len(holder.strip()) < 2:
            result.add_error(
                "CARD_HOLDER_REQUIRED",
                "Card holder name is required",
                field="payment_method.card.holder_name",
            )
        
        # Expiration
        exp_month = card.get("exp_month")
        exp_year = card.get("exp_year")
        
        if not exp_month or not exp_year:
            result.add_error(
                "CARD_EXPIRATION_REQUIRED",
                "Card expiration date is required",
                field="payment_method.card.exp_month",
            )
        else:
            try:
                month = int(exp_month)
                year = int(exp_year)
                
                if month < 1 or month > 12:
                    result.add_error(
                        "CARD_EXPIRATION_MONTH_INVALID",
                        "Invalid expiration month",
                        field="payment_method.card.exp_month",
                    )
                
                # Normalize 2-digit year
                if year < 100:
                    year += 2000
                
                now = datetime.utcnow()
                if year < now.year or (year == now.year and month < now.month):
                    result.add_error(
                        "CARD_EXPIRED",
                        "Card has expired",
                        field="payment_method.card.exp_year",
                    )
            except (ValueError, TypeError):
                result.add_error(
                    "CARD_EXPIRATION_FORMAT",
                    "Invalid expiration date format",
                    field="payment_method.card.exp_month",
                )
        
        # CVV
        cvv = card.get("cvv", "")
        if not cvv:
            result.add_error(
                "CARD_CVV_REQUIRED",
                "Card CVV is required",
                field="payment_method.card.cvv",
            )
        elif not re.match(r"^\d{3,4}$", str(cvv)):
            result.add_error(
                "CARD_CVV_INVALID",
                "CVV must be 3-4 digits",
                field="payment_method.card.cvv",
            )
        
        return result
    
    def _luhn_check(self, number: str) -> bool:
        """Validate card number using Luhn algorithm."""
        def digits_of(n):
            return [int(d) for d in str(n)]
        
        digits = digits_of(number)
        odd_digits = digits[-1::-2]
        even_digits = digits[-2::-2]
        
        checksum = sum(odd_digits)
        for d in even_digits:
            checksum += sum(digits_of(d * 2))
        
        return checksum % 10 == 0


class TransactionValidator:
    """
    Composite validator for payment transactions.
    
    Combines multiple validation rules and runs them all.
    
    Usage:
        validator = TransactionValidator([
            AmountValidationRule(),
            CurrencyValidationRule(),
            CustomerValidationRule(),
            PaymentMethodValidationRule(),
        ])
        
        result = validator.validate(
            amount=100.00,
            currency="BRL",
            customer={...},
            payment_method={...},
        )
        
        if not result.is_valid:
            raise ValidationError(result.errors)
    """
    
    def __init__(self, rules: Optional[List[ValidationRule]] = None):
        self._rules = rules or self._default_rules()
    
    @staticmethod
    def _default_rules() -> List[ValidationRule]:
        """Create default set of validation rules."""
        return [
            AmountValidationRule(),
            CurrencyValidationRule(),
            CustomerValidationRule(require_document=False, require_address=False),
            PaymentMethodValidationRule(),
        ]
    
    @classmethod
    def strict(cls) -> "TransactionValidator":
        """Create a strict validator with all checks enabled."""
        return cls([
            AmountValidationRule(min_amount=1.00, max_amount=100_000.00),
            CurrencyValidationRule(),
            CustomerValidationRule(require_document=True, require_address=True),
            PaymentMethodValidationRule(),
        ])
    
    @classmethod
    def lenient(cls) -> "TransactionValidator":
        """Create a lenient validator with minimal checks."""
        return cls([
            AmountValidationRule(),
            CurrencyValidationRule(),
        ])
    
    def add_rule(self, rule: ValidationRule) -> "TransactionValidator":
        """Add a validation rule."""
        self._rules.append(rule)
        return self
    
    def validate(
        self,
        amount: Optional[float] = None,
        currency: Optional[str] = None,
        customer: Optional[Dict[str, Any]] = None,
        payment_method: Optional[Dict[str, Any]] = None,
        **kwargs,
    ) -> ValidationResult:
        """
        Run all validation rules.
        
        Returns combined ValidationResult from all rules.
        """
        combined = ValidationResult()
        
        for rule in self._rules:
            try:
                rule_result = rule.validate(
                    amount=amount,
                    currency=currency,
                    customer=customer,
                    payment_method=payment_method,
                    **kwargs,
                )
                combined.merge(rule_result)
            except Exception as e:
                logger.error(f"Validation rule {rule.name} failed: {e}")
                combined.add_error(
                    "VALIDATION_RULE_ERROR",
                    f"Validation rule {rule.name} failed: {e}",
                )
        
        return combined
    
    def validate_or_raise(
        self,
        amount: Optional[float] = None,
        currency: Optional[str] = None,
        customer: Optional[Dict[str, Any]] = None,
        payment_method: Optional[Dict[str, Any]] = None,
        **kwargs,
    ) -> None:
        """
        Validate and raise exception if invalid.
        
        Raises:
            ValueError: If validation fails
        """
        result = self.validate(amount, currency, customer, payment_method, **kwargs)
        
        if not result.is_valid:
            error_messages = [f"{e.field_name or 'general'}: {e.message}" for e in result.errors]
            raise ValueError(f"Validation failed: {'; '.join(error_messages)}")


# ============================================================================
# Default Validator Instance
# ============================================================================

_default_validator: Optional[TransactionValidator] = None


def get_validator() -> TransactionValidator:
    """Get the global transaction validator (lazy initialization)."""
    global _default_validator
    if _default_validator is None:
        _default_validator = TransactionValidator()
    return _default_validator


def set_validator(validator: TransactionValidator) -> None:
    """Set a custom transaction validator."""
    global _default_validator
    _default_validator = validator
