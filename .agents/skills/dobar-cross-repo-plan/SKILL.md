---
name: dobar-cross-repo-plan
description: Plan Dobar changes spanning Flutter, backend, or payment engine by tracing contracts and defining ordered compatible implementation and verification tasks.
metadata:
  owner: cross-repo-planner
---

# dobar-cross-repo-plan

## Inputs and context

Read the spec, affected area instructions, [FE/BE contract](../../../docs/FE_BE_COMMUNICATION.md), and [BE/DPE contract](../../../docs/BE_DPE_COMMUNICATION.md). Inspect current callers, handlers, schemas, authorization, and relevant tests from the same checkout.

## Procedure and outputs

- Trace the journey end to end, including identifiers, units, authentication, error envelope, status transitions, and asynchronous events. Distinguish documented intent, observed implementation, and runtime evidence.
- Record mismatches with both paths and the affected acceptance criteria. Do not resolve contradictions by selecting whichever source is convenient.
- Define the minimum compatible contract change and migration/rollout order. Identify server-owned decisions such as amount, permissions, entitlement, and provider confirmation.
- Produce ordered FE, BE, and payments tasks only where necessary. Each task specifies its interface, prerequisites, owner role/skills, check commands, and integration acceptance evidence.
- Keep durable contract decisions in canonical communication docs; put desired journey behavior in the spec. Produce focused handoffs using `python -m tools.agent_workflow handoff --spec B08 --role backend` with the actual assignment.

## Boundaries, checks, and escalation

Planning does not authorize schema migrations, live charges, paid agents, or external publication. Validate metadata with `python -m tools.agent_workflow validate`; confirm the planned compatibility and failure handling against actual code. Escalate unresolved product meaning or breaking changes before dependent implementation. Output a decision-complete plan plus explicit blockers when a decision truly cannot be inferred.
