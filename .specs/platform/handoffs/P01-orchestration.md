# P01 planning and handoff package

Prepared 2026-10-25 using the [product role](../../../.agents/roles/product.md) and [orchestration skill](../../../.agents/skills/dobar-orchestrate/SKILL.md). Canonical acceptance remains in [P01](../P01-development-pr-workflow.md); this is an assignment package, not a new spec or implementation claim.

## Scope and inspection baseline

- Source revision: `8844c69763b2c9bea9a6304c2dcb60ba8b70240e`. The pre-existing modified [editor configuration](../../../.vscode/launch.json) is unrelated and must remain untouched, including its index state.
- At final review, concurrent edits renamed only the display names in [BE deployment](../../../.github/workflows/deploy-be.yml), [DPE deployment](../../../.github/workflows/deploy-dpe.yml) and [FE deployment](../../../.github/workflows/deploy-fe.yml). Those edits were not made by this planning session and were preserved; inspected triggers, targets and jobs were unchanged.
- This session prepares local planning artifacts only. No models/agents, external tickets, task branches, commits, PRs, settings changes or deployments are launched. Future assignments below describe work requiring a separate implementation or rollout instruction.
- P01 remains `delivery_status: ready`, `verification_status: unverified`. No acceptance criterion has been demonstrated end to end. Live GitHub permissions/rules, Linear configuration, Fly resources and secret provenance were not inspected.
- Read root, FE, BE, DPE and docs instructions, each runtime area's architecture/workflow guidance, DPE integration guidance, [context authority](../../../docs/AGENT_CONTEXT.md), [workflow](../../../docs/AGENT_WORKFLOW.md), [how-to](../../../docs/AGENT_WORKFLOW_HOWTO.md), and both canonical communication documents.
- The source MVP defines product journeys; the independent platform catalog defines P01. P01 must not silently absorb C09/S02 payment-product repairs or rewrite their acceptance.

## Acceptance gaps grounded in source

All rows are source observations, not runtime failures or verified deployed behavior. Task IDs below are local planning IDs, not Linear identifiers.

