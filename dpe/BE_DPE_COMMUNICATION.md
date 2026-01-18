# BARZ Backend ↔ Dobar Payment Engine Communication

Last Updated: January 18, 2026
Status: Integration Tested Locally ✅
barz-backend: https://barz-backend-bold-sun-5691.fly.dev (port 8000 locally)
dobar-payment-engine: TBD (port 8001 locally, gateways loaded)

---

## ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────────────────────────────────┐
│                         BARZ ECOSYSTEM                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐  │
│  │   BARZ APP   │      │ BARZ BACKEND │      │    DOBAR     │  │
│  │   (Flutter)  │◄────►│   (FastAPI)  │◄────►│   PAYMENT    │  │
│  │              │      │   + Wallet   │      │    ENGINE    │  │
│  └──────────────┘      └──────────────┘      └──────────────┘  │
│         │                     │                     │          │
│         │                     │                     │          │
│         ▼                     ▼                     ▼          │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐  │
│  │  Apple Pay   │      │  PostgreSQL  │      │    Stone     │  │
│  │  Google Pay  │      │    Redis     │      │   Pagar.me   │  │
│  │  (Tokenized) │      │   (Wallet)   │      │    Stripe    │  │
│  └──────────────┘      └──────────────┘      │    PayPal    │  │
│                                              └──────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## RESPONSIBILITY SPLIT

| Component | Responsibility |
|-----------|----------------|
| BARZ APP | UI, Apple Pay/Google Pay tokenization, user experience |
| BARZ BACKEND | Order management, wallet balance, auth, business logic |
| DOBAR PAYMENT ENGINE | Gateway routing, payment processing, refunds, PIX |

**Key Decision:** Wallet operations stay in barz-backend (closer to business logic).
DPE focuses purely on payment processing via external gateways.

---

## BUSINESS CONTEXT

### What Barz Is

Barz is an **on-site ordering system** for bars and restaurants.

Think: McDonald's self-order kiosk, but on the customer's phone.

Flow:
1. User enters bar/restaurant
2. User checks in via app (QR code or location)
3. User browses menu, adds items to cart
4. User pays via app (Apple Pay, Google Pay, Card, Pix)
5. Order appears on bar's dashboard - **already paid**
6. Bar prepares order, user picks up or waiter delivers to table

### What Barz Is NOT

- NOT a delivery app (no couriers, no logistics)
- NOT taking commission per transaction
- NOT adding fees to end users

### Revenue Model

| Revenue Stream | Description |
|----------------|-------------|
| Bar Subscriptions | Monthly fee for dashboard, analytics, menu management |
| Campaigns/Ads | Featured listings, promotions, happy hour visibility |
| Premium Features | Advanced analytics, multi-location, API access |

Users pay the exact menu price. No platform fee on transactions.

---

## PAYMENT PROVIDERS BY REGION

### Understanding Payment Methods vs Gateways

**Device Wallet Payments (FE-integrated):**
- Apple Pay → Tokenized card data sent to BE
- Google Pay → Tokenized card data sent to BE
- These are NOT gateways, they're tokenization layers

**Payment Gateways (BE-integrated):**
- Process the actual charge
- Handle refunds, disputes, settlements
- Provide dashboard for bar owners to see payouts

### Regional Strategy

| Region | Gateway | Payment Methods |
|--------|---------|-----------------|
| Brazil | Stone / Pagar.me | Pix, Credit, Debit |
| LATAM (AR, CL, CO, PE) | Stripe | Credit, Debit |
| Mexico | Stripe | Credit, Debit, OXXO |
| North America (US, CA) | PayPal | Credit, Debit |
| Europe | PayPal | Credit, Debit, SEPA |
| Rest of World | PayPal | Credit, Debit |

**Note:** Apple Pay and Google Pay work with ANY gateway - they just provide tokenized card data.

---

## DOBAR PAYMENT ENGINE STRUCTURE

### Implemented (dobar-payment-engine)

```
dobar-payment-engine/
├── dobar_payment/
│   ├── api/                    # HTTP API Layer (NEW)
│   │   ├── app.py              # FastAPI app factory
│   │   ├── routes.py           # PaymentRoutes, PixRoutes, HealthRoutes
│   │   ├── schemas.py          # Request/Response models
│   │   ├── middleware.py       # Auth, versioning, request context
│   │   └── dependencies.py     # PaymentStore, GatewayRegistry
│   ├── core/                   # Business logic
│   │   ├── router.py           # Smart gateway routing
│   │   ├── state_machine.py    # Transaction state management
│   │   ├── validation.py       # Payment validation rules
│   │   └── locks.py            # Distributed locking
│   ├── gateways/               # Payment providers
│   │   ├── stone.py            # Brazil
│   │   ├── stripe.py           # LATAM, Mexico
│   │   └── paypal.py           # US, CA, EU
│   ├── middleware/             # Circuit breaker, rate limiting
│   ├── models/                 # Domain models
│   └── exceptions/             # Error handling
└── tests/
    └── test_api.py             # API layer tests
```

