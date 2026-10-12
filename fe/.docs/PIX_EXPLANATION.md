## Pix Payment Flow Clarification

### Two Endpoints - Different Use Cases:

**1. `POST /payments/v2/charge` (Checkout Flow)**
- **Use when**: Customer is at checkout, order exists
- **How it works**: 
  - Sends `payment_method.type = "pix"` to DPE
  - DPE creates a Pix charge at Stone/PagarMe
  - Returns `pix_qr_code`, `pix_copia_e_cola`, `pix_expires_at`
  - Order status stays "pending" until webhook confirms payment

**2. `POST /pix/generate` (Standalone)**
- **Use when**: You want Pix before creating an order
- **Example**: "Pay with Pix" button on cart screen

### Where Does the QR Code Go?

```
Customer (Barz App)                DPE (Stone/PagarMe)                Bar Owner
       │                                │                                  │
       │── POST /payments/v2/charge ───▶│                                  │
       │    type: "pix"                 │                                  │
       │                                │── Create Pix Order ─────────────▶│
       │◀── Response: qr_code ──────────│    (Pix ID registered)           │
       │    pix_copia_e_colá            │                                  │
       │    expires_at                  │                                  │
       │                                │                                  │
       │ [Customer scans/enters         │                                  │
       │  Pix in banking app]           │                                  │
       │                                │◀── Pix Paid ─────────────────────│
       │                                │    (Webhook)                     │
       │◀── /payments/webhook ──────────│                                  │
       │    status: "succeeded"         │                                  │
```

The **QR code is displayed to the customer** in the app. They scan it with their bank app (or copy the Copia e Cola). When they pay, Stone notifies DPE, which webhooks your backend.

**Use `/payments/v2/charge`** for checkout - it's the correct endpoint. The frontend just needs to handle the Pix response fields properly.