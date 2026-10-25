# Frontend ↔ backend communication

Last updated: 2026-10-25

Rolling handoff: keep only the latest frontend update and latest backend update. Replace an area's previous entry when that area changes; retain the other area's latest entry. Git and linked Linear issues own history. Source inspection is not deployment or E2E evidence.

## Contract references

- [Auth/RBAC](../be/app/auth/rbac_models.py), [API errors](../fe/.docs/API_ERROR_CONTRACT.md), [payment schemas](../be/app/payment/schemas.py), [order routes](../be/app/bars_and_restaurants/routes/orders.py).
- [Journey specs](../.specs/mvp-v0.1/README.md) describe intended acceptance; [open findings](AGENT_CONTEXT.md) record unresolved mismatches; [payment boundary](BE_DPE_COMMUNICATION.md) covers BE/DPE.

## Latest frontend update

- Date: 2026-10-24.
- Scope: [DOB-90](https://linear.app/dobarecosystem/issue/DOB-90), B08 staff invitation acceptance FE implementation.
- Contract/action:
  - New route `/staff/invitations/accept?code=<DBR-XXXX-XXXX>` added to GoRouter as a public route; accessible unauthenticated (shows generic login frame).
  - `BusinessOnboardingView` "Aceitar Convite" action now navigates to this page instead of a coming-soon dialog.
  - `POST /me/bars/invitations/preview` (JSON `{"invitation_code": "..."}`) — FE calls this after authentication to load recipient-bound details (`venue_name`, `venue_address`, `venue_image_url`, `role`, `masked_recipient`, `expires_at`, `permissions`). Endpoint does not exist yet on BE; this is the B08/be dependency.
  - `POST /me/bars/accept-invitation` (JSON `{"invitation_code": "..."}`) — FE already sends this; response must include `bar_id`, `bar_name`, `role`, `permissions` to satisfy `BarAccess.fromJson`. Current BE returns fewer fields; this remains a B08/be dependency.
  - Error codes consumed by FE: `INVITATION_EXPIRED` (→ expired state), `INVITATION_REVOKED` (→ revoked), `INVITATION_CONTACT_MISMATCH` (→ wrong-account), `INVITATION_CONTACT_UNVERIFIED` (→ unverified), `INVITATION_INVALID` / 404 (→ invalid), `INVITATION_ALREADY_USED` / 409 (→ already-member if session has bar, else accept-error).
  - On success: FE dispatches `SessionEvent.barCreated` + `SessionEvent.refreshBarAccess`, selects accepted bar, navigates to `/business`.
- Evidence: `fe/lib/features/session/presentation/cubit/invitation_cubit.dart`, `fe/lib/features/session/presentation/pages/staff_invitation_page.dart`, `fe/lib/core/router/app_router.dart`. Source-inspected; no device/browser E2E run.
- Integration follow-up: [DOB-91 handoff](../.specs/mvp-v0.1/pilot/B08-backend-handoff.md) records BE work and FE risks: issuer-token/link parsing, asymmetric error-code handling, ignored contact type, login resume and venue-name fallback. These remain unverified; BE endpoints alone do not establish journey completion.

## Latest backend update

- Date: 2026-10-25 (independent inspection of the existing checkout change; no product repair).
- Scope: [DOB-91](https://linear.app/dobarecosystem/issue/DOB-91), [B08](../.specs/mvp-v0.1/B08-staff-invitation-acceptance.md); [criterion evidence/follow-ups](../.specs/mvp-v0.1/pilot/validation-checklist.md).
- Implemented declarations: authenticated `POST /me/bars/invitations/preview` takes JSON `invitation_code`; response fields are `venue_name`, nullable `venue_address`/`venue_image_url`, `role`, `masked_recipient`, ISO `expires_at`, `permissions`. `POST /me/bars/accept-invitation` declares JSON plus legacy query compatibility, rejects conflicts with 400, and declares `bar_id`, `bar_name`, `role`, `permissions`, additive `message`.
- Runtime blockers: real `databases.Record` lacks `.get()`, breaking recipient matching/preview/acceptance. Text matching does not establish verified identity. The PostgreSQL driver returns no scalar for this UPDATE without RETURNING; treating that as a false conflict rolls back acceptance. Atomic/idempotent acceptance is not validated.
- Error gaps: invalid 404 and expired/revoked 410 were exercised; mismatch 403 works only in isolated dictionary fixtures. Used-by-other preview/accept return inconsistent 409/403 there. `INVITATION_CONTACT_UNVERIFIED` is defined but never emitted; verification metadata (`contact_type`) is absent. Replay ignores active membership/current role and rejects an accepted invite after expiry.
- Migration/compatibility: nullable `accepted_by_user_id` is additive, but the new 35-character revision exceeds default `alembic_version VARCHAR(32)`. Legacy accepted rows have no accepting identity; define safe readback/backfill. No real PostgreSQL upgrade or concurrency validation ran.
- Recipient action: FE's 2026-10-24 entry above describes its earlier consumer snapshot; both endpoints now exist in source but are not integration-ready. Preserve opaque issuer tokens, fix login resume/structured errors/contact verification, agree preview status semantics and stable venue identity, then verify `/me/bars` and workspace entry. B07 pending-only issuance/delivery remains prerequisite work.
- Evidence: [routes](../be/app/bars_and_restaurants/routes/staff.py), [identity/RBAC](../be/app/auth/rbac_middleware.py), [migration](../be/migrations/versions/dob_91_staff_inv_accepted_by.py), [BE assignment](../.specs/mvp-v0.1/pilot/B08-backend-handoff.md). Independent checks: 35 staff/auth tests and 14 FE cubit tests passed; raw-record probe failed; dictionary diagnostics exposed further failures. See the criterion record for commands and limits. No deployment or journey validation is claimed.
