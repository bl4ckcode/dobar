# Frontend ↔ backend communication

Last updated: 2026-10-24

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

- Date: 2026-10-23.
- Scope: [DOB-85](https://linear.app/dobarecosystem/issue/DOB-85), [B05-AC05](../.specs/mvp-v0.1/B05-cashier-live-orders.md).
- Contract/action: `GET /bars/{bar_id}/orders/live` excludes orders after their creation operating day's closing time in venue-local time, including overnight shifts. No configured hours means previous behavior. FE keeps the existing response shape, preparation states and payment semantics.
- Evidence: [orders implementation](../be/app/bars_and_restaurants/routes/orders.py), [cashier regression tests](../be/tests/test_cashier_operations.py). Source inspected in the working tree; tests/deployment were not rerun for this documentation update.
