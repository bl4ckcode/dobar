# Architecture & Tech Stack

## What This Is

A **Python payment middleware** that abstracts multiple payment gateways (Stone/Pagar.me, Stripe, PayPal) behind a unified interface. It receives standardized payment requests from `barz-backend` and routes them to the appropriate gateway based on country and payment method.

## Project Layout

```
dobar_payment/
├── api/                    # FastAPI HTTP layer (app, routes, schemas, middleware)
├── core/                   # Business logic (router, state_machine, validation, locks, timeouts, webhooks, metrics)
├── gateways/               # Payment provider implementations
│   ├── stone.py            # Brazil — Stone/Pagar.me (PIX, Credit, Debit)
│   ├── stripe.py           # LATAM, Mexico — Stripe
│   └── paypal.py           # US, CA, EU — PayPal
├── models/                 # Domain models
├── middleware/              # Circuit breaker, rate limiting
├── exceptions/             # Error handling
├── pix/                    # PIX BR Code generation (brcode.py, gateway.py)
├── queue/                  # Async job processing (Redis Streams, workers)
├── pagarme_sdk/            # Vendored Pagar.me SDK (DO NOT modify)
└── utils/                  # Currency helpers, etc.
```

## Gateway Routing

Payments are routed by country code:

| Country | Gateway |
|---------|---------|
| BR | `stone` |
| AR, CL, CO, PE, MX | `stripe` |
| US, CA | `paypal` |
| Fallback | `paypal` |

Stripe is the strategic gateway for all **subscription lifecycle operations** (trials, off-session captures) regardless of country.

## Key Patterns

- **State Machine** (`core/state_machine.py`): Transaction lifecycle — `pending → processing → succeeded/failed`
- **Circuit Breaker** (`core/middleware/`): Auto-failover when a gateway errors out repeatedly
- **Idempotency**: All payment ops use `idempotency_key` (24h TTL cache) to prevent duplicate charges
- **Distributed Locks** (`core/locks.py`): In-memory or Redis-based, used for wallet/transaction concurrency

## Running Locally

```bash
pip install -e ".[all]"
uvicorn dobar_payment.api.app:create_app --factory --port 8001
```

## Deployment

- Hosted on **FlyIO**
- All deploys run via **GitHub Actions CI/CD** — never deploy manually
- Gateways auto-load from environment variables at startup
- Always ensure **backward compatibility** for existing users and data

## Environment Variables

```env
DPE_SERVICE_SECRET=<shared_secret_with_BE>
DPE_ENV=production

# PagarMe/Stone (Brazil) — sandbox auto-detected via sk_test_ prefix
PAGARME_USERNAME=sk_test_xxx  # or sk_live_xxx for production

STRIPE_API_KEY=<stripe_key>
PAYPAL_CLIENT_ID=<paypal_client>
PAYPAL_CLIENT_SECRET=<paypal_secret>

REDIS_URL=redis://localhost:6379
```

## External References

- [BE ↔ DPE API Contract](./api_contract.md)
- [Integration Guide](./integration_guide.md)
- [Canonical BE ↔ DPE contract](../../../docs/BE_DPE_COMMUNICATION.md)
- [MVP specifications](../../../.specs/mvp-v0.1/README.md)