---
id: P01
title: Isolated dev deployment and agent task-to-PR workflow
owner: product
areas: [fe, be, dpe]
labels: [platform]
priority: P0
depends_on: []
source_requirements: [P01-R01, P01-R02, P01-R03, P01-R04, P01-R05, P01-R06, P01-R07, P01-R08, P01-R09, P01-R10]
planning_role: cross-repo-planner
implementation_roles: [backend, frontend, payments]
skills: [dobar-cross-repo-plan, dobar-linear, dobar-commit, dobar-communication-docs, dobar-validation]
delivery_status: ready
verification_status: unverified
checks: [foundation, workflow-e2e]
---

# P01: Isolated dev deployment and agent task-to-PR workflow

## Outcome and boundaries

Give every explicitly started agent task an isolated branch/worktree, traceable Linear identity, and a tested pull request. Merges into `develop` deploy a shared dev environment; release PRs promote `develop` into protected `main`, which remains production. The owner decides merges. Automatic code review is a later integration; this feature supplies its stable PR/check interface.

This file specifies follow-on implementation. It does not provision Fly apps, change GitHub settings, create branches/commits/PRs, or authorize operations on the current user's unrelated changes.

## Current implementation evidence and gaps

- Existing [BE deployment](../../.github/workflows/deploy-be.yml), [DPE deployment](../../.github/workflows/deploy-dpe.yml), and [FE deployment](../../.github/workflows/deploy-fe.yml) target `main` and production Fly configurations. There is no inspected shared dev deployment pipeline.
- [FE endpoints](../../fe/lib/core/api/api_endpoints.dart) hardcode the production API URL. [BE startup](../../be/app/main.py) treats any `FLY_APP_NAME` as production, which must not silently select production configuration for a dev app.
- [Migration workflow](../../.github/workflows/run-migrations.yml) hardcodes the production app. BE deployment currently invokes migration after application deployment; dev automation must not reuse that target accidentally or boot code against an incompatible schema.
- [Workflow CLI](../../tools/agent_workflow/__main__.py) validates specs, drafts tickets and generates handoffs; it does not create worktrees, commits, pushes or PRs. Area test workflows have overlapping job names and incomplete PR wiring for a protected-branch gate.
- Root instructions currently prohibit automatic Git publication. The implemented workflow must introduce a narrow opt-in exception for an explicitly invoked task lifecycle, preserving the default prohibition. Inspection is not evidence of deployed isolation, repository-plan capabilities or enforced protections.

## Environment and delivery design

- Use GitHub environments `development` and `production`. Dev has separate FE/BE/DPE Fly apps in `gru`, separate service/webhook credentials, and isolated PostgreSQL, Redis, MongoDB, storage and auth/client-domain configuration. Proposed Fly names are `dobar-app-dev`, `dobar-backend-dev`, `dobar-payment-engine-dev`; validate availability and record actual IDs before provisioning.
- Use synthetic seed data and sandbox payment credentials only in dev. Route dev FE → dev BE → dev DPE; configure exact dev origins/callbacks. Missing dev configuration fails closed instead of falling back to production. No production data copy, real customer messaging, live charges or refunds belong to dev smoke checks.
- Add FE build-time `API_BASE_URL` configuration while retaining the current production value as the production default. Explicit BE `ENVIRONMENT` and DPE `DPE_ENV` select the target behavior independently of the presence of Fly runtime variables. Dev configuration must be complete; development auth/service-secret bypasses cannot become public app defaults.
- Task PRs target `develop`. After required checks and owner merge, GitHub Actions deploy the tested `develop` revision to dev, with environment-specific migration targets and a health/smoke gate. Deploy DPE/BE/FE in a compatible order; run required migrations as a guarded release phase before dependent code serves traffic. Stop on failure and retain prior app revisions for rollback; migrations use additive compatibility rather than destructive rollback.
- Release PRs go `develop` → `main`; production deployment remains GitHub Actions only and receives only production environment secrets. Do not auto-merge. Configure human approval for production when the repository plan supports it; otherwise keep the explicit owner release-merge gate and report the available protection level honestly.

## Task lifecycle interfaces and conventions

Extend the existing CLI with `task start` and `task finish`. Start accepts an issue ID or catalog/spec ID plus `fix|feat|docs`; prompts route through the same lifecycle. Resolve the linked Linear issue first. An explicitly invoked start may create a missing spec-linked issue within the authorized team, applying scope/type labels and the current-cycle policy; an ambiguous issue or failed write stops before Git mutation.

Start creates an isolated worktree from fetched `origin/develop`, records its base SHA, issue URL, spec/criteria, kind, branch and owned paths under ignored runtime state, and returns its path to the agent. Do not switch, stash, reset, stage or rewrite the user's existing checkout. Reuse an existing recorded task branch on retry; never overwrite a branch collision.

