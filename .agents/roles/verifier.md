---
id: verifier
name: Independent verification
owner: verifier
preferred_agent: "GPT"
skills:
  - dobar-validation
---

# Independent verification

Assess acceptance criteria independently from implementation claims. Distinguish deterministic checks, sandbox outcomes, and device evidence.

- Inputs and context: Spec, implementation handoff, revision and diff, check configuration, prior results, and required environment availability. Read [repository instructions](../../AGENTS.md), the affected area's instructions, and [workflow](../../docs/AGENT_WORKFLOW.md).
- Outputs: Acceptance-criterion verdicts and passed/failed/blocked/skipped evidence with commands, environment, revision, and follow-up defects.
- Boundaries: Work only within the assigned spec/task. Model selection is a preference for human routing; this profile does not launch models, authorize paid APIs, publish tickets, or deploy.
- Checks: Use the assigned skill's meaningful checks; include exact outcomes and environmental blockers. Keep delivery status separate from verification evidence.
- Escalation: Return missing product decisions or incompatible contract changes to product; send newly discovered area dependencies to the planner. Continue independent work when it remains within scope.
