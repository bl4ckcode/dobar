# API Contract (barz-backend → DPE)

## Authentication

```
Header: X-Service-Auth: <shared_secret>
Header: X-Request-ID: <uuid>
Header: X-DPE-Version: 2026-01-16 (optional)
```

## Endpoints

### POST /payments/charge

Standard payment charge, with optional `proration_info` for subscription upgrades.

**Request fields (amount always in cents as integer):**
- `order_id`, `user_id`, `bar_id`
- `amount_cents` (integer) — **never use float reais**
- `currency`, `country`
- `payment_method`: `{ type, token, provider?, installments? }`
- `customer_info`: `{ name, email, document, phone }`
- `idempotency_key` (required)
- `metadata` (optional, e.g. `{"table": "5"}`)
- `proration_info` (optional, for prorated upgrades)

**Responses:**
- `200` → `{ payment_id, status, gateway, gateway_id, amount_cents, currency, created_at }`
- `200` (full credit) → `{ status: "credit_applied", gateway: "internal" }`
- `402` → `{ error_code, message, details, request_id }`

### POST /subscriptions/trial/setup

Creates a Stripe SetupIntent for subscription trials. Stripe is the strategic gateway for all trial operations regardless of country.

**Request:** `{ bar_id, owner_id, plan, trial_days, payment_method_id, customer_email, customer_name, idempotency_key, metadata }`
**Response:** `{ setup_intent_id, status, client_secret, stripe_customer_id, trial_ends_at, payment_method_id }`

BE schedules the capture call when `trial_ends_at` expires.

### POST /payments/capture

Captures a pre-authorized payment or post-trial charge.

**Request:** `{ payment_id, amount_cents, idempotency_key }`
**Response:** `{ payment_id, status, amount_cents, gateway, captured_at }`

### POST /payments/refund

**Request:** `{ payment_id, amount_cents, reason, idempotency_key }`
**Response:** `{ refund_id, payment_id, status, amount_cents, created_at }`

### GET /payments/{payment_id}

Payments are **NOT** attached to specific gateways. Routes by country, not payment method.

**Response:** `{ payment_id, status, amount_cents, currency, gateway, refunded_amount_cents, created_at }`

### POST /webhooks/{gateway} (DPE → BARZ-BACKEND)

DPE listens for external gateways at `POST /webhooks/{gateway}` automatically, validates signatures, standardizes and forwards to the backend.

**Request (from DPE, protected by X-Service-Auth):**
`{ event, payment_id, order_id, status, amount_cents, currency, gateway, created_at }`

### POST /pix/generate (Brazil only)

**Request:** `{ order_id, amount_cents, description, expiration_seconds, payer_info: { name, document } }`
**Response:** `{ pix_id, brcode, qr_code_base64, expires_at, status }`

### GET /health

**Response:** `{ status: "healthy", version, gateways: { stone: "healthy", ... } }`

## Error Codes

| Code | HTTP | Description |
|------|------|-------------|
| PAYMENT_DECLINED | 402 | Card declined by issuer |
| INSUFFICIENT_FUNDS | 402 | Card has no funds |
| INVALID_CARD | 400 | Card number/expiry invalid |
| GATEWAY_ERROR | 502 | Payment gateway unavailable |
| DUPLICATE_REQUEST | 409 | Idempotency key already used |
| NOT_FOUND | 404 | Payment/resource not found |
| AUTH_ERROR | 401 | Invalid service auth |
| VALIDATION_ERROR | 422 | Request validation failed |

**Error response format:**
```json
{ "error_code": "PAYMENT_DECLINED", "message": "...", "details": { "gateway": "stone", "gateway_code": "..." }, "request_id": "req_xxx" }
```

## API Versioning

Header-based, date-versioned (`X-DPE-Version: 2026-01-16`). Breaking changes = new version date. Each version supported for 12+ months.