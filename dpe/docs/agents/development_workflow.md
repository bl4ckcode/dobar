# Development Workflow

## Python Setup

- **Python 3.12** (per `runtime.txt`)
- **Package manager**: pip with pyproject.toml (setuptools)
- **Install**: `pip install -e ".[dev]"` for development, `pip install -e ".[all]"` for full

## Commands

```bash
# Run tests
pytest                          # all tests
pytest tests/test_gateways.py   # specific file

# Lint & format
ruff check .                    # lint
black .                         # format (line-length=100)

# Type check
mypy dobar_payment/             # strict mode enabled

# Run API locally
uvicorn dobar_payment.api.app:create_app --factory --port 8001
```

## Code Style

- **Line length**: 100 characters (`black` and `ruff` config)
- **Type hints**: Required on all public APIs (`mypy` strict mode)
- **Async**: All gateway methods are async; use `pytest-asyncio` with `asyncio_mode = "auto"`
- **Formatting**: `black` for formatting, `ruff` for linting (rules: E, F, I, W)

## Testing

- Test files live in `tests/` at the repo root
- Async tests use `pytest-asyncio` — no need for `@pytest.mark.asyncio` decorators (auto mode)
- Gateway tests use mocked HTTP clients; integration tests hit sandbox APIs
- Run with coverage: `pytest --cov=dobar_payment`

## Git Workflow

- All deploys go through **GitHub Actions CI/CD** → FlyIO
- Never push directly to production
- Ensure backward compatibility for existing users and data before merging

## Gateway Implementation Notes

When modifying or adding gateways:
- Extend the abstract base in `interfaces.py`
- All gateway methods must be `async`
- Return standardized response format (see [API Contract](./api_contract.md))
- Add webhook validation in `core/webhooks.py`
- Register new gateways in `core/router.py`
- **Do not modify** `pagarme_sdk/` — it is vendored

## Key Invariants

- Amounts are always **integers in cents** (`amount_cents`), never float reais
- All payment operations require an `idempotency_key`
- Payments route by **country**, not payment method
- Stripe is the strategic gateway for subscription lifecycle (trials, off-session)