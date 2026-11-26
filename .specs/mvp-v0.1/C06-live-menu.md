---
id: "C06"
title: "Live venue menu"
owner: "frontend"
areas: ["fe", "be"]
priority: "P0"
depends_on: ["C02"]
source_requirements: ["MVP-C06-01", "MVP-C06-02", "MVP-C06-03", "MVP-C06-04", "MVP-C06-05", "MVP-C06-06"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "in_progress"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "native-device"]
---

# C06: Live venue menu

## Intended behavior

Deliver the live venue menu journey for the Belo Horizonte MVP. Customer validation includes Android and iOS. Acceptance criteria below define the required observable outcome.

Menu reads are open to every logged-in user, including customers of any venue. Every menu and item mutation requires the matching permission at the venue that owns the menu.

## Current implementation evidence and gaps

Reviewed at PR #5 (`taiga_sessions_task_5`, head `e7bbd6fe`), assessed as merged into `main` at `9e352917`.

- The PR branch was based on an old `main` and listed 26 files, including `be/.coverage` and a `be/Dockerfile` change. It was rebased onto `main` (`9e352917`) on 2026-11-26. Its C06 delta is three files: [menus.py](../../be/app/bars_and_restaurants/routes/menus.py), [rbac_models.py](../../be/app/auth/rbac_models.py) and `be/tests/test_menu_authorization.py` (on the PR branch only). The same push adds fixes for the test breakages below and for CodeRabbit comments (see Delivery).

**Delivered (BE mutation authorization):**

- Every mutation in `menus.py` resolves the venue from the **stored** menu, then requires the permission there through the shared `authorize_bar_permission` resolver (role defaults plus custom permissions). The `bar_id` query parameter and the `X-Bar-Id` header are ignored, so a caller cannot be authorized at one venue and change another's menu.
  - `menu:create`: create a menu (venue from the body `bar_id`), add an item, bulk-add items.
  - `menu:edit`: update a menu, update an item, toggle availability.
  - `menu:delete`: delete a menu, delete an item.
- Item routes check that the item belongs to the authorized menu, so an item from another venue can't be reached through your own menu (returns 404). `MenuUpdate` and `MenuItemUpdate` have no `bar_id`/`menu_id`, so an update can't move a menu or item to another venue.
- Mutations emit the `X-Bar-*` headers. Response shapes are unchanged (shape tests per route).
- No other backend module writes `menus` or `menu_items`.
- **Role default change:** managers gain `menu:create` (they already had `menu:edit`). Deleting stays with owner and admin. Decided (D2).
- **Compatibility change:** all GETs on `/menus` now require an authenticated, active user; on `main` they were public. The Flutter app sends a token on every route except login, MFA, biometry and invitation acceptance, so in-app browsing is unaffected. Anonymous external callers would get 401 (none found in the repo). Decided (D1).

**Tests:** `test_menu_authorization.py` (137 tests):

- The 8 mutations are each tested as anonymous, a customer, another venue's owner, an inactive member, view-only roles (staff, cashier) and a custom grant for a different action. In every rejected case, nothing changes.
- They're also tested with header or query venue spoofing, owner/admin allowed, exact custom grants, manager defaults, cross-venue items, 404s and response shapes.
- Browsing is tested as anonymous (401), an invalid token (401), an inactive user (403), a logged-in customer, and another venue's staff.

**Test breakages caused by closing the open routes (fixed in `3d031841`):** 8 tests that passed on `main` failed on the merged tree. All 8 depended on the open routes this PR closes, so the fixtures were wrong, not the authorization.

