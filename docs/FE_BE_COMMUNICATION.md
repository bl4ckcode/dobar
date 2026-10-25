# Frontend ↔ backend communication

Last updated: 2026-10-23

Rolling handoff: keep only the latest frontend update and latest backend update. Replace an area's previous entry when that area changes; retain the other area's latest entry. Git and linked Linear issues own history. Source inspection is not deployment or E2E evidence.

## Contract references

- [Auth/RBAC](../be/app/auth/rbac_models.py), [API errors](../fe/.docs/API_ERROR_CONTRACT.md), [payment schemas](../be/app/payment/schemas.py), [order routes](../be/app/bars_and_restaurants/routes/orders.py).
- [Journey specs](../.specs/mvp-v0.1/README.md) describe intended acceptance; [open findings](AGENT_CONTEXT.md) record unresolved mismatches; [payment boundary](BE_DPE_COMMUNICATION.md) covers BE/DPE.

## Latest frontend update

- Date: 2026-10-22 (last inspected consumer contract; no newer FE change recorded here).
- Scope: [DOB-90](https://linear.app/dobarecosystem/issue/DOB-90), staff invitation acceptance.
- Contract/action: FE sends JSON `invitation_code` and expects workspace fields `bar_id`, `bar_name`, `role`, `permissions`; current BE accepts a query parameter and returns fewer fields. Coordinate B08 before wiring the acceptance page.
- Evidence: [session data source](../fe/lib/features/session/data/datasources/session_datasource.dart), [workspace model](../fe/lib/features/session/domain/models/bar_access.dart). Inspection only; this gap is not fixed or verified by this note.

## Latest backend update

- Date: 2026-10-23.
- Scope: [DOB-85](https://linear.app/dobarecosystem/issue/DOB-85), [B05-AC05](../.specs/mvp-v0.1/B05-cashier-live-orders.md).
- Contract/action: `GET /bars/{bar_id}/orders/live` excludes orders after their creation operating day's closing time in venue-local time, including overnight shifts. No configured hours means previous behavior. FE keeps the existing response shape, preparation states and payment semantics.
- Evidence: [orders implementation](../be/app/bars_and_restaurants/routes/orders.py), [cashier regression tests](../be/tests/test_cashier_operations.py). Source inspected in the working tree; tests/deployment were not rerun for this documentation update.
