---
id: "B05"
title: "Cashier and live order processing"
owner: "frontend"
areas: ["fe", "be"]
priority: "P0"
depends_on: ["B01", "C07"]
source_requirements: ["MVP-B05-01", "MVP-B05-02", "MVP-B05-03", "MVP-PRINCIPLE-02"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "in_progress"
verification_status: "unverified"
checks: ["foundation", "product-e2e"]
---

# B05: Cashier and live order processing

## Intended behavior

Deliver the cashier and live order processing journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

## Current implementation evidence and gaps

Reviewed at commit `5233ab94` ("feat: B05-cashier-live-orders.md"), which implements backend status-route hardening. Follow-up fixes on branch `taiga_sessions` (2026-11-25, uncommitted at the time of writing) resolve gaps 1, 2 and 5. This is source inspection plus deterministic backend and Flutter tests. No product E2E, multi-session browser or device check has run.

**Delivered in `5233ab94` (backend):**

- One shared transition service, [order_status.py](../../be/app/bars_and_restaurants/services/order_status.py). It defines `ORDER_STATUS_TRANSITIONS` with pending→confirmed|preparing|cancelled, confirmed→preparing|cancelled, preparing→ready|cancelled, ready→completed, and completed/cancelled as terminal. Legacy `confirmed` is kept. `pending→preparing` is new, so the four-state pipeline works without the confirm step.
- Compare-and-set write (`_compare_and_set_status`). The UPDATE is conditioned on the status that was validated, the history row is inserted in the same transaction, a lost race re-reads and re-validates (up to 5 attempts, then 409), and the status-change event is published only after commit. Publish failure never undoes the update, and DB errors are logged without being echoed to the client.
- Both HTTP routes delegate to `apply_status_transition` and keep their paths and `OrderSchema` responses. The legacy `PUT /orders/{id}/status` TODO is closed. The customer cancel route and WS `/ws/bar/{bar_id}/orders` commands use the same service, and WS commands re-check `order:process` on every command through `get_active_bar_permissions` in [rbac_middleware.py](../../be/app/auth/rbac_middleware.py).
- `check_order_conflict` in [sync_service.py](../../be/app/bars_and_restaurants/services/sync_service.py) is scoped to the caller's own orders, so it no longer reveals other users' order status.
- Tests: [test_order_status_updates.py](../../be/tests/test_order_status_updates.py) runs 143 tests against SQLite with real JWT/RBAC and a stubbed Redis publisher.

**Observed gaps at `5233ab94` and their state:**

1. **Resolved (BE-1, per D1).** The legacy `PUT /orders/{id}/status` was owner-only (`AuthUser.is_bar_owner`). It now requires `order:process` at the order's bar through `get_active_bar_permissions` ([orders.py](../../be/app/bars_and_restaurants/routes/orders.py)), the same rule as the venue route and WS commands, custom permission grants included. Callers without it get 404 `ORDER_NOT_FOUND`, so order existence and status no longer leak.
2. **Resolved.** `tests/test_orders.py::TestOrderStatusUpdate` encoded the old any-user bypass and was red. It now uses a cashier membership and adds a rejected-customer case.
3. **Open (BE-3), B05-AC02.** HTTP status changes do not reach live sockets. The HTTP routes publish `order.status_changed` to the Redis stream `orders:events`. Its only consumer, [order_worker.py](../../be/app/order_worker.py), is not started by [main.py](../../be/app/main.py) lifespan (only `projection_worker`), and [fly.toml](../../be/fly.toml) has no worker process. Only WS-originated commands notify sockets directly. The Flutter cashier changes status over HTTP (`ApiEndpoints.barOrderStatus` in [live_orders_remote_data_source.dart](../../fe/lib/features/orders/data/data_sources/live_orders_remote_data_source.dart)), so customer trackers and other cashier sessions never receive those changes. `ConnectionManager` is in memory per process, so delivery across machines needs a shared fan-out (Redis).
4. **Open (FE-2, per D2).** Offline cashier status sync is silently dropped. FE `OrderSyncExecutor._executeOrderStatusSync` ([order_sync_executor.dart](../../fe/lib/features/orders/data/sync/order_sync_executor.dart)) posts `operation: 'status_change'` to `POST /orders/sync`. `sync_operations` reads `type`, returns `unknown_operation` and never mutates status, and the FE treats the operation as synced.
5. **Resolved (REV-1).** Out-of-scope edits in `5233ab94` were reverted from its parent: the `email_service.py` production sender/support address, the `ProfileFrame` AppBar (its removal broke `profile_account_widget_test.dart` in Flutter CI) and the Dockerfile DPE TODO. `be/.gitignore` now ignores coverage artifacts. This PR removes `be/.coverage` and `be/coverage.xml` from the tracked tree.
6. **Open, smaller items.**
   - The WS customer tracker sends only a `connected` snapshot plus later events and has no sequence/version field, so B05-AC02 reconnect-without-duplicates is unproven (BE-3/FE-1).
   - No test asserts that `payment_status` is unchanged after a rejected or failed status transition (BE-2).

**Criterion status (deterministic evidence only; product verification remains unverified):**

| Criterion | Backend deterministic evidence | Status |
| --- | --- | --- |
| B05-AC01 | Venue route lifecycle and persistence tests pass. FE cashier flow not exercised. | Partial |
| B05-AC02 | No socket delivery for HTTP-originated changes (gap 3); reconnect not tested. | Failed (inspection) |
| B05-AC03 | Legacy, venue and WS routes all check `order:process` at the order's venue; cross-venue and unauthorized calls are rejected without side effects (tests pass). The sync path is non-mutating but drops queued changes (gap 4, FE-2). | Partial |
| B05-AC04 | CAS prevents regressing completed/cancelled orders; payment fields are untouched by status writes. No explicit payment-invariance test. | Partial |
| B05-AC05 | `compute_order_expiry_utc` tests in `tests/test_cashier_operations.py` pass. | Partial (no E2E) |

Observed source references:

- [fe/lib/ui/business/cashier_page.dart](../../fe/lib/ui/business/cashier_page.dart)
- [fe/lib/features/orders/presentation/bloc/live_orders_bloc.dart](../../fe/lib/features/orders/presentation/bloc/live_orders_bloc.dart)
- [be/app/bars_and_restaurants/routes/orders.py](../../be/app/bars_and_restaurants/routes/orders.py)
- [be/app/bars_and_restaurants/services/order_status.py](../../be/app/bars_and_restaurants/services/order_status.py)
- [be/app/bars_and_restaurants/services/connection_manager.py](../../be/app/bars_and_restaurants/services/connection_manager.py)
- [be/app/order_worker.py](../../be/app/order_worker.py)

## Contracts and compatibility

The canonical order workflow is Pending → Preparing → Ready → Completed. The existing bar-scoped live/status and websocket contracts stay, with compatibility handling for older states: `confirmed` is accepted and displayed as pending by the FE, and `cancelled` is terminal. The paths `PUT /orders/{id}/status`, `PUT /bars/{bar_id}/orders/{id}/status`, `POST /orders/{id}/cancel` and the `/ws/bar/{bar_id}/orders` command shape are unchanged. The legacy route's authorization now matches the venue route (`order:process`, with 404 for outsiders). The new 409 `CONFLICT` on persistent contention and the `pending → preparing` transition are recorded in the [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) backend entry of 2026-11-25.

Use the [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md) for durable interfaces and update the canonical contracts in the implementing change. Preserve deployed callers and existing data.

## Acceptance criteria

- **B05-AC01** — An authorized order operator sees the current venue orders and advances the shared four-state pipeline with persisted backend acknowledgement.
- **B05-AC02** — A status transition immediately reaches connected customer trackers and other authorized cashier sessions, whichever route made it (HTTP or WS). Reconnecting recovers the current snapshot without duplicates.
- **B05-AC03** — Every cashier status mutation route checks venue scope and the `order:process` permission. This includes the legacy general route, the venue route, WS commands and any offline-sync path. Customer cancellation (`POST /orders/{id}/cancel`) is separate: it is authorized by order ownership and cancellation eligibility, not `order:process`. Direct unauthorized or cross-venue mutations are rejected without revealing order state.
- **B05-AC04** — Pending, failed and confirmed payment states remain distinguishable. Retries or simultaneous updates cannot regress a completed order or invent payment success.
- **B05-AC05** — The live cashier excludes orders past their venue's operating-day close. An order expires at the close of the venue operating day (local venue time, `America/Sao_Paulo` for the BH MVP) in which it was created. Overnight shifts that span midnight are covered: an evening order expires at the next-day close, and an early-morning order belongs to the previous day's shift. Bars without configured operating hours keep previous behavior (no expiry). Payment records, API shape and cashier status semantics are unchanged.

## Product decisions

Decided by product on 2026-11-25:

- **D1**: `PUT /orders/{id}/status` accepts any active member with `order:process` at the order's bar, the same rule as the venue route. It is not owner-only. Implemented as BE-1.
- **D2**: Offline status changes retry `PUT /bars/{bar_id}/orders/{id}/status`. `status_change` is not supported through `POST /orders/sync`, so there is one authorized write path. To be implemented as FE-2.

## Remaining work and handoffs

Planner ordering: BE-1 and REV-1 are done. BE-2 and FE-2 are independent of each other. BE-3 must land before FE-1 can be verified end to end. VER-1 runs last.

- **BE-1 (backend), B05-AC03: done.** The legacy route checks `order:process` and returns 404 for outsiders. Tests cover owner/admin/manager/cashier allowed, staff/other-venue/inactive/customer rejected, cross-venue, and custom grants.
- **BE-2 (backend), B05-AC04:**
  - Add tests asserting that `payment_status`/`payment_id` are unchanged after successful, rejected (400), conflicting (409) and failing (500) transitions.
  - Add a test that completing an order with `payment_status` pending or failed does not make it paid.
- **BE-3 (backend, cross-area), B05-AC02:**
  - Deliver `order.status_changed` and `order.cancelled` events to sockets: run the order worker in the app lifespan (as with `projection_worker`), or fan out through Redis pub/sub to every app machine's `ConnectionManager`.
  - Remove the direct notification in `handle_bar_owner_command` once the worker path is live, to avoid duplicates.
  - Add an `updated_at`/sequence field to WS payloads so clients can drop stale or duplicate events after reconnect.
  - Document the change in the FE/BE contract.
- **FE-1 (frontend), B05-AC01/AC02:**
  - Have `LiveOrdersBloc` and the customer tracker apply WS `order_update`/`status_update` idempotently: ignore events older than the held `updated_at`, and refetch `/live` on reconnect.
  - Surface 409 `CONFLICT` as "order changed, refreshing" and refetch.
  - Show `payment_status` separately from the preparation status on cashier cards.
- **FE-2 (frontend), B05-AC03, per D2:**
  - In `OrderSyncExecutor`, send queued status changes through the venue-scoped PUT instead of `POST /orders/sync`.
  - Treat 400 and 404 as a final rejection of the queued change, refetch on 409, and never treat `unknown_operation` as synced.
- **REV-1 (human review): done.**
- **VER-1 (verifier):** After BE-1/BE-2/BE-3/FE-1/FE-2 (offline replay and payment invariance need BE-2 and FE-2), run the validation scenarios below and record the evidence per criterion.

## Validation scenarios and evidence

- Two browser cashier sessions plus one device tracker. Process the full pipeline, disconnect and reconnect, race actions, and call both mutation routes and the sync route as an unrelated account and as a cashier of another venue.
- Run the configured foundation checks and the affected-area contract/unit checks before product E2E. Record the exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

Evidence at `5233ab94` (macOS, Python 3.11.14, scratch venv; SQLite fixtures, Redis stubbed; no real Postgres/Redis):

- `pytest tests/test_order_status_updates.py`: passed (143).
- `pytest tests`: failed (535 passed, 2 failed, 41 skipped); the failures are gap 2.
- `python -m unittest discover -s tools/agent_workflow/tests`: 1 error. `test_deployment_workflows` still expected the `deploy.yml` layout from before `641a8ee3`; this is unrelated to B05.
- Flutter CI: `profile_account_widget_test.dart` failed (gap 5, AppBar removed).

Historical observation after the 2026-11-25 fixes (same environment; Flutter 3.47.1; run on an uncommitted tree, so no SHA identifies it; rerun on an identified commit for VER-1):

- `pytest tests/` with the `be-unit-tests.yml` env: passed (541 passed, 41 skipped).
- `python -m tools.agent_workflow validate`, `--catalog platform validate`, `unittest discover -s tools/agent_workflow/tests` (38 tests) and `-s tools/agent_workflow/contract_tests`: all passed.
- Flutter CI sequence (`pub get`, `gen-l10n`, `build_runner`, `analyze --no-fatal-infos --no-fatal-warnings`, `flutter test test/core/ test/features/`): passed (230 tests; 1 non-fatal analyzer issue).
- `python -m tools.agent_workflow verify --spec B05`: foundation passed; product-e2e blocked (no runner configured).
- Not run: browser multi-session, device tracker, Postgres-backed concurrency, CI on GitHub (CI uses Python 3.12; local runs used 3.11).

## Delivery and verification

Delivery: in progress. Backend route hardening (including BE-1) is delivered and D1/D2 are decided; BE-2, BE-3, FE-1, FE-2 and VER-1 remain. Verification: unverified. The evidence is deterministic backend tests and source inspection only; no product E2E, provider or device checks have run. A passing foundation check validates artifact structure only. An independent verifier must assess every criterion before changing the verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B05-01, MVP-B05-02 and MVP-B05-03. Source: the [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and the approved launch decisions in the [workflow guide](../../docs/AGENT_WORKFLOW.md).
