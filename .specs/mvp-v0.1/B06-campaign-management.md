---
id: "B06"
title: "Campaign creation and management"
owner: "frontend"
areas: ["fe", "be"]
priority: "P1"
depends_on: ["B01"]
source_requirements: ["MVP-B06-01", "MVP-B06-02", "MVP-B06-03", "MVP-B06-04", "MVP-B06-05", "MVP-B06-06", "LAUNCH-B06-01"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e"]
---

# B06: Campaign creation and management

## Intended behavior

Deliver the campaign creation and management journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Multi-step campaign sheet, advertising routes and centralized placement/rate-card constraints exist. Existing role enum has no Marketing member; permissions include ads:view and ads:manage.

Validate all five placements and five-step submission against actual rate card, tier gating and billing outcome; avoid introducing a new role to resolve wording.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/advertising/presentation/widgets/multi_step_campaign_sheet.dart](../../fe/lib/features/advertising/presentation/widgets/multi_step_campaign_sheet.dart)
- [be/app/advertising/routes.py](../../be/app/advertising/routes.py)
- [be/app/advertising/pricing.py](../../be/app/advertising/pricing.py)
- [fe/lib/features/advertising/presentation/widgets/subscription_plans_sheet.dart](../../fe/lib/features/advertising/presentation/widgets/subscription_plans_sheet.dart)

## Contracts and compatibility

Advertising campaign/rate-card/plan endpoints; ads:view reads and ads:manage modifies, with backend authority for tier and budget eligibility.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B06-AC01** — Five-step campaign flow covers placement/objective, budget, creative, target public and review before submission.
- **B06-AC02** — Available placements include Feature Bar, Search Boost, Map Pin Highlight, Promo Boost and Banner Ads; budget and creative rules match the server rate card.
- **B06-AC03** — Regular-tier users see a Master/VIP upgrade entry; restricted creation remains gated by confirmed entitlements and links into B11.
- **B06-AC04** — Users with ads:view can view campaigns; only ads:manage can create/edit according to current venue permissions; rejected submissions preserve draft input.
- **B06-AC05** — Created campaigns, lifecycle state and summaries render persisted backend results with empty/loading/error states.

## Validation scenarios and evidence

- Create each placement using permitted budgets; reject incompatible creative/budget, test regular vs paid tier, switch venue and attempt direct unauthorized submission.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B06-01, MVP-B06-02, MVP-B06-03, MVP-B06-04, MVP-B06-05, MVP-B06-06, LAUNCH-B06-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
