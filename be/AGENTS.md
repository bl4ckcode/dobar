# Dobar backend agent guidelines

Production FastAPI backend with Postgres, Redis, MongoDB, and external services. Read [root instructions](../AGENTS.md) first.

- Preserve wire/data compatibility, enforce authentication and bar permissions server-side, and keep pricing and entitlement decisions server-owned.
- Read [architecture](docs/agents/architecture.md) and [development workflow](docs/agents/development_workflow.md). Use a virtual environment and `requirements.txt` / `requirements-test.txt`.
- Use the canonical [FE ↔ BE](../docs/FE_BE_COMMUNICATION.md) and [BE ↔ DPE](../docs/BE_DPE_COMMUNICATION.md) contracts. Keep durable contract changes there; acceptance intent lives in specs.
- Run affected `pytest` suites and contract checks. Use local `../dpe` source for monorepo integration checks; provider mocks are not sandbox verification.
- Describe migrations and authorization/error-contract changes in handoffs. Never log card data, tokens, or credentials.
- Deploy to FlyIO only through existing GitHub Actions CI/CD. Never deploy manually or automatically stage/commit/push.
