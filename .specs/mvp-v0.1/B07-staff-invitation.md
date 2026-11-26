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

The working tree unifies both issuance routes behind venue-scoped `staff:manage` authorization and a shared service. Invitations use canonicalized contact values, begin pending, and do not grant membership before verified-recipient acceptance. The user-confirmed role hierarchy prevents an inviter from assigning a role above their own. Staff role changes and removals also enforce rank in the current implementation. These checks change which operations previously authorized callers may perform; preserve endpoint shapes and communicate rollout implications.

The shared service implements active-member checks and a pending-invitation reuse/replacement policy, with per-venue locking for PostgreSQL. The [authorization tests](../../be/tests/test_staff_invite_authorization.py) and the [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) cover local tests and temporary PostgreSQL concurrency checks; those are author-reported evidence, not independent verification or provider delivery. The working tree provides no invitation delivery channel or explicit revoke endpoint. Email/phone delivery, visible failure and safe retry remain to be implemented and verified. SQLite does not establish the PostgreSQL lock behavior.

Observed source references (inspection only unless a test result is separately recorded):

- [fe/lib/ui/business/staff_management_page.dart](../../fe/lib/ui/business/staff_management_page.dart)
- [fe/lib/features/staff/data/datasources/staff_remote_data_source.dart](../../fe/lib/features/staff/data/datasources/staff_remote_data_source.dart)
- [be/app/bars_and_restaurants/routes/staff.py](../../be/app/bars_and_restaurants/routes/staff.py)
- [be/app/bars_and_restaurants/routes/staff_invite.py](../../be/app/bars_and_restaurants/routes/staff_invite.py)
- [be/app/bars_and_restaurants/services/staff_invitations.py](../../be/app/bars_and_restaurants/services/staff_invitations.py)
- [be/app/auth/contact_validation.py](../../be/app/auth/contact_validation.py)
- [be/tests/test_staff_invite_authorization.py](../../be/tests/test_staff_invite_authorization.py)
- [be/app/bars_and_restaurants/services/email_service.py](../../be/app/bars_and_restaurants/services/email_service.py)

## Contracts and compatibility

Existing /bars/{bar_id}/staff/invite and /staff/invite compatibility adapter; both delegate to one permission-checked issuance service. B08 owns acceptance. Invitation contacts are validated and normalized at issuance; authenticated acceptance requires a matching verified account contact. Format validation alone does not verify control of a phone number. An inviter may assign only a role at or below their own venue role; `staff:manage` remains required. Preserve deployed response shapes and explain stricter authorization and duplicate/resend semantics to clients.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B07-AC01** — A user with staff:manage can invite by Google/Apple account email or phone and assign only an allowed existing role at or below their own role at that venue; owner assignment retains owner-only protection.
- **B07-AC02** — Invitation always remains pending until authenticated recipient explicitly accepts, including when the contact already has an account; no membership is granted at issuance.
- **B07-AC03** — Issued invite is delivered to intended email/phone using a resumable invitation link/code with expiry; delivery failure is visible and resend does not silently grant access.
- **B07-AC04** — Both compatibility endpoints enforce the same venue permission rules, contact validation and safe duplicate/already-member behavior.
- **B07-AC05** — Recipient secrets/contact data are excluded from logs and unrelated responses, and revocation/expiry is respected by later acceptance.

## Validation scenarios and evidence

- Exercise both routes with role defaults and custom permissions, cross-venue callers, rank boundaries, malformed contacts, existing members, pending duplicates and concurrent PostgreSQL issuance; verify new and existing accounts have no membership before acceptance.
- Deliver invitations through a test adapter, inject failure and retry/resend; independently verify provider delivery with redacted sandbox evidence. Verify expired, replaced and explicitly revoked invitations cannot grant access, and record the absence of an explicit revoke endpoint until resolved.
- Verify logged and returned errors do not expose contacts or codes, including validation and database failures. Review legacy invitation rows and client compatibility for normalized contacts and reuse/replacement behavior.
- Local working-tree check: `cd be && PYTHONDONTWRITEBYTECODE=1 ../tmp/be-submission-quarantine/venv/bin/python -m pytest -o addopts='' -p no:cacheprovider tests/test_staff_invite_authorization.py -q --disable-warnings` passed 493 tests on SQLite with mocked services; this does not prove provider delivery, PostgreSQL concurrency or product E2E.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Delivery: partial in the working tree. Shared authorization, pending issuance, rank checks and duplicate handling are implemented; delivery, delivery-failure visibility and an explicit revoke workflow remain open. Verification: unverified for the journey. The focused SQLite suite passed as recorded above; the authorization handoff's PostgreSQL claims require independent reproduction, and provider and product E2E checks have not been established here. Foundation validation currently fails on references to files moved to the submission quarantine; a passing foundation check would validate artifact structure only.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B07-01, MVP-B07-02, MVP-B07-03, LAUNCH-B07-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
