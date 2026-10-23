---
id: "B02"
title: "Resumable venue onboarding"
owner: "frontend"
areas: ["fe", "be"]
priority: "P1"
depends_on: ["B01"]
source_requirements: ["MVP-B02-01"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e"]
---

# B02: Resumable venue onboarding

## Intended behavior

Deliver the resumable venue onboarding journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Business onboarding entry and details form exist; backend supports bar wizard creation, image updates and bank-account routes.

Existing onboarding entry is not proof of draft persistence. Specify resume checkpoint behavior and ensure incomplete data cannot be confused with a completed venue or authorized bank setup.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/ui/business/forms/business_details_form.dart](../../fe/lib/ui/business/forms/business_details_form.dart)
- [fe/lib/ui/business/widgets/business_onboarding_view.dart](../../fe/lib/ui/business/widgets/business_onboarding_view.dart)
- [be/app/bars_and_restaurants/routes/bars.py](../../be/app/bars_and_restaurants/routes/bars.py)
- [be/app/bars_and_restaurants/routes/bank_accounts.py](../../be/app/bars_and_restaurants/routes/bank_accounts.py)

## Contracts and compatibility

Current venue wizard, image/contact/settings and bank-account capabilities; add a documented authenticated draft capability only if existing persistence cannot safely resume.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B02-AC01** — An authenticated owner can optionally onboard venue images, contact information and bank details and enter AI menu import from the same flow.
- **B02-AC02** — Saving progress records a draft for that owner; reopening the browser/session restores saved values and the next incomplete step.
- **B02-AC03** — Failed save/upload is visible and retry does not create a second venue; finalization validates required venue fields.
- **B02-AC04** — Only authorized users access drafts and sensitive bank fields, and successful creation refreshes business venue access.

## Validation scenarios and evidence

- Save after contact step, close/reopen browser, resume as same owner, retry network failure, finalize twice and attempt another account draft.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B02-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
