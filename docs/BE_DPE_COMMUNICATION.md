# Backend ↔ payment engine communication

Last updated: 2026-11-03

Rolling handoff: one latest update per sender. Git and Linear own history. Local tests are separate from deployment, provider sandbox and settlement evidence.

## Contract references

- [BE client](../be/app/payment/dpe_client.py), [order payments](../be/app/payment/order_payments.py), [BE schemas](../be/app/payment/schemas.py), [DPE schemas](../dpe/dobar_payment/api/schemas.py), [DPE routes](../dpe/dobar_payment/api/routes.py), [PagarMe adapter](../dpe/dobar_payment/gateways/stone.py).
- BE owns authorization/pricing/entitlements; DPE owns provider interaction. HTTP DPE amounts remain integer `amount_cents`, converted once from BE currency units using decimal arithmetic. Internal calls require `X-Service-Auth`; preserve request and idempotency correlation.
- Intent: [C08](../.specs/mvp-v0.1/C08-card-checkout.md), [C09](../.specs/mvp-v0.1/C09-pix-checkout.md), [S02](../.specs/mvp-v0.1/S02-payment-reconciliation.md). Other [open findings](AGENT_CONTEXT.md) remain unresolved.

## Latest backend update

- Date: 2026-11-03. Scope: approved checkout and saved-card defect correction.
- Shared order charging validates authenticated ownership, canonical order amount/venue/BRL and persisted customer name/email/CPF before calling `/payments/charge`. Stable attempt keys and request fingerprints persist; unknown outcomes retry the same attempt, definitive failures permit a new attempt. New FE defers legacy cart autocharge and calls this service once.
- Saved-card creation calls authenticated `POST /cards` with a fresh provider `token`, `user_id` and `customer_info`, then stores the returned durable `card_id`. Charge methods carry `card_id` for saved cards or fresh `token` for supported direct-token flows; no empty/fabricated references are valid.
- Service errors preserve validation/decline/unavailable distinctions. Provider-confirmed state and correlated callbacks update the owned order; pending/authorized events cannot imply payment success. Confirmation/reward replay is idempotent and paid state cannot regress.
- Action: release compatible DPE endpoints/mappings before BE and FE through existing CI/CD. Real merchant-required address/phone/domain configuration remains a provider acceptance prerequisite; no fabricated customer data is supplied.
- Evidence: [checkout regressions](../be/tests/test_checkout_payment_regressions.py), [card tests](../be/tests/test_cards.py), [PostgreSQL concurrency](../be/tests/test_payment_postgres_concurrency.py). No provider sandbox or settlement claimed.

## Latest DPE update

- Date: 2026-11-03. Scope: PagarMe card exchange, charge/status correlation and safe error handling.
- Authenticated `/cards` exchanges a short-lived `token_` via the real provider customer/card APIs and returns `card_id`, masked metadata and expiry. Card charge fields map compatible `token`/`card_token`/`card_id` forms into PagarMe requests; HTTP cents remain exact integers and provider idempotency is forwarded.
- DPE stores provider charge/order correlation, returns provider-confirmed status and Pix QR/Copia e Cola/expiry fields, and resolves authenticated provider events back to the stable DPE payment ID. Process-local DPE storage remains a limitation; deterministic IDs, provider metadata and stable provider idempotency preserve retry/callback correlation across recreation.
- Request logging no longer consumes/replays POST bodies or exposes customer/card inputs; validation and gateway failures expose sanitized errors. Unavailable provider/account/domain configuration remains actionable, not a successful transaction.
- Compatibility: generic country routing remains; subscriptions retain their existing strategy. Standalone `/pix/generate` still has the previously recorded hardcoded payload problem and is outside this checkout repair; new checkout uses provider-backed `/payments/charge`.
- Evidence: [gateway tests](../dpe/tests/gateways/test_stone_gateway.py), [API recovery tests](../dpe/tests/test_checkout_recovery.py), [webhook tests](../dpe/tests/test_webhooks.py). Mocked tests do not prove sandbox availability, QR settlement or native wallets.
