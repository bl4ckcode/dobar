---
owner: backend
spec: B08
artifact: implementation-handoff
status: ready-for-planning-and-implementation
---

# DOB-91: Backend handoff after DOB-90 frontend implementation

Prepared 2026-10-24 from this checkout. Assignment: [DOB-91](https://linear.app/dobarecosystem/issue/DOB-91), parent [DOB-89](https://linear.app/dobarecosystem/issue/DOB-89). Implement BE preview/acceptance; preserve the existing FE patch. This is a source-based assignment, not independent validation of DOB-90 or evidence of a working invitation journey. Recheck changed source and live issue context when available before implementation.

Independent verification on 2026-10-25: implementation is present but fails backend/consumer checks. The producer gap below records the assignment's earlier baseline, not today's endpoint availability. Use the [current criterion evidence and follow-ups](validation-checklist.md) and [latest BE communication entry](../../../docs/FE_BE_COMMUNICATION.md) for observed behavior. The author-reported 14 FE tests were rerun successfully; they do not cover the failing real-record, issuer-token, error-envelope or login-resume paths. No product code was repaired by verification.

## Required context and ownership

- Read [root instructions](../../../AGENTS.md), [BE instructions](../../../be/AGENTS.md), [backend skill](../../../.agents/skills/dobar-backend/SKILL.md), and [communication skill](../../../.agents/skills/dobar-communication-docs/SKILL.md). Follow the BE architecture/workflow links. Use the cross-repo planning skill only for unresolved boundary decisions.
- Acceptance: [B08-AC01 through AC05](../B08-staff-invitation-acceptance.md); exact BE assignment: [B08/be](implementation-tasks.md#b08be--bind-atomic-acceptance-to-the-verified-recipient).
- Current boundary note: [FE/BE](../../../docs/FE_BE_COMMUNICATION.md); error design: [API errors](../../../fe/.docs/API_ERROR_CONTRACT.md). No payment-engine work belongs to this assignment.
- Write BE routes/services/schemas, necessary additive migrations and meaningful tests. Record FE follow-ups; do not rewrite the frontend translation. Preserve user changes and existing callers. Do not stage, commit, push, publish Linear updates or deploy.

## Observed producer/consumer gap

[BE staff routes](../../../be/app/bars_and_restaurants/routes/staff.py) expose query-only `POST /me/bars/accept-invitation`, return only `message`, `bar_id`, `role`, and write membership and invitation status separately without verified-recipient matching. No preview endpoint was found in the inspected invitation routes. [Alternate issuance](../../../be/app/bars_and_restaurants/routes/staff_invite.py) also needs the separate B07 correction.

[FE datasource](../../../fe/lib/features/session/data/datasources/session_datasource.dart) now calls both endpoints with JSON `{"invitation_code": "opaque-code"}`. It parses successful preview as [InvitationPreview](../../../fe/lib/features/session/domain/models/invitation_preview.dart) and acceptance as [BarAccess](../../../fe/lib/features/session/domain/models/bar_access.dart). These expectations are implemented consumers, not deployed BE support.

## BE implementation and contract

1. Add authenticated `POST /me/bars/invitations/preview`. Resolve the invitation and match a normalized, server-verified recipient contact before disclosing private venue/contact details. Return `venue_name` and ISO-8601 `expires_at` strings, nullable `venue_address`/`venue_image_url`, the actual `role`, `masked_recipient`, and permission-code array. Include safe pending/already-accepted semantics per B08; coordinate any extra FE state fields explicitly. Do not derive authorization from possession of the code.
2. Accept JSON at `POST /me/bars/accept-invitation`; retain legacy query callers and reject conflicting values. Validate recipient, status, expiry, venue and assigned role. Return integer `bar_id`, string `bar_name`, actual `role` and permission-code array; retain additive `message`. Permissions must agree with `/me/bars` and server authorization, rather than being inferred by the client.
3. Atomically consume the invitation and create/reactivate the permitted membership. Audit current constraints/data before additive migrations. Persist recipient identity for safe duplicate/concurrent same-user acceptance; return the same current access. Another user cannot consume it. Replay cannot restore subsequently revoked access. Preserve historical memberships.
4. Return canonical `error_code` plus human-readable `message`, with safe HTTP statuses: invalid 404, expired/revoked 410, mismatch/unverified 403, used by another recipient 409. Same-recipient idempotent success is 200. Define safe verification metadata, including `contact_type` (`email` or `phone`) for the unverified-contact branch, and coordinate its FE consumption. Preserve compatible error details as needed; do not put machine codes into localized messages to compensate for a client parser gap.
5. Follow [B07](../B07-staff-invitation.md) for pending-only issuance, authorization and delivery. Both current issuance routes grant existing users immediate membership and generate `secrets.token_urlsafe(16)` codes. Do not silently replace existing tokens with the React fixture's DBR format. Correct B07 through its separate assignment; B08 cannot receive complete journey evidence while it remains unresolved.

## FE follow-ups requiring integration verification

These are inspected risks to reproduce and resolve in FE follow-up work, not reasons to weaken BE authorization or redesign persisted tokens:

| Finding | Evidence and next action |
|---|---|
| Manual code/full-link parsing conflicts with current issuance | [InvitationCubit](../../../fe/lib/features/session/presentation/cubit/invitation_cubit.dart) only normalizes `DBR-XXXX-XXXX`, and full links recognize `codigo` or `/convite/...`; [B07 issuance](../../../be/app/bars_and_restaurants/routes/staff.py) produces URL-safe opaque tokens and the specified entry route uses `/staff/invitations/accept?code=...`. Test direct route, pasted links and manual codes using real issuer output; preserve existing token compatibility. |
| Error handling differs between preview and accept | Preview reads top-level `error_code`; acceptance reads only `message`. Cubit preview uses exact code matching and accept special-cases a code substring. Returning canonical BE errors alone will not make all FE branches work. Add datasource-to-cubit contract tests and preserve structured codes through both paths. |
| `contact_type` is currently discarded | Cubit emits `InvitationUnverified(... contactType: 'email')` unconditionally. Adding a BE field alone cannot activate the phone branch; FE must preserve and consume the agreed metadata. |
| Login resume is not established by passing router extras | [Page](../../../fe/lib/features/session/presentation/pages/staff_invitation_page.dart) sends `pendingInvitationCode` to sign-in. A repository search found no consuming use beyond those send sites; `onLoginReturned` has no external call site. Verify actual sign-in routes and a full signed-out → login → invitation round trip, including refresh. |
| Already-member fallback uses a venue name | Cubit matches existing access by `barName == preview.venueName` after an acceptance error. Names are not stable identifiers. Prefer the BE's idempotent BarAccess success and verify same-name venues cannot select the wrong workspace. |

## Evidence and completion handoff

The implementation author reported 14 session tests passing and analyzer output of two info hints, plus two reportedly pre-existing payment test failures. Those results were not rerun or independently verified in preparing this document. An unchanged payment test file alone does not prove the failures predate the change; compare with baseline before recording that conclusion.

The [React source record](react-source-handoff.md) now names a local export and translation map, but its immutable revision and product review are still pending; its final paragraph also retains the old blocked wording. Resolve that provenance/status contradiction during verification without inventing a source SHA or treating translation as independently validated.

Run affected tests from `be`, starting with the relevant staff/auth tests (inspect `tests/test_staff.py` and `tests/test_auth.py` and add focused coverage). Cover real JSON/legacy query/conflict inputs, exact preview/access response serialization, absent/wrong/unverified identity, expired/revoked/used tokens, transaction rollback, concurrent retries, revoked-membership replay and `/me/bars` readback. Isolate external services and report unavailable infrastructure honestly.

Before integration completion, add FE datasource/response/error fixtures and browser login-resume/workspace checks; mocked cubit tests alone do not exercise these contracts. B07-delivered links and correct server permissions remain journey prerequisites. Record exact revision/environment, commands and criterion outcomes separately as passed, failed, blocked or skipped.

Replace only the latest BE entry in FE/BE communication when BE behavior changes, retaining the FE entry/date. Deliver migrations/compatibility details, contract examples, actual checks, a concise frontend integration follow-up and an independent verification assignment. Do not mark DOB-89 or the full B08 spec validated from BE-only results.
