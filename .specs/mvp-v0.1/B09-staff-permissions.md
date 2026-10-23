---
id: "B09"
title: "Staff permissions and management"
owner: "backend"
areas: ["fe", "be"]
priority: "P0"
depends_on: ["B01"]
source_requirements: ["MVP-B09-01", "MVP-B09-02"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e"]
---

# B09: Staff permissions and management

## Intended behavior

Deliver the staff permissions and management journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Backend defines owner/admin/manager/cashier/staff with granular permissions; FE permission enum is a subset and local manager defaults differ from server capabilities. Staff routes gate view/manage separately.

Use server-issued per-venue permissions as authority, preserve unknown permission compatibility and resolve UI/server disagreements. Marketing is a capability grouping, not a role migration.

Observed source references (inspection only; no runtime or E2E validation):

- [be/app/auth/rbac_models.py](../../be/app/auth/rbac_models.py)
- [be/app/auth/rbac_middleware.py](../../be/app/auth/rbac_middleware.py)
- [be/app/bars_and_restaurants/routes/staff.py](../../be/app/bars_and_restaurants/routes/staff.py)
- [fe/lib/core/rbac/permission.dart](../../fe/lib/core/rbac/permission.dart)
- [fe/lib/ui/business/staff_management_page.dart](../../fe/lib/ui/business/staff_management_page.dart)

## Contracts and compatibility

GET /me/bars and X-Bar-* context headers; staff list/role/remove routes with staff:view/staff:manage and owner-specific restrictions.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B09-AC01** — Existing five roles remain; marketing and other capabilities use explicit server-issued permission codes for the active venue.
- **B09-AC02** — Staff listing, inviting, role edits and removal enforce matching backend/UI permissions and prevent cross-venue data or action access.
- **B09-AC03** — Only authorized owner operations grant/change ownership; forbidden role changes return actionable errors without optimistic persistence.
- **B09-AC04** — Permission refresh, role change and revocation update active workspace access; unknown additive permission codes do not crash existing clients.

## Validation scenarios and evidence

- Matrix all roles against staff actions and ads/billing navigation, compare /me/bars with headers, modify permissions in another session and attempt cross-venue IDs.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B09-01, MVP-B09-02. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
