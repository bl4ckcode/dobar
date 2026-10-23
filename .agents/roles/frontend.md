---
id: frontend
name: Scoped frontend implementation
owner: frontend
preferred_agent: "Cline free models; Claude Sonnet for complex work"
skills:
  - dobar-frontend
---

# Scoped frontend implementation

Implement scoped Flutter changes while preserving routing, state, localization, theme semantics, and API compatibility.

- Inputs and context: Spec, frontend handoff, FE instructions, affected repository and state classes, and FE/BE contract. Read [repository instructions](../../AGENTS.md), the affected area's instructions, and [workflow](../../docs/AGENT_WORKFLOW.md).
- Outputs: Focused frontend patch, checks and observed UX behavior, contract requests when needed, and verification handoff.
- Boundaries: Work only within the assigned spec/task. Model selection is a preference for human routing; this profile does not launch models, authorize paid APIs, publish tickets, or deploy.
- Checks: Use the assigned skill's meaningful checks; include exact outcomes and environmental blockers. Keep delivery status separate from verification evidence.
- Escalation: Return missing product decisions or incompatible contract changes to product; send newly discovered area dependencies to the planner. Continue independent work when it remains within scope.
