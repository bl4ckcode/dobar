# Backend ↔ payment engine contract

Canonical concise summary reviewed against this checkout on 2026-10-22. [Context authority/findings](AGENT_CONTEXT.md) apply; this is source inspection, not sandbox or production verification. Historical strategy, examples, and unverified completion claims remain in the [noncanonical archive](archive/agent-context-2026-10-22/BE_DPE_COMMUNICATION.md).

## Responsibilities and transport

BE owns user/bar authorization, cart/orders, wallet accounting, pricing, and subscription entitlements. DPE owns gateway adapters, provider interaction, and payment event normalization. FE calls BE; provider tokenization/hosted UI is a separate explicitly designed flow, never an exposure of DPE service secrets.

BE [DPEClient](../be/app/payment/dpe_client.py) uses `DPE_URL`, `DPE_SERVICE_SECRET`, and `DPE_TIMEOUT`. Requests use `X-Service-Auth`, `X-Request-ID`, and JSON; charge/refund methods can add `X-Idempotency-Key`, while the payment body contains the actual required `idempotency_key`. DPE [middleware](../dpe/dobar_payment/api/middleware.py) and [app](../dpe/dobar_payment/api/app.py) define authentication, request IDs, and `X-DPE-Version` handling. Do not use development default secrets outside local development.

## Current HTTP interfaces

Source of wire types: DPE [schemas](../dpe/dobar_payment/api/schemas.py), [routes](../dpe/dobar_payment/api/routes.py), and [app registration](../dpe/dobar_payment/api/app.py). Amounts on these APIs are integer cents, unlike BE currency-unit `amount` fields. BE converts IDs to strings and `amount` to `amount_cents` with `int(round(amount * 100))`; audit precision/authoritative totals in checkout work.

| Endpoint | Request → response fields |
|---|---|
| `POST /payments/charge` | `{order_id: str, user_id: str, bar_id: str, amount_cents: positive int, currency, country, payment_method, idempotency_key, customer_info?, metadata?, description?, proration_info?}` → `{payment_id, status, gateway, gateway_id, amount_cents, currency, created_at, pix_qr_code?, pix_copia_e_cola?, pix_expires_at?, card_last_four?, card_brand?, proration_credit_cents?}` |
| `POST /payments/refund` | `{payment_id, amount_cents?, reason?, idempotency_key}` → `{refund_id, payment_id, status, amount_cents, created_at}` |
| `GET /payments/{payment_id}` | → `{payment_id, status, amount_cents, currency, gateway, refunded_amount_cents, created_at}` |
| `POST /pix/generate` | `{order_id, amount_cents, description, expiration_seconds, payer_info?: {name, document}}` → `{pix_id, brcode, qr_code_base64, expires_at, status}` |
| `POST /subscriptions/trial/setup` | `{bar_id, owner_id, plan, trial_days, payment_method_id, customer_email, customer_name, idempotency_key, metadata?}` → `{setup_intent_id, status, client_secret?, stripe_customer_id, trial_ends_at, payment_method_id}` |
| `POST /payments/capture` | `{payment_id, amount_cents, idempotency_key}` → `{payment_id, status, amount_cents, gateway, captured_at}` |
| `GET /health` | → `{status, version, gateways, timestamp?}`; liveness is not payment validation |

`payment_method` is `{type: card|pix, token?, provider?, pix_key?, expires_in?, installments}`. `customer_info` includes `{name, email, document, type?, phone?}`. Subscription proration currently accepts `{previous_plan, new_plan, credit_amount_cents, cycle_start, cycle_end, upgrade_date}`; full credit can return `status: credit_applied`, `gateway: internal`, and `amount_cents: 0`. Treat client-supplied credit/amount inputs as a security finding pending server-owned pricing work.

DPE structured errors are `{error_code, message, details?, request_id?}` with HTTP mappings from middleware. BE currently translates some DPE errors to `APIError.payment_declined` and can lose distinctions; timeout, non-JSON, CORS, service-unavailable, and provider-decline failures need separate diagnostics. The [FE error design](../fe/.docs/API_ERROR_CONTRACT.md) is not proof of uniform current responses.

## Routing and asynchronous confirmation

- Generic charge currently selects a configured gateway by country through [gateway registry](../dpe/dobar_payment/api/dependencies.py): BR → `stone` (PagarMe); LATAM/MX → Stripe; other configured routing/fallbacks follow source. Provider names in wire data remain `stone`, `stripe`, or `paypal`.
- Trial/setup and capture paths contain explicit Stripe behavior. Generic Brazil subscription charges can still follow country routing; future Stripe Checkout and Customer Portal flows require implementation, configuration, and webhook entitlement tests.
- Providers send `POST /webhooks/{gateway}` **to DPE**. DPE verifies signatures through [webhook handling](../dpe/dobar_payment/core/webhooks.py), normalizes supported events, then forwards **to BE** `POST /payments/webhook` with `X-Service-Auth` and `X-Request-ID`.
- Forwarded payload currently contains `{event, payment_id, order_id, status, amount_cents?, currency?, gateway?, created_at?}`. The current DPE forwarding schema omits `metadata`, while BE subscription/payout branches expect it. Provider IDs also need mapping to internal payment/order IDs; do not assume a provider event ID is an internal payment ID.
- BE must authorize and reconcile confirmation before presenting paid orders or activating entitlements. Duplicate delivery, out-of-order events, retries, reversals, and missing metadata remain acceptance scenarios, not proven guarantees.

## Observed contradictions and MVP requirements

| Finding | Current evidence and required follow-up |
|---|---|
| Standalone Pix is not a provider-backed charge | `PixRoutes.generate_brcode` constructs a local BR Code with `pix@barz.app`; provider-generated Pix checkout must use the real provider path and reconcile its payment ID |
| Invalid QR image encoding | Standalone route labels base64-encoded BR Code **text bytes** as `data:image/png`; render a real QR PNG or documented provider URL and test decoding |
| Pix schemas differ | Standalone `brcode`/`qr_code_base64` differ from charge `pix_copia_e_cola`/`pix_qr_code`; check every FE/BE bridge and pending/expiry state |
| Subscription strategy is ahead of implementation | Existing setup/capture/generic charge APIs are not hosted Stripe Checkout/Customer Portal; never mark purchase E2E complete from those APIs alone |
| Historical completion and idempotency claims overstate evidence | Older documents claim deployed/complete and all operations idempotent; standalone Pix lacks an idempotency key and local storage behavior must be validated under restart/concurrency |
| Confirmation payload loses context | Forwarding omits metadata consumed by BE; correlation, entitlements, and cashier/client updates need contract and event tests |

MVP intent: provider-side card tokenization; references only through BE/DPE; server-authoritative amounts/credits; authenticated internal calls; redacted logs; stable retry keys; PagarMe customer purchases and Stripe business subscriptions. A proprietary card-security SDK is not the selected solution. Sandbox payment, decline, expiry, timeout, webhook replay, and native-device evidence must be recorded separately from structural checks.
