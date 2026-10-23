---
id: "B07"
title: "Staff invitation issuance and delivery"
owner: "backend"
areas: ["fe", "be"]
priority: "P0"
depends_on: ["B01", "B09"]
source_requirements: ["MVP-B07-01", "MVP-B07-02", "MVP-B07-03", "LAUNCH-B07-01"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e"]
---

# B07: Staff invitation issuance and delivery

## Intended behavior

Deliver the staff invitation issuance and delivery journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Both invite endpoints generate a code/7-day expiry and immediately add existing accounts as accepted; the shown issuance paths return invitation details but contain no delivery call. Simple endpoint permits manager-or-above while scoped endpoint uses staff:manage.

Unify authorization and pending semantics without dropping compatibility routes. Add actual email/phone delivery with retry visibility; existing account lookup must not grant access before acceptance.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/ui/business/staff_management_page.dart](../../fe/lib/ui/business/staff_management_page.dart)
- [fe/lib/features/staff/data/datasources/staff_remote_data_source.dart](../../fe/lib/features/staff/data/datasources/staff_remote_data_source.dart)
- [be/app/bars_and_restaurants/routes/staff.py](../../be/app/bars_and_restaurants/routes/staff.py)
- [be/app/bars_and_restaurants/routes/staff_invite.py](../../be/app/bars_and_restaurants/routes/staff_invite.py)
- [be/app/bars_and_restaurants/services/email_service.py](../../be/app/bars_and_restaurants/services/email_service.py)

## Contracts and compatibility

Existing /bars/{bar_id}/staff/invite and /staff/invite compatibility adapter; both delegate to one permission-checked issuance service. B08 owns acceptance. Contact must be a normalized email or verified phone target.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B07-AC01** — A user with staff:manage can invite by Google/Apple account email or phone and assign only an allowed existing role; owner assignment retains owner-only protection.
- **B07-AC02** — Invitation always remains pending until authenticated recipient explicitly accepts, including when the contact already has an account; no membership is granted at issuance.
- **B07-AC03** — Issued invite is delivered to intended email/phone using a resumable invitation link/code with expiry; delivery failure is visible and resend does not silently grant access.
- **B07-AC04** — Both compatibility endpoints enforce the same venue permission rules, contact validation and safe duplicate/already-member behavior.
- **B07-AC05** — Recipient secrets/contact data are excluded from logs and unrelated responses, and revocation/expiry is respected by later acceptance.

## Validation scenarios and evidence

- Invite new and existing email/phone users, verify no pre-accept access, inspect delivery test adapter, retry delivery, revoke, expire and call both routes as manager/cashier.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B07-01, MVP-B07-02, MVP-B07-03, LAUNCH-B07-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