- Branch: `fix/dob-85-cashier-order-expiry`, `feat/dob-89-staff-invitation-acceptance`, `docs/dob-88-lovable-prompts`.
- Commit subject and PR title: `fix: DOB-85: cashier order expiry`, with corresponding `feat:` or `docs:` prefixes. The issue identity is mandatory; the description can be shorter than the Linear title.
- PR body: direct Linear URL, spec and acceptance IDs, concrete behavior change, tests/evidence, migrations/compatibility and material blockers. Avoid a copied full spec.

Finish rechecks task ownership/base/revision and runs the approved affected-area checks. Once local checks pass, commit only the task's reviewed owned changes, push its task branch, and create or update one draft PR targeting `develop`. After remote required CI passes on that exact head SHA, mark it ready for owner review and optionally move the issue to the team's review state. Never mark the feature Done merely because a PR exists. Failed, blocked, skipped-required or stale checks keep it incomplete; publishing a blocked draft requires an explicit user choice.

An explicit lifecycle invocation grants only its recorded task's branch/commit/push/PR operations. Manual sessions outside it retain current Git safeguards. Foreign/unowned edits, merge conflicts or credentials failures stop publication without rewriting user work. Retry must reuse the branch, commit state and PR identity; uncertain external writes are reconciled before retry. No paid model calls or automatic reviewer are added.

## Protected branches and checks

Create an always-reported, uniquely named `quality-gate` for every PR into `develop` or `main`. It selects meaningful tests by affected area and aggregates their actual outcomes; documentation-only work still runs foundation checks. A path-filtered workflow must not leave a required check permanently pending, and skipped required product tests cannot count as passed. Test BE/DPE from the same checkout and ensure FE checks run before a dev merge/deploy.

Roll out required PR/check rules only after dev and the gate have passed. Prevent direct/force pushes and deletion of `main`; allow only release PRs from `develop` into main. Require resolved review conversations. The owner retains the merge decision; do not require a non-author approving review in a solo-maintainer setup until an eligible reviewer/review app exists. Verify GitHub plan/permission support before changing settings; unsupported enforcement is a blocker, not a claimed protection. Leave a documented extension point for future automatic review.

## Acceptance criteria

- **P01-AC01** — Dev FE/BE/DPE resolve only dev services/data, synthetic fixtures and sandbox providers; a missing variable, production URL/credential or wrong migration target prevents deployment. A dev smoke run cannot mutate production.
- **P01-AC02** — A successful `develop` merge deploys its tested revision to dev through GitHub Actions; release PRs promote to main/production only through the owner gate, with health/migration failures visible and recoverable.
- **P01-AC03** — Starting from a prompt or spec resolves one issue and creates/reuses one correctly named task branch in an isolated worktree; a dirty user's checkout and unrelated index remain unchanged.
- **P01-AC04** — Branches, commit subjects and PR titles follow the issue-linked fix/feat/docs conventions; task PRs target develop and their bodies link Linear, spec criteria and evidence.
- **P01-AC05** — Finish publishes only owned changes after local checks pass; a draft PR becomes ready only after required CI passes for its current head. Failed/blocked/stale or skipped-required checks cannot establish readiness.
- **P01-AC06** — Retrying interrupted start/finish creates no duplicate issue, worktree, branch or PR; conflicts, foreign edits and uncertain writes leave user changes intact and produce a recoverable report.
- **P01-AC07** — Every PR receives a unique aggregate gate; docs-only and each affected runtime exercise the right checks. Protected main rejects direct/force pushes and non-release source branches once supported rules are enabled.
- **P01-AC08** — Created issues retain relevant barz-fe/barz-be/payments/platform and type labels. Bugs/hotfixes/minor adjustments get the current cycle when available; explicit cycles survive and no current cycle remains an explicit unmet scheduling prerequisite.
- **P01-AC09** — The owner can review dev evidence and decide release/merge without a self-review deadlock. Automatic code review remains an independently implementable extension, not a fabricated approval.
- **P01-AC10** — A new-chat agent can follow the rollout/runbook, demonstrate each criterion with commands/environment/revision evidence, and distinguish source inspection, local tests, GitHub checks, dev deployment and production protection.

## Validation and rollout

Use temporary Git repositories and a fake GitHub/Linear transport to test lifecycle state/ownership, dirty workspaces, branch collisions, failed checks, stale SHAs, timeouts and response-loss retries. Validate all three naming types and missing issue IDs. Test CI aggregation for FE/BE/DPE/docs-only changes and branch-source restrictions.

Then provision the dev prerequisites through approved GitHub Actions, exercise signed sandbox confirmation plus client/cashier consistency separately from mocked tests, verify environment isolation, and attach dev deployment/smoke evidence. Pilot a disposable fix task through owner-merged develop PR before enabling branch protections. Document the exact supported GitHub controls and rollback/recovery procedure. Do not test protected-branch rejection by writing to production outside an authorized rollout exercise.

Delivery remains ready; verification remains unverified. `workflow-e2e` is blocked until the lifecycle/dev integration runner exists. This spec and its foundation validation do not enable any of the described automation.

Sources: [workflow policies](../../docs/AGENT_WORKFLOW.md), [GitHub protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches), [GitHub environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments), [Fly configuration](https://docs.fly.io/reference/configuration).