- `test_bars.py::TestBulkMenuItems::test_bulk_create_menu_items` posts as a user with no venue membership and gets 403.
- Seven `test_dashboard_stats.py` tests (added by PR #2) called `PUT`/`DELETE /menus/{id}/items/{id}` without a token, through the `rename_menu_item` and `delete_menu_item` helpers, and got 401. The helpers now take the venue member and send their headers; `test_bars.py` gives the user an owner membership at the menu's venue.

**Gaps against C06 (inspection):**

1. **Visibility (AC01, D3):** no read route filters `menus.is_active`, and the app doesn't filter either. Customers see inactive menus. Unavailable items are hidden only when the caller passes `available_only`.
2. **Live updates (AC02, AC03): not implemented.**
   - [realtime_updates.py](../../be/app/bars_and_restaurants/services/realtime_updates.py) only streams order changes.
   - No menu mutation publishes an event.
   - The backend has no menu WebSocket route. Only orders have one: `/ws/orders`, `/ws/bar/{bar_id}/orders` and `/ws/orders/{order_id}/status`.
   - [menu_network_socket_service.dart](../../fe/lib/features/menus/data/datasource/menu_network_socket_service.dart) connects to `"$barId/menus"`, which does not exist.
3. **Promotional price and groups (AC01):** `menu_items.promotional_price` exists in the database but in none of the API schemas, so it can't be read or written. There are no subcategories or item groups (only a flat `category`) and no stock quantity (only the `available` flag).
4. **Availability by floor staff (D4):** toggling availability requires `menu:edit`, so cashiers and staff can't mark an item sold out.
5. **Extraction authorization (B03) duplicates the resolver:** `authorize_menu_extraction` has its own permission code and also requires `accepted_at`, which the shared resolver doesn't. Two rules for one venue could drift.
6. Not assessed in this review: the customer menu UI (categories, quantity controls never going negative) and checkout revalidation (AC04, through C07).

Observed source references:

- [fe/lib/features/menus/presentation/bloc/menus_bloc.dart](../../fe/lib/features/menus/presentation/bloc/menus_bloc.dart)
- [fe/lib/features/menus/data/datasource/menu_network_socket_service.dart](../../fe/lib/features/menus/data/datasource/menu_network_socket_service.dart)
- [be/app/bars_and_restaurants/routes/menus.py](../../be/app/bars_and_restaurants/routes/menus.py)
- [be/app/bars_and_restaurants/services/realtime_updates.py](../../be/app/bars_and_restaurants/services/realtime_updates.py)
- [be/app/bars_and_restaurants/services/connection_manager.py](../../be/app/bars_and_restaurants/services/connection_manager.py)
- [be/app/bars_and_restaurants/models/relational_models.py](../../be/app/bars_and_restaurants/models/relational_models.py) (`MenuItem.promotional_price`)

## Contracts and compatibility

Existing menu/full/items and availability contracts plus menu event payloads; persist authority in BE and revalidate checkout through C07.

- **Mutations:** venue-scoped `menu:create`/`menu:edit`/`menu:delete`, judged on the stored menu's venue. They return 401 without a login and 403 without the permission. Record this in the FE/BE contract.
- **Reads:** require login (D1). Fields added for promotional price or groups must be additive and optional.
- **Menu events:** a new WebSocket, with an initial snapshot and a monotonic version so clients can drop stale events and resync on reconnect.

Use [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces; update canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **C06-AC01** — Menu shows venue-specific categories/subcategories, prices, promotional prices and increment/decrement controls without negative quantity.
- **C06-AC02** — Business price, item availability/quantity and item-group changes update an already-open customer view without manual navigation.
- **C06-AC03** — Disconnected clients display connectivity state and reconcile a fresh snapshot on reconnect so stale data cannot authorize checkout.
- **C06-AC04** — Proceeding from menu triggers cart revalidation and communicates changed/removed selections before charge.

## Product decisions

Decided by product on 2026-11-26:

- **D1 (anonymous browsing): login-only reads for the MVP.** Every menu read requires an authenticated, active user, as PR #5 implements. A public web or QR menu is not part of the MVP; if one is added later, it needs its own public read route rather than opening these.
- **D2 (manager creates menus): yes.** Managers hold `menu:create` by default, so they can add items and import menus as well as edit. Deleting stays with owner and admin. Record it in the B09 permission matrix.
- **D3 (inactive menus): hidden from customers.**
  - Customers and non-members see only active menus. An inactive menu returns 404 from `/{menu_id}`, `/full`, `/items` and `/items/{item_id}`, and is left out of `/bar/{bar_id}`.
  - Members of the venue holding `menu:view` see all of the venue's menus.
  - Response shapes stay the same.
- **D4 (who marks items sold out): a narrower `menu:availability` permission.**
  - `PATCH /menus/{menu_id}/items/{item_id}/availability` accepts either `menu:availability` or `menu:edit` at the menu's venue, so nobody who can toggle today loses access. Price and other edits still need `menu:edit`.
  - Default holders: owner, admin, manager and cashier. Staff do not hold it by default; it can be granted as a custom permission. *This role assignment is the planner's assumption: confirm it, in particular whether cashiers should have it.*
  - Old app builds ignore the unknown permission value (see B09), so rollout is backend first.

## Remaining work and handoffs

Planner ordering:

- BE-0 is done (`3d031841`); CI is green and PR #5 awaits review.
- BE-1, BE-4 and BE-5 are independent of each other and of BE-2. BE-2 and FE-1 go together. BE-3 needs product to confirm the fields.
- VER-1 runs last.

- **BE-0 (backend): done in `3d031841`.**
  - PR #5 was rebased onto `main`, and the 8 fixtures were fixed as described above.
  - The full suite shows no failures beyond `main`'s existing ones (see Evidence).
  - The FE/BE contract now records the 401/403 rules for menu mutations and reads (`docs/FE_BE_COMMUNICATION.md`, latest backend update).
- **BE-1 (backend), C06-AC01, per D3:**
  - Filter inactive menus for callers without `menu:view` at the menu's venue.
  - Tests for: a customer, a member of another venue, a member with `menu:view`, and the inactive menu reached through every read route, including the legacy `/menus/items/{menu_id}`.
- **BE-2 (backend), C06-AC02/AC03:**
  - Add an authenticated menu WebSocket per venue (for example `/ws/bar/{bar_id}/menu`) that sends a full snapshot on connect.
  - Publish a versioned event after every successful mutation in `menus.py` (create, update, delete, bulk, availability), fanned out across app instances like the B05 BE-3 order events.
  - Bump the version on every change, so reconnecting clients resync from a fresh snapshot.
- **BE-3 (backend), C06-AC01:**
  - Expose `promotional_price` in the item schemas (optional, never above `price`).
  - Add optional item groups or subcategories, and stock quantity if product wants it, in an additive migration.
- **BE-4 (backend), per D4:**
  - Add `Permission.MENU_AVAILABILITY = "menu:availability"` and grant it by default to owner, admin, manager and cashier.
  - Make the availability toggle accept `menu:availability` or `menu:edit` at the menu's venue. It keeps the stored-menu venue rule, and the other `menu:edit` routes are unchanged.
  - Tests: cashier allowed; staff rejected; staff with a custom `menu:availability` grant allowed; cashier still rejected on price edit, create and delete; another venue's cashier rejected; the item must belong to the menu.
  - Add the value to `/me/bars` permissions and the FE/BE contract.
- **BE-5 (backend, with B03):** make `authorize_menu_extraction` use `authorize_bar_permission`. Decide whether `accepted_at` still matters for any membership.
- **FE-1 (frontend), C06-AC02/AC03:**
  - Point `MenuSocketService` at the BE-2 route with authentication.
  - Apply events idempotently by version, and refetch the snapshot on reconnect.
  - Show connectivity state, and block checkout while the menu is stale.
- **FE-2 (frontend), C06-AC01:** categories, subcategories and promotional prices (after BE-3), and quantity controls that never go negative. Show the 403 from menu mutations in the business editor.
- **FE-3 (frontend, with C07), C06-AC04:** continuing from the menu triggers cart revalidation and shows changed or removed items before charging.
- **VER-1 (verifier):** after the work above, run the validation scenarios below.

## Validation scenarios and evidence

- Open customer menu and business editor concurrently; change price, stock and category, interrupt socket, reconnect and checkout with a sold-out item.
- **Authorization:** call every mutation as a customer, another venue's owner, an inactive member, staff and cashier: all rejected and nothing changes. Call them as owner/admin/manager and with exact custom grants: allowed per the role table.
- **Visibility (after BE-1):** a customer cannot open an inactive menu through any read route. A member with `menu:view` can.

Evidence at PR #5 head `3d031841` (rebased onto `main` at `9e352917`; macOS, Python 3.12.11, scratch venv; SQLite; `be-unit-tests.yml` env vars; `*_sandbox.py` excluded because those files fail to collect on `main`):

- `pytest tests/test_menu_authorization.py`: passed (137).
- `pytest tests/test_bars.py tests/test_dashboard_stats.py tests/test_menu_authorization.py`: passed (198).
- `pytest tests`: 1316 passed, 45 failed, 41 skipped. `main` alone, same environment: 1175 passed, 46 failed, 41 skipped. No new failures; the 45 also fail on `main` locally (datetime errors in `test_payment.py`, `test_orders_enhanced.py` and `test_wallet.py`). `main`'s own CI passes its backend tests, so these look environmental, but that is not reproduced here.
- `python -m tools.agent_workflow validate` and `--catalog platform validate`: passed. Workflow unit tests (38) and wire-contract tests (3): passed.
- GitHub on `3d031841`: "Run Tests" (4m4s) and "Specs, skills, and workflow checks" both passed. CodeRabbit skipped the review (manual review required for this repository).
- Not run: PostgreSQL, the trending-drinks query (PostgreSQL-only SQL), WebSocket, Flutter, and device or E2E checks.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.
- Record Android and iOS device/OS evidence for native journeys; unavailable device coverage remains blocked or skipped.

## Delivery and verification

Delivery: in progress.

- Venue-scoped mutation authorization is delivered in PR #5 (`3d031841`), with the 8 fixtures fixed. CI is green; it awaits review.
- The same push closes the CodeRabbit comments that were still open on `main`: a disabled user account now holds no bar permissions on sockets (`get_active_bar_permissions`), and the FE/BE contract and the B07 spec were updated. The other comments were already fixed on `main`.
- Inactive-menu visibility, live updates, promotional price and groups, the availability permission, and the FE/checkout work remain.

Verification: unverified. The evidence is deterministic SQLite tests and source inspection only; no product E2E/provider/device checks have run. A passing foundation check validates artifact structure only. Independent verifier must assess every criterion before changing verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-C06-01, MVP-C06-02, MVP-C06-03, MVP-C06-04, MVP-C06-05, MVP-C06-06. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md).
