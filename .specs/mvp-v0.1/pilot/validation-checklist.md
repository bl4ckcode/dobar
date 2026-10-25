---
owner: verifier
spec: B08
artifact: validation-checklist
status: unverified
---

# Independent staff-invitation validation

Use [B08](../B08-staff-invitation-acceptance.md) criteria and [implementation contracts](implementation-tasks.md). Independent verification on **2026-10-25** found backend and FE integration defects. B08 remains **unverified and incomplete**. The scenario matrix defines required observations; actual executed evidence, failures and unexecuted work are recorded separately below.

| Scenario | Required observation | Criteria |
|---|---|---|
| Invite existing email/phone account | Delivered invitation remains pending; account has no new membership before accept | B07-AC02, B07-AC03; B08-AC01 |
| Invite new recipient | Link survives existing registration/phone or Google/Apple login and returns to preview | B08-AC01 |
| Signed-out preview | Generic login frame only; code alone cannot log in or disclose private roster/contact | B08-AC01, B08-AC02 |
| Verified matching email | Explicit acceptance returns BarAccess and correct venue access | B08-AC02, B08-AC03, B08-AC04 |
| Verified matching phone | Same behavior with normalized phone; unrelated matching display text cannot bypass verification | B08-AC02, B08-AC03 |
| Wrong/unverified account | Guidance to switch/verify, no membership, no code consumption | B08-AC02 |
| Cancel provider login / close browser | Resume safely without membership or losing intended invitation | B08-AC01 |
| JSON body / legacy query / conflict | Both compatible valid forms succeed; conflict fails; BarAccess fields decode in Flutter | B08-AC04 |
| Concurrent/repeated accept | One membership and one accepted user; same recipient obtains consistent access | B08-AC03 |
| Another recipient reuses accepted code | Safe rejection; no second membership | B08-AC03, B08-AC05 |
| Transaction fails halfway | Neither partial membership nor consumed invitation; safe retry | B08-AC03, B08-AC05 |
| Expired/revoked/invalid code | Distinct safe state and new-invite guidance; no access | B08-AC05 |
| Previously removed member replays code | No silent membership restoration | B08-AC03, B08-AC05 |
| Network timeout after acceptance | Retry/readback resolves actual result, one workspace entry | B08-AC03, B08-AC04, B08-AC05 |
| Venue context/permissions | `/me/bars` refresh, correct selected venue, direct restricted actions denied | B08-AC04 |
| Narrow/wide + dark/light | All states readable, theme token alignment, no clipped actions | B08-AC06 |
| Keyboard/screen reader/text scale | Focus order, live announcements, labeled controls and motion preference work | B08-AC06 |
| Provenance and handoffs | Real exported React revision, approved prompt states and scoped FE/BE tickets recorded | B08-AC06 |

For each executed row capture checkout commit, environment, account roles/contact-verification fixture (redacted), browser/OS, action, expected/actual result and artifact path. Record targeted FE/BE contract/test command outcomes. Keep real invite codes, contact values and auth secrets out of screenshots/logs.

Foundation validation only confirms spec/skill/reference structure. Hand-created invitations verify acceptance components but do not prove B07 delivery. A simulated login or React fixture cannot validate identity binding. Backend test passes do not replace browser resume and accessible UI checks. Only the independent verifier may recommend validated after every applicable B08 criterion has evidence; retain blocked status for missing source export, delivery service, verification capability or environment access.

## Checkout, assignment and evidence limits

