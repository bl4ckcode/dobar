# Dobar repository agent guidelines

Dobar is a monorepo: `fe` (Flutter), `be` (FastAPI), `dpe` (payment engine), and `docs` (durable product and integration context).

## Before changing an area

- Read its `AGENTS.md` and linked architecture/workflow guidance. For cross-area work, read every affected area's instructions.
- Use [context authority and observed findings](docs/AGENT_CONTEXT.md), [FE ↔ BE contract](docs/FE_BE_COMMUNICATION.md), and [BE ↔ DPE contract](docs/BE_DPE_COMMUNICATION.md). Keep canonical contracts concise and update them with contract changes; old paths are compatibility links.
- `docs` records durable decisions and current contracts; `.specs/mvp-v0.1` records intended behavior and acceptance criteria. Code evidence can reveal a contradiction; record it with a source reference rather than silently declaring either behavior validated.
- For spec-driven work, use [the workflow guide](docs/AGENT_WORKFLOW.md), role profiles in `.agents/roles`, and canonical skill packages in `.agents/skills`. Model preferences guide explicit handoffs; never automatically invoke paid APIs.

## Working rules

- Preserve backward compatibility for existing users, wire contracts, and stored data. Describe migrations or staged transitions explicitly.
- Preserve user changes. Never automatically stage, unstage, commit, or push; the user owns those operations unless explicitly requested.
- Deploy through existing GitHub Actions CI/CD only. Never deploy manually.
- Keep scope tied to a spec or reproducible defect. Shared order-flow intent is Pending → Preparing → Ready → Completed; current additional states require a compatibility plan.
- Brazil MVP: Belo Horizonte, BRL, Portuguese UI; PagarMe purchases and Stripe business subscriptions. Keep current behavior and planned integrations distinct.
- Validate with the narrow meaningful checks first. Report passed, failed, blocked, and skipped separately; a structural check or implementation claim is not E2E evidence.

## Foundation checks

From the repository root:

```sh
python -m pip install -r tools/agent_workflow/requirements.txt
python -m tools.agent_workflow validate
python -m unittest discover -s tools/agent_workflow/tests -v
```

Area-specific checks remain in their instructions. Never record unexecuted, unavailable-provider, or unavailable-device checks as passed.
