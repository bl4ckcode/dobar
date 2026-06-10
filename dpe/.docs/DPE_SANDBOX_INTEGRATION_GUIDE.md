# DPE Sandbox Integration Guide (Sprint 5)

This guide provides the necessary details for the backend team to integrate and test Credit Card and PIX payments using the `dobar-payment-engine` (DPE) in the **Sandbox** environment.

## 1. Sandbox Configuration

To operate in Sandbox (test mode), ensure the `.env` in DPE uses test keys:

```env
PAGARME_ENV=test
PAGARME_PASSWORD=sk_test_... # Your Pagar.me Test API Key
PAGARME_USERNAME= # Leave empty or as configured in Fly.io
```

## 2. API Endpoints for Integration

The backend (orchestrator) should use the following standardized calls to DPE.

### PIX Payment Generation

**Payload Example:**
```json
{
  "amount": 100.00,
  "currency": "BRL",
  "customer": {
    "name": "Test User",
    "email": "test@example.com",
    "document": "12345678909",
    "type": "individual"
  },
  "payment_method": {
    "payment_method": "pix",
    "expires_in": 3600
  },
  "idempotency_key": "unique_pix_123"
}
```

**Standardized Response (PIX):**
Expose these fields to the Frontend:
- `pix_qr_code`: The PIX Copy-Paste string (EMV).
- `pix_copia_e_cola`: (Alias) The PIX Copy-Paste string.
- `pix_qr_code_url`: URL to the QR Code image (PNG).
- `pix_expires_at`: Expiration datetime.
- `status`: `succeeded` or `pending`.

---

### Credit Card (CC) Payment

**Payload Example (using Card Token):**
```json
{
  "amount_cents": 14990,
  "currency": "BRL",
  "customer_info": { ... },
  "payment_method": {
    "type": "card",
    "token": "token_xxxx",
    "installments": 1
  }
}
```

**Standardized Response (CC):**
- `status`: `succeeded` or `pending`.
- `gateway_id`: Gateway reference.
- `card_brand`: Card brand (visa/master).
- `card_last_four`: Last 4 digits of the card.
- `acquirer_message`: Message from the processor.

## 3. Testing Status Transitions in Sandbox

### PIX
1. Generate the PIX using DPE.
2. In the **Pagar.me Dashboard (Sandbox)**, find the order and click **"Simular Pagamento"** (Simulate Payment).
3. Verify that your webhook/status-check in `barz-backend` reflects `paid`.

### Credit Card
Use [Pagar.me Test Cards](https://docs.pagar.me/docs/cartoes-de-teste) to simulate outcomes:
- **Success**: Any card with valid format.
- **Failure**: Specific test cards provided by Pagar.me for "Declined", "Insufficient Funds", etc.

## 4. Refund Management
Use the standardized `refund` endpoint in DPE:
```json
{
  "charge_id": "ch_xxxx",
  "amount": 50.00  // Optional for partial refund
}
```

## 5. Standardized Error Mapping
Refer to `API_ERROR_CONTRACT.md` for error handling. DPE now returns descriptive messages and mapping for Pagar.me SDK exceptions.
