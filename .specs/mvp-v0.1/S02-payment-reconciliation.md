---
id: "S02"
title: "Payment confirmation, reconciliation and error visibility"
owner: "payments"
areas: ["fe", "be", "dpe"]
priority: "P0"
depends_on: []
source_requirements: ["MVP-S02-01", "MVP-S02-02", "MVP-S02-03", "MVP-S02-04", "LAUNCH-S02-01", "MVP-PRINCIPLE-01", "MVP-PRINCIPLE-03", "MVP-PRINCIPLE-04"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend", "payments"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend", "dobar-payments"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "provider-sandbox"]
---

# S02: Payment confirmation, reconciliation and error visibility

## Intended behavior

Deliver the payment confirmation, reconciliation and error visibility journey for the Belo Horizonte MVP. Apply across affected launch journeys. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

BE payment webhook/status routes, DPE webhook/state-machine modules and realtime services exist. Communication docs contain historical end-to-end completion claims that do not prove current client-visible or provider-backed success.

Confirm actual provider-to-DPE-to-BE event path, signature/service authentication, durable event/payment state and broadcast timing. Capture contradictions instead of treating a mock response or health check as payment proof.

Observed source references (inspection only; no runtime or E2E validation):

- [be/app/payment/routes.py](../../be/app/payment/routes.py)
- [be/app/payment/dpe_client.py](../../be/app/payment/dpe_client.py)
- [dpe/dobar_payment/core/webhooks.py](../../dpe/dobar_payment/core/webhooks.py)
- [dpe/dobar_payment/core/state_machine.py](../../dpe/dobar_payment/core/state_machine.py)
- [dpe/dobar_payment/api/middleware.py](../../dpe/dobar_payment/api/middleware.py)
- [be/app/bars_and_restaurants/services/realtime_updates.py](../../be/app/bars_and_restaurants/services/realtime_updates.py)

## Contracts and compatibility

Canonical FE/BE and BE/DPE contracts: separate transport, payment and order states; correlation ID plus payment/order/provider identifiers, stable error categories and authenticated idempotent callbacks.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) and [BE/DPE contract](../../docs/BE_DPE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **S02-AC01** — Provider event authenticity and DPE->BE service authentication are verified before durable state change; invalid signatures and cross-order/provider mappings are rejected.
- **S02-AC02** — Duplicate/out-of-order events and retries cannot duplicate credit/order/entitlement side effects or regress terminal success; reconciliation recovers missed delivery from provider-backed status.
- **S02-AC03** — After durable payment confirmation both customer and authorized venue cashier receive the same paid outcome; pending/unknown/failed payment remains separate from preparation workflow.
- **S02-AC04** — A trace follows FE request through BE, DPE and provider with redacted identifiers; user-visible CORS/transport/validation/provider decline/timeouts are distinguishable without PAN/CVV/secrets.
- **S02-AC05** — Evidence records sandbox/provider/device environment and commands/outcomes; missing credentials, unavailable services or skipped checks report blocked/skipped and never validated.

## Validation scenarios and evidence

- Replay signed/invalid/duplicate/reordered events, drop callback then reconcile, interrupt BE/DPE, simulate preflight and decline, and correlate client/cashier/persisted provider outcome.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Use provider test mode only for sandbox verification; record provider IDs and redacted evidence. Missing provider access is blocked, not a passing mock.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-S02-01, MVP-S02-02, MVP-S02-03, MVP-S02-04, LAUNCH-S02-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
