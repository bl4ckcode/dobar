---
id: "B11"
title: "Master and VIP subscription purchase"
owner: "payments"
areas: ["fe", "be", "dpe"]
priority: "P0"
depends_on: ["B01"]
source_requirements: ["MVP-B11-01", "LAUNCH-B11-01"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend", "payments"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend", "dobar-payments"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "provider-sandbox"]
---

# B11: Master and VIP subscription purchase

## Intended behavior

Deliver the master and vip subscription purchase journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

FE has plans and trial UI; BE has trial/setup, capture, upgrade charge and a generic hosted-checkout route. Subscription service currently routes payment-method dictionaries through DPE, which is not proof of a browser subscription Checkout journey.

Create authorized Stripe subscription Checkout for Master/VIP and reconcile current trial/capture semantics. Generic hosted checkout and legacy successful-looking records must not establish paid entitlements.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/advertising/presentation/pages/subscription_plans_page.dart](../../fe/lib/features/advertising/presentation/pages/subscription_plans_page.dart)
- [fe/lib/features/advertising/presentation/bloc/subscription_trial_cubit.dart](../../fe/lib/features/advertising/presentation/bloc/subscription_trial_cubit.dart)
- [be/app/advertising/services/subscription_service.py](../../be/app/advertising/services/subscription_service.py)
- [be/app/payment/routes.py](../../be/app/payment/routes.py)
- [dpe/dobar_payment/gateways/stripe.py](../../dpe/dobar_payment/gateways/stripe.py)

## Contracts and compatibility

Backend-owned plan/Stripe Price mapping and allowlisted return URLs; authenticated subscription checkout capability returns Stripe hosted URL/session reference. Keep customer purchases on PagarMe; Stripe owns business subscription billing. See [Stripe Checkout](https://docs.stripe.com/payments/checkout/build-subscriptions).

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) and [BE/DPE contract](../../docs/BE_DPE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B11-AC01** — Authorized owner/admin selects an available Master or VIP plan and opens Stripe-hosted subscription Checkout with correct backend-configured BRL price and venue customer.
- **B11-AC02** — Client cannot supply arbitrary amount/Price/customer or switch another venue subscription; create/retry uses stable idempotency semantics.
- **B11-AC03** — Success/cancel return routes restore venue context and show pending/canceled/confirmed state; redirect query parameters never grant entitlements.
- **B11-AC04** — Verified Stripe events establish and update subscription/entitlements exactly once, including delayed/failed payment and trial transitions.
- **B11-AC05** — Legacy trial/setup/capture entry points remain compatible or have documented safe migration behavior; sandbox evidence includes Checkout payment and entitlement readback.

## Validation scenarios and evidence

- Sandbox Master/VIP purchase, cancel Checkout, retry after timeout, tamper plan/venue, fail payment and replay/delay Stripe events; verify portal entry only when customer association exists.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Use provider test mode only for sandbox verification; record provider IDs and redacted evidence. Missing provider access is blocked, not a passing mock.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B11-01, LAUNCH-B11-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