| Criterion | Observed implementation and remaining gap | Assigned work |
|---|---|---|
| P01-AC01 | [FE API endpoints](../../../fe/lib/core/api/api_endpoints.dart) hardcode production. A second [API constant](../../../fe/lib/core/network/api_config.dart), consumed by the [partners datasource](../../../fe/lib/features/partners/data/data_sources/partners_network_datasource.dart), and the [Apple callback](../../../fe/lib/features/authentication/presentation/widgets/login_buttons_widget.dart) also hardcode production. [BE startup](../../../be/app/main.py) and [database setup](../../../be/app/database.py) infer production from Fly runtime presence; startup tolerates Mongo/Redis failures and `/health` alone cannot prove readiness. [BE DPE client](../../../be/app/payment/dpe_client.py) defaults to localhost and `dev-secret`; [DPE forwarding](../../../dpe/dobar_payment/api/routes.py) defaults to localhost. [DPE app](../../../dpe/dobar_payment/api/app.py) loads credentials without a `DPE_ENV` gate, permits wildcard CORS and catches gateway startup failures. No complete dev isolation validation was found. | T00, T02–T04, T08–T10 |
| P01-AC02 | [BE](../../../.github/workflows/deploy-be.yml), [DPE](../../../.github/workflows/deploy-dpe.yml), and [FE](../../../.github/workflows/deploy-fe.yml) deployments trigger on path-filtered main pushes and use production Fly configs. BE migrates after deploying; [migration workflow](../../../.github/workflows/run-migrations.yml) hardcodes the production app. No shared develop deployment or coordinated release/rollback gate was found. | T05, T08–T12 |
| P01-AC03 | [CLI parser](../../../tools/agent_workflow/__main__.py) supports validate/tickets/handoff/verify only. No start command, prompt adapter, ownership record or isolated worktree lifecycle exists there. | T01, T06, T09–T10 |
| P01-AC04 | Conventions exist in [workflow guidance](../../../docs/AGENT_WORKFLOW.md); CLI has no branch/commit/PR enforcement or PR transport. | T06–T07, T09–T10 |
| P01-AC05 | No finish command or exact-head readiness transition exists. [Verification](../../../tools/agent_workflow/verification.py) provides checkout fingerprints and explicit incomplete outcomes, useful primitives but not publication authorization. | T05, T07, T09–T10 |
| P01-AC06 | [Linear sync](../../../tools/agent_workflow/linear.py) already uses deterministic IDs, ownership markers, locks and uncertain-create reconciliation. Its tests cover issue synchronization, not Git/worktree/PR crash recovery. Extend those invariants across the whole lifecycle. | T01, T06–T07, T09–T10 |
| P01-AC07 | [Foundation CI](../../../.github/workflows/agent-foundation.yml) runs on PRs and validates both catalogs. [FE tests](../../../.github/workflows/fe-unit-tests.yml) run on path-filtered PRs; [BE](../../../.github/workflows/be-unit-tests.yml) and [DPE](../../../.github/workflows/dpe-unit-tests.yml) tests are callable only and share `Run Tests` naming. No `quality-gate` aggregate or main source-branch gate was found. [Payment contracts](../../../.github/workflows/payment-contract-validation.yml) already install local sibling DPE and report actual outcomes; retain this. Remote protections are unknown. | T05, T09–T12 |
| P01-AC08 | [Ticket generation](../../../tools/agent_workflow/tickets.py) adds Feature, all area labels and platform to the P01 parent, but children receive only their area label. [Linear client](../../../tools/agent_workflow/linear.py) has no cycle lookup/read/write policy or fix/docs kind mapping. Existing explicit cycles and human fields must survive. | T01, T09–T10 |
| P01-AC09 | Owner gating and future review separation are documented intent. Live plan capability, release rules, approval requirements and absence of self-review deadlock are unverified. | T00, T08, T10–T12 |
| P01-AC10 | [Check registry](../../../tools/agent_workflow/checks.json) has `workflow-e2e.command: null`. Existing handoffs include the whole spec but no executable lifecycle/dev acceptance runner or P01-specific recovery runbook. | T00, T08–T12 |

Additional boundaries to carry into planning:

- [API-key middleware](../../../be/app/auth/api_key_middleware.py) bypasses that check when `TESTING=true` or no API keys exist. This does not prove JWT/RBAC is bypassed; verify those layers separately. Hosted dev must not adopt test bypasses or weak default secrets.
- [DPE integration guidance](../../../dpe/docs/agents/integration_guide.md) describes sandbox detection by key prefix. The active [Stone adapter](../../../dpe/dobar_payment/gateways/stone.py) has a separate `PAGARME_SANDBOX` check, while the [app loader](../../../dpe/dobar_payment/api/app.py) constructs the gateway directly. Planner/payments must trace the active path and specify fail-closed behavior; do not infer sandbox safety from docs or a dormant helper.
- Existing [FE/BE](../../../docs/FE_BE_COMMUNICATION.md) B08 findings include a migration revision exceeding the default Alembic version-column width. T08 must preflight the entire migration chain against a fresh disposable PostgreSQL database. A pre-existing migration failure blocks dev rollout and should become bounded follow-up work, not be hidden by the new pipeline.
- [BE/DPE findings](../../../docs/BE_DPE_COMMUNICATION.md) distinguish mocked/standalone Pix output from provider confirmation. Signed sandbox confirmation plus client/cashier consistency may expose C09/S02 prerequisites; record the specific blocker and hand it back to those specs.
- Generated P01 tickets currently comprise one parent and generic FE/BE/DPE children. They do not express tooling, CI, migration, protection or rollout ownership/dependencies. Do not publish that export as though it were this task plan.

## Planning decisions and prerequisites

T00 must close design questions before dependent implementation, while reporting external facts that remain unavailable. These are preparation requirements, not requests to execute external changes now.

