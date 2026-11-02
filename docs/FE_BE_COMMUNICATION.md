# Frontend ↔ backend communication

Last updated: 2026-11-01

Rolling handoff: keep only the latest frontend update and latest backend update. Replace an area's previous entry when that area changes; retain the other area's latest entry. Git and linked Linear issues own history. Source inspection is not deployment or E2E evidence.

## Contract references

- [Auth/RBAC](../be/app/auth/rbac_models.py), [API errors](../fe/.docs/API_ERROR_CONTRACT.md), [draft schemas](../be/app/bars_and_restaurants/schemas/onboarding.py), [draft routes](../be/app/bars_and_restaurants/routes/onboarding.py), [service](../be/app/bars_and_restaurants/services/onboarding.py).
- Journey intent: [B02](../.specs/mvp-v0.1/B02-venue-onboarding.md), [B03](../.specs/mvp-v0.1/B03-ai-menu-import.md). Other auth/navigation/invitation work remains with [C01](../.specs/mvp-v0.1/C01-customer-authentication.md), [B01](../.specs/mvp-v0.1/B01-business-auth-navigation.md), [B08](../.specs/mvp-v0.1/B08-staff-invitation-acceptance.md), and [S01](../.specs/mvp-v0.1/S01-design-system.md). [Open findings](AGENT_CONTEXT.md) and [payment boundary](BE_DPE_COMMUNICATION.md) remain unchanged.

## Latest frontend update

- Date: 2026-11-01. Scope: B01/B02/B08 business entry and invitation acceptance; existing B02 venue drafts are preserved.
- Implemented: [entry coordinator](../fe/lib/features/session/presentation/entry_coordinator.dart) replaces shell routing guesses. Profile, actual venue access and matching invitations resolve entry after login/restoration; failures retain retryable error state. Accepted membership bypasses incomplete role/country fields. No-access business profiles return to editable saved choices and the existing Create Bar/draft flow. Back awaits sign-out without deleting choices/drafts.
- FE consumes additive `GET /me/bars/invitations/pending`. One result opens preview, multiple results open a chooser; manual code is an explicit login action. Provider preference is retained through invitation login. Acceptance success precedes workspace access refresh; refresh retry cannot accept again and selects the exact accepted venue.
- Canonical/legacy `dobar.app` links use [one handler](../fe/lib/features/session/data/invitation_link_handler.dart), strict host/path parsing and case-preserving tokens. Pending intent uses secure native storage/browser session storage and clears on abandonment/acceptance/terminal errors. Invitation UI follows React `55ce9b5ddf04e9baa1200241208cb97e732c7e0f`; onboarding button-theme text styles now agree during transitions.
- Compatibility/action: release the additive backend endpoint before FE through existing CI/CD. B02 draft APIs/migration and legacy wizard compatibility remain required. Native association files are packaged by existing nginx hosting; Android currently signs release with its actual debug certificate. Production-signing/domain/signed-device checks remain release prerequisites. No deployment claimed.
- Evidence: [entry tests](../fe/test/features/session/entry_ui_test.dart), [resolution](../fe/test/features/session/domain/entry_resolution_test.dart), [invitation state tests](../fe/test/features/session/presentation/cubit/invitation_cubit_test.dart), existing [B02 tests](../fe/test/features/bars/venue_access_refresh_test.dart). Exact check outputs and visual evidence are in ignored `.agent-workflow/reports/business-entry`; deterministic tests do not establish provider/native E2E.

## Latest backend update

- Date: 2026-11-01. Scope: B08 additive authenticated pending-invitation discovery; B02 owner-scoped drafts remain implemented and unchanged by this entry correction.
- Implemented: `GET /me/bars/invitations/pending` returns an array of `invitation_id`, `invitation_code`, `bar_id` plus existing recipient-bound preview fields. Only pending, unexpired records matching server-verified normalized email/phone are returned; empty array means successful discovery with no match. Failed requests remain failures. Discovery grants no membership. Preview and acceptance retain existing contracts and recheck recipient/status/permissions; accepted replay now also rechecks verified contact.
- Existing B02: partial versioned saves, masked bank summaries, idempotent creation/assets/finalization, exact final `bar_id` and Mongo projection outbox remain. The additive [migration](../be/migrations/versions/b02_venue_onboarding_drafts.py), stable bank-encryption key and real S3 configuration are still deployment prerequisites for drafts; legacy `/bars/wizard` remains supported. Incomplete drafts grant no access. Bank persistence is not provider verification.
- Compatibility/action: discovery requires no migration or onboarding-completion flag. Deploy backend before FE using existing GitHub Actions. Never log invitation codes or recipient contacts; FE body logging is disabled and query credentials are redacted.
- Evidence: [staff routes](../be/app/bars_and_restaurants/routes/staff.py), [discovery tests](../be/tests/test_pending_invitations.py), [B02 tests](../be/tests/test_venue_onboarding.py). Real isolated PostgreSQL discovery/acceptance/replay and B02 draft/locking/migration checks passed in the local run; exact commands/results live in `.agent-workflow/reports/business-entry`. Auth-provider, hosted-domain and signed-device outcomes remain unverified; no deployment claimed.
