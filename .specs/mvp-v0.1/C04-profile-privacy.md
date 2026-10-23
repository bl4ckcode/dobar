---
id: "C04"
title: "Customer profile, privacy and deletion"
owner: "frontend"
areas: ["fe", "be"]
priority: "P1"
depends_on: ["C01"]
source_requirements: ["MVP-C04-01"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "native-device"]
---

# C04: Customer profile, privacy and deletion

## Intended behavior

Deliver the customer profile, privacy and deletion journey for the Belo Horizonte MVP. Customer validation includes Android and iOS. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Profile and privacy pages exist; backend exposes profile, notification/privacy preferences, consent and DELETE data routes.

Validate persistence and completed deletion semantics across auth/session and data stores. Store policy obligations need release review; no compliance certification is inferred from route existence.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/home/presentation/pages/profile/profile_home_page.dart](../../fe/lib/features/home/presentation/pages/profile/profile_home_page.dart)
- [fe/lib/features/home/presentation/pages/profile/privacy_settings_page.dart](../../fe/lib/features/home/presentation/pages/profile/privacy_settings_page.dart)
- [be/app/auth/profile.py](../../be/app/auth/profile.py)

## Contracts and compatibility

Existing authenticated profile/preferences and data-deletion contracts; account-specific operations derive identity from authentication.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **C04-AC01** — Customer edits supported profile/account preferences and sees persisted values after reopening the app.
- **C04-AC02** — Privacy and notification choices persist and legal links/consent remain reachable in Portuguese.
- **C04-AC03** — Explicit deletion confirmation invokes the account deletion flow, reports success or actionable failure, and ends local session access on completion.
- **C04-AC04** — Deletion evidence records retained categories and backend outcome for App/Google store release review without claiming blanket legal compliance.

## Validation scenarios and evidence

- Edit preferences, relaunch, cancel deletion, confirm deletion, inject backend failure and verify another account cannot target the first account.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Record Android and iOS device/OS evidence for native journeys; unavailable device coverage remains blocked or skipped.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-C04-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
