"""
dobar API Error Contract Implementation

This module provides standardized error responses following the mobile app contract.
All errors use the same JSON structure for consistent frontend handling.

Response format:
{
    "error_code": "ERROR_CODE_HERE",
    "message": "Human-readable error message",
    "details": {"field_name": ["Error message 1"]},  # Optional
    "gateway_code": "GATEWAY_SPECIFIC_CODE",          # Optional (payments)
    "transaction_id": "txn_123456"                    # Optional (payments)
}
"""

from pydantic import BaseModel
from typing import Optional, Dict, List, Any
from enum import Enum


class ErrorCode(str, Enum):
    """All standardized error codes as defined in API_ERROR_CONTRACT.md"""
    
    # General Errors
    UNKNOWN = "UNKNOWN"
    NETWORK_TIMEOUT = "NETWORK_TIMEOUT"
    NETWORK_ERROR = "NETWORK_ERROR"
    NO_INTERNET = "NO_INTERNET"
    SERVER_UNAVAILABLE = "SERVER_UNAVAILABLE"
    BAD_REQUEST = "BAD_REQUEST"
    NOT_FOUND = "NOT_FOUND"
    CONFLICT = "CONFLICT"
    VALIDATION_ERROR = "VALIDATION_ERROR"
    RATE_LIMITED = "RATE_LIMITED"
    MAINTENANCE_MODE = "MAINTENANCE_MODE"
    
    # Authentication Errors
    UNAUTHORIZED = "UNAUTHORIZED"
    FORBIDDEN = "FORBIDDEN"
    SESSION_EXPIRED = "SESSION_EXPIRED"
    INVALID_TOKEN = "INVALID_TOKEN"
    MFA_REQUIRED = "MFA_REQUIRED"
    MFA_INVALID = "MFA_INVALID"
    
    # Payment Errors
    PAYMENT_DECLINED = "PAYMENT_DECLINED"
    PAYMENT_EXPIRED = "PAYMENT_EXPIRED"
    INSUFFICIENT_FUNDS = "INSUFFICIENT_FUNDS"
    INVALID_CARD = "INVALID_CARD"
    CARD_EXPIRED = "CARD_EXPIRED"
    PIX_EXPIRED = "PIX_EXPIRED"
    PAYMENT_PROCESSING = "PAYMENT_PROCESSING"
    REFUND_FAILED = "REFUND_FAILED"
    WALLET_LIMIT_EXCEEDED = "WALLET_LIMIT_EXCEEDED"
    MINIMUM_AMOUNT_NOT_MET = "MINIMUM_AMOUNT_NOT_MET"
    MAXIMUM_AMOUNT_EXCEEDED = "MAXIMUM_AMOUNT_EXCEEDED"
    
    # Order Errors
    ORDER_NOT_FOUND = "ORDER_NOT_FOUND"
    ORDER_CANCELLED = "ORDER_CANCELLED"
    ORDER_ALREADY_PAID = "ORDER_ALREADY_PAID"
    ORDER_EXPIRED = "ORDER_EXPIRED"
    
    # User Errors
    USER_NOT_FOUND = "USER_NOT_FOUND"
    EMAIL_IN_USE = "EMAIL_IN_USE"
    PHONE_IN_USE = "PHONE_IN_USE"
    INVALID_CPF = "INVALID_CPF"
    INVALID_RG = "INVALID_RG"
    DOCUMENT_IN_USE = "DOCUMENT_IN_USE"
    
    # Partner Errors
    PARTNER_NOT_FOUND = "PARTNER_NOT_FOUND"
    PARTNER_CLOSED = "PARTNER_CLOSED"
    ITEM_UNAVAILABLE = "ITEM_UNAVAILABLE"
    
    # Cart Errors
    CART_ITEM_NOT_FOUND = "CART_ITEM_NOT_FOUND"
    CART_EMPTY = "CART_EMPTY"

    # Invitation Errors
    INVITATION_EXPIRED = "INVITATION_EXPIRED"
    INVITATION_REVOKED = "INVITATION_REVOKED"
    INVITATION_CONTACT_MISMATCH = "INVITATION_CONTACT_MISMATCH"
    INVITATION_CONTACT_UNVERIFIED = "INVITATION_CONTACT_UNVERIFIED"
    INVITATION_INVALID = "INVITATION_INVALID"
    INVITATION_ALREADY_USED = "INVITATION_ALREADY_USED"
    
    # Promotion Errors
    PROMOTION_EXPIRED = "PROMOTION_EXPIRED"
    PROMOTION_NOT_APPLICABLE = "PROMOTION_NOT_APPLICABLE"
    OFFER_ALREADY_REDEEMED = "OFFER_ALREADY_REDEEMED"

    # Pro Coupon Errors
    PRO_SUBSCRIPTION_REQUIRED = "PRO_SUBSCRIPTION_REQUIRED"
    PRO_COUPON_QUOTA_EXCEEDED = "PRO_COUPON_QUOTA_EXCEEDED"


