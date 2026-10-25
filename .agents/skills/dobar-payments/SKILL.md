---
name: dobar-payments
description: Implement Dobar payment-engine and BE/DPE boundary changes covering provider tokens, integer cents, idempotency, Pix confirmation, Stripe subscriptions, and sandbox evidence.
metadata:
  owner: payments
---

# dobar-payments

## Inputs and context

Read the spec, [DPE instructions](../../../dpe/AGENTS.md), [architecture](../../../dpe/docs/agents/architecture.md), [development workflow](../../../dpe/docs/agents/development_workflow.md), [BE/DPE contract](../../../docs/BE_DPE_COMMUNICATION.md), and [sandbox guide](../../../dpe/docs/agents/integration_guide.md). Verify current primary provider documentation before changing provider integration assumptions.

## Procedure and outputs

- Trace Flutter → BE → DPE → provider and asynchronous confirmation. PagarMe/Stone handles Brazilian purchases; Stripe handles business subscription lifecycle. Do not switch purchase providers as an incidental fix.
- Keep DPE amounts integer cents, convert once at the BE boundary using exact decimal semantics, and preserve currency/country. BE owns charge amounts and plan selection; DPE validates routing and provider requests.
- Require authenticated BE/DPE calls and verified provider webhooks. Propagate idempotency and request IDs; reject conflicting retries and handle duplicate/out-of-order events without double charges or grants.
- Use provider-side card tokenization and provider card references; never route PAN/CVV through application services/logs or design a proprietary card-security SDK. Do not modify vendored `dobar_payment/pagarme_sdk`.
- Pix must create a provider-backed charge, return valid Copia e Cola/QR data with expiry, and confirm settlement through authenticated status/webhook evidence. Inspect the standalone route's hardcoded payload and QR encoding when assigned Pix fixes; displaying a QR alone is not settlement.
- Stripe subscription work uses Checkout for purchase and Customer Portal for management. Grant entitlements from verified backend/webhook state, not browser redirects. Preserve cancellation/payment-failure recovery.

## Boundaries, checks, and escalation

Run relevant mocked gateway/API/contract `pytest` checks from `dpe`, plus configured `ruff check .` and `mypy dobar_payment/` when relevant. Validate FE/BE/DPE contract fixtures from one checkout. Run provider sandbox cases separately and record provider request references without secrets; unavailable credentials are blocked evidence. Live charges/refunds and deployment require explicit task authorization. Output deterministic results, sandbox evidence, and remaining reconciliation risks; escalate ambiguous monetary ownership or provider capabilities before money-moving changes.

## Communication handoff

When this task changes an integration boundary, use [dobar-communication-docs](../dobar-communication-docs/SKILL.md). Replace the latest entry for the sending area, retain the other side's entry, update the date and remove superseded text. Git/Linear carry history; do not append a change log or a full API catalog.
