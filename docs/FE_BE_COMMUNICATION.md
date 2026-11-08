# Frontend ↔ backend communication

Last updated: 2026-11-07

Rolling handoff: one latest update per sender. Git and Linear own history. Implementation and local checks do not establish deployment, provider or native-device E2E acceptance.

## Contract references

- [Checkout schemas](../be/app/bars_and_restaurants/schemas/cart.py), [checkout routes](../be/app/bars_and_restaurants/routes/cart.py), [order payments](../be/app/payment/order_payments.py), [payment schemas/routes](../be/app/payment/routes.py), [API errors](../fe/.docs/API_ERROR_CONTRACT.md).
- [Check-in schemas](../be/app/bars_and_restaurants/schemas/checkin.py), [routes](../be/app/bars_and_restaurants/routes/checkin.py), [service](../be/app/bars_and_restaurants/services/checkin.py). Intent: [C05](../.specs/mvp-v0.1/C05-check-in.md), [C07](../.specs/mvp-v0.1/C07-cart-revalidation.md), [C08](../.specs/mvp-v0.1/C08-card-checkout.md), [C09](../.specs/mvp-v0.1/C09-pix-checkout.md), [S02](../.specs/mvp-v0.1/S02-payment-reconciliation.md), [B03](../.specs/mvp-v0.1/B03-ai-menu-import.md).
- Earlier additive venue-draft and invitation APIs remain: [onboarding](../be/app/bars_and_restaurants/routes/onboarding.py), [staff](../be/app/bars_and_restaurants/routes/staff.py), [entry coordinator](../fe/lib/features/session/presentation/entry_coordinator.dart). [Open findings](AGENT_CONTEXT.md) retain other unresolved contracts.

## Latest frontend update

- Date: 2026-11-03. Scope: approved checkout, menu import and check-in defect corrections; no deployment claimed.
- New checkout uses `defer_payment: true` plus stable `X-Idempotency-Key` on `/cart/checkout`, then a single `/payments/v2/charge` with `card|pix`. Saved cards use `payment_method.payment_method_id`; charge references remain opaque strings. `/cart/checkout/pending` restores the existing order and `payment_attempt_key` across retries/reopen.
- Card entry calls PagarMe public-key tokenization directly, then `/me/cards` exchanges the fresh `token_` for a durable provider card. Configure `PAGARME_PUBLIC_KEY` as a build define; web CI reads the matching GitHub variable/secret. Missing key remains actionable. CPF-save responses are documents; profile and document hydration are separate. No fabricated token authorizes a charge.
- Auth-scoped check-in consumes `GET /checkins/active` (object or null), `POST /checkins`, and `DELETE /checkins/active`. Menu browsing remains available; order/cart entry retains venue/action through confirmation. Home's 500m prompt and existing pulse remain. QR input accepts real links; camera scanning remains unavailable.
- Import entry stacks options/tips on narrow widths, uses localized copy and shared responsive constraints. Decorated onboarding cards provide Material for ListTiles. Focused widget checks cover entry layouts/themes; extracted-results/save and native/provider E2E remain unverified.

## Latest backend update

- Date: 2026-11-07. Scope: [C05-AC04](../.specs/mvp-v0.1/C05-check-in.md) profile identity correction; existing checkout/menu/check-in rollout obligations remain below.
- [Profile response](../be/app/auth/profile.py) now includes required integer `id` from the authenticated account, including profile-update/onboarding responses. This additive field supplies the identity already expected by FE `UserModel` and the singleton `SessionBloc`; no storage migration or FE persistence change is needed. Release BE through GitHub Actions and reinitialize/relaunch existing app sessions after rollout. [HTTP regression](../be/tests/test_profile_identity.py) covers account IDs distinct from profile-row IDs and unauthenticated access; [FE regression](../fe/test/features/checkin/checkin_profile_identity_test.dart) covers profile → session → confirmation with scripted HTTP, without login. Local checks do not establish deployment/device acceptance.
- `defer_payment` defaults false for legacy callers. New deferred checkout requires stable idempotency and creates/resumes one unpaid order. Customer prerequisites and server menu prices are validated before cart mutation. Shared charging authorizes the order, derives BRL totals, resolves owned saved cards and retains payment outcomes/attempt correlation. Paid state and rewards cannot regress or duplicate on replay.
- `/me/cards` requires a fresh PagarMe `token_`, exchanges it via DPE, and persists a durable `card_`; invalid legacy references are marked unusable. Blank references return validation errors; uniqueness races preserve the existing default card transactionally. Error categories distinguish validation, decline and unavailable/unknown outcomes.
- `POST /checkins` accepts `bar_id`, coordinates, `measured_at`, optional `accuracy_meters` and `table_number`. Server confirmation requires a fix ≤120s old and distance <10m, validates configured locations, and persists user/venue ownership. Active sessions expire after 12h by default (`CHECKIN_TTL_HOURS`); checkout requires the matching session and retains the validated location. Apply [C05 migration](../be/migrations/versions/c05_customer_checkins.py) before enabling this code.
- Menu parsing uses configurable `OPENAI_MENU_MODEL` (default `gpt-5.6-terra`), async structured output and bounded provider requests; controlled provider/configuration failures return canonical `503 SERVER_UNAVAILABLE` without provider secrets.
- Rollout: compatible DPE → migrated BE → FE via existing GitHub Actions. Existing B02 draft migration, stable bank-encryption key/S3 configuration and B08 native-link/domain/signing prerequisites still apply. Existing `/bars/wizard` remains supported.
- Evidence: focused [payment regressions](../be/tests/test_checkout_payment_regressions.py), [PostgreSQL payment concurrency](../be/tests/test_payment_postgres_concurrency.py), [check-in regressions](../be/tests/test_customer_checkin.py), [parser failures](../be/tests/test_menu_extraction_failures.py). These checks do not establish provider availability, GPS accuracy or settlement.