# Default user-facing messages for each error code
ERROR_MESSAGES: Dict[ErrorCode, str] = {
    ErrorCode.UNKNOWN: "An unexpected error occurred",
    ErrorCode.NETWORK_TIMEOUT: "Connection timed out",
    ErrorCode.NETWORK_ERROR: "Network connection failed",
    ErrorCode.NO_INTERNET: "No internet connection",
    ErrorCode.SERVER_UNAVAILABLE: "Server is temporarily unavailable",
    ErrorCode.BAD_REQUEST: "Invalid request",
    ErrorCode.NOT_FOUND: "Resource not found",
    ErrorCode.CONFLICT: "Resource already exists",
    ErrorCode.VALIDATION_ERROR: "Invalid data provided",
    ErrorCode.RATE_LIMITED: "Too many requests, please try again later",
    ErrorCode.MAINTENANCE_MODE: "Service is under maintenance",
    
    ErrorCode.UNAUTHORIZED: "Authentication required",
    ErrorCode.FORBIDDEN: "Access denied",
    ErrorCode.SESSION_EXPIRED: "Your session has expired",
    ErrorCode.INVALID_TOKEN: "Invalid authentication token",
    
    ErrorCode.PAYMENT_DECLINED: "Payment was declined",
    ErrorCode.PAYMENT_EXPIRED: "Payment has expired",
    ErrorCode.INSUFFICIENT_FUNDS: "Insufficient funds",
    ErrorCode.INVALID_CARD: "Invalid card details",
    ErrorCode.CARD_EXPIRED: "Card has expired",
    ErrorCode.PIX_EXPIRED: "PIX payment has expired",
    ErrorCode.PAYMENT_PROCESSING: "Payment is being processed",
    ErrorCode.REFUND_FAILED: "Refund could not be processed",
    ErrorCode.WALLET_LIMIT_EXCEEDED: "Wallet limit exceeded",
    ErrorCode.MINIMUM_AMOUNT_NOT_MET: "Minimum amount not met",
    ErrorCode.MAXIMUM_AMOUNT_EXCEEDED: "Maximum amount exceeded",
    
    ErrorCode.ORDER_NOT_FOUND: "Order not found",
    ErrorCode.ORDER_CANCELLED: "Order has been cancelled",
    ErrorCode.ORDER_ALREADY_PAID: "Order has already been paid",
    ErrorCode.ORDER_EXPIRED: "Order has expired",
    
    ErrorCode.USER_NOT_FOUND: "User not found",
    ErrorCode.EMAIL_IN_USE: "Email is already registered",
    ErrorCode.PHONE_IN_USE: "Phone number is already registered",
    ErrorCode.INVALID_CPF: "Invalid CPF number",
    ErrorCode.INVALID_RG: "Invalid RG number",
    ErrorCode.DOCUMENT_IN_USE: "Document is already registered",
    
    ErrorCode.PARTNER_NOT_FOUND: "Partner not found",
    ErrorCode.PARTNER_CLOSED: "Partner is currently closed",
    ErrorCode.ITEM_UNAVAILABLE: "Item is not available",
    
    ErrorCode.CART_ITEM_NOT_FOUND: "Cart item not found",
    ErrorCode.CART_EMPTY: "Cart is empty",
    ErrorCode.INVITATION_EXPIRED: "Invitation expired",
    ErrorCode.INVITATION_REVOKED: "Invitation revoked",
    ErrorCode.INVITATION_CONTACT_MISMATCH: "Invitation recipient does not match authenticated user",
    ErrorCode.INVITATION_CONTACT_UNVERIFIED: "Invitation recipient is not verified",
    ErrorCode.INVITATION_INVALID: "Invitation not found",
    ErrorCode.INVITATION_ALREADY_USED: "Invitation already used",
    
    ErrorCode.PROMOTION_EXPIRED: "Promotion has expired",
    ErrorCode.PROMOTION_NOT_APPLICABLE: "Promotion is not applicable",
    ErrorCode.OFFER_ALREADY_REDEEMED: "Offer has already been redeemed",

    ErrorCode.PRO_SUBSCRIPTION_REQUIRED: "Dobar Pro subscription required for cashback promotions",
    ErrorCode.PRO_COUPON_QUOTA_EXCEEDED: "Monthly Pro coupon allowance exhausted",
}


class ErrorResponse(BaseModel):
    """
    Standardized error response following mobile app contract.
    """
    error_code: str
    message: str
    details: Optional[Dict[str, List[str]]] = None
    gateway_code: Optional[str] = None
    transaction_id: Optional[str] = None


