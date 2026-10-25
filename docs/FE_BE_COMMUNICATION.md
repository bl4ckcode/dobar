# Frontend ↔ backend communication

Last updated: 2026-10-25

Rolling handoff: keep only the latest frontend update and latest backend update. Replace an area's previous entry when that area changes; retain the other area's latest entry. Git and linked Linear issues own history. Source inspection is not deployment or E2E evidence.

## Contract references

- [Auth/RBAC](../be/app/auth/rbac_models.py), [API errors](../fe/.docs/API_ERROR_CONTRACT.md), [payment schemas](../be/app/payment/schemas.py), [order routes](../be/app/bars_and_restaurants/routes/orders.py).
- [Journey specs](../.specs/mvp-v0.1/README.md) describe intended acceptance; [open findings](AGENT_CONTEXT.md) record unresolved mismatches; [payment boundary](BE_DPE_COMMUNICATION.md) covers BE/DPE.

## Latest frontend update

- Date: 2026-10-25 (re-verification of changed FE source; no product repair by verifier).
- Scope: [DOB-90](https://linear.app/dobarecosystem/issue/DOB-90), [B08](../.specs/mvp-v0.1/B08-staff-invitation-acceptance.md); [current evidence/follow-ups](../.specs/mvp-v0.1/pilot/validation-checklist.md).
- Contract/action: both preview/accept calls send JSON `invitation_code`; both now preserve top-level `error_code`. Preview parses venue/role/masked contact/expiry/permissions; acceptance parses `bar_id`, `bar_name`, `role`, `permissions`. Success dispatches barCreated/refresh and offers workspace entry; the integrated outcome remains unverified.
- Remaining gaps: parser still rejects opaque issuer tokens and pasted `/staff/invitations/accept?code=…` links. LoginPage's new pending-code handling reads ModalRoute in initState and fails the default-page widget probe; GoRouter does not pass its extra to the new constructor. Durable login/onboarding/MFA/refresh resume remains incomplete.
- Error/action gaps: phone metadata is discarded and unverified state hardcodes email. The verify CTA now opens profile edit, which does not verify ownership; already-member fallback still uses venue name, and accept failures use generic rendering. Coordinate contact metadata, distinct localized states and stable venue selection with BE.
- Evidence: [datasource](../fe/lib/features/session/data/datasources/session_datasource.dart), [cubit](../fe/lib/features/session/presentation/cubit/invitation_cubit.dart), [login](../fe/lib/features/authentication/presentation/pages/login_page.dart), [router](../fe/lib/core/router/app_router.dart). Re-run: 14 cubit tests and 2 datasource probes pass; 2 parsing probes and 1 login widget probe fail; 2 login BLoC tests pass. Analyzer reports 2 info hints. No browser/device E2E evidence.

## Latest backend update

- Date: 2026-10-25 (independent re-verification of changed BE source; no product repair by verifier).
- Scope: [DOB-91](https://linear.app/dobarecosystem/issue/DOB-91), [B08](../.specs/mvp-v0.1/B08-staff-invitation-acceptance.md); [criterion evidence/follow-ups](../.specs/mvp-v0.1/pilot/validation-checklist.md).
- Implemented declarations: authenticated `POST /me/bars/invitations/preview` takes JSON `invitation_code`; response fields are `venue_name`, nullable `venue_address`/`venue_image_url`, `role`, `masked_recipient`, ISO `expires_at`, `permissions`. `POST /me/bars/accept-invitation` declares JSON plus legacy query compatibility, rejects conflicts with 400, and declares `bar_id`, `bar_name`, `role`, `permissions`, additive `message`.
- Observed repairs: pending preview uses supported record access; verified flags gate contact matches; profile edits clear flags; replay checks current active membership/role. These pass actual-record probes with synthetic flags. Invalid 404, expired/revoked 410 and wrong/unverified 403 are exercised without new membership. Actual provider verification acquisition remains absent.
- Runtime blockers: valid acceptance raises `AttributeError` at `.returning(StaffInvitation.c.id)`; accepted preview retains unsupported `invitation.get`. Neither JSON nor query acceptance reaches successful BarAccess/readback. PostgreSQL transaction/race validation is blocked by the earlier exception.
- Error/state gaps: used-other acceptance returns mismatch 403 instead of required 409; unverified responses lack `contact_type`; accepted replay after expiry returns 410. Preview status semantics, current-access retry behavior and safe invalid-role handling still need agreement/tests.
- Migration/compatibility: renamed `dob_91_staff_inv_accepted_by` fits Alembic's version column and adds nullable accepted-by FK. New non-null `users.email_verified`/`phone_verified` fields have no migration, no working omitted-field insert defaults and no trusted-provider setter. Old schemas cannot satisfy User SELECTs; new-user inserts fail. Correct schema/initialization and provider writes before integration.
- Recipient action: both endpoint shapes exist but acceptance is not integration-ready. Alternate issuer now stays pending; scoped issuer still auto-grants existing users membership. Complete B07 issuance/delivery, preserve opaque-token compatibility, coordinate FE verification/resume, then prove refresh/workspace entry and PostgreSQL concurrency.
- Evidence: [routes](../be/app/bars_and_restaurants/routes/staff.py), [identity/RBAC](../be/app/auth/rbac_middleware.py), [migration](../be/migrations/versions/dob_91_staff_inv_accepted_by.py), [BE assignment](../.specs/mvp-v0.1/pilot/B08-backend-handoff.md). Staff/auth re-run: 27 failed, 5 passed, 3 errors. Independent BE probes: 15 passed, 11 failed assertions, 3 errors; unreachable write/concurrency checks stay blocked. See criterion evidence for limits. No deployment or journey validation is claimed.
