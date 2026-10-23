---
id: "B10"
title: "Business settings, bank and account preferences"
owner: "frontend"
areas: ["fe", "be"]
priority: "P1"
depends_on: ["B01", "B09"]
source_requirements: ["MVP-B10-01", "MVP-B10-02", "MVP-B10-03", "MVP-B10-04"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e"]
---

# B10: Business settings, bank and account preferences

## Intended behavior

Deliver the business settings, bank and account preferences journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Business settings page/BLoC and backend details/contact/data/deactivation/reactivation routes exist alongside dedicated bank-account and profile routes.

Validate settings permissions independently of marketing access and distinguish deleting personal account from deleting venue data. Preserve existing auth-provider-appropriate password options.

Observed source references (inspection only; no runtime or E2E validation):

- [fe/lib/ui/business/business_settings_page.dart](../../fe/lib/ui/business/business_settings_page.dart)
- [fe/lib/features/business_settings/presentation/bloc/business_settings_bloc.dart](../../fe/lib/features/business_settings/presentation/bloc/business_settings_bloc.dart)
- [be/app/bars_and_restaurants/routes/business_settings.py](../../be/app/bars_and_restaurants/routes/business_settings.py)
- [be/app/bars_and_restaurants/routes/bank_accounts.py](../../be/app/bars_and_restaurants/routes/bank_accounts.py)
- [be/app/auth/profile.py](../../be/app/auth/profile.py)

## Contracts and compatibility

Current business details/contact, bank-account and personal profile/deletion routes; bank/account authorization remains enforced server-side.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B10-AC01** — Users with relevant bar permissions edit venue information, working hours and contact settings and see persisted values.
- **B10-AC02** — Bank account details are shown/edited only to authorized admin/owner billing users and never exposed through broader marketing access.
- **B10-AC03** — All authenticated users can change language, access supported credential/password management and request their own account deletion with confirmation.
- **B10-AC04** — Light/dark preference, loading/save errors and destructive confirmation remain accessible, localized and correctly scoped to personal account versus business data.

## Validation scenarios and evidence

- Edit hours/contact, reload, attempt bank access as cashier/marketing-only user, switch language/theme, cancel personal deletion and inject save failure.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

## Delivery and verification

Delivery: ready for planning/implementation, subject to listed dependencies. Verification: unverified. Source inspection is the only evidence so far; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B10-01, MVP-B10-02, MVP-B10-03, MVP-B10-04. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
