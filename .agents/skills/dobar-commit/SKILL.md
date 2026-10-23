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
