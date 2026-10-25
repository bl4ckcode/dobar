# Backend ↔ payment engine communication

Last updated: 2026-10-23

Rolling handoff: keep only the latest backend update and latest DPE update. Replace an area's previous entry when that area changes; retain the other area's latest entry. Git and linked Linear issues own history. Source inspection is not provider or E2E evidence.

## Contract references

- [BE client](../be/app/payment/dpe_client.py), [BE schemas](../be/app/payment/schemas.py), [DPE schemas](../dpe/dobar_payment/api/schemas.py), [DPE routes](../dpe/dobar_payment/api/routes.py).
- BE owns authorization/pricing/entitlements; DPE owns provider interaction. HTTP DPE amounts use integer `amount_cents`; BE currency-unit amounts are converted at the bridge. Internal calls use `X-Service-Auth`, request IDs and operation idempotency keys.
- [Open findings](AGENT_CONTEXT.md) and [S02](../.specs/mvp-v0.1/S02-payment-reconciliation.md) own unresolved confirmation/error work; inspect source for complete wire fields rather than copying an endpoint catalog here.

## Latest backend update

- Date: 2026-10-22 (last inspected boundary; no newer BE/DPE change recorded here).
- Scope: BE charge/confirmation bridge, [S02](../.specs/mvp-v0.1/S02-payment-reconciliation.md).
- Contract/action: BE sends string order/user/bar IDs and cents to `/payments/charge`, and receives DPE confirmation at `/payments/webhook`. Preserve provider/payment/order correlation and service authentication. BE subscription/payout branches expect metadata missing from the current forwarded DPE schema.
- Evidence: [bridge](../be/app/payment/dpe_client.py), [webhook consumer](../be/app/payment/routes.py). Inspection only; reconciliation/provider outcomes remain unverified.

## Latest DPE update

- Date: 2026-10-22 (last inspected producer contract; no newer DPE change recorded here).
- Scope: Pix and forwarded provider events, [C09](../.specs/mvp-v0.1/C09-pix-checkout.md), [S02](../.specs/mvp-v0.1/S02-payment-reconciliation.md).
- Contract/action: Charge responses expose `pix_qr_code`, `pix_copia_e_cola`, `pix_expires_at`; standalone `/pix/generate` instead exposes `brcode`/`qr_code_base64`. The standalone route uses a hardcoded recipient and labels encoded text as PNG. It cannot establish provider-backed payment confirmation; fix through the linked specs.
- Evidence: [DPE routes](../dpe/dobar_payment/api/routes.py), [signature validators](../dpe/dobar_payment/core/webhooks.py). No provider sandbox or settlement validation is claimed.
