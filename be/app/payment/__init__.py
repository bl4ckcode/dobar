"""
Payment module for barz-backend.

This module re-exports the dobar-payment-engine package for use in barz-backend.
The actual payment engine implementation lives at:
https://github.com/bl4ckcode/dobar-payment-engine

Usage:
    from app.payment import PaymentEngine, get_payment_gateway
    
    # Or use the FastAPI dependency
    @app.post("/charge")
    def charge(gateway: PaymentGateway = Depends(get_payment_gateway)):
        return gateway.create_charge(...)
"""

# Re-export everything from dobar-payment-engine
from dobar_payment import (
    # Version
    __version__,
    
    # Core Engine
    PaymentEngine,
    PaymentGateway,
    GatewayCapability,
    GatewayRegistry,
    get_registry,
    get_payment_engine,
    get_payment_gateway,
    
    # Models
    PaymentStatus,
    PaymentMethodType,
    Currency,
    Customer,
    Address,
    Card,
    ChargeRequest,
    TransactionResponse,
    
    # Exceptions
    PaymentException,
    PaymentErrorCode,
    CardDeclinedException,
    InsufficientFundsException,
    GatewayUnavailableException,
    DuplicateTransactionException,
    IdempotencyConflictException,
    RateLimitedException,
    
    # Middleware
    PaymentContext,
    CircuitBreaker,
    CircuitState,
    RateLimiter,
    IdempotencyStore,
    
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
    PaymentMetrics,
    GatewayHealthScore,
    Counter,
    Histogram,
    Gauge,
    get_metrics_provider,
    set_metrics_provider,
    get_payment_metrics,
    
    # Timeouts
    Deadline,
    TimeoutManager,
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
    
    # Routing
    GatewayRouter,
    SmartRouter,
    RoutingStrategy,
    GatewayConfig,
    GatewayStats,
    get_router,
    set_router,
    
    # Webhooks
    WebhookHandler,
    WebhookValidator,
    WebhookPayload,
    WebhookVerificationError,
    StripeWebhookValidator,
    PagarmeWebhookValidator,
    PayPalWebhookValidator,
)

__all__ = [
    # Version
    "__version__",
    
    # Core Engine
    "PaymentEngine",
    "PaymentGateway",
    "GatewayCapability",
    "GatewayRegistry",
    "get_registry",
    "get_payment_engine",
    "get_payment_gateway",
    
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
    "PaymentMetrics",
    "GatewayHealthScore",
    "Counter",
    "Histogram",
    "Gauge",
    "get_metrics_provider",
    "set_metrics_provider",
    "get_payment_metrics",
    
    # Timeouts
    "Deadline",
    "TimeoutManager",
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
    
    # Routing
    "GatewayRouter",
    "SmartRouter",
    "RoutingStrategy",
    "GatewayConfig",
    "GatewayStats",
    "get_router",
    "set_router",
    
    # Webhooks
    "WebhookHandler",
    "WebhookValidator",
    "WebhookPayload",
    "WebhookVerificationError",
    "StripeWebhookValidator",
    "PagarmeWebhookValidator",
    "PayPalWebhookValidator",
]
