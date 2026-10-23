# Frontend ↔ backend contract

Canonical integration summary, reviewed against this checkout on 2026-10-22. These are observed interfaces, not an E2E/deployment guarantee. [Authority and findings](AGENT_CONTEXT.md) distinguish current contracts from MVP intent. Historical examples and requirements remain in the [noncanonical archive](archive/agent-context-2026-10-22/FE_BE_COMMUNICATION.md).

## Authentication and bar context

- FE calls BE with the existing access-token authentication; refresh/logout use `/auth/refresh` and `/auth/logout`. Login routes include `/auth/phone-login`, `/auth/google-login`, and `/auth/apple-login`; see [auth routes](../be/app/auth/routes.py) for provider payloads and aliases.
- `GET /me/bars` returns `[{bar_id, bar_name, role, permissions}]` for workspace entry. Keep bar IDs and explicit permissions in selected-workspace state.
- Bar-scoped calls resolve `bar_id` from path, query, or `X-Bar-Id`; BE authorization owns access decisions. `X-Bar-Id`, `X-Bar-Role`, and `X-Bar-Permissions` response headers supply UI context, not authorization granted by the browser. See [RBAC middleware](../be/app/auth/rbac_middleware.py).
- Roles are `owner`, `admin`, `manager`, `cashier`, `staff`. Marketing capabilities use `ads:view`, `ads:manage`, `promo:view`, and `promo:manage`; billing and staff permissions remain distinct. See [permission definitions](../be/app/auth/rbac_models.py).
- The [API error contract](../fe/.docs/API_ERROR_CONTRACT.md) is the canonical FE error design. Actual routes still mix this shape and FastAPI `detail`; treat deviations as findings, not an invitation to fabricate a uniform response.

## Customer journeys

| Capability | Current routes / wire contract |
|---|---|
| Home/discovery | `GET /home/`, `GET /bars/`; [home](../be/app/bars_and_restaurants/routes/home.py), [bars](../be/app/bars_and_restaurants/routes/bars.py) define filters and responses |
| Menu | `GET /menus/bar/{bar_id}`, `GET /menus/{menu_id}/full`, item APIs under `/menus/{menu_id}/items`; [menu routes](../be/app/bars_and_restaurants/routes/menus.py) |
| Location | `GET /bars/{bar_id}/location-config`, `GET /bars/{bar_id}/spots/{spot_id}/availability`; proximity and check-in acceptance remain spec requirements requiring verification |
| Profile/privacy | `GET/PUT /me/profile`, `/me/notification-preferences`, `/me/privacy-settings`, `DELETE /me/data`; [profile routes](../be/app/auth/profile.py) |
| Cart | `/cart/`, `/cart/items`, `POST /cart/calculate`, `POST /cart/sync`, `POST /cart/checkout`; [routes](../be/app/bars_and_restaurants/routes/cart.py), [schemas](../be/app/bars_and_restaurants/schemas/cart.py) |
| Orders | `GET /orders/user/me`, `GET /orders/{order_id}`, `GET /orders/{order_id}/timeline`; [order routes](../be/app/bars_and_restaurants/routes/orders.py) |

`POST /cart/checkout` requires `order_type` and `payment_method`; optional fields include `tip`, `coupon_code`, `payment_details`, `location_identifier`, `active_promotion_ids`, delivery fields, and notes. It returns `order_id`, `status`, `payment_status`, `total`, optional `payment_id`, `estimated_ready_time`, `pix_qr_code`, `pix_copia_e_cola`, and `pix_expires_at`. JSON `payment_details` is currently generic; it must not be interpreted as proof that card handling is safe or provider-tokenized. Server cart recalculation and actual provider outcomes need the acceptance checks in the checkout specs.

## Payments

