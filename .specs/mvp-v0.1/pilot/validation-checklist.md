---
owner: verifier
spec: B08
artifact: validation-checklist
status: unverified
---

# Independent staff-invitation validation

Use [B08](../B08-staff-invitation-acceptance.md) criteria and [implementation contracts](implementation-tasks.md). Independent backend verification on **2026-10-25** found DOB-91 runtime defects; earlier FE observations are retained below as unrerun context. B08 remains **unverified and incomplete**. The scenario matrix defines required observations; actual executed evidence, failures and unexecuted work are recorded separately below.

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

## Current backend verification scope and limits

This **2026-10-25 DOB-91 backend pass** supersedes the older backend results in this checklist, the [backend handoff](B08-backend-handoff.md), the spec's earlier narrative, and the latest BE communication note wherever they conflict. No backend implementation was authored or repaired in this pass. The FE implementation, product approval and browser journey were not independently rerun.

- Checkout: HEAD `8844c69763b2c9bea9a6304c2dcb60ba8b70240e`, plus the existing unstaged changes to `auth_models.py` / `staff.py` and untracked `dob_92_user_contact_verification.py`. Git index was empty. Reviewed the complete BE diff from `971e5ee2` through this working tree, the current spec/tasks, author handoff and previous check logs. The old `971e5ee2`/staged-diff fingerprint does **not** identify this run.
- Read DOB-91 and its comments through Linear, without publishing anything. It remains Backlog; its only comment is the GitHub sync notice. No newer author BE execution log or B08 regression-test patch was supplied. Earlier FE test/analyzer and payment-baseline claims are not current backend evidence; payment-baseline attribution remains unverified.
- Environment: macOS arm64, Python 3.12.11, FastAPI 0.112.0, databases 0.9.0, asyncpg 0.30.0, SQLAlchemy 2.0.32, Alembic 1.13.2, pytest 8.4.2. Existing virtual environments were usable without installing packages. PostgreSQL 14.17 ran in an isolated temporary cluster on localhost:55491 with synthetic databases `b08_current` and `b08_upgrade`; no deployed database/account/provider was contacted. The temporary server was shut down after checks.
- Run artifacts were recorded under the ignored local path `.agent-workflow/verification/B08-dob91-current/`; they are not committed or portable repository references. The earlier probes reused a reduced FastAPI/auth harness and actual `databases.Record` objects. External startup services were mocked. Positive fixtures set verification flags explicitly; they do not establish provider trust or whole-app behavior.
- The earlier raw probe suite was rerun unchanged first: 29 methods, 24 passed, 3 failures, 2 errors. Two results were stale probe assumptions: its old-schema test never executes a migration, and its phone assertion expects a string although the canonical `details` envelope uses lists. The current probes actually execute the new migration and assert `details.contact_type == ["phone"]`; these pass. They do not hide the remaining insert/concurrency failures.
- PostgreSQL route fixtures use current ORM-created schemas and timezone-naive stored expiry values. The separate upgrade probe creates a representative predecessor schema by removing the newly added columns, preserves an existing user, stamps `20250720_fix_pricing_swap`, and runs real Alembic `upgrade head`. This proves the two additive upgrades on that fixture, not the complete historical migration chain or deployed-data readiness.

## Executed checks

Commands start at the monorepo root unless a working directory is stated. Logs are under `.agent-workflow/verification/B08-dob91-current/`.

| Check / command | Outcome | Evidence and practical limit |
|---|---|---|
| `.agent-workflow/venv/bin/python -m tools.agent_workflow validate` | passed, exit 0 | `foundation.log`: 25 specs, 13 skills, 8 roles; no findings. Structure only; rerun after evidence edits. |
| `.agent-workflow/venv/bin/python -m unittest discover -s tools/agent_workflow/tests -v` | passed, exit 0 | `workflow-tests.log`: 30 tests. Workflow/fake-service checks, not B08 behavior. |
| In `be`: `venv/bin/python -m pytest tests/test_staff.py tests/test_auth.py -o addopts='' --tb=short -q` | failed, exit 1 | `staff-auth.log`: **27 failed, 5 passed, 3 errors**. New/fixture user inserts still fail `NOT NULL constraint failed: users.email_verified`. Coverage disabled through the existing addopts override; user's `.coverage` preserved. No historical baseline rerun was performed. |
| `be/venv/bin/python -m unittest discover -s .agent-workflow/verification/B08-dob91-current -p test_current.py -v` | failed, exit 1 | `sqlite.log`: **32 methods, 26 passed, 5 failed methods (6 failure records including Google/Apple subtests), 1 error**. Positive acceptance/readback/rollback components pass; concurrent requests return `[200, 500]`, omitted flags fail, provider-login fixtures leave flags false, invalid role returns 500, recipientless persisted invitation grants access. |
| `B08_POSTGRES=1 be/venv/bin/python -m unittest discover -s .agent-workflow/verification/B08-dob91-current -p test_current.py -v` | failed, exit 1 | `postgres.log`: **12 checks, 8 passed, 2 failed, 2 errors**. Includes real Alembic upgrade. Valid JSON/query/both acceptance returns `[500, 500, 500]`; concurrent requests return `[500, 500]` before meaningful race handling. Omitted verification flags fail with PostgreSQL `NotNullViolationError`. Local-server network/shared-memory access required sandbox escalation. |
| In `be`: `venv/bin/alembic heads` | passed, exit 0 | One head: `dob_92_user_contact_verification` (31 characters; fits the default version column). Real upgrade also records this head successfully. |
| In `be`: `DATABASE_URL=postgresql://synthetic:synthetic@localhost/synthetic venv/bin/alembic upgrade 20250720_fix_pricing_swap:head --sql` | passed, exit 0 | `migration.sql`: accepted-by FK and both non-null flags with server defaults false. This offline check alone would not establish runtime compatibility. |
| `.agent-workflow/venv/bin/python -m tools.agent_workflow verify --spec B08 --output .agent-workflow/reports/B08-DOB91-current.json` | blocked/incomplete, exit 2 | Foundation passes; `product-e2e` has no configured runner. This workflow report does not execute or replace the manual backend probes/failures. |