### Running the API

```bash
pip install dobar-payment-engine[api]
uvicorn dobar_payment.api.app:create_app --factory --port 8000
```

---

## API CONTRACT: BARZ-BACKEND → DPE

### Authentication

```
Header: X-Service-Auth: <shared_secret>
Header: X-Request-ID: <uuid>
Header: X-DPE-Version: 2026-01-16 (optional)
```

### POST /payments/charge

```json
Request:
{
  "order_id": "order_12345",
  "user_id": "user_67890",
  "bar_id": "bar_111",
  "amount_cents": 4550,
  "currency": "BRL",
  "country": "BR",
  "payment_method": {
    "type": "card",
    "token": "tok_xxx",
    "provider": "apple_pay"
  },
  "customer_info": {
    "name": "Carlos Alves",
    "email": "carlos@example.com",
    "document": "12345678901",
    "phone": "+5511999999999"
  },
  "idempotency_key": "uuid-xxx",
  "metadata": {"table": "5"}
}

Response 200:
{
  "payment_id": "pay_abc123",
  "status": "succeeded",
  "gateway": "stone",
  "gateway_id": "stone_txn_xxx",
  "amount_cents": 4550,
  "currency": "BRL",
  "created_at": "2026-01-16T10:30:00Z"
}

Response 402:
{
  "error_code": "PAYMENT_DECLINED",
  "message": "Card declined by issuer",
  "details": {
    "gateway": "stone",
    "gateway_code": "insufficient_funds"
  },
  "request_id": "req_xxx"
}
```

### POST /payments/refund

```json
Request:
{
  "payment_id": "pay_abc123",
  "amount_cents": 4550,
  "reason": "order_cancelled",
  "idempotency_key": "uuid-yyy"
}

Response 200:
{
  "refund_id": "ref_xyz789",
  "payment_id": "pay_abc123",
  "status": "succeeded",
  "amount_cents": 4550,
  "created_at": "2026-01-16T11:00:00Z"
}
```

### GET /payments/{payment_id}

```json
Response 200:
{
  "payment_id": "pay_abc123",
  "status": "succeeded",
  "amount_cents": 4550,
  "currency": "BRL",
  "gateway": "stone",
  "refunded_amount_cents": 0,
  "created_at": "2026-01-16T10:30:00Z"
}
```

### POST /pix/generate (Brazil only)

```json
Request:
{
  "order_id": "order_12345",
  "amount_cents": 4550,
  "description": "Mesa 5 - Bar do Zé",
  "expiration_seconds": 3600,
  "payer_info": {
    "name": "Carlos Alves",
    "document": "12345678901"
  }
}

Response 200:
{
  "pix_id": "pix_abc123",
  "brcode": "00020126...PIX_CODE...6304XXXX",
  "qr_code_base64": "data:image/png;base64,...",
  "expires_at": "2026-01-16T11:30:00Z",
  "status": "pending"
}
```

### GET /health

```json
Response 200:
{
  "status": "healthy",
  "version": "2.0.0",
  "gateways": {
    "stone": "healthy",
    "stripe": "healthy",
    "paypal": "degraded"
  }
}
```
---

## WALLET (BARZ-BACKEND RESPONSIBILITY)

Wallet operations stay in barz-backend since they're tightly coupled to user accounts and business logic.

### Endpoints (in barz-backend, NOT DPE)

- `POST /wallet/balance/check` - Check if user has sufficient balance
- `POST /wallet/debit` - Debit wallet for payment
- `POST /wallet/credit` - Add cashback or refund to wallet
- `GET /wallet/balance` - Get current balance

### Concurrency: Distributed Locking

```python
async def debit_wallet(user_id: int, amount: float, idempotency_key: str):
    lock_key = f"wallet:lock:user:{user_id}"
    
    acquired = await redis.set(lock_key, idempotency_key, nx=True, ex=5)
    if not acquired:
        raise APIError.conflict("Wallet operation in progress")
    
    try:
        result = await database.execute(
            """
            UPDATE wallets 
            SET balance = balance - :amount
            WHERE user_id = :user_id AND balance >= :amount
            RETURNING balance
            """
        )
        if not result:
            raise APIError.conflict("Insufficient balance")
        return result
    finally:
        await redis.delete(lock_key)
```

---

## IDEMPOTENCY (DPE)

All payment operations in DPE are idempotent via `idempotency_key`.

- DPE stores: `idempotency:{key}` → response (24h TTL)
- Duplicate requests return cached response immediately
- Keys scoped per operation type (charge, refund, pix)

---

## ERROR CODES

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

### Error Response Format

```json
{
  "error_code": "PAYMENT_DECLINED",
  "message": "Card declined by issuer",
  "details": {
    "gateway": "stone",
    "gateway_code": "insufficient_funds"
  },
  "request_id": "req_xxx"
}
```

---

## API VERSIONING

Header-based, date-versioned (Stripe/GitHub approach):

```
Header: X-DPE-Version: 2026-01-16
```

