# Integration Guide (barz-backend → DPE)

This covers how `barz-backend` integrates with `dobar-payment-engine` via HTTP.

## Environment Setup

**Sandbox (test mode):** Set PagarMe username with `sk_test_` prefix — DPE auto-detects sandbox vs production via the key prefix.

```env
PAGARME_USERNAME=sk_test_xxx   # auto-detected as sandbox
PAGARME_USERNAME=sk_live_xxx   # auto-detected as production
```

**Integration URLs (local):**
- barz-backend: `http://localhost:8000`
- dobar-payment-engine: `http://localhost:8001`

## Data Flow

```
Dobar App (Flutter) → barz-backend (FastAPI) → dobar-payment-engine → Payment Gateway
```

- Wallet operations stay in `barz-backend` (not DPE)
- DPE handles: gateway routing, payment processing, refunds, PIX
- barz-backend calls DPE via HTTP; payments are **NOT** attached to specific gateways

## Testing Sandbox Payments

### PIX
1. Generate PIX via DPE
2. In Pagar.me Dashboard (Sandbox), find the order and click "Simular Pagamento"
3. Verify webhook/status-check in barz-backend reflects `paid`

### Credit Cards
Use Pagar.me test cards to simulate different outcomes (success, declined, insufficient funds).

## Webhooks

DPE listens for external gateway webhooks at `POST /webhooks/{gateway}`, validates signatures, standardized and forwards to barz-backend at `POST /payments/webhook`.

## Error Codes Ref

See [API Contract](./api_contract.md) for the full error code table.