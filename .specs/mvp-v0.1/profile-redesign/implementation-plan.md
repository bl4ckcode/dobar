---
owner: product
spec: C04
artifact: implementation-plan
---

# Profile refinement implementation and remaining dependencies

The approved design replaces placeholder identity with Conta, adds real destinations, removes showcase controls, and preserves legal/logout routes. User selected account details, card replacement rather than metadata editing, and design → source export → Flutter translation. The actual React export is recorded in the [source handoff](react-source-handoff.md).

## Ordered delivery

1. **Frontend:** translate profile groups, account details, settings, history and saved cards using existing BLoC/Cubit, repository, GetIt, localization and GoRouter conventions. Allowed area: `fe`; documentation/spec updates are part of the handoff. No home, badge, toolbar or global navigation redesign.
2. **Cross-repo planning (done 2026-11-08):** product direction: benefits are Dobar Pro monthly coupons (5 per month) plus, later, venue-participation promotions. Backend contract is `/me/benefits` and `/me/benefits/{id}/venues`, covering the Pro-coupon allowance and its eligible venues (active, in-window, bar-funded `cashback` promotions). The wallet is exposed as `brl_cents` but with `venue_filter_supported=false`: `redeem_cashback` is wallet-wide and the product rule is undecided. Venue-participation promotions need a new model and are out of scope.
3. **Frontend after compatible BE (done, local):** loading/empty/failure/retry/unauthorized states, a real active count, a venue list preserving conditions, and navigation to `/bar/{id}` with no redeem/apply call. Interfaces are recorded in the FE/BE note.
4. **Payments/C10 (partially done):** a testable capability gate (OS + merchant `--dart-define` + backend advertisement + OS probe) hides wallets by default, and BE/DPE regressions prove wallet payloads are rejected. Still required before advertising: merchant IDs, a wallet plugin and probe, a verified PagarMe wallet-token mapping, sandbox and device evidence. See [C10](../C10-native-wallets.md).
5. **Independent verification:** run the [checklist](validation-checklist.md), record revision/environment and distinguish deterministic results from browser/device/provider acceptance. Release changes only through existing CI/CD.

## Compatibility and failure behavior

Keep `/profile/edit` and legal URLs, existing profile/avatar storage, and existing payment APIs. Add `/profile/settings`, `/profile/payments`, `/profile/benefits`, `/profile/benefits/:benefitId/venues`. Additive wire changes: `/me/benefits*`, `/me/contact-change*`, optional order `bar_name`; migration `dob_95` (new table). `PUT /me/profile` now rejects changed email/phone with 409. Replacement orchestration is local to PaymentBloc and adds an optional internal event field, not a server payload field. PAN/CVV go only to the existing direct-provider tokenizer.

Account edits load authenticated data before editing. Only name editing is enabled. The backend flow is now implemented: a 10-minute challenge, a Firebase proof for the new contact (signed in within 5 minutes), single use, session revocation. The UI stays read-only until the app can obtain that proof (phone OTP, or a Google/Apple identity with a verified email); there is no email-OTP sender today. Failed saves retain the draft; unsaved changes require discard confirmation. Notification preferences load/save through the existing use case; load failure does not substitute successful defaults. Locale persists through existing LocaleCubit. System notification permission is inspected separately from app preferences and rechecked after returning from device settings.

Validate with workflow checks, Flutter analysis, profile widget/state tests and checkout regressions. Real backend persistence, data retention, native permission/wallet behavior and visual comparisons require runtime evidence. Delivery remains partial until the above dependencies pass acceptance.
