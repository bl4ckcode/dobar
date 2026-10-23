---
id: "S01"
title: "Design-system alignment"
owner: "frontend"
areas: ["fe"]
priority: "P1"
depends_on: []
source_requirements: ["MVP-S01-01", "MVP-S01-02", "MVP-S01-03", "MVP-S01-04", "LAUNCH-S01-01", "MVP-PRINCIPLE-05"]
planning_role: "product"
implementation_roles: ["frontend"]
skills: ["dobar-spec", "dobar-frontend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e"]
---

# S01: Design-system alignment

## Intended behavior

Deliver the design-system alignment journey for the Belo Horizonte MVP. Apply across affected launch journeys. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Repository has semantic DobarColors and multiple theme/token entry points; existing Lovable prompts mix dark-only guidance, hardcoded colors and requests for Flutter output.

Align changed screens to semantic tokens and actual app theme without broad unrelated visual refactoring. Pilot Lovable output must be React source followed by reviewed Flutter translation.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/core/design/tokens/dobar_colors.dart](../../fe/lib/core/design/tokens/dobar_colors.dart)
- [fe/lib/core/design/theme/barz_theme.dart](../../fe/lib/core/design/theme/barz_theme.dart)
- [fe/lib/core/theme/app_theme.dart](../../fe/lib/core/theme/app_theme.dart)
- [fe/.docs/lovable_stitch_prompts.md](../../fe/.docs/lovable_stitch_prompts.md)

## Contracts and compatibility

Existing semantic theme API, shared widgets, localization keys and BLoC boundaries; source export revision is required for translation reproducibility.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **S01-AC01** — Changed customer/business/pilot screens derive background, surface, labels, accent, status and border colors from semantic theme tokens in both light and dark modes.
- **S01-AC02** — Portuguese strings use localization, text scales without clipped controls, and keyboard/screen-reader focus and contrast are checked in relevant layouts.
- **S01-AC03** — Lovable prompt explicitly produces React UI matching Industrial Modern Dobar style; translation records real source repository revision and maps reusable widgets into Flutter architecture.
- **S01-AC04** — Design evidence includes representative narrow/wide and light/dark screenshots plus interaction checks, with unresolved visual contradictions recorded for review.

## Validation scenarios and evidence

- Review pilot and order/cashier screens at narrow/wide widths, text scaling, keyboard navigation, reduced motion and both themes; compare semantic tokens rather than raw color replacement.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-S01-01, MVP-S01-02, MVP-S01-03, MVP-S01-04, LAUNCH-S01-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
