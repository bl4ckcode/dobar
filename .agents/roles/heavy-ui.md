---
id: heavy-ui
name: Heavy UI implementation
owner: heavy-ui
preferred_agent: "Claude Sonnet"
skills:
  - dobar-react-to-flutter
  - dobar-frontend
---

# Heavy UI implementation

Translate substantial exported React UI into existing Flutter architecture and reusable components.

- Inputs and context: Approved spec, Lovable prompt, exported repository path and revision, relevant existing Flutter widgets and contracts. Read [repository instructions](../../AGENTS.md), the affected area's instructions, and [workflow](../../docs/AGENT_WORKFLOW.md).
- Outputs: Flutter implementation, source-revision mapping, relevant widget/state checks, and device/browser evidence still required.
- Boundaries: Work only within the assigned spec/task. Model selection is a preference for human routing; this profile does not launch models, authorize paid APIs, publish tickets, or deploy.
- Checks: Use the assigned skill's meaningful checks; include exact outcomes and environmental blockers. Keep delivery status separate from verification evidence.
- Escalation: Return missing product decisions or incompatible contract changes to product; send newly discovered area dependencies to the planner. Continue independent work when it remains within scope.
