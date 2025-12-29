"""
dobar-payment-engine

Enterprise-grade payment processing engine for Latin America.
Supports multiple gateways: Stripe, Stone/Pagar.me, PayPal.

Usage:
    from dobar_payment import PaymentEngine
    
    engine = PaymentEngine()
    result = engine.charge(
        amount=100.00,
        currency="BRL",
        customer={...},
        payment_method={...},
    )
"""

__version__ = "1.0.0"
__author__ = "Carlos Alves"

from .interfaces import PaymentGateway, GatewayCapability
from .factory import PaymentEngine, GatewayRegistry, get_registry
from .exceptions import (
    PaymentException,
    PaymentErrorCode,
    CardDeclinedException,
    InsufficientFundsException,
    GatewayUnavailableException,
    DuplicateTransactionException,
    IdempotencyConflictException,
    RateLimitedException,
)
from .models import (
    PaymentStatus,
    PaymentMethodType,
    Currency,
    Customer,
    Address,
    Card,
    ChargeRequest,
    TransactionResponse,
)
from .middleware import (
    PaymentContext,
    CircuitBreaker,
    CircuitState,
    RateLimiter,
    IdempotencyStore,
)

__all__ = [
    # Version
    "__version__",
    
    # Core
    "PaymentEngine",
    "PaymentGateway",
    "GatewayRegistry",
    "GatewayCapability",
    "get_registry",
    
    # Models
    "PaymentStatus",
    "PaymentMethodType",
    "Currency",
    "Customer",
    "Address",
    "Card",
    "ChargeRequest",
    "ChargeResponse",
    
    # Exceptions
    "PaymentException",
    "PaymentErrorCode",
    "CardDeclinedException",
    "InsufficientFundsException",
    "GatewayUnavailableException",
    "DuplicateTransactionException",
    "IdempotencyConflictException",
    "RateLimitedException",
    
    # Middleware
    "PaymentContext",
    "CircuitBreaker",
    "CircuitState",
    "RateLimiter",
    "IdempotencyStore",
]
