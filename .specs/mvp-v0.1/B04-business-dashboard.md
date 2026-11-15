---
id: "B04"
title: "Business dashboard and shortcuts"
owner: "frontend"
areas: ["fe", "be"]
priority: "P1"
depends_on: ["B01"]
source_requirements: ["MVP-B04-01", "MVP-B04-02", "MVP-B04-03", "MVP-PRINCIPLE-04"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e"]
---

# B04: Business dashboard and shortcuts

## Intended behavior

Deliver the business dashboard and shortcuts journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Dashboard page and backend dashboard stats/orders/status endpoints exist; campaign analytics are in advertising routes. In the current staged working tree, the stats endpoint requires venue-scoped `analytics:view`, computes counts and paid non-cancelled order revenue, average ticket and top items using venue-local period windows, and retains its existing response shape. Managers have `analytics:view` by default; confirm that manager and custom-permission financial access matches the intended owner/admin policy.

The staged calculation subtracts refund ledger entries, including pending entries whose outcome is uncertain, from the period in which the order was created. Partially refunded item totals remain at sold prices. Confirm these cohort, pending-refund and item-revenue definitions before presenting them as settled financial results. Legacy refund paths and historical refunds are not comprehensively represented by the new ledger. The staged refund worker and payment authorization changes need separate BE/DPE reconciliation, compatibility and provider verification; customer-initiated refund eligibility requires an explicit product decision.

The staged patch edits the already committed `dob_96_order_refunds` migration rather than adding a new revision. Determine whether it has been applied anywhere; an existing database needs an additive forward migration and a rollout/backfill plan rather than relying on the modified original migration.

Observed source references (inspection only except where test results are separately recorded):

- [fe/lib/ui/business/business_dashboard_page.dart](../../fe/lib/ui/business/business_dashboard_page.dart)
- [be/app/bars_and_restaurants/routes/dashboard.py](../../be/app/bars_and_restaurants/routes/dashboard.py)
- [be/tests/test_dashboard_stats.py](../../be/tests/test_dashboard_stats.py)
- [be/app/payment/order_payments.py](../../be/app/payment/order_payments.py)
- [be/app/payment/routes.py](../../be/app/payment/routes.py)
- [be/app/advertising/routes.py](../../be/app/advertising/routes.py)

## Contracts and compatibility

Existing dashboard stats and order summaries scoped by venue/time range; campaigns require ads:view and financial metrics require appropriate billing/analytics access.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B04-AC01** — Owner/admin dashboard shows backend-derived profit, revenue, total orders and economy versus the configured comparison basis with clear period/BRL units.
- **B04-AC02** — Order summary opens the selected venue cashier/live orders; campaign summary opens that venue campaigns when ads:view is granted.
- **B04-AC03** — No-data, loading and failed metrics are distinguished from zero, and unauthorized users cannot retrieve financial data by direct API access.

## Validation scenarios and evidence

- Seed paid/unpaid/refunded orders and campaign data; compare displayed aggregates, shortcuts and selected venue against backend, then test permission denial.
- Independently verify paid, pending, failed, cancelled, full/partial refund and unknown refund outcomes, historical and legacy refunds, and failed/retried reconciliation against authoritative provider-backed data. Confirm time attribution and item-revenue definitions and behavior for deleted/renamed items.
- Validate the additive migration and existing-data upgrade on PostgreSQL; test cross-venue and financial permission boundaries, including manager and custom-permission policy. Test provider sandbox outcomes and concurrent refund reconciliation separately from mocks.
- Local working-tree check: `cd be && PYTHONDONTWRITEBYTECODE=1 ../tmp/be-submission-quarantine/venv/bin/python -m pytest -o addopts='' -p no:cacheprovider tests/test_dashboard_stats.py tests/test_refund_authorization.py -q --disable-warnings` passed 66 tests on SQLite with mocked DPE; it is not PostgreSQL, provider or product E2E evidence.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Delivery: partial in the staged working tree. The scoped stats endpoint and focused tests are present; financial definitions, safe refund reconciliation and migration compatibility remain unresolved. Profit/economy metrics, shortcuts and browser experience still need assessment against B04. Verification: unverified for the journey; the focused mocked SQLite check is recorded above. Foundation validation currently fails on references to quarantined files and a missing handoff; provider, PostgreSQL and product E2E evidence has not been established here. A passing foundation check validates artifact structure only.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B04-01, MVP-B04-02, MVP-B04-03. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