| Decision / fact | Proposed direction and required evidence | Owner / blocks |
|---|---|---|
| Shared-file ownership | Use the backend role for explicitly scoped Python tooling and CI assignments, with planner coordination and FE/payments review. There is no platform implementation role today. Confirm the expanded allowed paths in each future assignment; do not pretend the default backend role already owns every platform file. | Product/planner; T01, T05–T08 |
| Environment matrix | Record actual app IDs, database/replica/schema identity, Redis, Mongo database, storage, auth project/client IDs, origins, redirects, webhook endpoints, provider account/mode, and secret reference names for each environment. Proposed dev app names in P01 remain unreserved. Values containing credentials never enter documents/logs. | Planner + runtime owners; T02–T04 design, T08/T10 activation |
| Isolation proof | Exact allowlisted dev resource identities and environment-scoped credentials/permissions; deny production endpoints and fail before build/deploy when required dev values are absent. Opaque secret mode cannot be established by string prefix alone: record provider/account provenance without recording secrets. Disable unsupported dev integrations explicitly; no silent provider fallback. | Planner/payments/backend; AC01 |
| Local versus hosted dev | Explicit `ENVIRONMENT`/`DPE_ENV` behavior must distinguish local tests from a publicly hosted development environment. Keep production defaults compatible during transition; explicitly stamp production jobs before removing Fly-based inference. Reject test auth bypasses for hosted dev. | Planner; T02–T04, T08 |
| Linear policy | Verify authorized team, platform/area/type labels, current-cycle semantics and review state by read-only lookup in a later assignment. Distinguish fix/feat/docs naming from Bug/Feature/Improvement classification; a docs task is not inherently a minor adjustment. Missing current cycle is an explicit unmet scheduling prerequisite, never success. Define whether that leaves an issue-only blocked task; no Git mutation until resolution is unambiguous. | Product/planner; T01 |
| Permissions and protections | Later read-only discovery must establish GitHub plan, visibility, Actions/environment privileges, rule/bypass capabilities and available reviewer setup. Optional production environment approval may fall back to owner release-merge gating as P01 allows; missing required main enforcement remains blocked. No self-review approval requirement for a solo maintainer. | Owner/planner; T10–T11 |
| Tested revision | A PR head, GitHub synthetic merge ref, resulting develop SHA and released main SHA may differ. Define and record each; gate the actual deploy revision (rerun required checks on merge SHA or prove tested artifact identity) and bind finish readiness to the current PR head. | Planner/CI; T05, T07–T08 |
| Bootstrap | Existing no-automatic-publication rules still apply while the lifecycle is implemented. Owner-managed publication/merges bootstrap develop and Actions. Do not use the unimplemented lifecycle to authorize its own publication. | Product/owner; T08–T10 |
| Windows checkout prerequisite | This checkout materializes the tracked Claude/Cline discovery symlinks as regular files (`core.symlinks=false`), causing 26 validation findings. Plan a supported checkout/setup correction and revalidate before claiming F passes; do not weaken validation or rewrite links as part of this planning task. Canonical skills can still be read directly for T00. | Planner / development-environment owner; generated handoffs and T09 |

Unresolved live IDs, permissions and credentials block activation and live verification, not offline design or fake-transport tests. No additional product scope decision is needed to prepare this package.

## Dependency-ordered assignments

Each row inherits P01, root/affected-area instructions, the two canonical communication contracts, and the evidence rules below. “Allowed” means proposed ownership for a future explicit assignment, not current write authorization. All tasks are **prepared / not started**. T00 is the next handoff.

