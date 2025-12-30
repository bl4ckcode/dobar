# dobar-payment-engine

A payment processing engine for Python applications. 
Provides a unified interface for multiple payment gateways with built-in reliability patterns.

## Supported Gateways

- **Stripe** - Global payments, Apple Pay, Google Pay
- **Stone/Pagar.me** - Brazil (PIX, credit cards, boleto)
- **PayPal** - Global PayPal payments

## Installation

```bash
pip install git+https://github.com/bl4ckcode/dobar-payment-engine.git
```

## Features

### Reliability

- **Idempotency** - Prevents duplicate charges using request deduplication
- **Circuit Breaker** - Stops requests to unhealthy gateways
- **Rate Limiting** - Token bucket algorithm to prevent overload

### Distributed Locking

Prevent double-charging with transaction locks.

### State Machine

Track transaction lifecycle.

### Intelligent Routing

Route transactions to optimal gateways.

## Response Format

All gateways return a standardized response:

## License

Carlos Augusto Alves
