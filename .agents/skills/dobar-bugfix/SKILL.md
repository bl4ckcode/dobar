---
name: dobar-bugfix
description: Diagnose and fix a bounded Dobar defect, or prepare an evidence-based ticket and handoff when reproduction, product intent, or compatible scope is unresolved.
metadata:
  owner: bugfix
---

# dobar-bugfix

## Inputs and context

Collect observed behavior, expected behavior or spec criterion, reproduction context, and affected revision (including relevant local changes). Identify missing inputs explicitly; continue safe source tracing without inventing fixtures, product intent, or runtime evidence. Read [repository instructions](../../../AGENTS.md), relevant area instructions, and select dobar-frontend, dobar-backend, or dobar-payments according to the failing boundary. Keep sensitive values out of reproduction artifacts.

## Procedure and outputs

- Reproduce with the smallest relevant check; capture exact inputs, command, environment, and failure. If local reproduction is unavailable, trace the failing code path and clearly label the limit.
- Trace the cause across caller/handler boundaries before editing symptoms. Compare errors and contracts, especially CORS/transport failures versus provider failures, response-shape mismatches, and stale permission context.
- Make a scoped correction preserving deployed API/data compatibility. If the cause needs a material product change or several area contracts, return a planner handoff instead of expanding the patch silently.
- Add a regression check that fails for the original defect where meaningful; reuse existing tests or fixtures. Avoid broad refactoring and assertions that merely mirror implementation constants.

## Boundaries, checks, and escalation

Run the regression and appropriate affected-area checks once the fix is complete; broaden only when evidence justifies it. Keep implementation status separate from verification, and report blocked environments. Deliver cause, changed behavior, test results, and remaining uncertainties. Do not stage/commit/deploy or retry live money-moving operations as part of debugging without explicit authorization. Escalate missing expected behavior or an unbounded fix while continuing safe independent diagnosis.

## Spec and ticket hygiene

Use the existing journey spec when the defect belongs to it. Add or refine supported acceptance before implementation, preserving criterion IDs, and link the issue when available; do not create a duplicate spec for each fix. A new independently testable capability needs product/spec work through [dobar-spec](../dobar-spec/SKILL.md), including a real source/decision reference rather than invented requirement provenance. For implemented boundary changes, replace the appropriate sender entry using [rolling communication notes](../dobar-communication-docs/SKILL.md); unresolved proposals belong in the handoff, not as current wire contracts.

## Unresolved outcomes and artifact placement

When no safe fix can be completed, state the outcome: `not reproduced`, `blocked by missing evidence`, `needs product decision`, or `feature candidate`. These describe diagnosis, not verification success. Explain why implementation stopped and what specific evidence or decision permits the next step. Do not treat lack of reproduction as proof that the bug is absent or is a feature.

- Put local diagnosis and check evidence in `.agent-workflow/reports/<issue-or-slug>-diagnosis.md`, a ticket draft in `.agent-workflow/tickets/<issue-or-slug>.md`, and the next assignment in `.agent-workflow/handoffs/<issue-or-slug>-<role>.md`. These ignored files are runtime artifacts: return their exact paths and keep durable intent in the existing spec, unresolved contradictions in `docs/AGENT_CONTEXT.md`, and history in Git/Linear. Do not put a standalone bug report or design proposal under `.specs/mvp-v0.1`, invent a spec ID, or register a new journey just to store diagnosis.
- The diagnosis separates reported behavior, source inspection, executed reproduction, hypotheses, and proposed changes. Include revision/environment, exact commands/inputs/results or the reason reproduction was unavailable, source symbols, affected criteria, and passed/failed/blocked/skipped checks. Quoted current code and schemas must match the checkout; label pseudocode and unapproved interfaces as proposals.
- The ticket draft includes symptom and impact, expected-behavior source (or explicit uncertainty), reproduction/evidence, affected spec/criteria/areas, implementation and verification status, missing inputs/decisions, and the next owner/action. Apply [dobar-linear](../dobar-linear/SKILL.md): search existing issues/mappings before creating; preserve human content, labels and existing cycles. Use `Bug` for an evidenced defect, `Feature` only for established new capability, and describe unresolved classification honestly. Assign a current cycle to new bugs/minor adjustments only when one exists; do not automatically schedule a feature.
- Publish only within the user's explicit authorization for Linear writes. With authorization and access, create/update the scoped issue and read back its actual ID/URL before linking it. Without authorization or access, deliver the complete local draft and report publication as pending or blocked with the reason. Skill invocation alone does not authorize publication. The spec ticket exporter creates feature parent/area tasks; it is not a standalone bug-intake command. Do not sync a whole journey merely to register one defect.
- Produce a handoff when another role must act: product for undefined expected behavior or a feature decision, cross-repo-planner for incompatible/multi-area contracts, or the affected implementer for a bounded fix awaiting evidence. Name the receiving role, concrete objective and allowed scope, canonical spec/criteria or unmapped-intent gap, evidence/ticket paths, prerequisites, exact open decisions or missing data, ordered next steps, check commands and completion conditions. Include the publication state and an executable starting prompt. A handoff may be explicitly blocked; do not label it implementation-ready until its prerequisites are met. If no further action is needed, explain that disposition rather than creating an artificial assignment.

Return cause/confidence, outcome, changed files (if any), check results, artifact paths, ticket publication state, and the next responsible role. Generated CLI handoffs for registered specs are context snapshots; add the actual bug assignment and blockers before routing them. Do not use an unregistered report identifier with `handoff --spec`.
