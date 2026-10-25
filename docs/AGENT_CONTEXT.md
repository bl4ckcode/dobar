# Agent context authority and findings

## Read order and authority

1. Root and affected-area `AGENTS.md` define operational constraints.
2. [MVP source](q4_2026/Dobar_MVP_v0.1.md) and approved specs define desired behavior; specs carry testable acceptance and handoffs.
3. [FE ↔ BE](FE_BE_COMMUNICATION.md) and [BE ↔ DPE](BE_DPE_COMMUNICATION.md) are rolling handoffs containing only the latest update per sender and minimal source links. Schemas/routes define full wire behavior; [FE API errors](../fe/.docs/API_ERROR_CONTRACT.md) defines the error design. Area architecture/workflow documents supply implementation context.
4. Implementation and reproducible test observations establish what the current checkout does. They do not automatically supersede approved intent. When implementation contradicts a contract or spec, record both, attach evidence, and create corrective work.

Never promote a historical “complete”, “deployed”, or “verified” label to current evidence. Validation requires a named check, outcome, relevant revision/environment, and usable evidence. Keep delivery status separate from verification; blocked/skipped checks cannot satisfy acceptance. The [workflow guide](AGENT_WORKFLOW.md) describes the executable tooling.

## Open findings from foundation inspection (2026-10-22)

| ID | Observed conflict | Evidence / owner |
|---|---|---|
| CTX-001 | Current order pipeline includes `confirmed`; MVP specifies four stages. A compatibility decision and coordinated migration are needed before changing persisted/wire values. | [order routes](../be/app/bars_and_restaurants/routes/orders.py); FE/BE |
| CTX-002 | Archived docs report staff COMPLETE, but FE expects `invite_id`, sends acceptance JSON to a query-parameter API, and expects absent workspace fields. | [staff routes](../be/app/bars_and_restaurants/routes/staff.py), [FE source](../fe/lib/features/staff/data/datasources/staff_remote_data_source.dart); FE/BE pilot |
| CTX-003 | Inviting existing users grants membership before explicit acceptance; acceptance does not match a verified contact. Alternate invite authorization differs. | [staff](../be/app/bars_and_restaurants/routes/staff.py), [alternate invite](../be/app/bars_and_restaurants/routes/staff_invite.py); BE pilot |
| CTX-004 | Standalone Pix constructs a hardcoded-key BR Code and encodes text as PNG; this is not provider-backed payment confirmation. | [Pix route](../dpe/dobar_payment/api/routes.py); DPE/FE |
| CTX-005 | Generic country routing can send Brazil subscriptions to PagarMe; the approved Stripe Checkout/Portal journey is follow-on implementation. | [subscription service](../be/app/advertising/services/subscription_service.py), [DPE routes](../dpe/dobar_payment/api/routes.py); BE/DPE |
| CTX-006 | DPE forwarded webhooks omit metadata that BE subscription/payout logic expects. | [DPE schema](../dpe/dobar_payment/api/schemas.py), [BE webhook](../be/app/payment/routes.py); BE/DPE |
| CTX-007 | Error contract and current route behaviors differ; payment translation collapses upstream outcomes and source contains legacy card payloads/client-controlled totals. | [payment routes](../be/app/payment/routes.py), [schemas](../be/app/payment/schemas.py); FE/BE/DPE |
| CTX-008 | Legacy DPE/external validators introspect methods or declare response shapes; they do not prove provider availability, native wallet support, or E2E correctness. | [contract validators](../be/tests/contract_validation/validate_dpe_contracts.py), [external validator](../be/tests/contract_validation/validate_external_apis.py); validation |

Do not silently resolve semantic contradictions during automated context scans. Report a finding with source, expected behavior, observed behavior, owner, and next acceptance check. Deterministic validation can check structure/coverage/links; it cannot establish business correctness.

## Historical context

[Consolidation snapshots](archive/agent-context-2026-10-22/README.md) preserve earlier requirements, rate-card details, decisions, and examples. They are excluded from canonical context. Old FE and DPE API-summary paths point to root contracts. There is no current `dpe/.docs` tree; old links to it are historical.

Retain these existing snapshots as history; do not add routine handoff archives. New communication changes replace the corresponding sender entry and rely on Git/Linear for past versions.
