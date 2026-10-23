---
id: "C01"
title: "Customer authentication and onboarding"
owner: "frontend"
areas: ["fe", "be"]
priority: "P0"
depends_on: []
source_requirements: ["MVP-C01-01", "MVP-C01-02", "MVP-C01-03", "LAUNCH-C01-01", "MVP-PRINCIPLE-05"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "native-device"]
---

# C01: Customer authentication and onboarding

## Intended behavior

Deliver the customer authentication and onboarding journey for the Belo Horizonte MVP. Customer validation includes Android and iOS. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Login BLoC, SMS validation page and backend phone, Google and Apple login routes exist. Onboarding has country/user-type submission; code presence does not establish provider configuration or device success.

Validate actual provider credentials, SMS confirmation semantics, token refresh and business-entry routing. Never replace existing identity verification with invitation-token authentication.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/authentication/presentation/bloc/login_bloc.dart](../../fe/lib/features/authentication/presentation/bloc/login_bloc.dart)
- [fe/lib/features/authentication/presentation/pages/login_sms_validation_page.dart](../../fe/lib/features/authentication/presentation/pages/login_sms_validation_page.dart)
- [be/app/auth/routes.py](../../be/app/auth/routes.py)
- [fe/lib/features/onboarding/presentation/pages/onboarding_page.dart](../../fe/lib/features/onboarding/presentation/pages/onboarding_page.dart)

## Contracts and compatibility

Existing auth routes and token/refresh contracts; onboarding profile and country select Brazil. SMS confirmation applies to the phone flow; Google/Apple must validate their own provider identity rather than force an unrelated SMS step.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **C01-AC01** — A first-time phone user completes verified SMS login and lands on Home; rejected/expired codes leave the user unauthenticated with retry guidance.
- **C01-AC02** — Google and Apple users complete the existing provider login, receive the same authenticated session semantics and reach onboarding/Home as appropriate.
- **C01-AC03** — Onboarding offers business entry, requests location permission with a recoverable denied state, and defaults launch country to Brazil with Portuguese copy.
- **C01-AC04** — Logout clears authenticated context; expired access tokens refresh or return to login without exposing another user or venue session.

## Validation scenarios and evidence

- Run first/returning phone, Google and Apple login on Android and iOS; include denied location, canceled provider login, expired code and refresh failure.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Record Android and iOS device/OS evidence for native journeys; unavailable device coverage remains blocked or skipped.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-C01-01, MVP-C01-02, MVP-C01-03, LAUNCH-C01-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
