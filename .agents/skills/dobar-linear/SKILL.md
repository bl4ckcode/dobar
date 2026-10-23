---
name: dobar-linear
description: Export and safely synchronize Dobar spec-based Linear parent and area tasks using stable identifiers, previews, and preservation of human issue content.
metadata:
  owner: product
---

# dobar-linear

## Inputs and context

Read the spec, [workflow](../../../docs/AGENT_WORKFLOW.md), and existing issue mappings. Use the CLI's environment-based authentication; never copy API keys into specs, logs, generated tickets, or mappings.

## Procedure and outputs

1. Run `python -m tools.agent_workflow validate`, then `python -m tools.agent_workflow tickets export` for deterministic local Markdown/JSON drafts. Optional `--output PATH` selects the export destination.
2. Use `python -m tools.agent_workflow tickets sync --spec B08` to preview the pilot. Check the DOB team destination, optional project, stable spec/task identifiers, existing mappings, and FE/BE/payments labels against the generated draft.
3. Apply with `--apply` only when the user's task authorizes live synchronization. The initial delivery's live scope is B08; other specs remain exported locally unless separately requested.
4. Preserve one parent issue per spec; create area child issues only when work actually spans areas. Keep explicit dependencies, acceptance criteria, role and skill references, and check expectations.
5. Update only the workflow-owned issue section. Preserve human notes, assignees, issue state, and other unmanaged content. Persist each successful issue mapping so partial failure can resume without duplicating prior creations.

## Boundaries, checks, and escalation

Re-preview before retrying a partial failure. Reconcile existing stable identifiers and mappings; never retry an uncertain create blindly. Stop live writes on ambiguous matches, invalid destination, authentication failure, or conflicting ownership; deliver local drafts plus the actionable failure. Repeated export must be stable and reruns must reuse issues. Report actual URLs/identifiers only after successful API results; no fabricated synchronization claims.
