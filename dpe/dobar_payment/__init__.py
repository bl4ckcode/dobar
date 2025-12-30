"""
dobar-payment-engine

Enterprise-grade payment processing engine for Latin America.
Supports multiple gateways: Stripe, Stone/Pagar.me, PayPal.

Scientific-based payment processing with:
- Distributed locking (prevent double charges)
- Transaction state machines (auditability)
- Intelligent gateway routing (adaptive selection)
- Metrics and observability
- Webhook signature verification
- Transaction validation

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

__version__ = "2.0.0"
__author__ = "Carlos Alves"

from .interfaces import PaymentGateway, GatewayCapability
from .factory import PaymentEngine, GatewayRegistry, get_registry, get_payment_engine
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

# Core Scientific Features
from .core import (
    # Distributed Locks
    DistributedLock,
    LockProvider,
    InMemoryLockProvider,
    TransactionLock,
    get_lock_provider,
    set_lock_provider,
    # State Machine
    TransactionState,
    TransactionEvent,
    TransactionStateMachine,
    StateTransition,
    create_credit_card_machine,
    create_pix_machine,
    # Metrics
    MetricsProvider,
    NullMetricsProvider,
    InMemoryMetricsProvider,
    Counter,
    Histogram,
    Gauge,
    PaymentMetrics,
    GatewayHealthScore,
    get_metrics_provider,
    set_metrics_provider,
    get_payment_metrics,
    # Timeouts
    Deadline,
    TimeoutManager,
    TimeoutError,
    with_timeout,
    get_timeout_manager,
    set_timeout_manager,
    # Validation
    TransactionValidator,
    ValidationResult,
    ValidationRule,
    ValidationIssue,
    ValidationSeverity,
    AmountValidationRule,
    CurrencyValidationRule,
    CustomerValidationRule,
    PaymentMethodValidationRule,
    get_validator,
    set_validator,
    # Webhooks
    WebhookValidator,
    WebhookPayload,
    WebhookVerificationError,
    WebhookHandler,
    StripeWebhookValidator,
    PagarmeWebhookValidator,
    PayPalWebhookValidator,
    # Router
    GatewayRouter,
    SmartRouter,
    GatewayConfig,
    GatewayStats,
    RoutingStrategy,
    get_router,
    set_router,
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
    "get_payment_engine",
    
    # Models
    "PaymentStatus",
    "PaymentMethodType",
    "Currency",
    "Customer",
    "Address",
    "Card",
    "ChargeRequest",
    "TransactionResponse",
    
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
    
    # Distributed Locks
    "DistributedLock",
    "LockProvider",
    "InMemoryLockProvider",
    "TransactionLock",
    "get_lock_provider",
    "set_lock_provider",
    
    # State Machine
    "TransactionState",
    "TransactionEvent",
    "TransactionStateMachine",
    "StateTransition",
    "create_credit_card_machine",
    "create_pix_machine",
    
    # Metrics
    "MetricsProvider",
    "NullMetricsProvider",
    "InMemoryMetricsProvider",
    "Counter",
    "Histogram",
    "Gauge",
    "PaymentMetrics",
    "GatewayHealthScore",
    "get_metrics_provider",
    "set_metrics_provider",
    "get_payment_metrics",
    
    # Timeouts
    "Deadline",
    "TimeoutManager",
    "TimeoutError",
    "with_timeout",
    "get_timeout_manager",
    "set_timeout_manager",
    
    # Validation
    "TransactionValidator",
    "ValidationResult",
    "ValidationRule",
    "ValidationIssue",
    "ValidationSeverity",
    "AmountValidationRule",
    "CurrencyValidationRule",
    "CustomerValidationRule",
    "PaymentMethodValidationRule",
    "get_validator",
    "set_validator",
    
    # Webhooks
    "WebhookValidator",
    "WebhookPayload",
    "WebhookVerificationError",
    "WebhookHandler",
    "StripeWebhookValidator",
    "PagarmeWebhookValidator",
    "PayPalWebhookValidator",
    
    # Router
    "GatewayRouter",
    "SmartRouter",
    "GatewayConfig",
    "GatewayStats",
    "RoutingStrategy",
    "get_router",
    "set_router",
]
