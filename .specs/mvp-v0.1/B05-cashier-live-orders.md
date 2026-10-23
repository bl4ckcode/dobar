---
id: "B05"
title: "Cashier and live order processing"
owner: "frontend"
areas: ["fe", "be"]
priority: "P0"
depends_on: ["B01", "C07"]
source_requirements: ["MVP-B05-01", "MVP-B05-02", "MVP-B05-03", "MVP-PRINCIPLE-02"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e"]
---

# B05: Cashier and live order processing

## Intended behavior

Deliver the cashier and live order processing journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Cashier defines pending/preparing/ready/completed constants, loads LiveOrdersBloc asynchronously and dispatches bar/order status changes. Backend has both general and bar-scoped status endpoints; general endpoint contains an ownership-verification TODO.

Close authorization bypasses across all status routes, align wire mappings and prove event delivery. Paid state and preparation state must not be conflated.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/ui/business/cashier_page.dart](../../fe/lib/ui/business/cashier_page.dart)
- [fe/lib/features/orders/presentation/bloc/live_orders_bloc.dart](../../fe/lib/features/orders/presentation/bloc/live_orders_bloc.dart)
- [be/app/bars_and_restaurants/routes/orders.py](../../be/app/bars_and_restaurants/routes/orders.py)
- [be/app/bars_and_restaurants/services/connection_manager.py](../../be/app/bars_and_restaurants/services/connection_manager.py)

## Contracts and compatibility

Canonical order workflow Pending -> Preparing -> Ready -> Completed; existing bar-scoped live/status and websocket contracts, with compatibility handling for older states.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B05-AC01** — Authorized order operator sees current venue orders and advances the shared four-state pipeline with persisted backend acknowledgement.
- **B05-AC02** — A status transition immediately reaches connected customer trackers and other authorized cashier sessions; reconnect recovers current snapshot without duplicates.
- **B05-AC03** — Every status mutation route checks venue scope and order:process permission; direct unauthorized or cross-venue mutations are rejected.
- **B05-AC04** — Payment pending/failed/confirmed remains distinguishable, and retries or simultaneous updates cannot regress a completed order or invent payment success.
- **B05-AC05** — Live cashier excludes orders past their venue's operating-day close. An order expires at the close of the venue operating day (local venue time, `America/Sao_Paulo` for the BH MVP) in which it was created. Overnight shifts that span midnight are covered: an evening order expires at the next-day close, and an early-morning order belongs to the previous day's shift. Bars without configured operating hours keep previous behavior (no expiry). Payment records, API shape, and cashier status semantics are unchanged.

## Validation scenarios and evidence

- Two browser cashier sessions plus one device tracker; process full pipeline, disconnect/reconnect, race actions and call legacy mutation route as unrelated account.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B05-01, MVP-B05-02, MVP-B05-03. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
