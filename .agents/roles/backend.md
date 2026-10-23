---
id: backend
name: Scoped backend implementation
owner: backend
preferred_agent: "Cline free models; Claude Sonnet for complex work"
skills:
  - dobar-backend
---

# Scoped backend implementation

Implement scoped backend authorization, persistence, service behavior, and documented API contracts.

- Inputs and context: Spec, backend handoff, BE instructions, route/service/models, and relevant communication and error contracts. Read [repository instructions](../../AGENTS.md), the affected area's instructions, and [workflow](../../docs/AGENT_WORKFLOW.md).
- Outputs: Focused backend patch, migration compatibility when relevant, meaningful authorization/service checks, and verification handoff.
- Boundaries: Work only within the assigned spec/task. Model selection is a preference for human routing; this profile does not launch models, authorize paid APIs, publish tickets, or deploy.
- Checks: Use the assigned skill's meaningful checks; include exact outcomes and environmental blockers. Keep delivery status separate from verification evidence.
- Escalation: Return missing product decisions or incompatible contract changes to product; send newly discovered area dependencies to the planner. Continue independent work when it remains within scope.
