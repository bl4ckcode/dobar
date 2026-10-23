---
id: "C10"
title: "Apple Pay and Google Pay"
owner: "payments"
areas: ["fe", "be", "dpe"]
priority: "P1"
depends_on: ["C08"]
source_requirements: ["MVP-C10-01", "LAUNCH-C10-01"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend", "payments"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend", "dobar-payments"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "provider-sandbox", "native-device"]
---

# C10: Apple Pay and Google Pay

## Intended behavior

Deliver the apple pay and google pay journey for the Belo Horizonte MVP. Customer validation includes Android and iOS. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Checkout offers Apple/Google selectors and tags provider apple_pay/google_pay; presentation of a selector does not establish device token acquisition or PagarMe wallet readiness.

Obtain merchant/device capability configuration and verify active PagarMe adapter wallet-token mapping. Unsupported devices must fall back to card/Pix; do not switch customer routing to Stripe without a new product decision.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/payments/presentation/widgets/digital_wallets_section.dart](../../fe/lib/features/payments/presentation/widgets/digital_wallets_section.dart)
- [fe/lib/features/payments/presentation/pages/checkout_page.dart](../../fe/lib/features/payments/presentation/pages/checkout_page.dart)
- [dpe/dobar_payment/api/schemas.py](../../dpe/dobar_payment/api/schemas.py)
- [dpe/dobar_payment/gateways/stone.py](../../dpe/dobar_payment/gateways/stone.py)

## Contracts and compatibility

Provider-supported native wallet token format mapped into existing DPE payment-method contract; document only verified payload support. Device merchant identifiers and capabilities are environment configuration, not repository secrets.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) and [BE/DPE contract](../../docs/BE_DPE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **C10-AC01** — Apple Pay appears only on supported/configured iOS devices and Google Pay only on supported/configured Android devices, with an accessible card/Pix fallback.
- **C10-AC02** — Native wallet approval produces a genuine provider-supported token for the server-priced BRL order and routes Brazilian purchase through PagarMe.
- **C10-AC03** — Cancel, unavailable wallet, token rejection and retry cannot mark payment successful or duplicate charges.
- **C10-AC04** — Android and iOS device evidence includes wallet authorization and provider-confirmed outcome; simulator UI evidence alone cannot validate this journey.

## Validation scenarios and evidence

- Run supported native devices with merchant sandbox setup; cancel sheet, reject token, remove capability and retry a timeout using C08/S02 invariants.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Use provider test mode only for sandbox verification; record provider IDs and redacted evidence. Missing provider access is blocked, not a passing mock.
- Record Android and iOS device/OS evidence for native journeys; unavailable device coverage remains blocked or skipped.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-C10-01, LAUNCH-C10-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
