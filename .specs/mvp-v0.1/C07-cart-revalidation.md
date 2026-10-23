---
id: "C07"
title: "Cart, promotions and checkout revalidation"
owner: "backend"
areas: ["fe", "be"]
priority: "P0"
depends_on: ["C05", "C06"]
source_requirements: ["MVP-C07-01", "MVP-C07-02", "MVP-C07-03"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "native-device"]
---

# C07: Cart, promotions and checkout revalidation

## Intended behavior

Deliver the cart, promotions and checkout revalidation journey for the Belo Horizonte MVP. Customer validation includes Android and iOS. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Cart page/BLoC and backend calculate, item mutation, sync and checkout routes exist; checkout spans order creation and payment inputs.

Prove inventory/promotion race handling and amount authority. Do not trust frontend total or duplicate a newly created order when retrying an uncertain payment.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/cart/presentation/pages/cart_page.dart](../../fe/lib/features/cart/presentation/pages/cart_page.dart)
- [fe/lib/features/cart/presentation/bloc/cart_bloc.dart](../../fe/lib/features/cart/presentation/bloc/cart_bloc.dart)
- [be/app/bars_and_restaurants/routes/cart.py](../../be/app/bars_and_restaurants/routes/cart.py)
- [be/app/bars_and_restaurants/services/cart_service.py](../../be/app/bars_and_restaurants/services/cart_service.py)

## Contracts and compatibility

Existing cart calculate/checkout contracts and C08/C09 payment linkage; canonical contracts must describe item changes and order/payment identifiers.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **C07-AC01** — Customer edits/removes quantities and applies a redemption code with accurate localized validation feedback.
- **C07-AC02** — Cart displays current server-calculated item prices, discounts and BRL total; expired/ineligible codes and changed stock/prices require a refreshed confirmation.
- **C07-AC03** — Checkout confirms the check-in location or requests a valid delivery/table location and retains it on the resulting order.
- **C07-AC04** — Order creation and payment retries preserve one logical order; mismatched venue/items and client-modified totals are rejected by server authority.

## Validation scenarios and evidence

- Test valid/expired/ineligible codes, concurrent stock depletion, price update between menu and checkout, missing table and repeated checkout after timeout.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Record Android and iOS device/OS evidence for native journeys; unavailable device coverage remains blocked or skipped.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-C07-01, MVP-C07-02, MVP-C07-03. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
