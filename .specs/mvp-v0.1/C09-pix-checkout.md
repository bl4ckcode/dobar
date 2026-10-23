---
id: "C09"
title: "Brazilian Pix checkout"
owner: "payments"
areas: ["fe", "be", "dpe"]
priority: "P0"
depends_on: ["C07"]
source_requirements: ["MVP-C09-01", "LAUNCH-C09-01", "MVP-PRINCIPLE-05"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend", "payments"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend", "dobar-payments"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "provider-sandbox", "native-device"]
---

# C09: Brazilian Pix checkout

## Intended behavior

Deliver the brazilian pix checkout journey for the Belo Horizonte MVP. Customer validation includes Android and iOS. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

DPE standalone Pix generation hardcodes pix@barz.app and base64-encodes BR Code text as image/png; the Stone charge adapter instead exposes provider QR, Copia e Cola and expiry fields. BE has both generation and v2 charge paths.

Choose provider-backed order charge as authoritative checkout capability, document one compatible response mapping and remove hardcoded standalone generation from the release checkout path. Diagnose actual CORS separately from provider failures.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/payments/presentation/widgets/pix_payment_modal.dart](../../fe/lib/features/payments/presentation/widgets/pix_payment_modal.dart)
- [be/app/payment/routes.py](../../be/app/payment/routes.py)
- [be/app/payment/dpe_client.py](../../be/app/payment/dpe_client.py)
- [dpe/dobar_payment/api/routes.py](../../dpe/dobar_payment/api/routes.py)
- [dpe/dobar_payment/gateways/stone.py](../../dpe/dobar_payment/gateways/stone.py)

## Contracts and compatibility

Provider-backed Pix creation and canonical payment result fields (payload, valid QR representation, expiry, payment/order ID), status lookup and S02 events. See [PagarMe Pix](https://docs.pagar.me/reference/pix-2).

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) and [BE/DPE contract](../../docs/BE_DPE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **C09-AC01** — Checkout creates an actual provider-backed PagarMe Pix charge for the authenticated server-priced order, linked to stable payment and provider identifiers.
- **C09-AC02** — Modal shows nonempty Pix Copia e Cola, functional copy action, a decodable QR encoding that exact payload, BRL amount and provider expiry; base64 text cannot masquerade as a PNG.
- **C09-AC03** — Pending and expired charges remain unpaid; expiry disables stale payment instructions and retry starts or reuses the appropriate logical attempt without losing order context.
- **C09-AC04** — Authenticated provider confirmation transitions payment once and updates client tracker and cashier; invalid/duplicate/out-of-order webhooks cannot falsely mark paid.
- **C09-AC05** — CORS/preflight, BE transport and DPE/provider failures have distinct traceable outcomes and recoverable Portuguese UI without hiding provider diagnostics.

## Validation scenarios and evidence

- Compare copied payload with decoded QR, verify provider charge association, simulate expiry and signed sandbox confirmation, duplicate webhook, browser preflight and downstream timeout.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Use provider test mode only for sandbox verification; record provider IDs and redacted evidence. Missing provider access is blocked, not a passing mock.
- Record Android and iOS device/OS evidence for native journeys; unavailable device coverage remains blocked or skipped.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-C09-01, LAUNCH-C09-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
