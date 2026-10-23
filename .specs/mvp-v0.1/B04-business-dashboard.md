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

Dashboard page and backend dashboard stats/orders/status endpoints exist; campaign analytics are in advertising routes.

Validate metric definitions and permissions against persisted orders, rather than accepting demo-looking numbers as financial evidence.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/ui/business/business_dashboard_page.dart](../../fe/lib/ui/business/business_dashboard_page.dart)
- [be/app/bars_and_restaurants/routes/dashboard.py](../../be/app/bars_and_restaurants/routes/dashboard.py)
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
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B04-01, MVP-B04-02, MVP-B04-03. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
