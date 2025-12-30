# dobar-payment-engine

A payment processing engine for Python applications. Provides a unified interface for multiple payment gateways with built-in reliability patterns.

## Supported Gateways

- **Stripe** - Global payments, Apple Pay, Google Pay
- **Stone/Pagar.me** - Brazil (PIX, credit cards, boleto)
- **PayPal** - Global PayPal payments

## Installation

```bash
pip install git+https://github.com/bl4ckcode/dobar-payment-engine.git
```

## Quick Start

```python
from dobar_payment import PaymentEngine

engine = PaymentEngine(gateway="stripe")

result = engine.charge(
    amount=100.00,
    currency="BRL",
    customer={
        "name": "John Doe",
        "email": "john@example.com",
        "document": "12345678900",
    },
    payment_method={
        "payment_method": "credit_card",
        "card": {
            "number": "4111111111111111",
            "holder_name": "JOHN DOE",
            "exp_month": 12,
            "exp_year": 2030,
            "cvv": "123",
        },
    },
    idempotency_key="order-123",
)
```

## Configuration

Set the following environment variables:

```bash
# Gateway selection
PAYMENT_GATEWAY=stripe  # stripe, stone, or paypal

# Stripe
STRIPE_API_KEY=sk_...

# Stone/Pagar.me
PAGARME_USERNAME=sk_...
PAGARME_PASSWORD=...
PAGARME_ENV=sandbox

# PayPal
PAYPAL_CLIENT_ID=...
PAYPAL_CLIENT_SECRET=...
PAYPAL_ENV=sandbox
```

## Features

### Reliability

- **Idempotency** - Prevents duplicate charges using request deduplication
- **Circuit Breaker** - Stops requests to unhealthy gateways
- **Rate Limiting** - Token bucket algorithm to prevent overload

### Gateway Selection

```python
from dobar_payment import get_registry

registry = get_registry()

# Select by currency
gateway = registry.get_gateway_for_currency("BRL")  # Returns Stone
gateway = registry.get_gateway_for_currency("USD")  # Returns Stripe

# Health check
health = registry.health_check_all()
```

### Transaction Validation

```python
from dobar_payment import TransactionValidator, get_validator

validator = get_validator()
result = validator.validate(
    amount=100.00,
    currency="BRL",
    customer={"name": "John", "email": "john@example.com"},
    payment_method={"payment_method": "credit_card"},
)

if not result.is_valid:
    print(result.errors)
```

### Distributed Locking

Prevent double-charging with transaction locks:

```python
from dobar_payment import TransactionLock

async with TransactionLock(idempotency_key="order-123"):
    # Only one instance can process this order
    result = engine.charge(...)
```

### State Machine

Track transaction lifecycle:

```python
from dobar_payment import TransactionStateMachine, TransactionEvent

machine = TransactionStateMachine(transaction_id="txn-123")
machine.transition(TransactionEvent.SUBMIT)
machine.transition(TransactionEvent.AUTHORIZE)
machine.transition(TransactionEvent.CAPTURE)

print(machine.current_state)  # TransactionState.CAPTURED
print(machine.history)        # Full audit trail
```

### Intelligent Routing

Route transactions to optimal gateways:

```python
from dobar_payment import SmartRouter, RoutingStrategy

router = SmartRouter()
gateway = router.select(
    amount=100.00,
    currency="BRL",
    strategy=RoutingStrategy.HIGHEST_SUCCESS,
)
```

Available strategies: `PRIORITY`, `ROUND_ROBIN`, `WEIGHTED`, `LEAST_LATENCY`, `HIGHEST_SUCCESS`, `COST_OPTIMIZED`, `ADAPTIVE`

## Response Format

All gateways return a standardized response:

```python
{
    "status": "success",
    "charge_id": "ch_xxx",
    "charge_status": "paid",
    "provider": "stripe",
    "amount": 10000,
    "currency": "BRL",
    "request_id": "uuid-xxx",
    "elapsed_ms": 245.5,
}
```

## Testing

```bash
pip install -e ".[dev]"
pytest tests/ -v
```

## License

MIT
