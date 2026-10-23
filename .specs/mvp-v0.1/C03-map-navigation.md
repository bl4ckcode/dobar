---
id: "C03"
title: "Partner map and navigation"
owner: "frontend"
areas: ["fe", "be"]
priority: "P1"
depends_on: ["C01", "C02"]
source_requirements: ["MVP-C03-01", "MVP-C03-02"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "native-device"]
---

# C03: Partner map and navigation

## Intended behavior

Deliver the partner map and navigation journey for the Belo Horizonte MVP. Customer validation includes Android and iOS. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Search page uses google_maps_flutter, camera movement and map-ad loading with coordinates; places and advertising routes provide discovery inputs.

Validate partner versus promotion markers, route drawing and external maps handoff on both mobile platforms. Map rendering alone is insufficient evidence.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/home/presentation/pages/search/search_home_page.dart](../../fe/lib/features/home/presentation/pages/search/search_home_page.dart)
- [be/app/advertising/routes.py](../../be/app/advertising/routes.py)
- [be/app/bars_and_restaurants/routes/places.py](../../be/app/bars_and_restaurants/routes/places.py)

## Contracts and compatibility

Existing place/map-ad endpoints and platform URL intent handling. Directions use the selected venue coordinates, never a marketing placeholder.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **C03-AC01** — Map displays partner venue pins and distinguishable active promotion pins with correct venue details.
- **C03-AC02** — A selected partner supports drawing a route and opening an installed maps application with its destination coordinates.
- **C03-AC03** — Denied location, missing maps apps, empty data and map-provider failure present accessible fallback actions.

## Validation scenarios and evidence

- Use known coordinates for two partners; select a promotion, draw route and open Maps on Android/iOS, then repeat without location access.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Record Android and iOS device/OS evidence for native journeys; unavailable device coverage remains blocked or skipped.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-C03-01, MVP-C03-02. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
