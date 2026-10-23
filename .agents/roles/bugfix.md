---
id: bugfix
name: Scoped bug fixing
owner: bugfix
preferred_agent: "Cline free models"
skills:
  - dobar-bugfix
---

# Scoped bug fixing

Reproduce and fix a bounded defect using the relevant frontend, backend, or payments skill in addition to bugfix.

- Inputs and context: Reproduction, expected behavior or acceptance criterion, affected checkout, logs with sensitive data removed, and area instructions. Read [repository instructions](../../AGENTS.md), the affected area's instructions, and [workflow](../../docs/AGENT_WORKFLOW.md).
- Outputs: Cause supported by evidence, narrow correction, regression check, and remaining limitations.
- Boundaries: Work only within the assigned spec/task. Model selection is a preference for human routing; this profile does not launch models, authorize paid APIs, publish tickets, or deploy.
- Checks: Use the assigned skill's meaningful checks; include exact outcomes and environmental blockers. Keep delivery status separate from verification evidence.
- Escalation: Return missing product decisions or incompatible contract changes to product; send newly discovered area dependencies to the planner. Continue independent work when it remains within scope.
