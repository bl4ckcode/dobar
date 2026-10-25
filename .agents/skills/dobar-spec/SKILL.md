---
name: dobar-spec
description: Create or refine Dobar MVP journey specs with source coverage, repository evidence, observable acceptance criteria, and separate implementation and verification status.
metadata:
  owner: product
---

# dobar-spec

## Inputs and context

Read the source [MVP](../../../docs/q4_2026/Dobar_MVP_v0.1.md), the [spec index](../../../.specs/mvp-v0.1/README.md), [workflow](../../../docs/AGENT_WORKFLOW.md), area instructions, and affected code. Use the existing spec metadata shape; keep stable C01–C11, B01–B12, and S01–S02 IDs.

## Procedure and outputs

- Map each source requirement to an identified acceptance criterion. Preserve stable requirement and criterion IDs when wording is refined.
- Describe desired behavior separately from current implementation evidence. Cite concrete paths/symbols and mark unexecuted code inspection as inspection, never runtime proof.
- Set owner role, affected areas, dependencies, priority, source requirements, planning/implementation role assignments, required skills, and delivery/verification status using the repository schema.
- Write user-observable criteria and scenarios that a verifier can assess. Include failure/retry/authorization behavior where the journey needs it; link durable API details from canonical docs instead of copying architecture.
- Keep the confirmed Brazil/BRL/Portuguese launch, native customer and browser business surfaces, Pending → Preparing → Ready → Completed order flow, explicit marketing permissions, and authenticated staff acceptance.

## Boundaries, checks, and escalation

Run `python -m tools.agent_workflow validate`; inspect coverage and unresolved findings. Specs describe intended behavior and never silently declare gaps fixed. Ask product for material scope conflicts; ask the planner about incompatible cross-area contracts. Record blocked evidence without downgrading the intended acceptance criteria. Output the updated spec/index mappings and a short list of decisions or dependencies still needed.

## Revisiting a spec

Revise the existing journey spec for refinements, missing cases and bugs within that journey. Keep its spec ID and existing acceptance IDs; append new acceptance IDs and link the driving Linear issue. A bug ticket is not automatically a new journey spec. New independent capabilities get a new catalog/spec, such as [platform work](../../../.specs/platform/README.md).

Before implementing a changed requirement, reconcile intended acceptance with current code. Keep delivery and verification separate; invalidate affected verification claims when behavior changes. Update requirement mappings when acceptance/source coverage changes, and refresh source snapshots only after reviewing semantic coverage. Record history in Git/Linear rather than accumulating old spec versions or changelogs in Markdown. A complete file rewrite is allowed; stable IDs and traceability must survive.
