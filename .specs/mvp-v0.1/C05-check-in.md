---
id: "C05"
title: "Location and table check-in"
owner: "frontend"
areas: ["fe", "be"]
priority: "P0"
depends_on: ["C01", "C03"]
source_requirements: ["MVP-C05-01", "MVP-C05-02", "MVP-C05-03", "MVP-C05-04"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "native-device"]
---

# C05: Location and table check-in

## Intended behavior

Deliver the location and table check-in journey for the Belo Horizonte MVP. Customer validation includes Android and iOS. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

CheckinBloc searches nearby bars with a 5000m radius and stores a local check-in with userId 0; the page displays a hardcoded 200m distance and a demo scan control.

This differs materially from the <10m requirement. Separate broad discovery from eligibility; remove demo success from release flows and integrate authenticated venue/table validation before relying on check-in for orders.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/checkin/presentation/bloc/checkin_bloc.dart](../../fe/lib/features/checkin/presentation/bloc/checkin_bloc.dart)
- [fe/lib/features/checkin/presentation/pages/checkin_page.dart](../../fe/lib/features/checkin/presentation/pages/checkin_page.dart)
- [fe/lib/features/checkin/domain/models/checkin_model.dart](../../fe/lib/features/checkin/domain/models/checkin_model.dart)
- [be/app/bars_and_restaurants/routes/bars.py](../../be/app/bars_and_restaurants/routes/bars.py)

## Contracts and compatibility

Existing venue/location configuration and table/spot availability contracts; authenticated check-in capability must be documented in the canonical FE/BE contract when implemented. QR selection does not bypass distance eligibility.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **C05-AC01** — Check-in entry eligibility and confirmation require current distance strictly less than 10m from a partner venue; 10m or greater cannot silently create a valid check-in.
- **C05-AC02** — Customer can supply/confirm table or delivery-location details before ordering or during checkout, with selected venue retained.
- **C05-AC03** — Real QR input selects a valid partner/table and validates it; demo controls and hardcoded distance never determine release eligibility.
- **C05-AC04** — Authenticated check-in survives supported resume/reopen behavior, and stale location, denied permission or incompatible venue/table returns a recoverable state.

## Validation scenarios and evidence

- Exercise 9m/10m/11m coordinates, stale GPS, malformed QR, unavailable table, relaunch and checkout without prior check-in; verify backend cannot trust a forged local session.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Record Android and iOS device/OS evidence for native journeys; unavailable device coverage remains blocked or skipped.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-C05-01, MVP-C05-02, MVP-C05-03, MVP-C05-04. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
