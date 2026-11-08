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

Authenticated check-in is persisted by the backend and scoped to the logged-in user and selected venue. Confirmation validates a location fix no older than 120 seconds and distance strictly below 10m. Sessions expire after 12 hours by default (`CHECKIN_TTL_HOURS`); ending a session invalidates it. Stored local `userId: 0` records no longer authorize ordering.

Home discovery retains its nearby-venue prompt within 500m. The active customer shell's check-in button pulses continuously; its animation is not proximity-dependent. Broad nearby discovery is separate from confirmation eligibility. Menu browsing remains available; ordering/cart paths request check-in and retain the venue and intended action. Backend checkout independently requires an active matching session and validates the selected table/location.

The demo scan control and hardcoded distance have been removed. Real QR/link input can select a venue/table, followed by the same server checks. Camera scanning is not implemented; native GPS, camera and device E2E acceptance remains unverified.

Source and regression references:

- [Check-in state](../../fe/lib/features/checkin/presentation/bloc/checkin_bloc.dart), [page](../../fe/lib/features/checkin/presentation/pages/checkin_page.dart), [entry gate](../../fe/lib/features/checkin/presentation/checkin_gate.dart).
- [Home prompt](../../fe/lib/ui/screens/home_connected.dart), [active customer shell](../../fe/lib/ui/shell/wireframe_shell.dart).
- [Authenticated routes](../../be/app/bars_and_restaurants/routes/checkin.py), [eligibility/session service](../../be/app/bars_and_restaurants/services/checkin.py), [additive migration](../../be/migrations/versions/c05_customer_checkins.py).
- [Backend regression tests](../../be/tests/test_customer_checkin.py). Local SQLite/PostgreSQL service, HTTP ownership, migration and concurrency checks do not establish native-device E2E acceptance.
- [Profile identity HTTP regression](../../be/tests/test_profile_identity.py) and [profile-to-check-in regression](../../fe/test/features/checkin/checkin_profile_identity_test.dart) cover the authenticated account ID required by the shared session. The backend profile response now supplies `id`; local scripted HTTP checks do not prove deployed cached-token or native-device behavior.

## Contracts and compatibility

Authenticated `/checkins` routes extend existing venue/location and table/spot configuration. Deploy the additive migration and backend before the consuming frontend through existing CI/CD. Existing local check-ins require server revalidation. QR selection does not bypass distance eligibility.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **C05-AC01** — Check-in entry eligibility and confirmation require current distance strictly less than 10m from a partner venue; 10m or greater cannot silently create a valid check-in. For venues with an address but missing internal coordinates, resolve the address server-side before measuring distance; unavailable or uncertain resolution remains recoverable and never substitutes the customer’s position for the venue.
- **C05-AC02** — Customer can browse the menu without check-in. The first concrete ordering action and cart entry require an authenticated check-in for that venue, retain the intended action through confirmation, and resume it only on success. Table or delivery-location details can be supplied before ordering or during checkout and are retained on the order.
- **C05-AC03** — Real QR input selects a valid partner/table and validates it; demo controls and hardcoded distance never determine release eligibility.
- **C05-AC04** — Authenticated check-in survives supported resume/reopen behavior, and stale location, denied permission or incompatible venue/table returns a recoverable state. Opening with a cached valid token hydrates the authenticated account ID into the shared session and permits check-in confirmation without requiring another login.

## Validation scenarios and evidence

- Exercise 9m/10m/11m coordinates, stale GPS, malformed QR, unavailable table, relaunch and checkout without prior check-in; verify backend cannot trust a forged local session.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Record Android and iOS device/OS evidence for native journeys; unavailable device coverage remains blocked or skipped.

## Delivery and verification

Delivery: implementation and focused local regression checks are present; deployment remains pending. Verification: unverified. Local checks cover service/HTTP behavior, migration and PostgreSQL concurrency; no product E2E or native-device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-C05-01, MVP-C05-02, MVP-C05-03, MVP-C05-04. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