class APIError(Exception):
    """
    Custom exception that follows the dobar API error contract.
    
    Usage:
        raise APIError.not_found("Bar not found")
        raise APIError.validation_error(details={"email": ["Invalid format"]})
        raise APIError.payment_declined(gateway_code="insufficient_funds", transaction_id="txn_123")
    """
    
    def __init__(
        self,
        status_code: int,
        error_code: ErrorCode,
        message: Optional[str] = None,
        details: Optional[Dict[str, List[str]]] = None,
        gateway_code: Optional[str] = None,
        transaction_id: Optional[str] = None
    ):
        self.status_code = status_code
        self.error_code = error_code
        self.message = message or ERROR_MESSAGES.get(error_code, "An error occurred")
        self.details = details
        self.gateway_code = gateway_code
        self.transaction_id = transaction_id
        super().__init__(self.message)
    
    def to_response(self) -> ErrorResponse:
        """Convert exception to ErrorResponse model."""
        return ErrorResponse(
            error_code=self.error_code.value,
            message=self.message,
            details=self.details,
            gateway_code=self.gateway_code,
            transaction_id=self.transaction_id
        )
    
    # ============== General Errors ==============
    
    @classmethod
    def bad_request(cls, message: Optional[str] = None, details: Optional[Dict[str, List[str]]] = None):
        return cls(400, ErrorCode.BAD_REQUEST, message, details)
    
    @classmethod
    def not_found(cls, message: Optional[str] = None):
        return cls(404, ErrorCode.NOT_FOUND, message)
    
    @classmethod
    def conflict(cls, message: Optional[str] = None):
        return cls(409, ErrorCode.CONFLICT, message)
    
    @classmethod
    def validation_error(cls, message: Optional[str] = None, details: Optional[Dict[str, List[str]]] = None):
        return cls(422, ErrorCode.VALIDATION_ERROR, message or "Validation failed", details)
    
    @classmethod
    def server_error(cls, message: Optional[str] = None):
        return cls(500, ErrorCode.SERVER_UNAVAILABLE, message or "An internal error occurred")
    
    @classmethod
    def rate_limited(cls, message: Optional[str] = None):
        return cls(429, ErrorCode.RATE_LIMITED, message)
    
    # ============== Authentication Errors ==============
    
    @classmethod
    def unauthorized(cls, message: Optional[str] = None):
        return cls(401, ErrorCode.UNAUTHORIZED, message)
    
    @classmethod
    def forbidden(cls, message: Optional[str] = None):
        return cls(403, ErrorCode.FORBIDDEN, message)
    
    @classmethod
    def session_expired(cls, message: Optional[str] = None):
        return cls(401, ErrorCode.SESSION_EXPIRED, message or "Your session has expired. Please log in again.")
    
    @classmethod
    def invalid_token(cls, message: Optional[str] = None):
        return cls(401, ErrorCode.INVALID_TOKEN, message)
    
    # ============== Payment Errors ==============
    
    @classmethod
    def payment_declined(
        cls, 
        message: Optional[str] = None, 
        gateway_code: Optional[str] = None,
        transaction_id: Optional[str] = None
    ):
        return cls(400, ErrorCode.PAYMENT_DECLINED, message, gateway_code=gateway_code, transaction_id=transaction_id)
    
    @classmethod
    def insufficient_funds(
        cls, 
        message: Optional[str] = None, 
        gateway_code: Optional[str] = None,
        transaction_id: Optional[str] = None
    ):
        return cls(400, ErrorCode.INSUFFICIENT_FUNDS, message, gateway_code=gateway_code, transaction_id=transaction_id)
    
    @classmethod
    def invalid_card(cls, message: Optional[str] = None, gateway_code: Optional[str] = None):
        return cls(400, ErrorCode.INVALID_CARD, message, gateway_code=gateway_code)
    
    @classmethod
    def card_expired(cls, message: Optional[str] = None, gateway_code: Optional[str] = None):
        return cls(400, ErrorCode.CARD_EXPIRED, message, gateway_code=gateway_code)
    
    @classmethod
    def pix_expired(cls, message: Optional[str] = None, transaction_id: Optional[str] = None):
        return cls(400, ErrorCode.PIX_EXPIRED, message, transaction_id=transaction_id)
    
    @classmethod
    def refund_failed(cls, message: Optional[str] = None, transaction_id: Optional[str] = None):
        return cls(400, ErrorCode.REFUND_FAILED, message, transaction_id=transaction_id)
    
    @classmethod
    def wallet_limit_exceeded(cls, message: Optional[str] = None):
        return cls(400, ErrorCode.WALLET_LIMIT_EXCEEDED, message)
    
    # ============== Order Errors ==============
    
    @classmethod
    def order_not_found(cls, message: Optional[str] = None):
        return cls(404, ErrorCode.ORDER_NOT_FOUND, message)
    
    @classmethod
    def order_cancelled(cls, message: Optional[str] = None):
        return cls(400, ErrorCode.ORDER_CANCELLED, message)
    
    @classmethod
    def order_already_paid(cls, message: Optional[str] = None):
        return cls(409, ErrorCode.ORDER_ALREADY_PAID, message)
    
    @classmethod
    def order_expired(cls, message: Optional[str] = None):
        return cls(400, ErrorCode.ORDER_EXPIRED, message)
    
    # ============== User Errors ==============
    
    @classmethod
    def user_not_found(cls, message: Optional[str] = None):
        return cls(404, ErrorCode.USER_NOT_FOUND, message)
    
    @classmethod
    def email_in_use(cls, message: Optional[str] = None):
        return cls(409, ErrorCode.EMAIL_IN_USE, message)
    
    @classmethod
    def phone_in_use(cls, message: Optional[str] = None):
        return cls(409, ErrorCode.PHONE_IN_USE, message)
    
    # ============== Partner/Bar Errors ==============
    
    @classmethod
    def partner_not_found(cls, message: Optional[str] = None):
        return cls(404, ErrorCode.PARTNER_NOT_FOUND, message or "Bar or restaurant not found")
    
    @classmethod
    def partner_closed(cls, message: Optional[str] = None):
        return cls(400, ErrorCode.PARTNER_CLOSED, message)
    
    @classmethod
    def item_unavailable(cls, message: Optional[str] = None):
        return cls(400, ErrorCode.ITEM_UNAVAILABLE, message)
    
    # ============== Cart Errors ==============
    
    @classmethod
    def cart_item_not_found(cls, message: Optional[str] = None):
        return cls(404, ErrorCode.CART_ITEM_NOT_FOUND, message)
    
    @classmethod
    def cart_empty(cls, message: Optional[str] = None):
        return cls(400, ErrorCode.CART_EMPTY, message)

    # ============== Pro Coupon Errors ==============

    @classmethod
    def pro_subscription_required(cls, message: Optional[str] = None):
        return cls(403, ErrorCode.PRO_SUBSCRIPTION_REQUIRED, message)

    @classmethod
    def pro_coupon_quota_exceeded(cls, message: Optional[str] = None):
        return cls(409, ErrorCode.PRO_COUPON_QUOTA_EXCEEDED, message)


