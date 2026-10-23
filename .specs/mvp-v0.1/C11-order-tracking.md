---
id: "C11"
title: "Customer order tracking"
owner: "frontend"
areas: ["fe", "be"]
priority: "P0"
depends_on: ["C07"]
source_requirements: ["MVP-C11-01", "MVP-C11-02", "LAUNCH-C11-01"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "native-device"]
---

# C11: Customer order tracking

## Intended behavior

Deliver the customer order tracking journey for the Belo Horizonte MVP. Customer validation includes Android and iOS. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

OrderTrackingPage includes 30-second polling and a local elapsed timer; status handling still references confirmed while cashier constants use pending/preparing/ready/completed. Backend offers timeline and live-order routes.

Unify user-visible state mapping and prove event subscription, reconnect and authenticated order visibility. Do not remove legacy wire values without a compatibility mapping.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/orders/presentation/pages/order_tracking_page.dart](../../fe/lib/features/orders/presentation/pages/order_tracking_page.dart)
- [fe/lib/core/services/websocket/order_tracking_service.dart](../../fe/lib/core/services/websocket/order_tracking_service.dart)
- [fe/lib/ui/business/cashier_page.dart](../../fe/lib/ui/business/cashier_page.dart)
- [be/app/bars_and_restaurants/routes/orders.py](../../be/app/bars_and_restaurants/routes/orders.py)

## Contracts and compatibility

Canonical order states Pending -> Preparing -> Ready -> Completed with payment status separate; existing timeline/live socket contracts and fallback snapshot retrieval.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **C11-AC01** — Confirmed checkout opens the correct order; customer sees Pending, Preparing, Ready and Completed with localized meaning, venue/table and order summary.
- **C11-AC02** — Authorized cashier changes update an already-open customer tracker through events, and reconnect/resume refreshes an authoritative timeline without regressing state.
- **C11-AC03** — Legacy confirmed/done/delivered representations map compatibly where still received; new UI does not create extra workflow steps.
- **C11-AC04** — Unknown/unauthorized orders, payment pending/failure, socket loss and terminal states show accurate feedback; elapsed time derives from order timestamps after reload.

## Validation scenarios and evidence

- Drive all four states from a separate cashier session, reload midway, replay duplicate/stale events, interrupt network and attempt another customer order ID.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Record Android and iOS device/OS evidence for native journeys; unavailable device coverage remains blocked or skipped.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-C11-01, MVP-C11-02, LAUNCH-C11-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
