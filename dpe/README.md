# dobar-payment-engine 💳

**Enterprise-grade payment processing engine for Latin America.**

A unified, production-ready payment gateway abstraction layer that supports multiple providers with built-in safety mechanisms for high-scale operations.

## ✨ Features

### 🌎 Multi-Gateway Support
- **Stripe** - Global payments, Apple Pay, Google Pay
- **Stone/Pagar.me** - Brazil (PIX, credit card, boleto)
- **PayPal** - Global PayPal payments

### 🛡️ Enterprise Safety Mechanisms
- **Idempotency** - Prevent double charges with automatic request deduplication
- **Circuit Breaker** - Automatic failover when gateways are unhealthy
- **Rate Limiting** - Token bucket algorithm to prevent gateway overload
- **Retry with Backoff** - Exponential backoff for transient failures

### 🚀 Production Ready
- Type-safe with Pydantic models
- Structured logging
- Unified error taxonomy
- Request tracing with unique IDs

## 📦 Installation

```bash
pip install dobar-payment-engine
```

Or install from source:

```bash
pip install git+https://github.com/bl4ckcode/dobar-payment-engine.git
```

## 🔧 Quick Start

```python
from dobar_payment import PaymentEngine

# Initialize engine (uses PAYMENT_GATEWAY env var or defaults to stone)
engine = PaymentEngine(gateway="stripe")

# Create a charge
result = engine.charge(
    amount=100.00,
    currency="BRL",
    customer={
        "name": "João Silva",
        "email": "joao@example.com",
        "document": "12345678900",
        "type": "individual",
        "address": {
            "street": "Av Paulista",
            "number": "1000",
            "city": "São Paulo",
            "state": "SP",
            "zip_code": "01310100",
            "country": "BR",
        },
    },
    payment_method={
        "payment_method": "credit_card",
        "card": {
            "number": "4111111111111111",
            "holder_name": "JOAO SILVA",
            "exp_month": 12,
            "exp_year": 2030,
            "cvv": "123",
        },
        "installments": 1,
        "capture": True,
    },
    idempotency_key="unique-order-123",
)

if result["status"] == "success":
    print(f"Charge created: {result['charge_id']}")
else:
    print(f"Error: {result['message']}")
```

## 🔑 Environment Variables

```bash
# Gateway Selection
PAYMENT_GATEWAY=stripe  # or stone, paypal

# Stripe
STRIPE_API_KEY=sk_test_...

# Stone/Pagar.me
PAGARME_USERNAME=sk_test_...
PAGARME_PASSWORD=x
PAGARME_ENV=sandbox  # or production

# PayPal
PAYPAL_CLIENT_ID=...
PAYPAL_CLIENT_SECRET=...
PAYPAL_ENV=sandbox  # or production
```

## 🏗️ Architecture

```
dobar_payment/
├── __init__.py          # Package exports
├── factory.py           # PaymentEngine & GatewayRegistry
├── interfaces.py        # Abstract gateway interface
├── middleware/          # Safety mechanisms
│   └── __init__.py      # Idempotency, Circuit Breaker, Rate Limiter
├── exceptions/          # Unified error taxonomy
│   └── __init__.py      # PaymentException hierarchy
├── models/              # Pydantic models
│   └── __init__.py      # Customer, Card, ChargeRequest, etc.
└── gateways/            # Gateway implementations
    ├── stripe.py        # Stripe gateway
    ├── stone.py         # Stone/Pagar.me gateway
    └── paypal.py        # PayPal gateway
```

## 🔒 Safety Mechanisms

### Idempotency
Prevents double charges by caching results:

```python
# Same idempotency_key returns cached result
result1 = engine.charge(..., idempotency_key="order-123")
result2 = engine.charge(..., idempotency_key="order-123")  # Returns cached

assert result1["charge_id"] == result2["charge_id"]
```

### Circuit Breaker
Automatically stops sending requests to unhealthy gateways:

```python
from dobar_payment import PaymentEngine

# Circuit breaker is enabled by default
engine = PaymentEngine(
    gateway="stripe",
    enable_circuit_breaker=True,  # Default
)

# After 5 consecutive failures, circuit opens for 60 seconds
# Half-open state tests recovery with 3 probe requests
```

### Rate Limiting
Token bucket algorithm prevents overwhelming gateways:

```python
engine = PaymentEngine(
    gateway="stripe",
    enable_rate_limiting=True,  # Default
)
# Default: 10 requests/second, burst of 20
```

## 🌐 Gateway Selection

### Automatic by Currency
```python
from dobar_payment import get_registry

registry = get_registry()
gateway = registry.get_gateway_for_currency("BRL")  # Returns Stone
gateway = registry.get_gateway_for_currency("USD")  # Returns Stripe
```

### Automatic by Region
```python
gateway = registry.get_gateway_for_region("BR")    # Returns Stone
gateway = registry.get_gateway_for_region("LATAM") # Returns Stripe
gateway = registry.get_gateway_for_region("US")    # Returns Stripe
```

### Health Checks
```python
health = registry.health_check_all()
# {
#     "stripe": {"healthy": True, "latency_ms": 45.2},
#     "stone": {"healthy": True, "latency_ms": 120.5},
#     "paypal": {"healthy": True, "latency_ms": 89.1},
# }
```

## 📊 Response Format

All gateways return a standardized response:

```python
{
    "status": "success",           # or "error"
    "charge_id": "ch_xxx",         # Gateway transaction ID
    "charge_status": "paid",       # paid, pending, failed, etc.
    "provider": "stripe",          # Gateway name
    "amount": 10000,               # Amount in cents
    "currency": "BRL",
    "request_id": "uuid-xxx",      # For tracing
    "elapsed_ms": 245.5,           # Processing time
    
    # For PIX payments
    "qr_code": "base64...",
    "qr_code_url": "https://...",
    "pix_copia_e_cola": "00020101...",
    "expires_at": "2024-12-30T12:00:00Z",
}
```

## 🧪 Testing

```bash
# Install dev dependencies
pip install -e ".[dev]"

# Run tests
pytest tests/ -v

# With coverage
pytest tests/ --cov=dobar_payment
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

## 🙏 Acknowledgments

Built with ❤️ for the Latin American fintech ecosystem.

**dobar** (from *do bar* - "from the bar") represents our roots in the hospitality industry, now powering payments worldwide.

---

*Part of the [dobar.app](https://dobar.app) ecosystem*
