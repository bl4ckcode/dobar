"""
dobar-payment-engine: Unified Exception Taxonomy

A standardized error hierarchy for payment processing that abstracts
gateway-specific errors into a unified, actionable exception model.
"""

from enum import Enum
from typing import Optional, Dict, Any
from datetime import datetime
import uuid


class PaymentErrorCode(str, Enum):
    """Standardized error codes across all payment gateways."""
    
    # Authentication & Authorization
    INVALID_CREDENTIALS = "invalid_credentials"
    UNAUTHORIZED = "unauthorized"
    FORBIDDEN = "forbidden"
    
    # Validation Errors
    INVALID_AMOUNT = "invalid_amount"
    INVALID_CURRENCY = "invalid_currency"
    INVALID_CUSTOMER = "invalid_customer"
    INVALID_PAYMENT_METHOD = "invalid_payment_method"
    MISSING_REQUIRED_FIELD = "missing_required_field"
    
    # Card Errors
    CARD_DECLINED = "card_declined"
    CARD_EXPIRED = "card_expired"
    CARD_INVALID = "card_invalid"
    INSUFFICIENT_FUNDS = "insufficient_funds"
    CARD_NOT_SUPPORTED = "card_not_supported"
    CVV_INVALID = "cvv_invalid"
    
    # Transaction Errors
    DUPLICATE_TRANSACTION = "duplicate_transaction"
    TRANSACTION_NOT_FOUND = "transaction_not_found"
    TRANSACTION_ALREADY_REFUNDED = "transaction_already_refunded"
    TRANSACTION_ALREADY_CAPTURED = "transaction_already_captured"
    TRANSACTION_EXPIRED = "transaction_expired"
    REFUND_EXCEEDS_AMOUNT = "refund_exceeds_amount"
    
    # Gateway Errors
    GATEWAY_UNAVAILABLE = "gateway_unavailable"
    GATEWAY_TIMEOUT = "gateway_timeout"
    GATEWAY_ERROR = "gateway_error"
    GATEWAY_NOT_CONFIGURED = "gateway_not_configured"
    UNSUPPORTED_OPERATION = "unsupported_operation"
    
    # Rate Limiting
    RATE_LIMITED = "rate_limited"
    
    # Idempotency
    IDEMPOTENCY_CONFLICT = "idempotency_conflict"
    
    # General
    UNKNOWN_ERROR = "unknown_error"


class PaymentException(Exception):
    """Base exception for all payment-related errors."""
    
    def __init__(
        self,
        code: PaymentErrorCode,
        message: str,
        gateway: Optional[str] = None,
        gateway_code: Optional[str] = None,
        gateway_message: Optional[str] = None,
        request_id: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        retryable: bool = False,
        details: Optional[Dict[str, Any]] = None,
    ):
        self.code = code
        self.message = message
        self.gateway = gateway
        self.gateway_code = gateway_code
        self.gateway_message = gateway_message
        self.request_id = request_id or str(uuid.uuid4())
        self.idempotency_key = idempotency_key
        self.retryable = retryable
        self.details = details or {}
        self.timestamp = datetime.utcnow().isoformat()
        super().__init__(self.message)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert exception to a serializable dictionary."""
        return {
            "error": {
                "code": self.code.value,
                "message": self.message,
                "gateway": self.gateway,
                "gateway_code": self.gateway_code,
                "gateway_message": self.gateway_message,
                "request_id": self.request_id,
                "idempotency_key": self.idempotency_key,
                "retryable": self.retryable,
                "details": self.details,
                "timestamp": self.timestamp,
            }
        }


class CardDeclinedException(PaymentException):
    """Card was declined by the issuer."""
    
    def __init__(self, message: str = "Card was declined", **kwargs):
        super().__init__(
            code=PaymentErrorCode.CARD_DECLINED,
            message=message,
            retryable=False,
            **kwargs
        )


class InsufficientFundsException(PaymentException):
    """Card has insufficient funds."""
    
    def __init__(self, message: str = "Insufficient funds", **kwargs):
        super().__init__(
            code=PaymentErrorCode.INSUFFICIENT_FUNDS,
            message=message,
            retryable=False,
            **kwargs
        )


class GatewayUnavailableException(PaymentException):
    """Payment gateway is temporarily unavailable."""
    
    def __init__(self, message: str = "Payment gateway unavailable", **kwargs):
        super().__init__(
            code=PaymentErrorCode.GATEWAY_UNAVAILABLE,
            message=message,
            retryable=True,
            **kwargs
        )


class DuplicateTransactionException(PaymentException):
    """Attempt to create a duplicate transaction."""
    
    def __init__(
        self,
        message: str = "Duplicate transaction detected",
        original_transaction_id: Optional[str] = None,
        **kwargs
    ):
        details = kwargs.pop("details", {})
        if original_transaction_id:
            details["original_transaction_id"] = original_transaction_id
        super().__init__(
            code=PaymentErrorCode.DUPLICATE_TRANSACTION,
            message=message,
            retryable=False,
            details=details,
            **kwargs
        )


class IdempotencyConflictException(PaymentException):
    """Idempotency key was already used with different parameters."""
    
    def __init__(self, message: str = "Idempotency key conflict", **kwargs):
        super().__init__(
            code=PaymentErrorCode.IDEMPOTENCY_CONFLICT,
            message=message,
            retryable=False,
            **kwargs
        )


class ValidationException(PaymentException):
    """Request validation failed."""
    
    def __init__(
        self,
        message: str,
        field: Optional[str] = None,
        code: PaymentErrorCode = PaymentErrorCode.MISSING_REQUIRED_FIELD,
        **kwargs
    ):
        details = kwargs.pop("details", {})
        if field:
            details["field"] = field
        super().__init__(
            code=code,
            message=message,
            retryable=False,
            details=details,
            **kwargs
        )


class RateLimitedException(PaymentException):
    """Rate limit exceeded."""
    
    def __init__(
        self,
        message: str = "Rate limit exceeded",
        retry_after: Optional[int] = None,
        **kwargs
    ):
        details = kwargs.pop("details", {})
        if retry_after:
            details["retry_after_seconds"] = retry_after
        super().__init__(
            code=PaymentErrorCode.RATE_LIMITED,
            message=message,
            retryable=True,
            details=details,
            **kwargs
        )
