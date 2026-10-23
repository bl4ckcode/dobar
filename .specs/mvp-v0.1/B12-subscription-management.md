---
id: "B12"
title: "Business subscription management"
owner: "payments"
areas: ["fe", "be", "dpe"]
priority: "P0"
depends_on: ["B11"]
source_requirements: ["MVP-B12-01", "LAUNCH-B12-01"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend", "payments"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend", "dobar-payments"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "provider-sandbox"]
---

# B12: Business subscription management

## Intended behavior

Deliver the business subscription management journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Plans/lifecycle code exists but inspection of payment routes finds no customer-portal capability; existing documents assert completed trial and upgrade flows without browser portal evidence.

Add authorized short-lived portal sessions linked to existing Stripe customer and configured product policies; reconcile cancellation, payment failures and upgrades through verified events.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/advertising/presentation/pages/subscription_plans_page.dart](../../fe/lib/features/advertising/presentation/pages/subscription_plans_page.dart)
- [be/app/advertising/routes.py](../../be/app/advertising/routes.py)
- [be/app/advertising/services/subscription_service.py](../../be/app/advertising/services/subscription_service.py)
- [dpe/dobar_payment/gateways/stripe.py](../../dpe/dobar_payment/gateways/stripe.py)

## Contracts and compatibility

Authenticated Customer Portal session creation and current subscription readback; backend owns venue/customer binding and return URLs. See [Stripe Customer Portal](https://docs.stripe.com/customer-management).

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) and [BE/DPE contract](../../docs/BE_DPE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B12-AC01** — Authorized subscription manager opens Stripe Customer Portal for the selected venue Stripe customer through a freshly created short-lived session.
- **B12-AC02** — Portal supports configured payment-method/invoice and plan/cancel management; unauthorized/cross-venue requests and client-provided customer IDs are rejected.
- **B12-AC03** — Returning to app refreshes backend subscription state; cancellation/upgrade/payment failure and recovery follow verified Stripe events rather than browser redirects.
- **B12-AC04** — No existing subscription/customer, unavailable Stripe and expired sessions provide actionable Portuguese outcomes without exposing secret portal URLs in logs.

## Validation scenarios and evidence

- Open portal for two venues, test cross-venue denial, update payment method, cancel/upgrade per configured policy, expire session and replay billing webhooks.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Use provider test mode only for sandbox verification; record provider IDs and redacted evidence. Missing provider access is blocked, not a passing mock.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B12-01, LAUNCH-B12-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