# ============== Gateway Error Mapping ==============

# Pagar.me gateway codes → APIError
PAGARME_ERROR_MAP = {
    "refused": ErrorCode.PAYMENT_DECLINED,
    "insufficient_funds": ErrorCode.INSUFFICIENT_FUNDS,
    "invalid_card_number": ErrorCode.INVALID_CARD,
    "expired_card": ErrorCode.CARD_EXPIRED,
    "processing_error": ErrorCode.PAYMENT_DECLINED,
}

# Stripe gateway codes → APIError  
STRIPE_ERROR_MAP = {
    "card_declined": ErrorCode.PAYMENT_DECLINED,
    "insufficient_funds": ErrorCode.INSUFFICIENT_FUNDS,
    "invalid_number": ErrorCode.INVALID_CARD,
    "expired_card": ErrorCode.CARD_EXPIRED,
    "processing_error": ErrorCode.PAYMENT_DECLINED,
}

# PayPal gateway codes → APIError
PAYPAL_ERROR_MAP = {
    "INSTRUMENT_DECLINED": ErrorCode.PAYMENT_DECLINED,
    "INSUFFICIENT_FUNDS": ErrorCode.INSUFFICIENT_FUNDS,
    "INVALID_ACCOUNT": ErrorCode.INVALID_CARD,
    "EXPIRED_CARD": ErrorCode.CARD_EXPIRED,
}


def map_gateway_error(gateway: str, gateway_code: str, transaction_id: Optional[str] = None) -> APIError:
    """
    Map a payment gateway error code to an APIError.
    
    Args:
        gateway: The payment gateway name (pagarme, stripe, paypal)
        gateway_code: The error code from the gateway
        transaction_id: Optional transaction ID for tracking
    
    Returns:
        APIError: Properly formatted API error
    """
    error_maps = {
        "pagarme": PAGARME_ERROR_MAP,
        "stripe": STRIPE_ERROR_MAP,
        "paypal": PAYPAL_ERROR_MAP,
    }
    
    error_map = error_maps.get(gateway.lower(), {})
    error_code = error_map.get(gateway_code, ErrorCode.PAYMENT_DECLINED)
    
    return APIError(
        status_code=400,
        error_code=error_code,
        message=ERROR_MESSAGES.get(error_code),
        gateway_code=gateway_code,
        transaction_id=transaction_id
    )


# ============== Backward Compatibility ==============
# Keep CustomHTTPException as an alias for migration
CustomHTTPException = APIError