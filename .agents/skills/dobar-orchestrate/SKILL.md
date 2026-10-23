---
name: dobar-orchestrate
description: Coordinate Dobar MVP specifications, dependency ordering, role handoffs, and evidence-based completion across FE, BE, and payments.
metadata:
  owner: product
---

# dobar-orchestrate

## Inputs and context

Read the requested spec from the [MVP index](../../../.specs/mvp-v0.1/README.md), [workflow](../../../docs/AGENT_WORKFLOW.md), [repository instructions](../../../AGENTS.md), and affected area instructions. Load [role profiles](../../roles/product.md) to choose ownership; model preferences live in profiles.

## Procedure and outputs

- Confirm user intent against the source MVP and current implementation. Record conflicts as findings with paths; do not turn undocumented behavior into a product decision.
- Split work at contract boundaries. For multi-area changes, hand off first to cross-repo-planner, then assign ordered area tasks. Bug fixes also load the affected-area skill.
- Run `python -m tools.agent_workflow validate` before exporting tickets. Use `python -m tools.agent_workflow handoff --spec B08 --role frontend` as the handoff pattern, substituting the real spec and role.
- Every handoff identifies acceptance criteria, dependencies, allowed area, relevant contracts, check commands, and unanswered decisions. Provide minimal relevant context rather than the entire repository.
- Send implementation evidence to verifier. Keep implementation delivery and verified acceptance separate; report unavailable providers or devices as blocked/skipped evidence.

## Boundaries, checks, and escalation

Do not automatically call paid models, create live tickets, stage, commit, or deploy. Parallel work must use disjoint ownership and explicit integration points. A profile expresses a preferred agent, not an automatic invocation. Escalate product changes and conflicting security/contract expectations before dependent implementation; preserve independently useful work. Completion requires acceptance evidence, not only a clean diff or a successful metadata check.
