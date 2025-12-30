"""
dobar-payment-engine: Core Module

Scientific-based payment processing infrastructure with:
- Distributed locking for concurrent transaction safety
- Transaction state machines for auditability
- Metrics and observability interfaces
- Async-first architecture
- Timeout and deadline management
- Webhook signature verification
- Intelligent gateway routing
"""

from dobar_payment.core.locks import (
    DistributedLock,
    LockProvider,
    InMemoryLockProvider,
    TransactionLock,
    get_lock_provider,
    set_lock_provider,
)
from dobar_payment.core.state_machine import (
    TransactionState,
    TransactionEvent,
    TransactionStateMachine,
    StateTransition,
    create_credit_card_machine,
    create_pix_machine,
)
from dobar_payment.core.metrics import (
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
)
from dobar_payment.core.timeouts import (
    Deadline,
    TimeoutManager,
    TimeoutError,
    with_timeout,
    get_timeout_manager,
    set_timeout_manager,
)
from dobar_payment.core.validation import (
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
)
from dobar_payment.core.webhooks import (
    WebhookValidator,
    WebhookPayload,
    WebhookVerificationError,
    WebhookHandler,
    StripeWebhookValidator,
    PagarmeWebhookValidator,
    PayPalWebhookValidator,
)
from dobar_payment.core.router import (
    GatewayRouter,
    SmartRouter,
    GatewayConfig,
    GatewayStats,
    RoutingStrategy,
    get_router,
    set_router,
)

__all__ = [
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
