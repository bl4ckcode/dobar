---
owner: cross-repo-planner
spec: B02
artifact: implementation-plan
status: implemented-pending-product-verification
---

# B02 implementation after Lovable export

Executed against the user-supplied React export at `5975413ccabd6f714af491370892a09c7e651a24`; see the [source handoff](react-source-handoff.md) and [validation record](validation-record.md). Interfaces below are implemented in the working tree, with no deployment claimed. [B02](../B02-venue-onboarding.md) retains stable acceptance IDs and unverified status. Existing [FE/BE](../../../docs/FE_BE_COMMUNICATION.md) and [BE/DPE](../../../docs/BE_DPE_COMMUNICATION.md) contracts remain unchanged until implementation.

## Source findings, inspected 2026-11-01

| Finding | Observed source / intended behavior | Owner / next check |
|---|---|---|
| No durable draft checkpoint | [CreateBarPage](../../../fe/lib/features/bars/presentation/pages/create_bar/create_bar_page.dart) holds mutable values/current step in memory and offers discard on exit. B02-AC02 requires owner-backed reopen/resume. | FE/BE: save, terminate browser, authenticate and restore |
| Optional contact and bank conflict | [basic step](../../../fe/lib/features/bars/presentation/pages/create_bar/steps/basic_info_step.dart) requires phone/email; [bank step](../../../fe/lib/features/bars/presentation/pages/create_bar/steps/bank_account_step.dart) blocks missing bank information and business ID. [BarCreate](../../../be/app/bars_and_restaurants/schemas/bars.py) requires phone/email. B02-AC01/MVP-B02-01 describe optional contact/bank setup. | Product/BE: resolve consumer compatibility before no-contact finalization |
| Photos are not uploads | [photos step](../../../fe/lib/features/bars/presentation/pages/create_bar/steps/photos_step.dart) displays “Image picker coming soon”; the page passes path strings as URLs. B02-AC01/03 need durable media and retry. | FE/BE: authenticated draft upload/reopen test |
| Retry is not durable idempotency | [wizard](../../../be/app/bars_and_restaurants/routes/bars.py) creates owner, venue, Mongo projection, BarStaff and bank sequentially; address/business duplicate checks cannot reconcile a lost success response or partial failure. B02-AC03 needs one venue after retry. | BE: lost response, concurrent finalize and projection-failure tests |
| Access refresh differs by entry | CreateBarPage initializes SessionBloc only for `fromOnboarding`; other entry returns `true`. B02-AC04 requires refreshed access after successful creation from either entry. | FE: both entry paths with refresh failure |
| Theme mixing and mobile focus | CreateBarPage/progress and step widgets use fixed surfaces; shared workflow-level outside-tap dismissal is absent. Screenshot shows white input text on cream. | FE: contrast and mobile keyboard checks throughout B02 |
| Bank saving is not verification | [bank routes](../../../be/app/bars_and_restaurants/routes/bank_accounts.py) enforce owner checks and return masked values; [wizard](../../../be/app/bars_and_restaurants/routes/bars.py) encrypts account/Pix values. This does not establish provider verification. | BE: reuse encrypted storage patterns, inspect key configuration, exclude secrets from draft responses/logging |
| AI entry needs authorized venue identity | [menu extraction](../../../be/app/bars_and_restaurants/routes/menus.py) includes `/extract` and `/extract-url`; JSON URL extraction checks bar existence, which alone is not ownership authorization. | FE/BE: bind entry to finalized bar and verify permissions in every extraction branch before reuse |

These are source observations, not reproduced runtime failures. Do not interpret existing `verification_status=pending` as draft state: it describes venue verification and must retain its meaning.

## Decisions and contract proposal

