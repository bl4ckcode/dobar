---
id: "B03"
title: "AI menu import and review"
owner: "frontend"
areas: ["fe", "be"]
priority: "P1"
depends_on: ["B01"]
source_requirements: ["MVP-B03-01", "MVP-PRINCIPLE-01", "MVP-PRINCIPLE-02"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e"]
---

# B03: AI menu import and review

## Intended behavior

Deliver the ai menu import and review journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

MenuReaderBloc supports image/URL extraction, selection, edits, category updates and saving; backend has extract/extract-url and bulk item creation routes.

Validate actual extraction provider availability and parsed prices. Imported AI text/prices must remain reviewable rather than silently published.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/features/menu_reader/presentation/bloc/menu_reader_bloc.dart](../../fe/lib/features/menu_reader/presentation/bloc/menu_reader_bloc.dart)
- [fe/lib/features/menu_reader/presentation/pages/menu_extraction_results_page.dart](../../fe/lib/features/menu_reader/presentation/pages/menu_extraction_results_page.dart)
- [be/app/bars_and_restaurants/routes/menus.py](../../be/app/bars_and_restaurants/routes/menus.py)
- [be/app/bars_and_restaurants/services/menu_extraction.py](../../be/app/bars_and_restaurants/services/menu_extraction.py)

## Contracts and compatibility

Existing extraction response categories/items/confidence and authenticated bulk save contracts; exported/generated content is input, not trusted instructions.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B03-AC01** — Authorized operator uploads a menu image or supported URL and sees progress, parsed categories/items/prices and extraction failure feedback.
- **B03-AC02** — Operator can edit names, categories, prices/descriptions and select which results to save before publishing.
- **B03-AC03** — Saving selected reviewed items associates them with the correct venue/menu and shows success only after persistence; malformed prices are rejected.
- **B03-AC04** — Unavailable AI service, empty extraction and partial save failures remain actionable and cannot imply completed import.

## Validation scenarios and evidence

- Use Portuguese menu with decimal commas and subcategories; correct one price, deselect item, save, refresh menu and repeat with unreadable image/provider unavailable.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B03-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