| ID / phase | Role and skills | Dependencies | Allowed area and required output | Criteria / validation package |
|---|---|---|---|---|
| T00 — planning contract | cross-repo-planner; dobar-cross-repo-plan | This source audit | Planning documents only. Return environment/interface matrix, secret provenance strategy, lifecycle state transitions, CI revision policy, ownership and rollout sequence. Resolve the table above or name a concrete blocker. | AC01–AC10; F and source review |
| T01 — issue resolution and scheduling | backend with explicit tooling assignment; dobar-linear, dobar-cross-repo-plan | T00 | [Workflow tooling](../../../tools/agent_workflow/) issue/config modules and fake transports/tests. Resolve exactly one issue before Git writes; reuse catalog-aware stable identity and uncertain-write reconciliation. Apply area/platform/type labels on creation; preserve existing human fields/cycles. Return an issue record and explicit scheduling status. | AC03, AC06, AC08; L |
| T02 — backend environment and migration contract | backend; dobar-backend, dobar-communication-docs | T00 | [BE](../../../be/) runtime/config/migration validation and tests; backend sender entries only when boundaries change. Validate datastore, DPE, auth, storage, origins and messaging settings before hosted startup. Define readiness distinct from process liveness and a guarded additive migration contract. No actual data migration. | AC01–AC02; B |
| T03 — payment environment contract | payments; dobar-payments, dobar-communication-docs | T00 | [DPE](../../../dpe/) configuration/startup/forwarding and tests; latest DPE sender entry. Require hosted-dev service auth, exact BE callback, sandbox provider credentials and signed webhooks; reject incomplete/mixed environment configuration. Preserve integer cents, idempotency and provider event semantics. Do not edit vendored SDK. | AC01–AC02; D |
| T04 — frontend environment routing | frontend; dobar-frontend, dobar-communication-docs | T00 | [FE](../../../fe/) endpoint/build configuration and focused tests; frontend sender entry. Wire build-time `API_BASE_URL` through both API clients, sockets/refresh, partners and auth callbacks. Preserve the production default only for production; dev builds must supply validated configuration. Return exact build inputs to T08. | AC01–AC02; E |
| T05 — PR quality and release-source gate | backend with explicit CI assignment; dobar-cross-repo-plan, dobar-validation | T00 | [.github/workflows](../../../.github/workflows/) test/foundation/aggregate workflows plus selection/aggregation tests. Always report one uniquely named `quality-gate` for PRs to develop/main; select all affected areas and shared contracts, foundation for docs, and reject same-named develop branches from foreign repositories for main releases. Runtime jobs consume the same checkout. | AC02, AC05, AC07, AC09; G |
| T06 — isolated task start | backend with explicit tooling assignment; dobar-cross-repo-plan, dobar-commit | T01 | [Workflow CLI](../../../tools/agent_workflow/) start/state/Git adapter/tests; ignored runtime state only. Resolve issue, fetch origin/develop, record base SHA and create/reuse isolated worktree without touching the original checkout/index. Prompt and spec adapters use the same entrypoint. Validate ownership/path boundaries, task kind and branch collisions; make each external step recoverable. | AC03–AC04, AC06; L |
| T07 — task finish and opt-in policy | backend with explicit tooling assignment; dobar-commit, dobar-linear | T05, T06 | [Workflow CLI](../../../tools/agent_workflow/) finish/GitHub adapter/tests, narrowly scoped root/area safeguards and [workflow guidance](../../../docs/AGENT_WORKFLOW.md). Recheck ownership/base/content; run allowlisted checks; publish only reviewed owned diff; reconcile commit/push/PR retries; target one draft PR to develop; ready only after current-head required CI. Document exact lifecycle-only authorization and keep ordinary sessions protected. | AC04–AC06, AC08–AC09; L + G |
| T08 — Actions delivery and runbook implementation | backend with explicit CI assignment; planner coordinates FE/payments review; dobar-cross-repo-plan, dobar-commit, dobar-communication-docs | T02, T03, T04, T05 | Deployment/migration workflows, each area's Fly config/build wiring, checks and P01 runbook. Prepare development/production environment separation and explicit revision binding. Preflight target, run additive migrations before dependent traffic, deploy compatible DPE then BE then FE, health/smoke gate each stage, stop failure, retain previous app releases. Include owner release gate and future review extension. No activation under this task. | AC01–AC02, AC09–AC10; R |
| T09 — independent deterministic verification | verifier; dobar-validation | T01–T08 | Verification reports and bounded defect handoffs only. Exercise temp-repository lifecycle, fake transports, config negatives and CI aggregation; validate the runbook against implementation. Ensure workflow-e2e cannot treat mocks as live deployment/protection evidence. | AC01–AC10 deterministic portions; F + L + B + D + E + G + R |
| T10 — authorized dev bootstrap and pilot | Owner executes/authorizes Actions; backend coordinates FE/payments; verifier observes | T09 accepted, actual dev resource/secret prerequisites recorded | Later explicit rollout scope only. Provision via approved GitHub Actions, use synthetic fixtures, validate isolated dev, owner-merge a disposable task PR, tie checks/deployment/smoke to SHA, exercise signed sandbox confirmation and client/cashier agreement. Record partial failure/recovery with prior compatible releases. | AC01–AC06, AC08–AC10 live portions; V |
| T11 — supported protection rollout | Owner / explicitly assigned platform operator; verifier; dobar-validation | T10 successful dev and gate evidence; capability inventory | Later authorized GitHub settings only. Require PR/quality gate and resolved conversations; protect main from direct/force push/deletion and non-release source PRs; preserve owner merge without author-review deadlock. Enable production approval where supported; record exact enforcement and bypass limits. | AC02, AC07, AC09; V |
| T12 — fresh-chat acceptance | independent verifier; dobar-validation | T10, T11 and complete implementation handoffs | Follow final runbook from a fresh chat; map every P01 criterion to revision/environment/commands/artifacts. Report passed/failed/blocked/skipped separately. Product updates status only from evidence; neither a PR nor foundation success means Done. | AC01–AC10; V and criterion ledger |

