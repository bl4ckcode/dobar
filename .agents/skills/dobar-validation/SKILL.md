---
name: dobar-validation
description: Independently verify Dobar spec acceptance using reproducible evidence and separate passed, failed, blocked, and skipped outcomes across deterministic, sandbox, and device checks.
metadata:
  owner: verifier
---

# dobar-validation

## Inputs and context

Read the assigned spec and criteria, implementation handoff/diff, checkout revision, [workflow](../../../docs/AGENT_WORKFLOW.md), and affected area instructions. Do not accept an author's completed checkbox as evidence.

## Procedure and outputs

- Run `python -m tools.agent_workflow validate` for foundation consistency, then `python -m tools.agent_workflow verify --spec B08` with the assigned ID. These commands cannot establish product E2E acceptance on their own.
- Map each criterion to evidence: command and exit result, environment/revision, inspected runtime state, redacted request/provider reference, or visual/device observation. Explain the practical limit of mocked checks.
- Use passed for observed expected behavior, failed for observed mismatch, blocked for missing required prerequisites, and skipped for checks deliberately not run. Missing keys, an unavailable provider, or a skipped check never imply validation success.
- Cover negative authorization/contact matching, stale/expired/revoked/used invitations, login-resume, duplicate/concurrent acceptance, and refresh/workspace entry for B08. Check membership is absent before acceptance and unchanged for wrong-account attempts.
- For payment specs distinguish deterministic contract checks, sandbox provider outcomes/webhook reconciliation, and native wallet/device behavior. Check expiry, declines/timeouts, duplicates/out-of-order events, and matching cashier/client status where criteria require them.
- Record follow-up defects with reproduction and criterion IDs. Update verification evidence only to the level actually demonstrated; delivery may be implemented while verification remains incomplete.

## Boundaries, checks, and escalation

Verification does not authorize live charges, publication, or deployment. Prefer independent assessment; if you also authored the patch, disclose that limit. Do not repair product code in the verification pass without a separate assigned implementation task. Report required missing environment or contradictory acceptance to product with actionable evidence; continue available checks. Deliver criterion-level outcomes and a clear remaining-work list.
