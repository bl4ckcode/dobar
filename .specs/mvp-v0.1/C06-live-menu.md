---
id: "C06"
title: "Live venue menu"
owner: "frontend"
areas: ["fe", "be"]
priority: "P0"
depends_on: ["C02"]
source_requirements: ["MVP-C06-01", "MVP-C06-02", "MVP-C06-03", "MVP-C06-04", "MVP-C06-05", "MVP-C06-06"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "native-device"]
---

# C06: Live venue menu

## Intended behavior

Deliver the live venue menu journey for the Belo Horizonte MVP. Customer validation includes Android and iOS. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Menu BLoC/socket data source and backend menu/item CRUD, availability updates and real-time update services exist.

Prove live price, stock and group updates reach an already-open customer menu and reconcile selection; socket classes alone do not prove subscription/auth or reconnect behavior.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/menus/presentation/bloc/menus_bloc.dart](../../fe/lib/features/menus/presentation/bloc/menus_bloc.dart)
- [fe/lib/features/menus/data/datasource/menu_network_socket_service.dart](../../fe/lib/features/menus/data/datasource/menu_network_socket_service.dart)
- [be/app/bars_and_restaurants/routes/menus.py](../../be/app/bars_and_restaurants/routes/menus.py)
- [be/app/bars_and_restaurants/services/realtime_updates.py](../../be/app/bars_and_restaurants/services/realtime_updates.py)

## Contracts and compatibility

Existing menu/full/items and availability contracts plus menu event payloads; persist authority in BE and revalidate checkout through C07.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **C06-AC01** — Menu shows venue-specific categories/subcategories, prices, promotional prices and increment/decrement controls without negative quantity.
- **C06-AC02** — Business price, item availability/quantity and item-group changes update an already-open customer view without manual navigation.
- **C06-AC03** — Disconnected clients display connectivity state and reconcile a fresh snapshot on reconnect so stale data cannot authorize checkout.
- **C06-AC04** — Proceeding from menu triggers cart revalidation and communicates changed/removed selections before charge.

## Validation scenarios and evidence

- Open customer menu and business editor concurrently; change price, stock and category, interrupt socket, reconnect and checkout with a sold-out item.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Record Android and iOS device/OS evidence for native journeys; unavailable device coverage remains blocked or skipped.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-C06-01, MVP-C06-02, MVP-C06-03, MVP-C06-04, MVP-C06-05, MVP-C06-06. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
