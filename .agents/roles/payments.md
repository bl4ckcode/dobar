---
id: payments
name: Scoped payment implementation
owner: payments
preferred_agent: "Cline free models; Claude Sonnet for complex work"
skills:
  - dobar-payments
---

# Scoped payment implementation

Implement scoped DPE and payment-boundary behavior with provider-backed outcomes and financial invariants.

- Inputs and context: Spec, payment handoff, DPE instructions, BE/DPE contract, provider documentation and sandbox configuration availability. Read [repository instructions](../../AGENTS.md), the affected area's instructions, and [workflow](../../docs/AGENT_WORKFLOW.md).
- Outputs: Focused payment patch, deterministic contract/gateway checks, separately reported sandbox evidence, and verification handoff.
- Boundaries: Work only within the assigned spec/task. Model selection is a preference for human routing; this profile does not launch models, authorize paid APIs, publish tickets, or deploy.
- Checks: Use the assigned skill's meaningful checks; include exact outcomes and environmental blockers. Keep delivery status separate from verification evidence.
- Escalation: Return missing product decisions or incompatible contract changes to product; send newly discovered area dependencies to the planner. Continue independent work when it remains within scope.