- Inspected HEAD `971e5ee2a46829b1c9b94b0d4c880bc757cdef7a` plus the existing unstaged changes to BE staff routes, RBAC model, errors, FE/BE note and untracked `dob_91_staff_invitation_accepted_by.py`. The pre-existing modified `be/.coverage` was preserved; checks disabled coverage writes. This verifier did not author or repair product code, stage files, publish issues or deploy.
- Read the current spec, actual diff, [DOB-91](https://linear.app/dobarecosystem/issue/DOB-91) and its comments, [backend assignment](B08-backend-handoff.md), `.agent-workflow/handoffs/B08-heavy-ui.md`, `.agent-workflow/handoffs/B08-frontend.md`, both sender notes, and actual BE/FE consumers. DOB-91 remained Backlog at read time; no author BE execution log or new acceptance tests were supplied in the diff/comments. A modified coverage file is not check evidence.
- The backend handoff reports 14 FE test passes, two analyzer hints and allegedly pre-existing payment failures. The 14 passes and two hints were reproduced. Payment failures were not rerun or compared with baseline; their pre-existing attribution remains unverified.
- Environment: macOS checkout; Python 3.12.11, FastAPI 0.112.0, databases 0.9.0, asyncpg 0.30.0, SQLAlchemy 2.0.32, Alembic 1.13.2, pytest 8.4.2. Existing BE/workflow virtual environments were used. Synthetic users, venue and codes only; temporary SQLite databases, actual route/auth dependencies, and existing import-time external-service mocks. No provider, live account or deployed service was exercised.
- Probe sources/logs live in ignored `.agent-workflow/verification/B08/`; FE probe execution source is `fe/.dart_tool/b08_contract_verification_test.dart`, copied there as `frontend_contract_probe.dart`. They are local verification artifacts, not product patches. The reduced FastAPI harness mounts the actual router and canonical API/validation handlers; it does not exercise the full application middleware/lifespan or a browser.
- Raw database records and dictionary fixtures are explicitly separate. The dictionary diagnostic mode substitutes `dict(record)` at the test boundary to inspect failures hidden behind the first runtime defect; its successes cannot establish acceptance against the unmodified database interface. The PostgreSQL probe uses the installed driver's compiler/execute method with synthetic `fetchval=None`, alongside a real SQLite transaction; it is not an actual PostgreSQL integration run.

## Executed check outcomes

All commands start at the monorepo root unless a working directory is stated.

| Check / command | Outcome | Evidence and practical limit |
|---|---|---|
| `.agent-workflow/venv/bin/python -m tools.agent_workflow validate` | passed, exit 0 | 25 specs, 13 skills, 8 roles; no findings. Structure only. Rerun after documentation edits. |
| `.agent-workflow/venv/bin/python -m unittest discover -s tools/agent_workflow/tests -v` | passed, exit 0 | 30 tests; workflow/fake-service coverage only. |
| In `be`: `venv/bin/python -m pytest tests/test_staff.py tests/test_auth.py -o addopts='' --tb=short -q` | passed, exit 0 | 35 tests. Existing staff tests are loose staff-management smoke tests; none exercise B08 preview/acceptance. |
| In `fe`: `flutter test --no-pub test/features/session/presentation/cubit/invitation_cubit_test.dart` | passed, exit 0 | 14 mocked usecase/cubit tests. They use DBR fixtures and omit datasource/error-envelope and login routing integration. |
| In `fe`: `flutter analyze --no-pub lib/features/session/presentation/cubit/invitation_cubit.dart lib/features/session/presentation/pages/staff_invitation_page.dart lib/features/session/data/datasources/session_datasource.dart lib/features/session/domain/models/invitation_preview.dart` | failed command, exit 1 | Exactly two `prefer_initializing_formals` info hints in cubit lines 27/28; no errors/warnings reported. This is not a journey check. Flutter cache access required sandbox escalation for both FE commands. |
| `be/venv/bin/python .agent-workflow/verification/B08/test_backend_probe.py BackendProbe.test_signed_out_no_details_or_membership BackendProbe.test_conflicts_and_missing_input_do_not_write BackendProbe.test_invalid_expired_revoked_distinct_without_writes BackendProbe.test_actual_database_record_preview` | failed, exit 1 | 3 passed, 1 errored: actual `databases.Record` preview raises `AttributeError: get` at `staff.py:305`. `backend-raw-records.log`. The broader raw-record exploratory run also returned 500 for valid authenticated acceptance. |
| `B08_DICT_ROWS=1 be/venv/bin/python -m unittest discover -s .agent-workflow/verification/B08 -p test_backend_probe.py -v` | failed, exit 1 | 21 diagnostics: 10 passed, 11 failed. `backend-dictionary-diagnostics.log`; fixture isolation only. Covers contact/security, JSON/query/readback, expiry/revocation/used, replay/concurrency, rollback, driver-result and migration constraints. |
| In `fe`: `flutter test --no-pub .dart_tool/b08_contract_verification_test.dart` | failed, exit 1 | 4 probes: preview error category retained; 3 fail for opaque manual token, pasted canonical link and acceptance error category. `frontend-contract-probe.log`. No server or browser involved. |
| In `be`: `venv/bin/alembic heads` | passed, exit 0 | One head, `dob_91_staff_invitation_accepted_by`; graph traversal does not prove upgrade safety. |
| In `be`: `DATABASE_URL=postgresql://synthetic:synthetic@localhost/synthetic venv/bin/alembic upgrade 20250720_fix_pricing_swap:head --sql` | passed, exit 0 | Offline SQL adds nullable column/FK and writes a 35-character revision into `alembic_version`; no database connection or actual upgrade ran. Default version-column compatibility failed the independent probe. |
| `.agent-workflow/venv/bin/python -m tools.agent_workflow verify --spec B08 --output .agent-workflow/reports/B08-independent-verification.json` | blocked/incomplete, exit 2 | Foundation passes; `product-e2e` has no configured runner. Report fingerprints the final documentation checkout. It does not execute the manual probes above or supersede their failures. |

## Assigned criterion outcomes

No complete journey criterion passed. Passing component evidence below is bounded by its fixture/environment.

| Criterion | Outcome | Observed evidence / remaining journey |
|---|---|---|
| B08-AC01 | failed; journey incomplete | Signed-out requests return 401 without details or membership (raw records: passed component). Valid authenticated preview fails on `Record.get`. FE opaque-token/manual-link probes fail. Real registration/login interruption, cancellation, return and refresh are blocked pending integration/runner. |
| B08-AC02 | failed | Raw recipient checks crash. With dictionary fixtures, wrong account returns 403 and preserves pending invite/no membership (passed diagnostic), but a matching account with no trusted verification evidence gets 200 preview and acceptance. `User`/`AuthUser` have no verified-contact state; profile contact fields are editable. Unverified error and metadata are absent. No real verified-provider identity was demonstrated. |
| B08-AC03 | failed | Dictionary fixtures demonstrate sequential SQLite acceptance/replay and rollback after an injected status-write failure (passed diagnostics). Driver-result probe gets false `409 CONFLICT` and rolls back valid acceptance. Concurrent SQLite pair produced 200/500; no unique `(user_id, bar_id)` constraint exists. Removed-membership replay returns 200, changed-role replay returns stale cashier instead of current staff, and historical null acceptor permits another normalized-email account to receive access. Real PostgreSQL locking/race behavior remains blocked. |
| B08-AC04 | failed; workspace incomplete | JSON, query and identical dual inputs serialize the required BarAccess shape and match `/me/bars` only in dictionary/SQLite diagnostics (passed); conflict input returns 400 with raw records. Real valid acceptance fails before readback; FE datasource discards canonical accept error codes. Flutter response parsing, refresh/selection, permission enforcement and correct workspace entry were not proven together. |
| B08-AC05 | failed; retry journey incomplete | Raw-record invalid 404 and expired/revoked 410 branches pass without membership. Dictionary fixtures show used-by-other preview 409 but accept 403; accepted same-user retry after expiry gets 410 instead of idempotent access. Network rollback probe passes only with dictionary fixtures; browser timeout/retry/context retention remain blocked. |
| B08-AC06 | blocked; incomplete | Prompt, tasks, source directory and translation map exist (inspection passed). Clean React checkout observed at `55ce9b5ddf04e9baa1200241208cb97e732c7e0f`; author confirmation of the actual translated revision and product approval remain missing. Narrow/wide, light/dark, keyboard, text scale and screen-reader observations were skipped; no UI acceptance evidence exists. |

## Actionable follow-ups

| Priority / owner | Reproduction and required next result | Criteria |
|---|---|---|
| P0 BE — database record compatibility | Use a future, pending invitation and matching authenticated user with actual `Database.fetch_one` records: preview/accept crash on `.get()`; preview venue lookups repeat the same mistake. Normalize records deliberately or use supported access. Add real-record route regression coverage before interpreting dictionary tests as integration success. | AC01–AC05 |
| P0 BE/auth — trusted contact binding | Dictionary probe creates a matching user without verification evidence and receives 200. `rbac_middleware.AuthUser`/`auth_models.User` expose text only; `auth/profile.py` updates email/phone without a verification transition. Persist/use trustworthy provider verification, invalidate it on contact edits, and fail closed. Exercise matching verified email/phone, unverified and mismatched accounts with no membership/details on failures. | AC01–AC03 |
| P0 BE — PostgreSQL acceptance/concurrency | `staff.py:421` UPDATE has no RETURNING; installed PostgreSQL `execute()` calls `fetchval`, so `None` triggers false conflict at line 433. Return/check a consumed row under transaction/locking and reconcile same-user races to current access. Audit duplicates before adding unique user/bar enforcement; test revoked/expired races and rollback using isolated PostgreSQL. SQLite success cannot close this. | AC03–AC05 |
| P1 BE — migration and historical data | Revision length is 35, while installed Alembic's default version column is 32; offline SQL tries to store that value. Shorten the undeployed revision or explicitly migrate the version schema if required by actual deployment state. Test real upgrade/downgrade and preserving historical rows. Define safe ownership/readback for accepted rows with null/deleted acceptor; do not infer authorization from matching text alone. | AC03–AC05 |
| P1 BE — replay returns current access | Accepted invite + inactive membership returns success; accepted invite with current `staff` membership returns original `cashier` access; an elapsed expiry defeats same-user retry. Read active membership/current role/permissions and venue before returning access, never restore removed access, and agree historical/expiry semantics. Add exact replay/readback/timeout tests. | AC03–AC05 |
| P1 FE/BE — finish error/state contract | Used-by-other guard ordering yields preview 409 vs accept 403; dictionary race branch uses generic `CONFLICT`; unknown stored role raises 500. Unverified 403 plus agreed safe `contact_type` metadata is not implemented. FE preview retains only the code; accept retains only the message; cubit hardcodes email, maps used preview to invalid and otherwise uses generic accept error. Preserve structured categories/metadata end to end and contract-test every negative branch. Define preview pending/already-accepted semantics (currently no status field), and stable venue identity if FE retains its name-based fallback. Required preview/accept endpoints exist in source; no additional invitation endpoint is specified by B08. | AC01–AC05 |
| P1 FE — entry/login/verification | `submitCode('synthetic_opaque-token_1')` and pasting `/staff/invitations/accept?code=…` fail, while direct route `initialCode` bypasses manual parsing. Accept URL-safe issuer output without uppercasing it and recognize the canonical link. `pendingInvitationCode` has only send sites, `onLoginReturned` no caller, login redirects home, and verify-contact CTA has `onPressed: () {}`. Implement durable resume/switch-account/verification actions; test complete login and reload. | AC01, AC02, AC04, AC05 |
| Prerequisite B07 / BE + delivery | Both issuance routes still add existing users immediately; alternate route uses role hierarchy rather than the agreed permission path. Preserve B07 ownership, fix pending-only authorization/delivery there, then prove no membership before explicit acceptance using genuinely delivered email/phone links. Hand-created fixtures do not close B07. | AC01–AC05 |
| Product / heavy-ui / verifier | Confirm translated React revision and approval; complete browser accessibility/theme and login/workspace observations with the corrected contracts. Register a spec-specific E2E runner and record test accounts/environment before assigning whole-journey acceptance. | AC01–AC06 |

Blocked: complete product E2E, trusted verified-identity fixtures, B07-delivered pending invites, and an isolated PostgreSQL migration/concurrency integration run. Skipped deliberately: broad unrelated BE/FE suites, payment-baseline investigation, browser/device/assistive-technology observations, and any deployment/live-provider work. No skipped or blocked check is counted as passed.

## Communication and handoff reconciliation

The prior BE sender entry claimed verified/atomic acceptance and consistent used errors from source inspection. It has been replaced with observed declarations, failures and recipient actions; the FE sender entry/date is preserved as its 2026-10-24 snapshot. Its statements that preview does not exist/accept returns fewer fields are now stale, explicitly clarified in the new BE entry. BE/DPE is unaffected and unchanged. Durable unresolved work remains here and in B08, rather than disappearing with the replaced note.

The generated FE/heavy-ui handoffs embed the preimplementation spec and are assignment snapshots, not current check evidence. The backend handoff likewise described query-only baseline behavior. Their desired contracts remain binding; the live source now declares the two endpoints and shapes but fails the observations above. The React record's contradictory final “translation stays blocked” wording was corrected to distinguish available source/translation from unconfirmed provenance and missing approval. No translation revision or product approval was invented.
