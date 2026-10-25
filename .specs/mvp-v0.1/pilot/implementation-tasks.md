---
owner: product
spec: B08
artifact: implementation-tasks
status: ready
---

# Invitation pilot implementation handoffs

Parent: [B08](../B08-staff-invitation-acceptance.md). Dependencies: [B07 issuance/delivery](../B07-staff-invitation.md), [B01 business entry](../B01-business-auth-navigation.md). These are ticket drafts; they do not assert Linear issues have been created.

## B08/fe — Resume and accept a staff invitation

Owner: frontend; heavy-ui translates the actual reviewed React export. Skills: dobar-frontend, dobar-react-to-flutter. Implement against the backend contract below, with B07-generated links.

- Replace the coming-soon acceptance dialog with manual-code entry and a routed preview page. Use browser route `/staff/invitations/accept?code=…` as the link target; retain the pending invitation through the existing login/registration flow and clear it after completion/dismissal. Never log the code or include it in analytics.
- Reuse phone/SMS, Google and Apple login; re-inspect after authentication. Match/verification is decided by backend, not locally comparing display strings. Present wrong-account/switch-account, unverified contact, expiry/revocation/invalid, submitting/network/retry and success states.
- Send JSON `invitation_code`, decode full BarAccess, refresh `/me/bars`, select the accepted bar and enter its permitted workspace. Do not add membership optimistically or discard current workspace until server confirmation.
- Translate reviewed React source using semantic tokens, localization, reusable widgets, BLoC/repository/DI, accessible keyboard/focus and narrow/wide browser layouts. Retain actual source revision in delivery evidence.
- Acceptance: B08-AC01, AC02, AC04, AC05, AC06. Verify routing/login resume, JSON serialization, response parsing, theme/a11y states and one success navigation under retries. Backend security criteria require backend evidence too.

## B08/be — Bind atomic acceptance to the verified recipient

Use the [focused DOB-91 handoff](B08-backend-handoff.md) for current FE consumer evidence, BE implementation scope and integration follow-ups after DOB-90.

Owner: backend; planner: cross-repo-planner. Skills: dobar-backend, dobar-cross-repo-plan. Existing issuance behavior is corrected by B07, not duplicated in this task.

- Add authenticated `POST /me/bars/invitations/preview` with JSON `invitation_code`. For matching verified recipient only, return safe venue name/image, offered role/permission labels or codes for localized display, masked contact, expiry and pending/already-accepted state. For mismatched/unverified identities return safe error categories without venue-private data. Signed-out page shows a generic invitation/login frame and fetches details after login; possession of code alone reveals no private roster/contact data.
- Update existing `POST /me/bars/accept-invitation` to accept JSON `invitation_code`; retain legacy query input, reject conflicting nonidentical values with 400. Resolve current query-vs-body mismatch. Success returns `bar_id`, `bar_name`, `role`, `permissions` (the existing BarAccess shape), with additive `message` retained for older consumers.
- Bind invited normalized email or phone to a **server-verified** contact on the authenticated user. Matching display email without verification is insufficient. Use existing identity-provider verification evidence; where persistence lacks trustworthy verification state, add explicit verified-contact persistence/verification before enabling acceptance. Never auto-login using invitation code.
- Validate token, expiry, revocation, venue and allowed role, then atomically create/reactivate a unique membership and consume invitation. Persist the accepting user so same-user repeated/concurrent acceptance is idempotent; another user cannot reuse it. Add necessary additive migration/unique constraints after auditing existing duplicates; preserve historical accepted memberships and do not retroactively revoke them from this spec alone.
- Map safe error categories: `INVITATION_INVALID` (404), `INVITATION_EXPIRED`/`INVITATION_REVOKED` (410), `INVITATION_CONTACT_MISMATCH`/`INVITATION_CONTACT_UNVERIFIED` (403), `INVITATION_ALREADY_USED` (409). Same recipient already accepted returns current BarAccess if membership still active; revoked membership must not be silently restored by replay. Include canonical error envelope details in the implementation contract; preserve compatible clients that consume existing error detail.
- Acceptance: B08-AC01 through AC05. Tests cover verified email/phone, mismatch/unverified, JSON/legacy query/conflicts, missing/expired/revoked codes, ownership restrictions, concurrent/repeated acceptance, transaction rollback, removed membership replay and full BarAccess parsing/readback.

## B07 prerequisite — Pending-only issuance and delivery

Existing scoped and simple invite routes grant existing contacts immediate membership; both must instead issue pending invitations through the same staff:manage authorization path. Implement email/phone delivery with resumable link, expiry and observable failures/resend. This belongs to B07 and must be linked as a prerequisite to both B08 child issues. B08 cannot be declared E2E validated using hand-created codes alone.

## Cross-area contract review

The planner updates the canonical [FE/BE communication contract](../../../docs/FE_BE_COMMUNICATION.md) with implemented preview/accept fields and error behavior before implementation merges. The preview/route choices here are desired additions, not claims of current API availability. Preserve current deployed interfaces while introducing the new flow. Verification follows the [independent checklist](validation-checklist.md); separate delivery completion from E2E evidence.
