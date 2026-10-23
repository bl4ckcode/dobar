---
id: "B01"
title: "Business authentication and navigation"
owner: "frontend"
areas: ["fe", "be"]
priority: "P0"
depends_on: ["C01"]
source_requirements: ["MVP-B01-01", "MVP-B01-02", "LAUNCH-B01-01"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e"]
---

# B01: Business authentication and navigation

## Intended behavior

Deliver the business authentication and navigation journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Business shells, side menu and SessionBloc exist; GET /me/bars returns venue-scoped role and permission access.

Validate session mode and venue switching, route guards and permission refresh in browsers. Existing enum has owner/admin/manager/cashier/staff, no Marketing role.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/ui/business/business_root_shell.dart](../../fe/lib/ui/business/business_root_shell.dart)
- [fe/lib/ui/business/business_shell.dart](../../fe/lib/ui/business/business_shell.dart)
- [fe/lib/ui/business/widgets/business_side_menu.dart](../../fe/lib/ui/business/widgets/business_side_menu.dart)
- [fe/lib/features/session/presentation/bloc/session_bloc.dart](../../fe/lib/features/session/presentation/bloc/session_bloc.dart)
- [be/app/bars_and_restaurants/routes/staff.py](../../be/app/bars_and_restaurants/routes/staff.py)

## Contracts and compatibility

Existing authentication and GET /me/bars access list plus bar-context response headers; use permission gates for campaigns, staff and settings.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B01-AC01** — Existing phone/Google/Apple login enters the business shell and resolves accessible venues; a user without venues can create a venue or accept an invitation.
- **B01-AC02** — Owner/admin sees authorized dashboard, order operators see cashier, and campaign/staff/settings navigation follows explicit permissions for the selected venue.
- **B01-AC03** — Venue switching and refreshed permissions update navigation and protected routes without carrying access from another venue.
- **B01-AC04** — Browser refresh/deep links and expired sessions preserve a safe intended destination and resume only after authentication.

## Validation scenarios and evidence

- Test owner, admin, manager, cashier and staff in desktop/mobile browsers; switch between two venues with different permissions and directly load restricted routes.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B01-01, MVP-B01-02, LAUNCH-B01-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
