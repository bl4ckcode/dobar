---
name: dobar-bugfix
description: Reproduce and fix a bounded Dobar defect with causal evidence, an affected-area skill, a narrow patch, and a meaningful regression check.
metadata:
  owner: bugfix
---

# dobar-bugfix

## Inputs and context

Require observed behavior, expected behavior or spec criterion, reproduction context, and affected revision. Read [repository instructions](../../../AGENTS.md), relevant area instructions, and select dobar-frontend, dobar-backend, or dobar-payments according to the failing boundary. Keep sensitive values out of reproduction artifacts.

## Procedure and outputs

- Reproduce with the smallest relevant check; capture exact inputs, command, environment, and failure. If local reproduction is unavailable, trace the failing code path and clearly label the limit.
- Trace the cause across caller/handler boundaries before editing symptoms. Compare errors and contracts, especially CORS/transport failures versus provider failures, response-shape mismatches, and stale permission context.
- Make a scoped correction preserving deployed API/data compatibility. If the cause needs a material product change or several area contracts, return a planner handoff instead of expanding the patch silently.
- Add a regression check that fails for the original defect where meaningful; reuse existing tests or fixtures. Avoid broad refactoring and assertions that merely mirror implementation constants.

## Boundaries, checks, and escalation

Run the regression and appropriate affected-area checks once the fix is complete; broaden only when evidence justifies it. Keep implementation status separate from verification, and report blocked environments. Deliver cause, changed behavior, test results, and remaining uncertainties. Do not stage/commit/deploy or retry live money-moving operations as part of debugging without explicit authorization. Escalate missing expected behavior or an unbounded fix while continuing safe independent diagnosis.
