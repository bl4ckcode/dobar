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
3. Apply with `--apply` only when the user's task authorizes live synchronization. Live writes follow the current user's authorized scope; do not publish the entire backlog merely because a spec was revised.
4. Preserve one parent issue per spec; create area child issues only when work actually spans areas. Keep explicit dependencies, acceptance criteria, role and skill references, and check expectations.
5. Update only the workflow-owned issue section. Preserve human notes, assignees, issue state, and other unmanaged content. Persist each successful issue mapping so partial failure can resume without duplicating prior creations.

## Boundaries, checks, and escalation

Re-preview before retrying a partial failure. Reconcile existing stable identifiers and mappings; never retry an uncertain create blindly. Stop live writes on ambiguous matches, invalid destination, authentication failure, or conflicting ownership; deliver local drafts plus the actionable failure. Repeated export must be stable and reruns must reuse issues. Report actual URLs/identifiers only after successful API results; no fabricated synchronization claims.

## Labels and cycle policy

Read existing team labels and cycles before creating/updating issues. Preserve existing labels; add the actual affected scopes: `barz-fe` for Flutter, `barz-be` for FastAPI, `payments` for payment/gateway work, and `platform` for infrastructure/CI/hosting/shared tooling. Cross-area work can carry several. Keep existing `dobar-dpe`, `security`, `infra`, and `ui` labels where relevant. Never infer backend-only ownership from a UI symptom without reading the issue.

Apply a type: `Bug` for a reproduced defect/hotfix, `Improvement` for a bounded adjustment/optimization, `Feature` for new capability. For a newly created bug/hotfix/minor adjustment without an explicit cycle, assign the team's current cycle. Preserve an already selected cycle; do not move a planned feature/epic or pull its children into a sprint automatically. When no current cycle exists, leave it unset and report the missing cycle; do not invent a sprint or choose a past/future cycle.

For an authorized backlog tagging pass, add missing labels without changing descriptions, status, assignee, priority, parents or cycles unless requested. Read back results. The feature-export CLI applies configured area/Feature labels; connected issue-creation work must also perform this type/cycle policy. Headless automation for the full task lifecycle is planned in P01.