- Default version: 2026-01-16
- Breaking changes = new version date
- Additive changes rolled to all versions
- Each version supported for 12+ months

---

## GATEWAY ROUTING

DPE automatically routes payments to the appropriate gateway based on country:

| Country | Gateway |
|---------|---------|
| BR | stone |
| AR, CL, CO, PE, MX | stripe |
| US, CA | paypal |
| Fallback | paypal |

### Smart Routing Features

- Circuit breaker per gateway (auto-failover on errors)
- Success rate tracking
- Latency-based routing (optional)
- Cost optimization (optional)

---

## DEPLOYMENT PHASES

### Phase 1: Current (Testing Complete)

- [x] DPE API layer implemented
- [x] Gateway routing logic
- [x] Request/response contracts defined
- [x] BE DPE client implemented (dpe_client.py)
- [x] BE v2 payment endpoints ready
- [x] PIX endpoint ready
- [x] Deploy DPE as separate service (tested locally)
- [x] DPE auto-loads gateways from environment variables
- [x] Stone & Stripe gateways registered and healthy
- [x] Full HTTP flow tested: BE → DPE → Stone gateway
- [ ] Add customer data to DPE schema (required for PagarMe)
- [ ] Fix PIX BR Code generation in DPE
- [ ] Configure shared secret for BE ↔ DPE auth

### Phase 2: Integration

- [ ] BE calls DPE for all payments
- [ ] Wallet stays in BE
- [ ] Webhooks for async payment updates

### Phase 3: Multi-Product

- DPE serves barz, dobar-events, dobar-restaurants
- Unified payment dashboard for bar owners

---

## ENVIRONMENT VARIABLES (DPE)

```env
DPE_SERVICE_SECRET=<shared_secret_with_BE>
DPE_ENV=production

STONE_API_KEY=<stone_key>
STONE_CLIENT_ID=<stone_client>
STRIPE_API_KEY=<stripe_key>
PAYPAL_CLIENT_ID=<paypal_client>
PAYPAL_CLIENT_SECRET=<paypal_secret>

REDIS_URL=redis://localhost:6379
```

---

## TESTING

### Sandbox Environments

| Provider | Sandbox URL | Test Cards |
|----------|-------------|------------|
| Stone | sandbox.stone.com.br | 4111111111111111 |
| Stripe | api.stripe.com (test mode) | 4242424242424242 |
| PayPal | sandbox.paypal.com | Use sandbox accounts |

### Integration Tests

```python
@pytest.mark.asyncio
async def test_payment_charge_success():
    response = await client.post("/payments/charge", json={
        "order_id": 1,
        "amount": 50.00,
        "currency": "BRL",
        "country": "BR",
        "payment_method": {"type": "card", "token": "tok_test"},
        "idempotency_key": str(uuid4())
    })
    assert response.status_code == 200
    assert response.json()["status"] == "succeeded"

@pytest.mark.asyncio
async def test_idempotency_returns_cached():
    key = str(uuid4())
    r1 = await client.post("/payments/charge", json={"idempotency_key": key})
    r2 = await client.post("/payments/charge", json={"idempotency_key": key})
    assert r1.json()["payment_id"] == r2.json()["payment_id"]
```

---

## MONITORING

### Key Metrics

| Metric | Alert Threshold |
|--------|-----------------|
| Payment success rate | < 95% |
| Payment latency p99 | > 5s |
| Provider errors | > 5/min |
| Wallet lock timeouts | > 10/min |

### Logging

All payment operations logged with:
- payment_id
- order_id
- user_id
- provider
- status
- latency_ms
- idempotency_key

---

## OPEN QUESTIONS

1. Settlement frequency: Daily or weekly payouts to bars?
2. Cross-border payments: User in Argentina paying at Brazilian bar?
3. Dispute handling: Who handles chargebacks?
4. PCI compliance: SAQ-A with tokenization (Apple Pay / Google Pay)

---

## CHANGELOG

| Date | Change |
|------|--------|
| 2026-01-18 | ✅ Fixed PIX BR Code parameter names (key, receiver_name, receiver_city, txid) |
| 2026-01-18 | ✅ Added customer_info to ChargeRequestAPI (name, email, document, phone) |
| 2026-01-18 | ✅ Added 18 new unit tests (customer validation + PIX BR Code) - 189 tests passing |
| 2026-01-18 | ✅ Local integration tested: BE→DPE→Stone gateway communication working |
| 2026-01-18 | ✅ DPE auto-loads gateways from env (PAGARME_USERNAME, STRIPE_API_KEY) |
| 2026-01-18 | ✅ Fixed amount_cents→amount conversion in DPE routes.py |
| 2026-01-18 | BE integration complete (dpe_client.py, v2 endpoints, PIX) |
| 2026-01-18 | Fixed amount_cents vs amount, provider vs gateway field names |
| 2026-01-16 | API layer implemented (schemas, routes, middleware) |
| 2026-01-16 | Decision: Wallet stays in barz-backend |
| 2026-01-16 | Added PIX BR Code generation endpoint |
| 2026-01-16 | Initial document created |