## Observed backend components

| Component | Outcome and evidence |
|---|---|
| Signed-out and wrong-account attempts | passed: actual auth dependency rejects signed-out requests with 401; mismatch returns 403 without venue details, membership or invitation consumption. Checked with SQLite and PostgreSQL. |
| Pending/accepted preview and recipient normalization | passed with synthetic flags: email case/whitespace and phone punctuation normalization, masked preview shape/expiry and no membership. Accepted-row preview no longer crashes on `Record.get`. These are actual-record SQLite components. |
| Unverified contact and metadata | passed: false flags reject preview/accept; phone metadata is `details.contact_type: ["phone"]`. Profile email/phone edits invalidate flags. Real verification acquisition remains failed/incomplete below. |
| JSON/query/conflict and BarAccess | passed on SQLite: JSON, legacy query, both identical, full `bar_id`/`bar_name`/`role`/`permissions` response and GET `/me/bars` readback. Conflict/missing input reject without writes. PostgreSQL positive acceptance fails, so this does not establish integration readiness. |
| Used/revoked/expired/replay | passed: invalid 404, expired/revoked 410, used-other 409 with no second membership; active same-recipient replay returns current role, inactive access stays removed. Accepted same-user retry after expiry now returns 200 on SQLite and PostgreSQL. Seeded replay does not prove an actual committed PostgreSQL acceptance. |
| Atomicity | SQLite injected status-write failure rolls back membership and leaves pending invitation. PostgreSQL timestamp failure also leaves zero membership and pending state; failure occurs before status write. Successful PostgreSQL commit, halfway-write rollback, revocation/expiry races and lost-response concurrency remain blocked by that earlier failure. |
| Both invitation issuers | passed in direct SQLite component checks: existing recipient remains pending without new membership through scoped and alternate issuers. This supersedes the old scoped-autoaccept finding. Delivery/resend and alternate issuer permission policy remain B07 prerequisites, not passed acceptance evidence. |
| Migration/schema | passed for the bounded real PostgreSQL upgrade: old user retained, flags initialized false, nullable accepted-by FK added, raw SQL omitted-flag insert receives defaults. **Application Core inserts still bind NULL**, so migration success does not resolve login/new-user compatibility. |

## Assigned criterion outcomes

No complete journey criterion passed. A passed backend component does not complete its frontend/product criterion.

| Criterion | Backend assessment | Whole criterion / remaining evidence |
|---|---|---|
| B08-AC01 | **blocked** overall; signed-out guard, read-only matching preview and pending-only issuer components passed | **Incomplete.** No delivered B07 link or real verified-login/resume observation. Portuguese entry, registration/login interruption/cancel/switch/refresh and return to the same invitation require the remaining FE/product journey. Previous FE parser/login failures were not rerun here. |
| B08-AC02 | **failed** | Guards pass for synthetic verified/unverified identities, but normal user inserts fail and existing phone/Google/Apple login fixtures never establish verified flags. A malformed persisted invitation with both contacts NULL accepts an unrelated account on SQLite. Real verification/switch-account guidance and FE handling remain incomplete. |
| B08-AC03 | **failed** | PostgreSQL explicit accept raises timezone `DataError` before membership/status commit. SQLite concurrent calls produce 200/500; no user/bar unique constraint exists. Sequential SQLite acceptance, rollback and seeded current-access replay pass. Successful PostgreSQL concurrency, one-membership guarantee, restore, stale-read reconciliation and late revocation/expiry race checks remain blocked. |
| B08-AC04 | **failed**; workspace journey incomplete | SQLite JSON/query compatibility and BarAccess + GET `/me/bars` readback pass. All three valid input forms return 500 on PostgreSQL. FE decode/refresh, stable venue selection, permitted workspace entry and direct permission-denial observations remain incomplete. |
| B08-AC05 | **failed**; retry journey incomplete | Distinct invalid/expired/revoked/used-other categories and late accepted replay pass. Invalid persisted role still produces 500; concurrent retry is not reliably idempotent. Network context preservation and a committed PostgreSQL lost-response retry remain incomplete. |
| B08-AC06 | **skipped** in this backend-only assignment | **Incomplete/blocked for product completion.** Prompt/source/tasks/checklist are present; source handoff still requires translated-revision confirmation and product approval. Responsive light/dark, keyboard/screen reader/text scale/browser checks were deliberately not run. |