T02, T03, T04, T05 and the T01→T06 tooling track are independent after T00 closes their interfaces. This is a dependency observation, not an instruction to launch agents. Serialize T01/T06/T07 edits to shared tooling. T05 owns test workflows before T08 edits deployment wiring. T08 may edit area config only after its area owner hands it over. Serialize updates to shared communication files; preserve the other sender's latest entry. Use Git/Linear history rather than new rolling-note archives.

## Validation packages for the handoffs

These are future check requirements unless the session evidence below records execution. Use isolated dependencies and synthetic fixtures. New test paths/runner commands must be supplied by implementers; commands for nonexistent runners are not claimed to work.

| Package | Commands / evidence required |
|---|---|
| F — foundation | From root: `python -m tools.agent_workflow validate`; `python -m tools.agent_workflow --catalog platform validate`; `python -m unittest discover -s tools/agent_workflow/tests -v`. These check structure/tooling only. |
| L — lifecycle | Extend the existing unittest discovery above with temporary Git repositories and fake GitHub/Linear. Cover fix/feat/docs and invalid/missing identities; dirty original checkout and staged index byte preservation; path escapes/symlinks and foreign changes; branch collisions; wrong base/head; failed, blocked, skipped-required, cancelled and stale checks; response loss after issue creation, worktree creation, commit, push and PR creation; concurrent starts; explicit blocked-draft choice; idempotent ready transition and optional review-state update. Assert no unauthorized write and no duplicate resource. Test current/explicit/no cycle and ambiguous team/label/issue resolution. |
| B — backend | In BE venv, from BE: `python -m pytest tests/ --no-cov -q` and focused new config/readiness tests. From root with same-checkout BE/DPE dependencies: `python -m unittest discover -s tools/agent_workflow/contract_tests -v`. Test unset/mixed environment, prod target, wrong replica/storage/auth identity, default secret, test bypass and failed critical dependency. Validate migration chain on disposable dev-only PostgreSQL; SQLite does not prove PostgreSQL migration compatibility. |
| D — payments | From DPE: `python -m pytest tests/ --no-cov -q`, `ruff check .`, `mypy dobar_payment/`; focused mode/credential/auth/callback and signature/replay tests. No outbound provider calls in deterministic suite. Sandbox confirmation is V, not a mocked test verdict. |
| E — frontend | From FE: `flutter analyze`, focused configuration/auth/socket/partner tests followed by `flutter test test/core/ test/features/`. Exercise production default and explicit dev build, absence of dev URL, incorrect production callback and refresh/WebSocket derivation. Build with `flutter build web --release --no-tree-shake-icons --dart-define=API_BASE_URL=<validated-dev-BE-origin>` once implemented; inspect compiled/runtime routing. Additional environment/auth defines come from T00/T04. |
| G — CI | Fixture matrix: docs-only, FE-only, BE-only, DPE-only, payment schemas, workflow/tooling changes, deletions/renames, mixed areas; actual success/failure/cancel/timeout/required-skip outcomes. Always-reported aggregate must fail closed when selection fails. Test main release restriction against same-repo develop, another branch, and fork develop. Later attach actual GitHub runs/check conclusions and head SHAs; YAML inspection is insufficient. |
| R — delivery | Config/preflight negatives for missing vars, prod URLs/credentials/resource IDs and wrong migration targets; disposable database migration tests; fake deployment stage failure at migration, DPE, BE, FE and smoke. Assert later stages stop, secrets stay environment-scoped, artifact/revision identities match and recovery keeps additive schema compatibility. Review production-default transition before enabling workflows. |
| V — integrated acceptance | `python -m tools.agent_workflow --catalog platform verify --spec P01 --output .agent-workflow/reports/P01.json` remains incomplete until an actual runner is implemented. Register it only with criterion-aware evidence and separate deterministic/GitHub/dev/provider/protection stages. Record Actions URL and run ID, PR/base/head/merge SHAs, image/release IDs, environment and nonsecret resource IDs, migration before/after, synthetic payment/order/request IDs, webhook verification and both client/cashier outcomes. Test protections only in an authorized rollout exercise; never probe production via an unapproved write. |

