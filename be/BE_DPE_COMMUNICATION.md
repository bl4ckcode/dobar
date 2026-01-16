# BARZ Backend ↔ Dobar Payment Engine Communication

Last Updated: January 16, 2026
Status: Planning Phase
barz-backend: https://barz-backend-bold-sun-5691.fly.dev
dobar-payment-engine: TBD

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
│  │              │      │              │      │    ENGINE    │  │
│  └──────────────┘      └──────────────┘      └──────────────┘  │
│         │                     │                     │          │
│         │                     │                     │          │
│         ▼                     ▼                     ▼          │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐  │
│  │  Apple Pay   │      │  PostgreSQL  │      │    Stone     │  │
│  │  Google Pay  │      │   MongoDB    │      │   Pagar.me   │  │
│  │  (Tokenized) │      │    Redis     │      │    Stripe    │  │
│  └──────────────┘      └──────────────┘      │    PayPal    │  │
│                                              └──────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

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
| Brazil | Stone / Pagar.me | Pix, Credit, Debit, Boleto |
| LATAM (AR, CL, CO, PE) | Stripe | Credit, Debit |
| Mexico | Stripe | Credit, Debit, OXXO |
| North America (US, CA) | PayPal | Credit, Debit |
| Europe | PayPal | Credit, Debit, SEPA |
| Rest of World | PayPal | Credit, Debit |

**Note:** Apple Pay and Google Pay work with ANY gateway - they just provide tokenized card data.

---

## DOBAR PAYMENT ENGINE RESPONSIBILITIES

### Current State (Embedded in barz-backend)

```
barz-backend/
├── app/
│   └── payment/
│       ├── routes.py
│       ├── schemas.py
│       └── models.py
```

### Future State (Separate Service)

```
dobar-payment-engine/
├── adapters/
│   ├── base.py
│   ├── stone_adapter.py      # Brazil
│   ├── stripe_adapter.py     # LATAM, Mexico
│   └── paypal_adapter.py     # US, CA, EU, ROW
├── services/
│   ├── payment_router.py
│   ├── refund_service.py
│   ├── settlement_service.py
│   └── wallet_service.py
├── models/
│   ├── payment.py
│   ├── refund.py
│   └── payout.py
└── api/
    └── routes.py
```

---

## API CONTRACT: BARZ-BACKEND → DPE

### Authentication

All requests from barz-backend to DPE use internal service auth:

```
Header: X-Service-Auth: <shared_secret>
Header: X-Request-ID: <uuid>
```

### POST /payments/charge

```json
Request:
{
  "order_id": 12345,
  "user_id": 67890,
  "bar_id": 111,
  "amount": 45.50,
  "currency": "BRL",
  "country": "BR",
  "payment_method": {
    "type": "card",
    "token": "tok_xxx",
    "provider": "apple_pay"
  },
  "idempotency_key": "uuid-xxx"
}

Response 200:
{
  "payment_id": "pay_abc123",
  "status": "succeeded",
  "provider": "stone",
  "provider_id": "stone_txn_xxx",
  "amount": 45.50,
  "currency": "BRL",
  "created_at": "2026-01-16T10:30:00Z"
}

Response 402:
{
  "error_code": "PAYMENT_DECLINED",
  "message": "Card declined by issuer",
  "provider_code": "insufficient_funds"
}
```

### POST /payments/refund

```json
Request:
{
  "payment_id": "pay_abc123",
  "amount": 45.50,
  "reason": "order_cancelled",
  "idempotency_key": "uuid-yyy"
}

Response 200:
{
  "refund_id": "ref_xyz789",
  "payment_id": "pay_abc123",
  "status": "succeeded",
  "amount": 45.50,
  "created_at": "2026-01-16T11:00:00Z"
}
```

### GET /payments/{payment_id}

```json
Response 200:
{
  "payment_id": "pay_abc123",
  "status": "succeeded",
  "amount": 45.50,
  "currency": "BRL",
  "provider": "stone",
  "refunded_amount": 0.00,
  "created_at": "2026-01-16T10:30:00Z"
}
```

### POST /wallet/balance/check

```json
Request:
{
  "user_id": 67890,
  "amount": 25.00,
  "currency": "BRL"
}

Response 200:
{
  "sufficient": true,
  "balance": 50.00,
  "currency": "BRL"
}
```

