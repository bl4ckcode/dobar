---
owner: backend
spec: B08
artifact: implementation-handoff
status: ready-for-planning-and-implementation
---

# DOB-91: Backend handoff after independent re-verification

Rechecked 2026-10-25 at HEAD 971e5ee2a46829b1c9b94b0d4c880bc757cdef7a plus the user's staged implementation. Assignment: [DOB-91](https://linear.app/dobarecosystem/issue/DOB-91), parent [DOB-89](https://linear.app/dobarecosystem/issue/DOB-89). Backend acceptance is implemented in source but remains incomplete and fails runtime checks. This handoff replaces the earlier query-only baseline description; it does not claim a working journey.

## Required context and boundaries

- Read [root instructions](../../../AGENTS.md), [BE instructions](../../../be/AGENTS.md), [backend skill](../../../.agents/skills/dobar-backend/SKILL.md) and [communication skill](../../../.agents/skills/dobar-communication-docs/SKILL.md), including linked architecture/workflow guidance.
- Acceptance remains [B08-AC01 through AC06](../B08-staff-invitation-acceptance.md); implementation ownership remains [B08/be](implementation-tasks.md#b08be--bind-atomic-acceptance-to-the-verified-recipient).
- Current [FE/BE communication](../../../docs/FE_BE_COMMUNICATION.md), [error design](../../../fe/.docs/API_ERROR_CONTRACT.md) and [independent criterion evidence](validation-checklist.md) distinguish declarations, tested components and blocked journeys.
- Preserve user changes, deployed request compatibility and historical memberships. No DPE work belongs here. Verification did not repair product code, stage/unstage files, publish issues or deploy; any implementation follow-up is a separate task.

## Current producer/consumer contract

[Staff routes](../../../be/app/bars_and_restaurants/routes/staff.py) declare authenticated POST /me/bars/invitations/preview taking JSON invitation_code and returning venue_name, nullable venue_address/venue_image_url, role, masked_recipient, ISO expires_at and permissions. Pending previews pass actual-record checks with explicit synthetic verified flags. Accepted preview still crashes on invitation.get at line 363.

POST /me/bars/accept-invitation declares JSON invitation_code, compatible legacy query and 400 for conflicting values. The declared success shape includes integer bar_id, bar_name, actual role, permission codes and additive message. [FE datasource](../../../fe/lib/features/session/data/datasources/session_datasource.dart) consumes both shapes and now preserves canonical error_code on both paths. Actual positive acceptance fails before success, rollback injection or PostgreSQL driver probes: RETURNING references StaffInvitation.c.id, but the mapped class has no c attribute.

[User](../../../be/app/auth/auth_models.py) and [AuthUser](../../../be/app/auth/rbac_middleware.py) now expose email_verified/phone_verified. The contact guard rejects unverified/mismatched accounts; [profile edits](../../../be/app/auth/profile.py) reset flags. These behaviors pass synthetic actual-record checks. However, no migration adds the new user columns, existing user inserts fail without explicit values, and auth provider paths never establish verified state. No real verified-login acceptance was demonstrated.

The [renamed migration](../../../be/migrations/versions/dob_91_staff_inv_accepted_by.py) has a valid 26-character revision and adds nullable accepted_by_user_id plus FK only. It does not provide the user-column migration, server defaults, trusted verification backfill or membership uniqueness. Safe historical compatibility and real upgrade evidence remain required.

## Remaining BE implementation and checks

1. Add a compatible verified-contact schema/default/initialization transition, preserve current users, and derive verification only from trustworthy identity-provider evidence. Check new/existing phone, Google and Apple paths plus invalidation on contact changes. The existing staff/auth suite currently has 27 failures, 5 passes and 3 setup errors.
2. Correct the mapped-class RETURNING reference and remaining accepted-preview Record.get access. Then exercise real JSON/query/conflict inputs, full preview/BarAccess serialization, membership/readback and safe errors. Do not interpret source declarations as successful writes.
3. Complete atomic same-recipient idempotency/concurrency: acquire/reconcile invitation and membership safely, audit duplicate user/bar rows before unique enforcement, and verify rollback, revocation/expiry races and lost-response retries with PostgreSQL. The current exception prevents these probes from reaching their intended write. Adding RETURNING alone does not prove them.
4. Preserve the now-working active-membership replay behavior: current role/permissions are returned, inactive membership is rejected without restoration, and legacy accepted rows cannot authorize a second account without current access. Same-user retry after expiry still gets 410; resolve accepted-current-access semantics without restoring revoked access.
5. Complete canonical safe errors: invalid 404; expired/revoked 410; mismatch/unverified 403; used-by-another 409; active same-recipient replay 200. Used-other acceptance currently yields mismatch 403 and accepted preview yields 500. Add agreed contact_type metadata for phone/email guidance, safe invalid-role handling, and pending/already-accepted preview semantics.
6. Keep [B07](../B07-staff-invitation.md) issuance/delivery ownership explicit. Alternate /staff/invite now creates a pending invite without membership for existing users; scoped /bars/{bar_id}/staff/invite still auto-adds and marks accepted. Complete both issuers' staff:manage authorization and real email/phone delivery/resend separately. Preserve existing secrets.token_urlsafe(16) tokens.

## FE integration follow-ups

| Finding | Current evidence and next action |
|---|---|
| Issuer tokens and pasted canonical links | Removing uppercase conversion did not extend the DBR-only parser or legacy codigo/convite link grammar. Two independent probes still reject actual URL-safe opaque tokens and /staff/invitations/accept?code=… input. Direct routed initialCode follows a different path. Preserve issued token case/compatibility. |
| Login mount and durable resume | Default LoginPage reads ModalRoute in initState and fails a widget probe. GoRouter still constructs const LoginPage() without passing its extra. Repair initialization and actual pending-code wiring; verify login/registration/onboarding/MFA/cancellation/refresh round trips. |
| Verification action/metadata | Unverified phone response lacks contact_type; cubit hardcodes email and the datasource discards metadata. The verify CTA now opens profile edit, which resets flags and does not establish ownership. Define a real verification/resume action. |
| Distinct errors and venue selection | Canonical preview/accept error-code preservation passes. Cubit/UI still use generic accept-error rendering, map used preview to invalid, and match already-member fallback by venue name. Verify distinct localized states and use stable identity/current idempotent access. |
| Workspace and accessibility | Successful acceptance, /me/bars refresh, correct selected venue/permission enforcement, keyboard/screen readers, narrow/wide and light/dark browser observations remain incomplete. Mocked state tests are insufficient. |

## Evidence and completion handoff

The [current criterion record](validation-checklist.md) contains exact commands, fixture limits and passed/failed/blocked/skipped outcomes. Current independent BE probes: 29 total, 15 passed, 11 failed assertions and 3 errors; several failures are earlier blockers to the intended write/concurrency checks. Original FE cubit tests: 14 passed; datasource probes: 2 passed; parsing probes: 2 failed. Login BLoC: 2 passed; default login widget: 1 failed. Analyzer: two info hints, exit 1.

The earlier author's claimed payment failures were not baseline-compared or rerun; do not label their origin proven. The [React source record](react-source-handoff.md) names clean observed HEAD 55ce9b5ddf04e9baa1200241208cb97e732c7e0f, but actual translated-revision confirmation and product approval remain pending.

Replace only the latest changed-area communication entries when implementing further changes. Provide actual PostgreSQL migration/security/concurrency evidence and FE contract/browser integration evidence before closing DOB-91's assigned criteria. The workflow verify report remains incomplete because product-e2e has no configured runner. Do not mark DOB-89 or the whole B08 journey validated from backend-only checks.
