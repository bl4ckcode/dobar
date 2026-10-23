---
id: "C08"
title: "Brazilian card checkout"
owner: "payments"
areas: ["fe", "be", "dpe"]
priority: "P0"
depends_on: ["C07"]
source_requirements: ["MVP-C08-01", "LAUNCH-C08-01", "MVP-PRINCIPLE-01", "MVP-PRINCIPLE-03"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend", "payments"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend", "dobar-payments"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "provider-sandbox", "native-device"]
---

# C08: Brazilian card checkout

## Intended behavior

Deliver the brazilian card checkout journey for the Belo Horizonte MVP. Customer validation includes Android and iOS. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

FE saved-card flow currently constructs tok_<timestamp> with a comment to tokenize via the gateway SDK; BE v2 charge delegates to DPE and Stone adapter accepts provider card token/id.

Fabricated tokens are a release blocker. Checkout currently serializes `PaymentType.credit` as `type: credit`, while the BE v2 schema accepts only `card|pix`; saved-card checkout sends `payment_method_id` with a null token, but that field is absent from the BE charge method schema. DPE forwards a card `token`, while the active Stone adapter reads `card_token` or `card_id`. Resolve these serialization and saved-card ownership/reference gaps together with provider token creation, BRL-to-cents conversion and confirmation. Repository claims about PCI scope are not proof.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/payments/presentation/pages/payment_methods_page.dart](../../fe/lib/features/payments/presentation/pages/payment_methods_page.dart)
- [fe/lib/features/payments/presentation/pages/checkout_page.dart](../../fe/lib/features/payments/presentation/pages/checkout_page.dart)
- [FE payment serialization](../../fe/lib/features/payments/domain/models/payment_model.dart)
- [BE payment schemas](../../be/app/payment/schemas.py)
- [be/app/payment/routes.py](../../be/app/payment/routes.py)
- [be/app/payment/dpe_client.py](../../be/app/payment/dpe_client.py)
- [dpe/dobar_payment/api/routes.py](../../dpe/dobar_payment/api/routes.py)
- [dpe/dobar_payment/gateways/stone.py](../../dpe/dobar_payment/gateways/stone.py)

## Contracts and compatibility

PagarMe provider tokenization at the frontend provider boundary; existing /payments/v2/charge -> DPE charge contract. Only provider tokens/card references cross FE->BE->DPE; provider secrets remain server-side. See [PagarMe tokenization](https://docs.pagar.me/reference/tokeniza%C3%A7%C3%A3o-1).

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) and [BE/DPE contract](../../docs/BE_DPE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **C08-AC01** — A real PagarMe sandbox token or provider card reference reaches BE/DPE and the selected Brazilian gateway; fabricated tokens cannot appear successful.
- **C08-AC02** — Server derives payable amount, order ownership and BRL currency; decimal-to-integer cents conversion is exact and client tampering is rejected.
- **C08-AC03** — PAN/CVV never reach Dobar BE/DPE, persistence or logs; TLS, authenticated BE/DPE calls and redaction protect token-bearing requests without a proprietary security SDK.
- **C08-AC04** — Repeated submits/timeouts reuse one logical idempotency key and cannot create duplicate charges; declined/uncertain outcomes remain actionable and unpaid until authenticated confirmation.
- **C08-AC05** — Confirmed payment opens the matching order tracker and updates the venue cashier through S02; a client success animation alone cannot mark paid.

## Validation scenarios and evidence

- Capture redacted FE/BE/DPE/provider identifiers for sandbox success, decline, invalid token, amount tamper, unauthorized call, timeout and retry; inspect logs for sensitive data.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Use provider test mode only for sandbox verification; record provider IDs and redacted evidence. Missing provider access is blocked, not a passing mock.
- Record Android and iOS device/OS evidence for native journeys; unavailable device coverage remains blocked or skipped.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-C08-01, LAUNCH-C08-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
