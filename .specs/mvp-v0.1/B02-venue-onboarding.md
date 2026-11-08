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
delivery_status: "done"
verification_status: "unverified"
checks: ["foundation", "product-e2e"]
---

# B02: Resumable venue onboarding

## Intended behavior

Deliver the resumable venue onboarding journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

The working tree implements the six-step React translation, authenticated owner-scoped drafts, partial saves/resume, optional setup, durable uploads, repeat-safe finalization and acknowledged venue access refresh. See the [source handoff](venue-onboarding/react-source-handoff.md) and [validation record](venue-onboarding/validation-record.md). No deployment or product E2E validation is claimed.

Entry correction: no-access business profiles now return to saved, editable role/country selection rather than manual invitation entry; Back awaits sign-out, customer selection is supported, and business continuation keeps the existing draft flow. The onboarding theme transition has a widget regression. Evidence is in `.agent-workflow/reports/business-entry`; no files were added to the venue-onboarding artifact directory for this correction.

Drafts use separate PostgreSQL tables and grant no active venue access. Bank summaries are masked; saving does not verify a receiving account. Browser/device behavior and live storage integration remain to be verified.

The [source-backed implementation plan](venue-onboarding/implementation-plan.md) records current gaps: in-memory-only wizard state, placeholder image selection, required contact/bank steps conflicting with optional onboarding intent, and finalization without a durable retry checkpoint. Contact compatibility is implemented as nullable draft contact plus empty-string legacy read projection; the strict legacy wizard request is preserved. These are inspection findings, not runtime validation.

## Refinement and design handoff

- Preserve the six-step wizard: find venue, details, receiving account, photos, hours and review. Offer AI menu import from review/completion, entering the existing import journey only after confirmed creation and authorized venue access refresh.
- Optional sections can be explicitly skipped. Save partial fields without finalizing; restore acknowledged values and the first required invalid step, then the first optional unfinished step, or review when complete/skipped. Saving bank details does not verify a receiving account; resumed bank values remain masked.
- Every B02 screen/state uses semantic light/dark colors and a top-right theme button. Inputs must remain readable on gold/cream surfaces. Mobile outside-field taps dismiss the keyboard without swallowing another control's action; keyboard-aware scrolling keeps inputs/actions accessible.
- Use the [Lovable prompt and criterion matrix](venue-onboarding/lovable-prompt.md), [ordered FE/BE plan](venue-onboarding/implementation-plan.md), and [pending React export handoff](venue-onboarding/react-source-handoff.md). The exported source is now translated at the revision in the handoff; prototype storage and fixture success are not backend evidence.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/ui/business/forms/business_details_form.dart](../../fe/lib/ui/business/forms/business_details_form.dart)
- [fe/lib/features/onboarding/presentation/pages/onboarding_page.dart](../../fe/lib/features/onboarding/presentation/pages/onboarding_page.dart)
- [be/app/bars_and_restaurants/routes/bars.py](../../be/app/bars_and_restaurants/routes/bars.py)
- [be/app/bars_and_restaurants/routes/bank_accounts.py](../../be/app/bars_and_restaurants/routes/bank_accounts.py)

## Contracts and compatibility

Current venue wizard, image/contact/settings and bank-account capabilities; add a documented authenticated draft capability only if existing persistence cannot safely resume.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B02-AC01** — An authenticated owner can optionally onboard venue images, contact information and bank details and enter AI menu import from the same flow.
- **B02-AC02** — Saving progress records a draft for that owner; reopening the browser/session restores saved values and the next incomplete step.
- **B02-AC03** — Failed save/upload is visible and retry does not create a second venue; finalization validates required venue fields. Owners supply an address without typing latitude/longitude; coordinates from place selection or server-side address resolution remain internal. Changing the address invalidates the previous position, and failed resolution preserves the draft for correction/retry.
- **B02-AC04** — Only authorized users access drafts and sensitive bank fields, and successful creation refreshes business venue access.

- **B02-AC05** — A restored legacy business account with no venue or matching invitation resumes role/country selection with saved choices, both editable. Choosing customer returns to customer home; continuing business enters the existing draft/Create Bar flow. Back signs out without deleting saved choices or drafts. Theme transitions in both directions must not throw TextStyle interpolation errors.

## Validation scenarios and evidence

- Save after contact step, close/reopen browser, resume as same owner, retry network failure, finalize twice and attempt another account draft.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Delivery: implemented in the working tree; migration/backend must roll out before frontend through existing CI/CD. Verification: unverified pending independent product E2E and browser/device acceptance. Deterministic Flutter and real temporary-PostgreSQL checks are recorded in the validation record; mocked S3/Mongo checks do not prove real storage/provider availability. Foundation validation establishes artifact consistency only.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B02-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