- Preserve six steps and add optional menu-import intent from review, executed only after finalization and access refresh. AI extraction/review/publication remains in [B03](../B03-ai-menu-import.md); B02 owns the entry and return path, not an import redesign.
- Store drafts in a separate PostgreSQL entity, never incomplete `bars` rows. Multiple owner-scoped drafts are allowed; provide a list to choose/resume. Save accepts partial/invalid text without finalization. A draft grants no BarAccess and never appears in public discovery or business venue lists.
- Required finalization identity: nonblank venue name, address, confirmed valid coordinates and supported country. Contact, bank details, photos and hours are optional, with supplied data validated or explicitly removed. Do not insert fabricated email/phone or 0,0 coordinates. Owner profile contact does not silently become public venue contact.
- **Compatibility decision (implemented):** database contact stays null when omitted. Additive draft `GET /{id}/venue` returns `schema_version: 1` and nullable contact. Legacy Bar read responses project absent contact to empty strings (not verified or fabricated contact); the existing wizard still requires valid contact. Flutter BarModel already normalizes absent values to empty strings; BusinessDetailsForm handles empty text; BE business-settings contact fields are already optional. Bar list/detail response schemas now accept the empty-string email sentinel. Tests exercise no-contact finalization and legacy serialization. This closes the original optional-contact rollout gate without changing legacy creation requests.

- Step keys: `find`, `details`, `receiving`, `photos`, `hours`, `review`. Store per-step unvisited/in-progress/complete/skipped and server-computed `next_step`. Resume earliest required invalid step, then earliest optional unvisited/in-progress step, else review. Explicit skip resolves an optional step; saving partial edits does not complete it. Store menu-import intent, not premature extraction results.
- Save synthetic mocks only in Lovable. Production uses authenticated server persistence; browser memory may hold unsaved edits, but no raw bank/Pix values or credentials go into localStorage, analytics or logs. Draft bank payload is encrypted at rest, excluded from general draft JSON, and read as a masked summary only. Resume restores a “saved account” marker; replacement requires explicit input. Partial bank values may be saved securely and must be completed/replaced/cleared before finalization.

Implemented additive API (draft router is registered before `/{bar_id}` routes):

| Interface | Semantics |
|---|---|
| `POST /bars/onboarding-drafts` | Authenticated owner from session, client creation key scoped to owner; idempotent retry returns same draft. No caller-controlled owner ID. |
| `GET /bars/onboarding-drafts` / `GET /bars/onboarding-drafts/{draft_id}` | Owner-only list/read; version, saved timestamp, partial public payload, step states, next step, masked bank summary, asset records, finalization status and nullable final bar ID. Cross-owner identifiers return non-disclosing 404. |
| `PATCH /bars/onboarding-drafts/{draft_id}` | Expected `version`, partial fields and step intent; explicit null removes a field, omitted leaves unchanged. Accept incomplete data within length/type limits; reject stale versions with canonical 409. Return new version/acknowledged values and next step. Dedicated write-only bank section accepts replace/clear; response never echoes raw values. |
| `POST /bars/onboarding-drafts/{draft_id}/assets` | Multipart file + client asset key; owner-scoped repeat-safe upload. Validate content/size/type using explicit configured limits; return durable asset ID/status. Preview uses renewable signed URL, not the persistent identity. |
| `DELETE /bars/onboarding-drafts/{draft_id}/assets/{asset_id}` | Owner-authorized unlink, safe repeat; background cleanup must not remove another draft/venue’s referenced media. |
| `POST /bars/onboarding-drafts/{draft_id}/finalize` | Expected version and operation key; strict server validation. Lock/uniquely claim draft, create at most one venue/membership/bank link and persist `bar_id` atomically in PostgreSQL. Replay returns same result. Reject mutation of finalized payload. |

Responses follow the [canonical error envelope](../../../fe/.docs/API_ERROR_CONTRACT.md): 401 session expiry, non-disclosing 404 for inaccessible drafts, 409 stale version/finalization conflict, 422 field errors, retryable transport/server failures. Keep IDs opaque in FE; preserve existing numeric venue IDs. Use one draft creation key and one finalize key across retries, scoped to authenticated owner and operation, with request-payload fingerprints to reject incompatible reuse. Upload retries reuse asset keys, not venue creation calls.

PostgreSQL is authoritative. Use an outbox in the same finalization transaction for Mongo/media projection and retry asynchronously by bar ID. After PG commit return confirmed creation with explicit projection status; a projection delay does not create a second venue or mislabel the draft as unsaved. A lost response is reconciled by draft GET, whose final `bar_id` is durable. Existing public visibility rules must hide unavailable projections until ready; finalize replay must repair/retry projection work without reinserting venue/membership. No provider calls or bank verification inside this transaction.

