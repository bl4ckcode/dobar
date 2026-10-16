# Dobar — Monorepo

> One repo. Four products. Agent-native by design.

Dobar is an **on-site ordering platform for bars & restaurants**. Customer checks in → browses menu → pays in-app → order appears on the bar dashboard **already paid**.

This repo is the **monorepo** for the whole ecosystem, structured to be ergonomic for both humans and coding agents — inspired by [Basis: How We Made Our Monorepo Ergonomic for Agents](https://www.getbasis.ai/blogs/how-we-made-our-monorepo-ergonomic-for-agents).

```
dobar/
├── be/         # Backend API — FastAPI + Postgres + Mongo + Redis (Fly: barz-backend-bold-sun-5691)
├── fe/         # Client + Business app — Flutter + Bloc (Fly: dobar-app)
├── dpe/        # Dobar Payment Engine — multi-gateway Python middleware (Fly: dobar-payment-engine)
├── landing/    # Marketing landing page (Vite + Tailwind)
├── docs/       # Canonical business + contract docs (SOURCE OF TRUTH)
├── .github/    # Path-filtered CI/CD per package
└── AGENTS.md   # Agent entrypoint — start here
```

Clone:

```bash
git clone https://github.com/bl4ckcode/dobar.git
cd dobar
```

---

## 1. Agent-Native Approach

A codebase is two things at once: **code that runs in production** and **context agents use to make decisions**. Every commit must keep both correct.

We follow 5 principles adapted from Basis:

| Principle | What it means here |
|-----------|-------------------|
| **1. Canonicality** | Every fact has ONE source of truth. `docs/` is truth for business + contracts. Package `AGENTS.md` is truth for how to work in that package. Never duplicate — link. |
| **2. Small, scoped modules** | Work in ONE package at a time (`be/` OR `fe/` OR `dpe/`). Cross-package changes must update the contract doc in `docs/`. |
| **3. Verifiability** | Every agent change must be verifiable: run tests + linter before finishing. CI is the gate, not an afterthought. |
| **4. Interoperability** | Packages talk only through versioned contracts (`docs/FE_BE_COMMUNICATION.md`, `docs/BE_DPE_COMMUNICATION.md`). No back-door imports across `be/fe/dpe`. |
| **5. Automatic context** | `AGENTS.md` files are the loader. Root `AGENTS.md` routes you; package `AGENTS.md` gives you essentials + links to `docs/agents/*.md`. Read them before coding. |

### How to work in this repo (humans + agents)

1. **Start at root `AGENTS.md`**, then read the package one:
   - `be/AGENTS.md` → links to `be/docs/agents/architecture.md`, `development_workflow.md`
   - `fe/AGENTS.md` → links to `fe/docs/agents/architecture.md`, `development_workflow.md`
   - `dpe/AGENTS.md` → links to `dpe/docs/agents/architecture.md`, `development_workflow.md`, `api_contract.md`, `integration_guide.md`
2. **Check `docs/` for contracts before changing APIs:**
   - `docs/FE_BE_COMMUNICATION.md` — FE ↔ BE endpoints, schemas, error contract
   - `docs/BE_DPE_COMMUNICATION.md` — BE ↔ DPE charge/refund/PIX, `payment_method: {type, token}` shape
   - `docs/business/` — vision, pricing, plans (never re-state these in code comments)
3. **Scope your diff:** `git diff --name-only` should touch ONE package + its workflow. If you touch two packages, you must touch a contract doc too.
4. **Never deploy manually.** All deploys go via GitHub Actions to Fly.io. Always keep backward compatibility (DB, API, stored app versions).
5. **Validate before you exit:** run the package's tests + build (see §3). CI will re-run the same.

---

## 2. Packages

### `be/` — Backend API (FastAPI)

On-site ordering, auth (Firebase + JWT), RBAC (owner/admin/manager/cashier/staff), cart/orders/wallet, subscriptions, advertising. One API, two experiences (client + business) by role.

| | |
|---|---|
| Stack | Python 3.12, FastAPI, PostgreSQL (SQLAlchemy async), MongoDB (geo), Redis, Alembic, S3, FCM |
| Payments | via `dpe/` (never directly to gateways) |
| Docs | `GET /health`, Swagger `/docs`, ReDoc `/redoc` |
| Full guide | `be/README.md` + `be/docs/agents/` |

```bash
cd be
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
# .env: SECRET_KEY, DATABASE_URL, MONGO_URI, FIREBASE_CREDENTIALS_JSON, AWS_*
uvicorn app.main:app --reload
pytest tests/ -v
```

### `fe/` — Flutter App (Client + Business)

Clean architecture (`core/` + `features/*/data|domain|presentation`), Bloc + GetIt + Dio + Firebase Auth + Google Maps. One app, two experiences by role.

| | |
|---|---|
| Stack | Flutter 3.47.1 (stable), Dart ^3.12.2, Bloc, Freezed, json_serializable |
| Gateways (via BE/DPE) | BR: Pagar.me (PIX/card/boleto) · LATAM/US: Stripe · RoW: PayPal |
| Full guide | `fe/README.md` + `fe/docs/agents/` |

```bash
cd fe
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter run
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test test/core/ test/features/
flutter build web --release --no-tree-shake-icons  # what Fly serves via nginx
```

### `dpe/` — Dobar Payment Engine (Python middleware)

Unified charge/refund/PIX over Stripe, Stone/Pagar.me, PayPal. Idempotency, circuit-breaker, rate-limiting, distributed locks, state machine, intelligent routing.

| | |
|---|---|
| Stack | Python >=3.10, FastAPI, `pyproject.toml` extras `[api,dev]` |
| Contract | `dpe/docs/agents/api_contract.md` + `docs/BE_DPE_COMMUNICATION.md` |
| Full guide | `dpe/README.md` + `dpe/docs/agents/` |

```bash
cd dpe
pip install -e ".[all]"
uvicorn dobar_payment.api.app:create_app --factory --port 8001
pytest
ruff check . && black . && mypy dobar_payment/
```

### `landing/` — Marketing site

Vite + Tailwind static site, separate Fly app (`landing/fly.toml`). No shared code with `fe/`.

```bash
cd landing
npm install && npm run dev
```

### `docs/` — Canonical context (read, don't duplicate)

```
docs/
├── FE_BE_COMMUNICATION.md   # FE<->BE contract — endpoints, schemas, error codes
├── BE_DPE_COMMUNICATION.md  # BE<->DPE contract — routing, PIX, subscriptions, changelog
├── business/                # Vision, business plan, pricing, pitch
└── q4_2026/                 # Market analysis, pricing strategy, bug triage
```

> Rule: if `docs/` disagrees with code, fix the code (or update `docs/` in the same PR). Never let a package README become a second source of truth for contracts.

---

## 3. CI/CD — Path-Filtered Per Package

Workflows live at root `.github/workflows/` but **run scoped to their subdir** via `defaults.run.working-directory` + `flyctl deploy --config fly.toml`.

| Push path | Workflow | What it does |
|---|---|---|
| `be/**` | `deploy-be.yml` | `be-unit-tests` → `payment-contract-validation` → Fly deploy → `run-migrations` (`alembic upgrade head`, idempotent) |
| `fe/**` | `deploy-fe.yml` | `flutter pub get` → `build_runner` → `flutter build web` → Fly deploy |
| `dpe/**` | `deploy-dpe.yml` | `dpe-unit-tests` → Fly deploy |
| `fe/**` (PR/push) | `fe-unit-tests.yml` | gen-l10n + analyze + `flutter test` |
| manual / `workflow_call` | `rate-card-live.yml` | live `GET /advertising/rates` contract check vs prod |

Each deploy workflow also triggers on its own workflow file (so editing CI redeploys). Editing `docs/` or root alone deploys nothing.

**Golden rule:** `fly.toml` + `Dockerfile` live IN each package (`be/fly.toml`, `fe/fly.toml`, ...). Never run `fly deploy` from root. CI already does `working-directory: <pkg>` + `--config fly.toml`.

```bash
# manual escape hatches (prefer CI)
fly deploy --config be/fly.toml
fly ssh console -a barz-backend-bold-sun-5691 -C "alembic upgrade head"
fly logs -a barz-backend-bold-sun-5691
```

---

## 4. Cross-Package Contracts (do not break)

```
fe (Flutter) --tokenized card/PIX--> be (FastAPI) --charge/refund--> dpe (Engine) --> Stripe / Pagar.me / PayPal
fe (Flutter) <--orders/wallet/errors-- be (FastAPI) <--standardized response-- dpe (Engine)
```

- **FE→BE:** `docs/FE_BE_COMMUNICATION.md` — base `https://barz-backend-bold-sun-5691.fly.dev`, `X-Idempotency-Key` on payments, `{error: {code, message}}` envelope.
- **BE→DPE:** `docs/BE_DPE_COMMUNICATION.md` — DPE at `https://dobar-payment-engine.fly.dev`, wallet stays in BE, DPE does gateway processing. Correct shape is `payment_method: {type: "card"|"pix", token, provider?}` — NOT `payment_method`/`card_token` keys, no `installments` on `/payments/charge`.
- **BE tests that guard contracts:** `be/tests/contract_validation/` (schemas, DPE, wallet, external APIs).

Changing any field above? Update the `docs/*.md` + DPE `api_contract.md` + tests in the SAME PR.

---

## 5. Common Pitfalls (monorepo)

- Running `flutter pub get` / `pytest` / `pip install -r requirements.txt` from root → `cd be|fe|dpe` first (or rely on CI `working-directory`).
- `ls migrations/versions/*.py` from root → `be/migrations/versions/*.py`.
- Grepping `app/payment/` in CI → `be/app/payment/` (git paths are now prefixed).
- `pip` cache miss → `cache-dependency-path: be/requirements.txt` / `dpe/pyproject.toml` (already in workflows).
- Flutter version drift (`3.27` vs `3.47`) → pinned `3.47.1` in both `deploy-fe` and `fe-unit-tests`.

---

## Contributing

1. Pick ONE package. Read its `AGENTS.md`.
2. Branch: `git checkout -b feat/<pkg>-<short-name>`
3. Code + tests. Keep `docs/` contracts in sync.
4. Validate locally (see §2 commands per package).
5. Push → path-filtered CI runs only affected packages → open PR.

## License

Proprietary. See `be/LICENSE` / `fe/LICENSE` / `dpe/LICENSE`.
