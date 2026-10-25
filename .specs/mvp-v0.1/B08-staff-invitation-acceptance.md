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

Independent backend verification on 2026-10-25 at HEAD `8844c697` plus the working-tree fixes found actual-record preview, contact guards, both pending-only issuers, SQLite JSON/query acceptance/readback and late accepted replay working with synthetic verification flags. The new verification migration passed a bounded real PostgreSQL upgrade preserving an existing user. Application inserts still bind NULL verification flags, however, and valid PostgreSQL acceptance fails on timezone-aware values bound to timezone-naive timestamp columns. The staff/auth suite reports 27 failed, 5 passed and 3 errors; concurrent SQLite acceptance returns 200/500. No auth provider path establishes verified state, and malformed persisted contact/role checks fail. Earlier FE parsing/login findings were not rerun in this backend-only pass. Login resume and the product journey remain incomplete.

The [criterion evidence and actionable follow-ups](pilot/validation-checklist.md) supersede older backend handoff results and separate passed components from failed, blocked and skipped checks. Both issuer components now remain pending without membership; B07 authorization/delivery and the remaining FE/product journey still require evidence. No whole-journey validation is claimed.

Observed source references (see the criterion record for executed checks and their limits):

- [fe/lib/ui/business/widgets/business_onboarding_view.dart](../../fe/lib/ui/business/widgets/business_onboarding_view.dart)
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

## Validation scenarios and evidence

- Follow full pilot checklist for new/existing email and phone accounts; interrupt login, switch account, expire/revoke token, accept concurrently, replay response and verify minimum workspace permissions.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Delivery remains incomplete, subject to the listed dependencies and verification findings. Verification: unverified; the independent 2026-10-25 backend checks found runtime failures, and frontend/product criteria remain incomplete. Product E2E is blocked because no runner is configured. See the [criterion record](pilot/validation-checklist.md); passing foundation checks establish artifact structure only.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B08-01, MVP-B08-02, MVP-B08-03, LAUNCH-B08-01, LAUNCH-B08-02. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).

## Pilot artifacts

- [Lovable React prompt](pilot/lovable-staff-invitation.md)
- [Source-export handoff](pilot/react-source-handoff.md)
- [Scoped FE/BE implementation tasks](pilot/implementation-tasks.md)
- [Independent verification checklist](pilot/validation-checklist.md)
