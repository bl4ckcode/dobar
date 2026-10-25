---
name: dobar-commit
description: Consult preserved Dobar contract, migration, and Git guidance when preparing an explicitly requested commit or reviewing deployment readiness.
metadata:
  owner: product
---

# Preserved repository workflow guidance

## Inputs and context

Read the original [commit guidance](../commit-skill.md), [root instructions](../../../AGENTS.md), and affected-area instructions. The original file is retained for existing callers.

## Outputs and boundaries

Prepare a scoped review or an explicitly requested Git operation. This skill does not authorize staging, committing, or deploying. Only an explicit user request permits staging/committing; deployment remains through GitHub Actions.

## Checks and escalation

Keep canonical communication/error contracts current when affected, confirm relevant tests, and account for CI-managed migration execution. Inspect workflow filenames from the current checkout rather than the legacy document's historical filename. Surface conflicting guidance before a dependent operation; do not discard the preserved instructions silently.

## Branch and title conventions

For authorized task branches, use `fix/dob-85-cashier-order-expiry`, `feat/dob-89-staff-invitation-acceptance`, or `docs/dob-88-lovable-prompts` as the naming pattern. Commit subjects and PR titles use `fix: DOB-85: cashier order expiry`, `feat: DOB-89: staff invitation acceptance`, or `docs: DOB-88: refine Lovable prompts`. Include a direct Linear issue link in the PR body, the relevant spec/criteria, validation results, and material blockers.

These conventions do not authorize automatic commits, pushes, PR publication or deployment. The opt-in task/PR automation, isolated worktrees, develop/dev environment and release-to-main flow are proposed in [P01](../../../.specs/platform/P01-development-pr-workflow.md); they are not implemented by this skill update. Preserve current root Git safeguards until that workflow is implemented and explicitly invoked.
