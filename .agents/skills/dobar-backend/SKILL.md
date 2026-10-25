---
name: dobar-backend
description: Implement scoped Dobar FastAPI behavior with server authorization, persistence, compatible schemas, canonical error contracts, and service-level regression validation.
metadata:
  owner: backend
---

# dobar-backend

## Inputs and context

Read the spec, [BE instructions](../../../be/AGENTS.md), [architecture](../../../be/docs/agents/architecture.md), [development workflow](../../../be/docs/agents/development_workflow.md), [FE/BE contract](../../../docs/FE_BE_COMMUNICATION.md), and [API errors](../../../fe/.docs/API_ERROR_CONTRACT.md). For payment boundary changes also read the [BE/DPE contract](../../../docs/BE_DPE_COMMUNICATION.md).

## Procedure and outputs

- Follow the current modular route/service/schema/model boundaries and FastAPI dependencies. Confirm the actual authenticated-user shape and bar-scoped permission dependency rather than relying on legacy role descriptions.
- Enforce resource ownership and permissions server-side. Existing staff roles remain; marketing uses explicit permissions. Invitation issuance cannot grant membership before authenticated, contact-matched acceptance.
- Validate amounts, plan IDs, bar/user ownership, and lifecycle transitions on the server. Preserve error code/category and request correlation across the DPE boundary; redact secrets and customer payment data.
- Use SQLAlchemy/Alembic conventions for persistence changes; plan backward-compatible migrations and transaction/race behavior. Migration detection is automated by CI; special commit tags are unnecessary.
- Update concise canonical contract details when approved request/response/error behavior changes. Do not duplicate endpoint architecture in the spec.

## Boundaries, checks, and escalation

From `be`, use the existing Python environment and relevant `pytest` targets, including auth/permission failures and transaction/idempotency behavior when affected. Follow the local no-comments/docstrings convention for new backend code. Preserve deployed endpoints/data and use GitHub Actions for deployment; do not deploy manually. Deliver patch, contract/migration implications, and exact test results. Escalate incompatible migrations, unresolved role policy, or payment responsibility changes before dependent work.

## Communication handoff

When this task changes an integration boundary, use [dobar-communication-docs](../dobar-communication-docs/SKILL.md). Replace the latest entry for the sending area, retain the other side's entry, update the date and remove superseded text. Git/Linear carry history; do not append a change log or a full API catalog.