### POST /wallet/debit

```json
Request:
{
  "user_id": 67890,
  "amount": 25.00,
  "currency": "BRL",
  "order_id": 12345,
  "idempotency_key": "uuid-zzz"
}

Response 200:
{
  "transaction_id": "wtx_abc",
  "new_balance": 25.00,
  "debited": 25.00
}
```

---

## WALLET CONCURRENCY

### Problem

User has R$50 wallet balance. Two simultaneous orders try to use it.

### Solution: Distributed Locking

```
Order A arrives → Redis SETNX wallet:lock:user:67890 → SUCCESS → Process
Order B arrives → Redis SETNX wallet:lock:user:67890 → FAIL → Wait/Retry
Order A completes → Release lock
Order B retries → SUCCESS → Process
```

### Implementation

```python
async def debit_wallet(user_id: int, amount: float, idempotency_key: str):
    lock_key = f"wallet:lock:user:{user_id}"
    
    acquired = await redis.set(lock_key, idempotency_key, nx=True, ex=5)
    if not acquired:
        raise APIError.conflict("Wallet operation in progress")
    
    try:
        wallet = await get_wallet(user_id)
        if wallet.balance < amount:
            raise APIError.bad_request("Insufficient balance")
        
        result = await database.execute(
            """
            UPDATE wallets 
            SET balance = balance - :amount, updated_at = NOW()
            WHERE user_id = :user_id AND balance >= :amount
            RETURNING balance
            """
        )
        if not result:
            raise APIError.conflict("Balance changed during transaction")
        
        return result
    finally:
        await redis.delete(lock_key)
```

---

## IDEMPOTENCY

All payment operations MUST be idempotent.

### How It Works

1. Client generates UUID for each unique payment intent
2. DPE stores: idempotency_key → response in Redis (24h TTL)
3. Duplicate requests return cached response immediately

### Implementation

```python
async def process_payment(request: PaymentRequest):
    cache_key = f"idempotency:{request.idempotency_key}"
    
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)
    
    result = await charge_provider(request)
    
    await redis.setex(cache_key, 86400, json.dumps(result))
    
    return result
```

---

## ERROR HANDLING

### Error Codes

| Code | HTTP | Description |
|------|------|-------------|
| PAYMENT_DECLINED | 402 | Card declined by issuer |
| INSUFFICIENT_FUNDS | 402 | Not enough balance (card or wallet) |
| INVALID_CARD | 400 | Card number/expiry invalid |
| PROVIDER_ERROR | 502 | Payment provider unavailable |
| DUPLICATE_PAYMENT | 409 | Idempotency key already used |
| WALLET_LOCKED | 409 | Another operation in progress |

### Response Format

All errors follow API_ERROR_CONTRACT.md:

```json
{
  "error_code": "PAYMENT_DECLINED",
  "message": "Card declined by issuer",
  "details": {
    "provider": "stone",
    "provider_code": "card_declined",
    "provider_message": "Insufficient funds"
  }
}
```

---

## VERSIONING STRATEGY

Following Stripe/GitHub approach (header-based, date-versioned):

```
Header: X-DPE-Version: 2026-01-16
```

- New accounts pinned to latest version
- Breaking changes = new version date
- Additive changes rolled to all versions
- Each version supported for 12+ months

---

## MIGRATION PLAN

### Phase 1: Current (Embedded)

- Payment logic lives in barz-backend
- Single deployment
- Direct database access

### Phase 2: Extraction (Post-PMF)

Trigger: When we need different deploy cycles or multiple products.

1. Create dobar-payment-engine as separate service
2. Migrate payment tables to DPE database
3. barz-backend calls DPE via internal API
4. Add Redis for idempotency + wallet locks

### Phase 3: Multi-Product

- DPE serves barz, dobar-events, dobar-restaurants
- Unified payment dashboard for bar owners
- Cross-product wallet (cashback works everywhere)

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
2. Multi-currency wallet: Can user have BRL + USD balance?
3. Cross-border payments: User in Argentina paying at Brazilian bar?
4. Dispute handling: Who handles chargebacks?
5. PCI compliance: Do we need SAQ-D or can we stay SAQ-A with tokenization?

---

## CHANGELOG

| Date | Change |
|------|--------|
| 2026-01-16 | Initial document created |
