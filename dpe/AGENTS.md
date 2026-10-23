# Dobar payment engine agent guidelines

FastAPI payment middleware routing to Stone/PagarMe, Stripe, and PayPal. Read [root instructions](../AGENTS.md) first.

- Preserve wire compatibility, idempotency, webhook authenticity, and existing payment data. Keep sensitive data and credentials out of logs and artifacts.
- Deploy to FlyIO only through existing GitHub Actions CI/CD; never deploy manually or automatically stage/commit/push.
- Read [architecture/routing](docs/agents/architecture.md), [development workflow](docs/agents/development_workflow.md), and [sandbox integration guide](docs/agents/integration_guide.md).
- The canonical [BE ↔ DPE contract](../docs/BE_DPE_COMMUNICATION.md) distinguishes observed APIs from MVP intent. Record contradictions with source evidence; historical completion labels are not verification.
- HTTP payment amounts use integer `amount_cents`; document conversions at gateway boundaries. Preserve retry/idempotency keys. Do not modify vendored `pagarme_sdk/`.
- Install with `pip install -e ".[dev,all]"`. Run affected `pytest` tests, `ruff check .`, and `mypy dobar_payment/` as appropriate; format changed Python with the existing Black configuration.
- PagarMe handles Brazil purchases; Stripe is the subscription strategy. Current generic routing is country-based; do not imply planned Checkout/Portal behavior already exists.