## Actionable follow-ups

| Priority / owner | Reproduction, required change and next verification | Criteria |
|---|---|---|
| P0 BE/auth — omitted flags | Existing login/fixture `User.__table__.insert().values(...)` omits flags. `insert-compilation.json` shows databases compiles both flag parameters as NULL even with server defaults; SQLite and PostgreSQL reject them. Fix application initialization/default execution without treating a supplied email/phone as verified. Rerun the 35 staff/auth cases and omitted-flag insert on PostgreSQL, including an upgraded database. The new migration itself is present and passed the bounded upgrade. | AC01–AC04 |
| P0 BE — PostgreSQL timestamps | Direct verified-fixture accept reaches `staff.py:465` → `rbac_middleware.py:496`, then asyncpg rejects aware `accepted_at` against `timestamp without time zone`. JSON/query/both return 500, zero memberships, pending invitation. Align timestamp storage/binding compatibly across issuance, membership insert/update and invitation update; then rerun actual commit/readback and halfway-write rollback on PostgreSQL. This is an observed current blocker; its historical origin was not baseline-tested. | AC03–AC05 |
| P0 BE/auth — acquire verified identity | Existing phone fixture with provider-confirmed number leaves `phone_verified=False`; Google and Apple verified-claim fixtures leave `email_verified=False`. Source has no trusted setter and token adapters discard verification claims. Implement trusted verification persistence for new/existing/linking paths and contact-change invalidation, with negative untrusted/request-field tests. Then demonstrate real sandbox/test-account login → invitation acceptance; mocked provider claims alone are insufficient. | AC01–AC03 |
| P1 BE — atomic concurrent retry | Current concurrent SQLite component returns `[200, 500]`; PostgreSQL cannot yet reach the race due to timestamp failure. Membership helper uses select-then-insert with no user/bar uniqueness, and invitation compare-and-set loss is not reconciled to same-user current access. Audit existing duplicates before compatible uniqueness enforcement and reconcile concurrent same-recipient acceptance. Rerun on PostgreSQL with controlled interleavings, removed access, expiry/revocation, lost responses and rollback; do not classify the present PostgreSQL 500/500 as proof of race handling. | AC03–AC05 |
| P1 BE — reject malformed contact/role | Seed both contacts NULL: unrelated authenticated user receives 200/BarAccess and a membership on SQLite because both matching/verification guards are vacuously true. Reject missing/invalid recipient data fail-closed, including historical rows; don't revoke historical memberships blindly. Seed invalid persisted role: preview/accept returns 500 instead of safe canonical error. Validate permitted roles/status before write and add safe error checks. | AC02, AC03, AC05 |
| B07 / BE + delivery | Both pending-only issuer checks now pass. Still prove staff:manage authorization for both routes and genuinely delivered/resendable email/phone links with no preaccept membership. Alternate issuer remains role-based in source; actual delivery was not demonstrated. | AC01–AC05 prerequisite |
| FE / product / verifier | Retest previous opaque-token/canonical-link parsing and LoginPage mounting/resume findings; consume list-valued contact metadata and implement a real verification action. Confirm translated React revision/product approval and validate registration/login/switch/refresh, all distinct errors, retry, `/me/bars`, stable venue/permission entry and accessible responsive light/dark browser states. Configure the spec-specific product E2E runner. | AC01–AC06 |

**Blocked:** real provider-verified identity journey, delivered B07 links, successful PostgreSQL acceptance/commit/race/late-retry evidence behind current defects, configured product E2E, final product approval and journey observations. **Skipped deliberately:** FE test reruns, browser/device/assistive-technology checks, unrelated/payment suites and baseline investigation, full historical migration-chain/deployed-data audit, live providers and deployment. No blocked/skipped check counts as passed.

## Prior FE evidence retained, not rerun

The preceding verifier recorded 14 passing cubit tests, two passing datasource error probes, two failing opaque-code/canonical-link parsing probes, two passing login BLoC tests and one failing default-login widget mount. Analysis reported two info hints. Those logs remain in `.agent-workflow/verification/B08/`; they are historical observations, not passed/failed executions in this backend pass. Existing source still shows email-hardcoded verification guidance and `ModalRoute.of(context)` in `initState`; FE must supply current integration evidence.

The author handoff and FE/BE notes still contain superseded backend statements about `StaffInvitation.c`, accepted-preview `.get`, missing migration, phone metadata, used-other errors, expired accepted replay and scoped autoaccept. This checklist records their observed replacements without rewriting the author's handoff or publishing a new contract. Product code, index/history, existing `.coverage`/debug DB, issues and deployment were not modified by verification.
