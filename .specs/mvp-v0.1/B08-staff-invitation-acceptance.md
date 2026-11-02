---
id: "B08"
title: "Staff invitation acceptance pilot"
owner: "product"
areas: ["fe", "be"]
priority: "P0"
depends_on: ["B07", "B01"]
source_requirements: ["MVP-B08-01", "MVP-B08-02", "MVP-B08-03", "LAUNCH-B08-01", "LAUNCH-B08-02"]
planning_role: "cross-repo-planner"
implementation_roles: ["heavy-ui", "frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend", "dobar-lovable-prompt", "dobar-react-to-flutter", "dobar-validation"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e"]
tasks: {"fe": {"title": "Resume and accept staff invitation in Flutter", "description": "Depends on B07 delivery link and B08 backend contract. Implement link/manual-code preview and existing-login resume, verified-contact mismatch/switch account and expired/revoked/used states. Replace coming-soon dialog; consume BarAccess response, refresh /me/bars and select workspace. Translate actual exported React revision using semantic light/dark tokens, localization, BLoC/repositories and accessible browser layouts. See pilot/implementation-tasks.md and B08-AC01 through AC06."}, "be": {"title": "Bind atomic invitation acceptance to verified recipient", "description": "Depends on B07 pending-only issuance and delivery; do not duplicate issuance work. Add safe authenticated preview; accept JSON invitation_code with compatible query support, reject conflicts; validate verified normalized recipient, pending/expiry/revocation and assigned role. Atomically write membership and acceptance with concurrent/repeated same-user idempotency, rejecting another recipient. Return BarAccess fields and safe errors. Contract/security tests for contact mismatch, concurrency, compatibility and access readback. See B08-AC01 through AC05."}}
---

# B08: Staff invitation acceptance pilot

## Intended behavior

Deliver the staff invitation acceptance pilot journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

The current working tree implements shared entry resolution, authenticated verified-contact pending discovery, single/multiple invitation entry, provider preference/cancellation continuity, awaited abandonment, secure native/browser session intent storage, deduplicated cold/warm parsing, confirmed acceptance and exact venue access refresh. The invitation UI is mapped from React revision `55ce9b5ddf04e9baa1200241208cb97e732c7e0f`. The existing preview/acceptance shapes remain compatible.

Local PostgreSQL discovery/acceptance/replay and preserved B02 draft checks pass with synthetic verified contacts. Flutter regressions cover decision precedence, errors, lifecycle races, parsing, native-storage mocks, acceptance/refresh separation, both themes, narrow/wide layouts, keyboard dismissal and Back. Screenshots and exact commands/results are in ignored `.agent-workflow/reports/business-entry`. These checks do not establish provider login or a signed-device journey. The older [pilot checklist](pilot/validation-checklist.md) remains a dated independent verification record; rerun its remaining auth/concurrency/product scenarios against the release candidate rather than treating that historical report as current validation.

Browser-storage execution is blocked by local Chrome launch failure. Live association endpoint probes time out, and signed-device/iPhone entry remains a release prerequisite after backend-first CI/CD rollout with controlled test invitations/accounts. No deployment or whole-journey validation is claimed.

Observed source references (see the criterion record for executed checks and their limits):

- [fe/lib/features/session/presentation/pages/staff_invitation_page.dart](../../fe/lib/features/session/presentation/pages/staff_invitation_page.dart)
- [fe/lib/features/session/data/datasources/session_datasource.dart](../../fe/lib/features/session/data/datasources/session_datasource.dart)
- [fe/lib/features/session/domain/models/bar_access.dart](../../fe/lib/features/session/domain/models/bar_access.dart)
- [be/app/bars_and_restaurants/routes/staff.py](../../be/app/bars_and_restaurants/routes/staff.py)
- [be/app/bars_and_restaurants/routes/staff_invite.py](../../be/app/bars_and_restaurants/routes/staff_invite.py)

## Contracts and compatibility

Keep /me/bars/accept-invitation: accept JSON {invitation_code}, retain legacy query as compatibility input and reject conflicting values. Successful acceptance returns BarAccess fields bar_id, bar_name, role, permissions; retain additive message. Add authenticated POST /me/bars/invitations/preview with JSON invitation_code for safe venue/role/expiry preview. Signed-out entry displays a generic login frame before obtaining recipient-bound details. Match verified email or phone on server; never use token alone to log in.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B08-AC01** — Invite link or manual code opens a Portuguese invitation entry; unauthenticated users see a generic login frame, use existing login and return to the same invitation without acquiring membership. A matching verified account then sees venue, offered role, masked recipient and expiry.
- **B08-AC02** — Only an authenticated user whose server-verified email or phone matches the invite can accept; wrong/unverified account gets switch-account/verification guidance without membership or private venue data.
- **B08-AC03** — Explicit accept atomically creates or restores one membership and marks invitation accepted; duplicate/concurrent acceptance by that recipient returns the same access, while another user cannot consume it.
- **B08-AC04** — Successful response satisfies BarAccess, refreshes GET /me/bars and enters the correct permitted business workspace; request/response contract tests cover JSON and compatible query callers.
- **B08-AC05** — Expired, revoked, invalid and already-used-by-another-user invites show distinct safe outcomes; network errors preserve context and retry cannot create duplicate membership.
- **B08-AC06** — React prompt, honest source-export metadata, FE/BE tasks and independent validation checklist are reviewable before translation; final Flutter UI supports light/dark, keyboard/screen readers and desktop/mobile browsers.

- **B08-AC07** — Authenticated pending-invitation discovery returns only pending, unexpired invitations bound to verified matching contacts, with identifiers and preview fields for a one-invitation preview or multiple-invitation chooser. Any authentication provider may be used; discovery grants no membership. Preview/acceptance recheck contact/status/permissions.
- **B08-AC08** — Canonical `https://dobar.app/staff/invitations/accept?code=…` and legacy `/convite/…` cold/warm links use one deduplicated handler, validate host/path and preserve opaque token case. Intent survives authentication and refresh in secure native storage/browser session storage; switching accounts retains it, and abandonment/acceptance/terminal invalidation clears it.
- **B08-AC09** — Google/Apple choices initiate the selected provider once; phone opens phone entry. Cancellation preserves intent. Invitation Back/“Agora não” awaits sign-out and returns to login; manual code entry is only an explicit action. Success appears only after acceptance confirmation, and workspace entry refreshes access and selects exactly the accepted venue; failed refresh retries do not accept again.
- **B08-AC10** — Invitation shell/card/branding/identity/role/permissions/success follow exported React revision `55ce9b5ddf04e9baa1200241208cb97e732c7e0f`. Both themes and narrow/wide layouts support keyboard dismissal and accessible focus. Native associated domains/verified filters and hosted association files use actual signing identifiers; live domain association and signed-device/iPhone evidence remain release prerequisites.

## Validation scenarios and evidence

- Follow full pilot checklist for new/existing email and phone accounts; interrupt login, switch account, expire/revoke token, accept concurrently, replay response and verify minimum workspace permissions.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Entry corrections are implemented locally; release readiness remains incomplete. Verification: unverified pending the browser/provider/signed-device/product checks above. Passing foundation checks establish artifact structure only; Git/Linear retain prior implementation and verification history.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B08-01, MVP-B08-02, MVP-B08-03, LAUNCH-B08-01, LAUNCH-B08-02. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).

## Pilot artifacts

- [Lovable React prompt](pilot/lovable-staff-invitation.md)
- [Source-export handoff](pilot/react-source-handoff.md)
- [Scoped FE/BE implementation tasks](pilot/implementation-tasks.md)
- [Independent verification checklist](pilot/validation-checklist.md)
