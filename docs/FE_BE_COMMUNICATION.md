# Frontend ↔ backend communication

Last updated: 2026-11-01

Rolling handoff: keep only the latest frontend update and latest backend update. Replace an area's previous entry when that area changes; retain the other area's latest entry. Git and linked Linear issues own history. Source inspection is not deployment or E2E evidence.

## Contract references

- [Auth/RBAC](../be/app/auth/rbac_models.py), [API errors](../fe/.docs/API_ERROR_CONTRACT.md), [payment schemas](../be/app/payment/schemas.py), [order routes](../be/app/bars_and_restaurants/routes/orders.py).
- Journey intent: [C01](../.specs/mvp-v0.1/C01-customer-authentication.md), [B01](../.specs/mvp-v0.1/B01-business-auth-navigation.md), [B02](../.specs/mvp-v0.1/B02-venue-onboarding.md), [B08](../.specs/mvp-v0.1/B08-staff-invitation-acceptance.md), [S01](../.specs/mvp-v0.1/S01-design-system.md). [Open findings](AGENT_CONTEXT.md) remain authoritative for unrelated mismatches; [payment boundary](BE_DPE_COMMUNICATION.md) is unchanged.

## Latest frontend update

- Date: 2026-11-01.
- Scope: C01/B01/B02/B08/S01 authentication, onboarding, checkout registration, invitation, and design-system paths. No public auth, invitation, or payment request shape changed.
- Contract/action: post-auth routing preserves `is_new_user`, selected user type, and pending invitation through phone, providers, SMS, and MFA. Pending invitations take precedence; incomplete profiles continue onboarding; completed users enter their role-appropriate home. Registration is checkout-origin only and returns to checkout for a deliberate second Pay action. Business onboarding enters Create Bar; zero-bar business shells offer manual invitation. Invitation accepts DBR codes, opaque URL-safe tokens, canonical same-host links, and legacy Dobar links; foreign hosts are rejected. Acceptance uses exact returned `bar_id` after session refresh.
- Verification: targeted Flutter auth/navigation/login/invitation tests pass (23 tests); analyzer completes with one pre-existing cart warning and one unrelated design-test import hint. Two constructor-style info hints in invitation cubit remain. Device screenshots, provider-backed login, and product E2E were not run.
- Evidence: [router](../fe/lib/core/router/app_router.dart), [login](../fe/lib/features/authentication/presentation/pages/login_page.dart), [onboarding](../fe/lib/features/onboarding/presentation/pages/onboarding_page.dart), [checkout](../fe/lib/features/payments/presentation/pages/checkout_page.dart), [invitation](../fe/lib/features/session/presentation/pages/staff_invitation_page.dart).

## Latest backend update

- Date: 2026-11-01.
- Scope: C01/B08 trusted-contact verification and invitation acceptance reliability; no DPE/payment contract change.
- Contract/action: successful trusted phone, Google, or Apple claims verify a matching existing contact; profile edits continue clearing verification. User verification flags have model and migration defaults. Invitation acceptance claims pending invitations atomically, reconciles same-recipient replay to current BarAccess, and creates/updates membership through the `(user_id, bar_id)` uniqueness constraint. Migration `dob_94_unique_bar_staff` audits duplicates and stops before applying the constraint if any exist. Preview/accept JSON, legacy query compatibility, canonical errors, and response shapes are retained.
- Verification: `pytest tests/test_auth.py tests/test_staff.py` passes (36 tests). SQLite proves the model-generated verification defaults. PostgreSQL concurrency/migration execution and provider-backed identity verification remain unverified; migration requires a clean duplicate audit on deployment data.
- Evidence: [auth routes](../be/app/auth/routes.py), [staff route](../be/app/bars_and_restaurants/routes/staff.py), [membership model](../be/app/auth/rbac_models.py), [migration](../be/migrations/versions/dob_94_unique_bar_staff_membership.py).