- `POST /payments/v2/charge`: `{order_id: int, bar_id: int, amount: float, currency, country, payment_method: {type, token?, provider?, pix_key?, installments?}, customer_info?, metadata?, description?, proration_info?}`. `X-Idempotency-Key` is accepted and otherwise generated. `user_id` comes from authentication. Response includes `{payment_id, status, gateway, gateway_id, amount, currency, created_at}` and optional Pix/card/proration fields.
- `POST /payments/v2/refund` and `GET /payments/v2/{payment_id}` use BE currency-unit `amount` fields; the BE/DPE bridge converts cents. Do not copy DPE cent fields directly into these FE requests.
- `POST /pix/generate`: `{order_id: int, bar_id: int, amount: float, description?, payer_name?, payer_document?, expires_in?}` → `{pix_id, brcode, qr_code_base64, expires_at, status}`. This shape is separate from the charge/checkout `pix_*` fields.
- `/me/cards` stores provider references with display metadata through `card_token`, `last_four`, `brand`, expiry, and `is_default`. Legacy `/payments/charge` accepts raw card fields; migration/security work belongs to the card spec.
- See [payment schemas](../be/app/payment/schemas.py), [routes](../be/app/payment/routes.py), and the [BE ↔ DPE contract](BE_DPE_COMMUNICATION.md). A QR being displayed, an HTTP 200, or a browser redirect does not prove settlement.

## Business journeys

| Capability | Current interfaces |
|---|---|
| Onboarding/menu import | `POST /bars/wizard`, `POST /menus/extract`, `POST /menus/extract-url`; resumability and AI failures need workflow validation |
| Live cashier | `GET /bars/{bar_id}/orders/live`, `PUT /bars/{bar_id}/orders/{order_id}/status` with `{status, notes?}`; mutation requires `order:process` |
| Campaigns | `/advertising/campaigns`, publish/pause/resume/delete routes, summary/analytics endpoints; [advertising routes](../be/app/advertising/routes.py) |
| Rate card | `GET /advertising/rates`; use [response schemas](../be/app/advertising/schemas.py) and current [rate-card test](../be/tests/test_advertising_contract.py), not archived response examples |
| Plans/subscriptions | `GET /advertising/plans`, `GET /advertising/my-plan`, `POST /advertising/subscribe`, `/advertising/invoices`; [subscription service](../be/app/advertising/services/subscription_service.py) |
| Trial/upgrade | `POST /subscriptions/trial/setup`, `POST /subscriptions/capture`, `POST /payments/v2/charge/upgrade`; these are existing APIs, not Stripe Checkout/Portal support |
| Business settings | `GET/PUT /bars/{bar_id}/details`, `GET/PUT /bars/{bar_id}/contact`, `DELETE /bars/{bar_id}/data`, deactivate/reactivate routes; [settings](../be/app/bars_and_restaurants/routes/business_settings.py) |

Current order transitions include `pending → confirmed → preparing → ready → completed` and cancellation branches. The shared MVP target is **Pending → Preparing → Ready → Completed**. Preserve compatibility and migrate deliberately; do not change wire state values solely because this summary states intent. Current live-event implementations and replay/reconnect behavior must be checked in [orders](../be/app/bars_and_restaurants/routes/orders.py) and [connection manager](../be/app/bars_and_restaurants/services/connection_manager.py) before claiming parity between cashier and client.

## Staff and invitation pilot

- `GET /bars/{bar_id}/staff` → members with integer `id`, `user_id`, `bar_id`, `role`, `is_active`, and optional `nickname`, `employee_id`, `display_name`, `email`, `phone`; requires `staff:view`.
- `POST /bars/{bar_id}/staff/invite` body `{contact, role}` → `{id: int, bar_id, email?, phone?, role, status, invitation_code, expires_at}`; requires `staff:manage`. Alternative `POST /staff/invite` also accepts `bar_id` and has separate role-hierarchy checks.
- `PUT /bars/{bar_id}/staff/{staff_id}/role` accepts `{role}`; `DELETE /bars/{bar_id}/staff/{staff_id}` removes access. Actual responses are message/update acknowledgements, not full member records.
- Current `POST /me/bars/accept-invitation` takes **query parameter** `invitation_code` plus authentication; response is `{message, bar_id, role}`. FE currently sends a JSON body and expects workspace fields that are absent. The new acceptance contract must be implemented through the pilot, not described as deployed.
- Both invite paths can currently grant existing users membership immediately; acceptance checks pending/expiry but not verified contact matching. FE also expects `invite_id` while BE returns integer `id`. Delivery and permission enforcement differ between routes. See [staff routes](../be/app/bars_and_restaurants/routes/staff.py), [alternate invite route](../be/app/bars_and_restaurants/routes/staff_invite.py), and [FE data source](../fe/lib/features/staff/data/datasources/staff_remote_data_source.dart).

MVP target: authenticate using existing methods, resume the invitation, match the verified contact, and accept explicitly before membership. The invitation specs define expiry/revocation/wrong-account/retry and workspace-entry acceptance tests. These gaps remain open until independently verified.
