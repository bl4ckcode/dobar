# Dobar Payment Engine

A **Python payment middleware** (FastAPI) that routes payments through multiple gateways — Stone/Pagar.me (Brazil), Stripe (LATAM/Mexico), PayPal (US/CA/EU).

## Non-Negotiable

- **Deploy only via GitHub Actions CI/CD** to FlyIO. Never deploy manually.
- **Always ensure backward compatibility** for existing users and data.

## Quick Reference

| What | How |
|------|-----|
| Install | `pip install -e ".[all]"` |
| Run API | `uvicorn dobar_payment.api.app:create_app --factory --port 8001` |
| Tests | `pytest` |
| Lint | `ruff check .` |
| Format | `black .` |
| Type check | `mypy dobar_payment/` |

## Detailed Documentation

| Topic | File |
|-------|------|
| Architecture & Gateway Routing | [docs/agents/architecture.md](docs/agents/architecture.md) |
| Python Conventions & Dev Workflow | [docs/agents/development_workflow.md](docs/agents/development_workflow.md) |
| API Contract (BE ↔ DPE) | [docs/agents/api_contract.md](docs/agents/api_contract.md) |
| Integration Guide (Sandbox) | [docs/agents/integration_guide.md](docs/agents/integration_guide.md) |
| Full Business Context & API Specs | [.docs/BE_DPE_COMMUNICATION.md](.docs/BE_DPE_COMMUNICATION.md) |
| Implementation Roadmap | [.docs/IMPLEMENTATION_PLAN.md](.docs/IMPLEMENTATION_PLAN.md) |