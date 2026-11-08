---
owner: validation
spec: C04
artifact: validation-checklist
---

# Profile acceptance and evidence

React source inspection: `2a32eb05a8702bba1e9c8dd1ada8fb817b613f52`. Flutter working-tree evidence is recorded below; no product E2E or production deployment is implied.

| Criterion | Screens/states | Current coverage |
|---|---|---|
| C04-AC01 | Account load/view/name edit/save/failure, notification settings, locale persistence | Real interfaces. Name-only updates omit auth contacts/avatar. Email/phone edit UI blocked (no Firebase proof UI); the BE verified flow has HTTP tests. Live relaunch persistence unverified |
| C04-AC02 | Legal links, notification and privacy preferences | Privacy toggles are now reachable in Configurações with load-failure/retry/save-failure states (cubit tests). The backend stores `location_enabled`/`data_sharing_enabled` but nothing reads them, so semantics remain a follow-up. Live persistence unverified |
| C04-AC03 | Delete confirmation/busy/failure/completion/session end | Existing API plus FE failure regression. The BE test confirms only the caller's data (including cards) is removed. Live deletion unverified |
| C04-AC04 | Retained categories/backend deletion outcome | Documented in C04 from source plus a SQLite test. Needs release review: provider/Mongo/log retention, no transaction, hard-deleted orders. No store-release approval |
| C04-AC05 | Conta/no avatar/no showcase | Translated; widget coverage |
| C04-AC06 | History/list/empty/loading/error/load-more/tracker | Existing OrderBloc. Venue name via additive `bar_name` (BE HTTP test, FE parse test). Widget rendering untested; live data unverified |
| C04-AC07 | Coupons/cashback/rewards → eligible venues | Pro coupons: BE inventory/eligibility/authorization/failure tests (21), a shared fixture contract, and FE state/widget tests (loading, empty, unavailable, zero balance, failure/retry, unauthorized, navigation without redeem). Cashback venue eligibility and venue-participation promotions blocked on product decisions. No live data |
| C04-AC08 | Cards/list/add/replace/remove and wallet eligibility | Saved cards connected. Wallet gate tested to hide by default. Native wallets blocked under C10 |
| C04-AC09 | Both themes, responsive/text scaling, keyboard, reduced motion | Widget checks; no added animations; browser/device/visual acceptance pending. Benefits screens are tested in the light theme at the default scale only |

## Reproducible checks

From `fe`:

```sh
flutter analyze --no-pub
flutter test --no-pub test/features/profile test/features/payments/checkout_recovery_test.dart test/features/payments/checkout_wire_contract_test.dart
```

From root:

```sh
.agent-workflow/venv/bin/python -m tools.agent_workflow validate
.agent-workflow/venv/bin/python -m unittest discover -s tools/agent_workflow/tests -v
```

## Outcomes

Run 2026-11-08 against the working tree (no commit); synthetic data only.

- **Passed:** workflow validation (no findings) and 37 workflow unit tests. Flutter: full `flutter test` 206 passed and profile+payments suites 72 passed. Backend: full `pytest tests` 383 passed, 41 skipped, including `test_profile_dependencies.py` (21), `test_native_wallet_boundary.py` (5), the updated `test_auth.py` profile test and 15 existing coupon/identity tests. DPE: 231 passed, including 2 new wallet-boundary tests. Backend DB is SQLite, not PostgreSQL.
- **Failed:** full `flutter analyze --no-pub` exits 1 for the same two findings as before, both outside this change: unused `activePromos` in `order_summary_section.dart:57` and an unnecessary import in `lovable_home_controls_test.dart:1`. Targeted analysis of the changed lib/test targets shows no issues.
- **Blocked:** email/phone edit UI; cashback and venue-participation eligibility (product); native wallets (merchant, provider, plugin and device access); release deletion-retention review; the PostgreSQL `dob_95` migration was not executed.
- **Skipped:** product E2E, Android/iOS execution, real Firebase/Google proof, live persistence/deletion, load/rate-limit behavior (the limiter was not exercised in tests), browser visual acceptance, and `ruff`/`mypy`.
- **Test-contract change:** `test_auth.py::test_update_profile_phone_and_avatar` asserted the old unverified phone change. It now asserts a 409 with no partial write, and avatar-only edits still succeed.