## Ordered implementation assignments

Execution: tasks 1–7 are implemented in the working tree. Task 8 has author-run deterministic evidence; independent product/browser acceptance is outstanding. The table retains the implementation ownership and required checks for review.

| Order / owner / skill | Work and dependency | Required evidence |
|---|---|---|
| 1 — Product + cross-repo planner (`dobar-spec`, `dobar-cross-repo-plan`) | Review exported state matrix; close contact compatibility gate; specify asset limits and draft retention/cleanup policy before implementation. Preserve B02 IDs; record interface choices in implementing handoff. | Approved source SHA, consumer inventory and compatibility decision; no invented source export |
| 2 — Backend (`dobar-backend`) | Add draft, asset and operation/outbox migrations/models with indexes on owner and unique operation keys. Reuse session auth and inspect actual role/owner resolution; add partial save/read/list and encrypted bank storage/masking. No active venue during save. | Migration upgrade/rollback on test Postgres; same-owner reopen; other owner/staff denied across list/read/write/upload/finalize; no raw sensitive fields in responses/logs |
| 3 — Backend (`dobar-backend`) | Add draft uploads, stable asset IDs, signed previews, limits and cleanup. Implement locked finalization plus membership/bank association and outbox; reuse validated creation logic without inheriting sequential partial writes. Depends on 2; honor optional contact gate. | Concurrent/lost-response finalize creates one venue, one membership and bank link; failed upload retries same asset; S3/Mongo failure and outbox replay preserve identity; invalid fields do not finalize |
| 4 — Frontend UI (`dobar-react-to-flutter`, `dobar-frontend`) | Translate approved React revision into existing feature layers; shared semantic themes/top-right toggle across B02, adaptive stepper/footer, ARB copy, accessibility and outside-tap unfocus for touch. Can proceed alongside 2–3 using repository fakes. | Both themes for every step/state; 320px mobile and desktop; 200% text, focus and reduced motion; unchanged values on theme/back/next |
| 5 — Frontend integration (`dobar-frontend`) | Repository/Dio + BLoC/Cubit draft lifecycle and DI; revision-aware debounce, explicit save/exit and dirty state; owner-bound login resume; masked bank edit model; durable media states. Wire finalize, unknown-result reconciliation and SessionBloc refresh for both entry modes; navigate to exact returned authorized bar. Depends on 2–4. | Save/reopen restores partial values and correct step; late save responses never clear newer dirty edits; 401/conflict/offline remain recoverable; refresh retry never re-finalizes |
| 6 — FE/BE menu handoff (`dobar-frontend`, `dobar-backend`) | Persist import intent and route to existing AI reader for confirmed bar after access refresh. Audit/fix permission checks in file/URL extraction paths before enabling the entry. Keep import save/publish validation under B03. | Optional skip works; selected intent survives reopen/finalize; unauthorized bar IDs denied; import failure leaves venue accessible |
| 7 — Integration documentation (`dobar-communication-docs`) | With actual interfaces implemented, replace respective sender entries in canonical FE/BE rolling notes; preserve other sender and 80-line limit. DPE work is unnecessary unless real provider verification is separately scoped. | Source-linked current interfaces and migration/rollout notes; no prospective endpoint presented as deployed |
| 8 — Independent validation (`dobar-validation`) | Verify all four B02 criteria against implemented revision and real browser backend; keep deterministic and provider/device evidence separate. | Criterion evidence matrix below; report passed/failed/blocked/skipped individually |

Source implementation and temporary-database migration checks are complete. No production migration, external ticket write or deployment was executed. Deploy through existing GitHub Actions only.


## Implemented operating policies