The runbook delivered by T08 and completed by T10/T11 must include prerequisites and environment matrix, local setup (including Windows paths), task start/finish examples, interruption recovery and ambiguous-write reconciliation, owner merge/release steps, dev smoke and provider instructions, per-stage rollback through Actions, and a criterion evidence template. Failed required checks must have an actionable report and leave publication incomplete.

## Explicit handoff prompts

### Next: product to cross-repo-planner

```text
Plan P01 using .agents/roles/cross-repo-planner.md and
.agents/skills/dobar-cross-repo-plan/SKILL.md. Read the root/affected-area
instructions, canonical P01 and .specs/platform/handoffs/P01-orchestration.md.
Execute only T00: recheck source evidence, settle the environment/interface
matrix, shared-file ownership, issue/cycle policy, exact-SHA check/deploy
contract, compatibility order and failure/recovery design. Return refined
T01–T12 briefs and concrete blockers, distinguishing local design from live
capability facts. Preserve stable AC IDs and keep P01 ready/unverified.
Planning only: do not implement infrastructure or product code, invoke
models/agents, publish tickets, mutate Git, change settings or deploy.
```

### Subsequent: planner to bounded implementer

```text
Implement only [one assigned T01–T08 ID] from the reviewed P01 handoff package.
Read its role/skills, root and affected-area instructions, canonical P01,
the planner's resolved interface decisions and predecessor evidence.
Confirm the assigned allowed paths, criteria and dependencies against the
current checkout. Return unresolved dependencies to the planner; do not
expand into unrelated product fixes. Implement and run its named validation
packages, including meaningful negative cases. Hand the verifier the diff,
base/head/content evidence, commands/results, compatibility/migration notes
and remaining blockers. Update only the relevant latest sender note if a
contract changes. No live issue writes, Git publication, settings changes,
provider operations or deployments are authorized by this local assignment.
```

The bracketed ID must be selected by the next assigning session. A generated role package alone does not assign all of P01. Tooling/CI assignments must explicitly include their shared paths; backend-only defaults are insufficient.

### Subsequent: implementation to independent verifier

