---
id: "C02"
title: "Home discovery and promotions"
owner: "frontend"
areas: ["fe", "be"]
priority: "P1"
depends_on: ["C01"]
source_requirements: ["MVP-C02-01"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "native-device"]
---

# C02: Home discovery and promotions

## Intended behavior

Deliver the home discovery and promotions journey for the Belo Horizonte MVP. Customer validation includes Android and iOS. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Home API accepts optional latitude/longitude and calls the home endpoint; backend has a HomeResponse route and separate trending menu endpoints.

Verify response decoding and the real sections rendered; make denied/stale location and empty discovery states explicit instead of silently showing misleading proximity.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/home/presentation/pages/home_page.dart](../../fe/lib/features/home/presentation/pages/home_page.dart)
- [fe/lib/features/home/data/data_sources/home_impl_api.dart](../../fe/lib/features/home/data/data_sources/home_impl_api.dart)
- [be/app/bars_and_restaurants/routes/home.py](../../be/app/bars_and_restaurants/routes/home.py)

## Contracts and compatibility

HomeResponse and menu trending responses; preserve current route compatibility and use venue IDs when opening menus or maps.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **C02-AC01** — Home renders nearby partner venues, most-ordered drinks, local trending and active promotions from backend data.
- **C02-AC02** — Selecting a venue, drink or promotion opens its correct destination with consistent venue context.
- **C02-AC03** — Empty results, denied location, loading and network failure show localized recoverable states without fabricated nearby data.

## Validation scenarios and evidence

- Seed two Belo Horizonte venues and an active/expired promotion; verify sections, taps, refresh, empty response and no-location fallback.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Record Android and iOS device/OS evidence for native journeys; unavailable device coverage remains blocked or skipped.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-C02-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
