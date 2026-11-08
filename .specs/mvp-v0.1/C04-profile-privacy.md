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

The user-approved [profile redesign package](profile-redesign/implementation-plan.md) refines the active `ProfileWireframe`, account, notifications/language/privacy, history, saved-card and benefits destinations using the [actual React export](profile-redesign/react-source-handoff.md). Home, badges and toolbars are deferred.

Dependencies resolved in the working tree (2026-11-08, local checks only): `GET /me/benefits` and `/me/benefits/{id}/venues` give an authenticated owned-benefit inventory with authoritative venue eligibility for Dobar Pro monthly coupons; the venue-to-benefit rule for plain cashback is still undefined. A verified contact-change flow exists in the backend (`/me/contact-change`); `PUT /me/profile` no longer changes email/phone. Order history carries the backend `bar_name`. Wallet buttons are gated by a capability check that reports unavailable. Privacy preferences are reachable in Configurações. Contracts: [FE/BE note](../../docs/FE_BE_COMMUNICATION.md).

Remaining gaps: Flutter has no email/phone edit UI because Firebase proof acquisition is not built. Native wallets stay blocked under C10. `location_enabled` and `data_sharing_enabled` persist, but no backend code reads them. Venue-participation promotions (for example 10% on a brand) have no model yet. Cashback venue eligibility needs a product decision. Deletion evidence is below.

### Deletion outcome and retained data (release review input, C04-AC04)

Source evidence is [DELETE /me/data](../../be/app/auth/profile.py) plus a [regression test](../../be/tests/test_profile_dependencies.py) on SQLite. No production or provider deletion was run, and this is not a compliance determination.

- **Deleted by the route:** user row; profile (name, avatar, FCM token, preferences); refresh/legacy tokens; MFA secrets; recovery and contact-change requests; carts and items; orders and order items; cashback ledger and wallet; Pro coupon usage; saved-card rows (`payment_cards`, added 2026-11-08); idempotency keys (added 2026-11-08). Database foreign-key cascades also reach check-ins, notifications and user documents (CPF).
- **Not deleted by the route, needs review:** the PagarMe customer and saved-card tokens at the provider (no provider delete call exists); MongoDB data keyed to the user, which was not inspected; advertising impressions keyed by a user-id string; order status-history rows, cascade unverified; payment records in DPE (process-local) and provider settlement records; application logs and backups; Redis/push queue items; and bars or staff memberships tied to a business account. Orders are hard-deleted, so confirm financial and tax record-keeping obligations before release.
- **Outcome contract:** `200 {message, reference: "DEL-<hash>", deleted_at}`. The FE ends the local session on success and keeps the account on failure (regression-tested). Atomicity is unverified: the route issues sequential deletes without a transaction, so a mid-way failure can leave partial data.

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

- **C04-AC05** — Perfil presents an avatar-free Conta entry and excludes the showcase toolbar and demo shortcuts.
- **C04-AC06** — Histórico de pedidos loads authenticated order history, exposes recoverable loading/empty/error/pagination states, and opens the matching order.
- **C04-AC07** — Cupons, cashback e recompensas displays authoritative active benefits and opens only the selected benefit's eligible bars/restaurants with conditions and context preserved; navigation does not redeem or apply a benefit.
- **C04-AC08** — Pagamentos lists masked saved credit cards, supports add/replacement/confirmed removal, preserves the original on add failure, and retains both on removal failure. Pix is not a saved method; native wallets appear only with supported/configured capability per C10.
- **C04-AC09** — Profile destinations provide localized loading, empty, failure/retry and submitting states where applicable; both themes, narrow/wide layouts, keyboard/focus/screen-reader access, text scaling and reduced motion remain usable.

## Validation scenarios and evidence

- Edit preferences, relaunch, cancel deletion, confirm deletion, inject backend failure and verify another account cannot target the first account.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Record Android and iOS device/OS evidence for native journeys; unavailable device coverage remains blocked or skipped.

## Delivery and verification

Delivery: partial. Implemented and locally tested: account/name, history with venue name, notification/language/privacy settings, saved cards, Pro-coupon benefits with eligible venues, and a backend verified contact-change flow. Blocked: email/phone edit UI (Firebase proof acquisition), cashback venue eligibility (product decision), native wallets (C10 merchant/provider/device access) and release deletion review. Verification: unverified. Local evidence is in the checklist; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-C04-01. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
