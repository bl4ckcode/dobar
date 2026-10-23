---
owner: product
---

# Dobar MVP agent workflow

This is the operating guide for the repository-backed MVP workflow. [Context authority and observed contradictions](AGENT_CONTEXT.md) distinguish current implementation from intended behavior. [The spec index](../.specs/mvp-v0.1/README.md) maps all journeys to [the MVP source](q4_2026/Dobar_MVP_v0.1.md). Specs and Linear are intent; executable evidence establishes verification.

## Approved launch decisions

- Launch in Belo Horizonte, Brazil: BRL and Portuguese UI. Customer journeys cover Android/iOS; business journeys cover responsive browsers.
- Order stages are Pending → Preparing → Ready → Completed. Existing `confirmed`/cancellation values require backward-compatible handling in follow-on work; this foundation changes no product wire states.
- Existing owner/admin/manager/cashier/staff roles remain. Marketing is a permission-based capability, not a new role. Use explicit server permissions, not an assumed hierarchy, for campaigns and staff management.
- Staff use existing phone/Google/Apple login, resume the invitation, prove a verified recipient match, and explicitly accept before gaining access. An invitation is not a session credential.
- PagarMe handles Brazilian customer purchases. Card data goes directly to provider tokenization; BE/DPE receive tokens or provider card IDs. Amounts/ownership are server-authoritative, retries are idempotent, and payment success requires authenticated provider confirmation. A proprietary card-security SDK and gateway migration are outside this delivery.
- Pix needs a real provider-backed charge, usable Copia e Cola and decodable QR, expiry, reconciliation and consistent client/cashier updates. Local BR Code generation is not payment confirmation.
- Stripe Checkout handles Master/VIP subscription purchase; Customer Portal handles existing subscription management. Server-owned plan selection and webhook-derived entitlement state are required; redirects cannot prove payment.
- Preserve traceability across FE → BE → DPE → provider without PAN/CVV/secrets in payloads to our servers or logs. Diagnose browser CORS, transport, and provider errors separately.
- Deliver all specs/roles/skills/tooling and the staff-invite prompt/ticket pilot now; implement product fixes as follow-on backlog work. Generate all tickets locally and synchronize only B08 initially. Agents and Lovable are explicitly launched by a human; this tooling never invokes paid model APIs.

## Start locally

From the monorepo root, use Python 3.12 or newer:

```sh
python3.12 -m venv .agent-workflow/venv
source .agent-workflow/venv/bin/activate
python -m pip install -r tools/agent_workflow/requirements.txt
python -m tools.agent_workflow validate
python -m unittest discover -s tools/agent_workflow/tests -v
python -m tools.agent_workflow tickets export
python -m tools.agent_workflow handoff --spec B08 --role cross-repo-planner
python -m tools.agent_workflow handoff --spec B08 --role frontend --output .agent-workflow/handoffs/B08-frontend.md
python -m tools.agent_workflow verify --spec B08 --output .agent-workflow/reports/B08.json
```

Runtime exports, mappings, reports, caches and this virtual environment live in ignored `.agent-workflow/`. Optional `--output PATH` writes exports, handoffs or reports elsewhere. No command stages, commits or deploys. The CLI uses argument arrays rather than shell commands.

The [check registry](../tools/agent_workflow/checks.json) is the explicit allowlist of verification commands. `product-e2e`, `provider-sandbox` and `native-device` are deliberately unconfigured until real runners exist. They report **blocked**, never passed. Register a runner that selects the requested `{spec}` and validates its acceptance criteria; provide the documented test accounts/environment before claiming coverage. Keep provider checks in sandbox environments and native evidence separate from mocked tests. Preserve backend and DPE deployment through GitHub Actions.

Exit codes: `0` successful operation/all required checks passed, `1` validation/execution failure, `2` incomplete verification or missing credentials for a preview. Each verification check reports `passed`, `failed`, `blocked` or `skipped`. `--skip CHECK` records a deliberate omission and makes the report incomplete. Verification does not edit the spec's delivery/verification metadata. Reports fingerprint checkout content and fail if it changes during checks; attach environment, acceptance evidence and artifact references for independent review.

If the active Xcode installation blocks system Git behind its license prompt, verification records a blocked fingerprint check. `DOBAR_GIT` can select an already installed working Git executable, for example the standalone Command Line Tools Git. No workflow command accepts software licenses or changes global developer-tool settings. Flutter/native execution remains blocked until the local SDK prerequisites are satisfied.

Only spec `verification_status` and `verification_evidence` metadata are excluded from the checkout fingerprint, so attaching the resulting report does not invalidate its evidence. Acceptance criteria, source code, tooling and other content remain included. Reset a spec to `unverified` after implementation/acceptance changes before re-verifying; a `validated` claim requires a readable report for the current fingerprint with every required check passed. Reports, not edited status wording, carry the evidence.

Coverage checks validate the 82 reviewed requirement atoms, their bidirectional spec/criterion mappings, and source snapshot drift. They cannot prove the original extraction is semantically exhaustive. Review changed source requirements before refreshing snapshot hashes; removing requirement mappings is a product decision. Criterion references alone do not count as definitions.

The shared synthetic [Pix wire fixture](../tools/agent_workflow/fixtures/pix-checkout.json) is consumed by Python bridge/schema checks and the Flutter serialization test. These checks exercise pending state, amount/ID conversion, idempotency transport and Pix field preservation; they do not prove QR validity, card support, authentication, provider processing or settlement. To run the Python subset independently:

```sh
python -m pip install -r tools/agent_workflow/contract_tests/requirements.txt
python -m unittest discover -s tools/agent_workflow/contract_tests -v
cd fe
flutter test test/features/payments/checkout_wire_contract_test.dart
```

## Route and hand off work

1. Product/GPT updates a journey spec and its source requirement/acceptance mapping. Preserve stable IDs. A change to a source snapshot requires reviewing coverage and refreshing its SHA-256 in [requirements](../.specs/mvp-v0.1/requirements.json).
2. For FE/BE/DPE dependencies, Gemini receives the `cross-repo-planner` handoff and returns ordered tasks and contract decisions. Planning must distinguish observed wire behavior from requested changes.
3. GPT produces the Lovable prompt. A human runs Lovable, exports the actual React source and records repository, immutable revision, entrypoints and assets in the [source handoff](../.specs/mvp-v0.1/pilot/react-source-handoff.md). The current export is pending, not fabricated.
4. Claude Sonnet translates heavy React UI work into Flutter. Scoped frontend/backend/payments work goes to Cline free models, or Sonnet when complexity warrants. Cline handles narrowly reproduced bugs. [Role profiles](../.agents/roles/frontend.md) select [portable skills](../.agents/skills/dobar-orchestrate/SKILL.md); no model version or API call is embedded in the workflow.
5. An independent verifier/GPT uses the acceptance checklist and actual check outputs. Failed, blocked and skipped checks stay visible. Passing foundation checks proves artifact consistency, not a product journey.

Skills are canonical under `.agents/skills`; Claude and Cline use relative links under their project skill directories. Gemini supports `.agents/skills` directly. `CLAUDE.md` and `GEMINI.md` point to the same root/area instructions. Client discovery conventions are documented by [Gemini](https://geminicli.com/docs/cli/skills/), [Claude](https://code.claude.com/docs/en/skills), and [Cline](https://docs.cline.bot/customization/skills); actual loading depends on the installed client and workspace trust.

## Linear preview and synchronization

Supply `LINEAR_API_KEY` through your environment or secret manager. The CLI does not store or print it. Personal API keys use Linear's documented Authorization header. `LINEAR_TEAM_KEY` defaults to `DOB`; optional `LINEAR_PROJECT_ID` must identify an existing project associated with that team. The reviewed DOB labels are configured in `tools/agent_workflow/linear-config.json`: `barz-fe`, `barz-be`, and `payments`, with `Feature` on parent issues. Existing unambiguous configured labels are required; change this mapping when using another workspace. The CLI never creates teams/projects/labels. A connected Linear tool can consume the same exported issue payloads and persist returned UUIDs to the same mapping; this does not expose its connection credentials to the headless CLI.

```sh
python -m tools.agent_workflow tickets sync --spec B08
python -m tools.agent_workflow tickets sync --spec B08 --apply
```

A preview reads the existing team, labels and issues but makes no writes. Without credentials it prints desired local payloads and exits `2`; this is not a remote comparison. The initial live scope is B08: one parent plus FE/BE children. B07 remains a linked prerequisite draft. Other specs require a separately requested synchronization.

Stable task markers and team-scoped deterministic UUIDs identify issues across reruns/worktrees. Archive-aware paginated reads recover issues after an uncertain create. Successful mappings persist after each operation; no automatic mutation retries occur. Rerun the preview to reconcile partial failures. Damaged/duplicate ownership markers, unavailable mappings, ambiguous labels and wrong-team mappings block writes. Local sync locks prevent simultaneous writes through the same mapping file; investigate a stale lock after a terminated process before removing it.

Only the section between `dobar-workflow:start` and `dobar-workflow:end` is updated on existing issues. Human notes outside it, titles, labels, assignees, state, project and parent choices are preserved. The markers themselves must remain intact. Existing unrelated issues, including DOB-85 through DOB-88 referenced in bug notes, are not automatically adopted by title; reconcile them explicitly rather than generating misleading matches. Linear integration follows the [official GraphQL API](https://linear.app/developers/graphql).

## Staff-invitation pilot and acceptance

Review [B08](../.specs/mvp-v0.1/B08-staff-invitation-acceptance.md), its [React prompt](../.specs/mvp-v0.1/pilot/lovable-staff-invitation.md), [FE/BE tasks](../.specs/mvp-v0.1/pilot/implementation-tasks.md), and [verification checklist](../.specs/mvp-v0.1/pilot/validation-checklist.md). They cover login resume, verified contact matching, safe preview, atomic acceptance, replay/concurrency, missing/expired/revoked/used tokens, workspace refresh, localization and both themes.

Foundation delivery is complete when 25 specs cover every source requirement, all skills and references validate, deterministic exports repeat identically, and fake-service tests prove safe sync reruns, partial failure recovery and preservation of human content. The current delivery does not claim product E2E, provider sandbox, native-device execution, or an exported React revision.

Pull requests and scheduled GitHub Actions run deterministic context/coverage checks and workflow tests. Semantic contradictions remain source-backed findings for review in [context findings](AGENT_CONTEXT.md); the scanner does not rewrite business intent or create external tickets. The source approach is adapted from [Basis's agent-ergonomic monorepo](https://www.getbasis.ai/blogs/how-we-made-our-monorepo-ergonomic-for-agents).
