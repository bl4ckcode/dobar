### 1. Secure menu and item mutations

**Spec:** [C06: Live menu](../../.specs/mvp-v0.1/C06-live-menu.md), with server authorization as a prerequisite for reliable business-side updates.

**Concrete starting point:** Several mutation routes in [menus.py](../../be/app/bars_and_restaurants/routes/menus.py#L48), including menu creation and item updates, have no authentication dependency. The bulk item route authenticates a user but does not visibly check that user’s permission for the menu’s venue.

**Task:** Apply venue-scoped menu permissions to every menu and item mutation while preserving customer menu browsing and existing API shapes.

The agent can work through:

1. Inventory creation, update, delete, bulk and availability routes, including legacy paths.
2. Map each operation to the existing `MENU_CREATE`, `MENU_EDIT` or `MENU_DELETE` permission.
3. Resolve the venue from the target menu or item and reject unauthenticated, unauthorized and cross-venue requests.
4. Cover custom permissions and mismatched menu/item IDs.
5. Preserve read-only customer access, response shapes and existing mutation behavior.
6. Add route-level tests proving rejected requests do not change data.

This task does not require a menu provider or live credentials. Real-time propagation and customer-device behavior remain separate C06 verification.

### 2. Secure the legacy global order-change WebSocket

**Spec:** [C11: Customer order tracking](../../.specs/mvp-v0.1/C11-order-tracking.md), especially authenticated order visibility.

**Concrete starting point:** [orders.py](../../be/app/bars_and_restaurants/routes/orders.py#L38) exposes a WebSocket without an authentication check. Its [change-stream service](../../be/app/bars_and_restaurants/services/realtime_updates.py#L4) watches the MongoDB orders collection with an empty filter and forwards changes. The separate order-specific tracker already checks the customer’s ownership, but this legacy stream needs its own compatibility and access review.

**Task:** Prevent unauthorized or cross-customer order data from reaching subscribers of the legacy stream, while preserving an explicit migration path for legitimate existing clients.

The agent can work through:

1. Trace the actual WebSocket path, payloads and known callers before changing it.
2. Define who may subscribe and which order or venue each subscriber may observe.
3. Authenticate before streaming and enforce ownership or venue permission server-side.
4. Filter the change stream and avoid exposing unrelated document data.
5. Handle invalid tokens, disconnects and database-stream failures without leaking details.
6. Test multiple users and venues with a mocked change stream, including attempts to subscribe to another user’s orders.

The agent should document any client migration needed rather than silently removing the endpoint. Mocked stream tests can validate filtering logic; real MongoDB change-stream behavior and device reconnects would still need separate verification.

For either task, the filtered backend currently includes the shared test fixture but not the original menu or order-tracking test suites. The sandbox agent can create focused tests, or you can review and include sanitized copies of relevant quarantined tests.