- Assets accept content signatures for PNG/JPEG/WebP up to 10MB, with one logo, one cover and six gallery items. No paid service is invoked during validation. Object identity is a deterministic draft/operation key; reserve the asset row before uploading so failed/unknown uploads remain reconcilable. Unfinished assets block finalization. Removed assets are queued for idempotent deletion, with no removal of finalized venue references.
- Retain draft metadata and encrypted partial bank data until a future explicit owner-discard/retention feature is approved; do not silently expire saved progress. No automatic purge or retention-duration claim is made. Finalization clears the draft's raw encrypted bank copy after transferring the configured account to the existing encrypted account table; the masked summary remains. Removed asset tombstones remain for operation replay safety.
- A lifespan worker polls the durable PostgreSQL projection/removed-asset queues every 30 seconds. PostgreSQL row locks serialize workers; Mongo upsert uses stable bar identity. A projection delay affects discovery readiness but not creation identity or owner access. Real S3/Mongo availability remains an integration check.
- Production bank draft saving fails closed unless `BANK_ACCOUNT_ENCRYPTION_KEY` is configured; it does not use the legacy helper's temporary-key fallback. Preserve that stable key across deployments/restarts.
- Contact consumer inventory: `BarCreate` remains strict; BarBase/Bar list/detail responses have the legacy absence projection; business-settings response fields are optional; FE BarModel and business details already handle absent/empty contact. New draft payload and versioned created-venue contact retain null semantics. Existing country/payment/verification contracts are unchanged.

## Compatibility and rollout

Add tables/routes without changing `POST /bars/wizard` request/response shapes or existing stored bars. No inferred backfill of drafts from active venues. Apply additive migration through CI/CD, deploy BE capability first, then enable new FE draft flow after contract tests and contact-read compatibility are ready. Existing callers retain the old wizard. Share safe finalization internals where possible without silently changing old contracts. FE rollback leaves saved drafts intact for a later resume; do not drop draft tables or encrypted bank data during a code rollback. Retention and abandoned-asset cleanup must distinguish active drafts, finalized references and expired sessions. No DPE payload, charges, entitlements or bank verification changes are planned.

## Verification assignments

From root run the repository’s foundation commands using the existing workflow virtual environment (install its requirements when needed):

```sh
.agent-workflow/venv/bin/python -m pip install -r tools/agent_workflow/requirements.txt
.agent-workflow/venv/bin/python -m tools.agent_workflow validate
.agent-workflow/venv/bin/python -m unittest discover -s tools/agent_workflow/tests -v
```

Backend owner: in the BE virtual environment run `pytest tests/test_bars.py` plus new focused draft/finalization/upload authorization suites, then relevant auth/session/menu tests. New tests must use real PostgreSQL for locks/uniqueness/concurrency; mocks establish error handling only. Test bank masking/encryption, expired upload previews, stale-version saves, incomplete optional data and outbox retries. Record exact test paths once implemented; actual test results are in the validation record.

Frontend owner: from `fe`, run `flutter analyze` and the affected wizard repository/BLoC/widget/navigation tests. Generate Freezed/DI files only if annotated inputs change, and run localization generation for changed ARBs. Widget tests cover save races, one-operation retry, optional skips, restored step, theme contrast roles, semantics, validation focus and access-refresh failure. Actual keyboard dismissal needs browser/device interaction; widget unfocus assertions alone do not prove it.

| Criterion | Product acceptance evidence after implementation |
|---|---|
| B02-AC01 | Authenticated owner navigates all six steps, configures or skips contact/bank/photos, selects AI import and enters it after authorized creation; no payment/verification claim |
| B02-AC02 | Save mid-details/contact and later optional step, close browser, reopen/sign in as same owner, restore acknowledged fields/assets/masked bank marker and next incomplete step; skipped steps stay skipped |
| B02-AC03 | Fail save/upload, retry, drop finalize response, double-click/concurrently finalize; query DB to prove exactly one venue/membership and stable result. Validate required fields and prevent incomplete bank/media from silently finalizing |
| B02-AC04 | Other-owner/staff attempts cannot read/write/finalize draft or retrieve bank values; both navigation entry modes refresh access and enter exact returned bar; refresh failure retries only refresh |
| UX refinement | All steps and error/success states in light/dark; mobile Safari and Chrome touch outside editable fields dismisses keyboard without eating button taps; footer/input stay visible; keyboard-only, screen reader, zoom and reduced-motion review |

Record commit SHA/content fingerprint, environment, account roles, commands, screenshots and artifacts. B02’s configured `product-e2e` check remains blocked until a real runner is registered; a foundation pass cannot validate the journey. No provider sandbox run is needed to prove draft saving; bank-provider verification is outside this scope and must not be reported passed.