```text
Use .agents/roles/verifier.md and .agents/skills/dobar-validation/SKILL.md
to execute T09 against the delivered P01 revision and evidence. Assess every
criterion's deterministic portion independently and reproduce adverse cases.
Separate source inspection, local tests, CI, dev deployment, provider sandbox
and production protection. Do not infer passing from a ready PR or a metadata
check. Return a criterion ledger with commands/environment/revision/artifacts,
passed/failed/blocked/skipped outcomes and bounded follow-up tasks.
Live T10–T12 checks require the separately authorized rollout and prerequisites;
leave those blocked/skipped until their actual evidence exists. Do not repair
implementation, publish tickets, change Git/settings or deploy in this review.
```

## Session evidence

Evidence covers this planning checkout at the baseline SHA above plus the planning document/index edits, not deployed P01. All commands ran on Windows PowerShell on 2026-10-25. `python` initially selected Python 3.15.0 without PyYAML. The registered Python 3.12 executable was absent. A local ignored venv now exists at `.agent-workflow/venv`; use its `Scripts/python.exe` for the commands below. It uses Python 3.15.0 and PyYAML 6.0.3, not the CI Python 3.12 environment.

| Outcome | Executed check / observation | Result and limit |
|---|---|---|
| Passed | `.agent-workflow/venv/Scripts/python.exe -m unittest discover -s tools/agent_workflow/tests -v` | 30 tests passed. Existing fake-service/tooling regressions only; no task lifecycle or live provider acceptance. |
| Passed | Planning document links through `Repository.validate_links`; `git diff --check` | No broken local links or tracked-diff whitespace errors. This does not override failed catalog validation below. |
| Failed | `.agent-workflow/venv/Scripts/python.exe -m tools.agent_workflow validate` | 26 `skill-discovery` findings; 25 specs, 8 roles and 13 skills loaded. No other finding category reported. |
| Failed | `.agent-workflow/venv/Scripts/python.exe -m tools.agent_workflow --catalog platform validate` | Same 26 discovery findings; 1 spec, 8 roles and 13 skills loaded. No broken-reference finding for this package. This is not a passing foundation verdict. |
| Blocked | CLI `--catalog platform handoff --spec P01 --role ROLE --output .agent-workflow/handoffs/P01-ROLE.md`, attempted for cross-repo-planner, backend, frontend, payments and verifier | Each command failed its foundation precondition; no generated package is claimed. Use the authored prompts and task rows above. |
| Blocked | P01 `workflow-e2e` prerequisite, source-inspected in the check registry | Runner remains null. P01 verification command was not run in this session; neither lifecycle nor deployed isolation/protection is validated. |
| Skipped | FE/BE/DPE runtime suites, GitHub checks, sandbox/device smoke, provisioning and protection exercises | Outside this planning session; no runtime implementation changed and live prerequisites were not established. |

Bootstrap attempts are distinct from these outcomes: initial default-Python commands failed imports because `yaml` was absent; initial PyYAML installation failed building its optional C extension because MSVC was unavailable. Retrying in the ignored venv with `PYYAML_FORCE_LIBYAML=0` successfully installed pure-Python PyYAML. No machine-wide Python/Git configuration or infrastructure was changed.

Discovery diagnosis: `git ls-files -s` records mode `120000` for the inspected orchestration entries in [.claude/skills](../../../.claude/skills/) and [.cline/skills](../../../.cline/skills/), while `Get-Item` reports regular files containing the relative target and `git config --get core.symlinks` returns `false`. The validator reported the same missing-link issue across all 13 skills in both locations. Canonical skill files are readable. Do not treat this checkout condition as proof that CI fails, or silently repair it under a planning-only assignment.

After the checkout prerequisite is resolved, generate fresh optional context packages with `python -m tools.agent_workflow --catalog platform handoff --spec P01 --role cross-repo-planner --output .agent-workflow/handoffs/P01-cross-repo-planner.md` (substitute backend/frontend/payments/verifier as needed). The CLI package is a broad snapshot; the task rows in this document define the narrower assignment. No ticket export or live synchronization is needed to use this plan.
