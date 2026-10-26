---
owner: product
---

# Platform specifications

Independent platform capabilities live outside the fixed 25-journey MVP inventory. Revise each spec in place, preserve acceptance IDs and use Git/Linear for history.

| Spec | Capability | Status |
|---|---|---|
| [P01](P01-development-pr-workflow.md) | Isolated dev environment, task worktrees/branches, tested PRs and protected-main rollout | Ready / unverified; implementation is follow-on work |

[P01 planning and handoffs](handoffs/P01-orchestration.md) records the source audit, acceptance gaps, dependency-ordered assignments and verification requirements. Start with its cross-repo-planner handoff; implementation and rollout have not started.

```sh
python -m tools.agent_workflow --catalog platform validate
python -m tools.agent_workflow --catalog platform handoff --spec P01 --role cross-repo-planner
python -m tools.agent_workflow --catalog platform tickets export --output .agent-workflow/platform-tickets
python -m tools.agent_workflow --catalog platform verify --spec P01
```

The last command reports blocked lifecycle E2E until implemented. Export is local; it does not create a Linear feature or provision resources. [Requirement mappings](requirements.json) and [manifest](manifest.json) define this catalog independently of the MVP.
