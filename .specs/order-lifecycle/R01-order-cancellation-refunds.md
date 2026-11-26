---
id: "R01"
title: "Order cancellation and refund requests"
owner: "product"
areas: ["fe", "be", "dpe"]
priority: "P0"
depends_on: []
source_requirements: ["R01-R01", "R01-R02", "R01-R03", "R01-R04", "R01-R05", "R01-R06", "R01-R07", "R01-R08"]
planning_role: "cross-repo-planner"
implementation_roles: ["backend", "frontend", "payments"]
skills: ["dobar-spec", "dobar-cross-repo-plan", "dobar-backend", "dobar-frontend", "dobar-payments"]
delivery_status: "ready"
verification_status: "unverified"
checks: ["foundation", "product-e2e", "provider-sandbox"]
---

# R01: Order cancellation and refund requests

## Intended behavior

Dobar serves on-site consumption. The customer is in the venue while the order is live, so refunds are the venue's decision:

- **Before the venue accepts the order** (status `pending`), the customer may cancel it. If the order was paid, the system refunds it in full automatically.
- **After the venue accepts it** (`confirmed`, `preparing`, `ready`, `completed`), the customer's cancel action becomes a *request* to the venue. The venue approves it (full or partial refund) or declines it.
- **Customers can request a refund only until 24 h after the order's operating day ends.** After that, only the venue can refund.
- **Venues may refund at any time**, limited only by the payment provider's own refund limits.
- Customers never move money directly.

Related journeys (cross-catalog references; the tooling does not track them as dependencies):

- [C11 order tracking](../mvp-v0.1/C11-order-tracking.md): the customer cancels and sees the outcome.
- [B05 cashier live orders](../mvp-v0.1/B05-cashier-live-orders.md): the cashier handles requests.
- [S02 payment reconciliation](../mvp-v0.1/S02-payment-reconciliation.md): refund execution and reconciliation.
- [B04 business dashboard](../mvp-v0.1/B04-business-dashboard.md): refunds reduce net revenue in the period in which they happen.

## Product decisions

Decided by product on 2026-11-26 (recorded with the B04 review of PR #2):

- **D1:** Customers cannot call the refund endpoint. They may cancel only while the order is `pending`; a paid `pending` order is refunded in full automatically.
- **D2:** After `pending`, the customer's app flow stays the same (the same cancel action), but the backend records a request for the venue instead of cancelling. Only the copy for "request sent" changes.
- **D3:** Customer requests are accepted until `order_expiry_utc(order) + 24 h`. `order_expiry_utc` is the B05 operating-day end: the shift close, or 24 h after creation when the venue has no usable hours. A request filed inside the window can be approved later, because venues have no time limit.
- **D4:** Venue-initiated refunds have no Dobar time limit.
- **D5:** Refunds made before the `order_refunds` ledger existed are kept as history. They are imported read-only from DPE records with their original dates. No money moves.

- **D6:** Unanswered requests do not expire. They stay visible to the cashier until the venue approves or declines them, and the window in D3 limits only when a customer may *file* one.
  - *Deferred, not in the MVP:* an "Expired" tab in the cashier view for requests left unanswered past a threshold that product will set. Implement it as a cashier view filter over the same requests, without a new request status, so it can be added later with no migration.
- **D7:** After a venue declines a request, the customer may ask again while the D3 window is open. Each order has at most one *open* request at a time, so repeated taps while a request is open return that same request.

## Current implementation evidence and gaps

Inspected at `8a35c170` (branch `taiga_sessions_task_4`, PR #2). Code was read, not executed, except where noted.

- [order_status.py:54](../../be/app/bars_and_restaurants/services/order_status.py#L54): `CUSTOMER_CANCELLABLE_STATUSES = {"pending", "confirmed"}`. This allows `confirmed`, which contradicts D1. `cancel_order_as_customer` cancels without any refund, so the customer of a paid order loses the money and the venue keeps it.
- [order_payments.py `refundable_order`](../../be/app/payment/order_payments.py): allows the paying consumer to refund, which contradicts D1. On `main`, any authenticated user could refund any `payment_id`. PR #2 closes that.
- The refund ledger (`order_refunds`, migration `dob_96`, not on `main`) and its reconciliation worker exist in PR #2. The following defects were found by CodeRabbit and re-checked during the B04 review:
  - Reconciliation settles individual rows from the payment's aggregate refunded total. **Reproduced:** on R$30 + R$50 refunds that timed out, the ledger kept R$30 while the provider refunded R$50.
  - A retry of a `failed` row does not restore the reservation.
  - A confirmation that lands between the DPE read and settlement causes mis-settlement (a plausible race).
  - A full refund sends `amount=None` to DPE.
  - Confirmed refunds are not replayed on retry.
  - The new per-user hashed key breaks retries that span the deployment.
  - Callers without `X-Idempotency-Key` have no retry key.
  - Downgrading the migration drops the ledger.
- There is no refund-request model, endpoint, notification or cashier UI. There is no refund window check and no historical import.
- Amounts are `Float`. The BE/DPE contract expects integer cents.

## Contracts and compatibility

- **`POST /orders/{id}/cancel`:** keeps its path, request and `OrderSchema` response.
  - A `pending` order becomes `cancelled`. If it was paid, a refund starts with a deterministic idempotency key (`order-cancel:{order_id}`).
  - For later statuses, the order status is unchanged and the response carries an additive `cancellation_request: {id, status, created_at}`.
  - Outside the window, the endpoint returns a stable error code (for example `REFUND_WINDOW_CLOSED`).
  - Deployed apps keep working; a new build shows "request sent".
- **`POST /payments/v2/refund`:** venue staff with `order:refund` at the order's venue only.
  - Customers receive the same 404 as an unknown payment. Venue members without the permission get 403.
  - Sending the reserved amount (never `None`) and per-attempt settlement are recorded in the [BE/DPE contract](../../docs/BE_DPE_COMMUNICATION.md). Retries of refunds made before deployment keep reaching their original DPE entry.
- **New venue endpoints** to list, approve (full or partial amount) and decline requests, plus WS events to the cashier and the customer. Record them in the [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md).
- **Migrations are additive:** a `refund_requests` table, `order_refunds.source` (`live`/`imported`), and integer-cent amounts. The ledger has never been deployed, so `dob_96` may still change as long as no shared database applied it.

## Acceptance criteria

- **R01-AC01** — A customer cancelling their `pending` order gets it cancelled. If it was paid, exactly one full refund is issued and recorded, even under retries or concurrent venue actions. Customer and cashier both see the cancellation and the refund outcome (pending, succeeded or failed).
- **R01-AC02** — A customer cancel action on a `confirmed`, `preparing`, `ready` or `completed` order leaves its status unchanged. It creates a request, or returns the order's existing open request, so an order never has two open requests. The venue's cashier is notified and sees the request until resolving it, with no expiry. The cashier can approve it (full or partial refund through the ledger) or decline it with a reason. The customer sees the outcome and, after a decline, may file a new request while the window is open.
- **R01-AC03** — Customers and unrelated users cannot issue refunds directly. Only active venue members holding `order:refund` at the order's venue can refund, and responses do not reveal whether a payment exists to outsiders.
- **R01-AC04** — Customer requests are accepted until 24 h after the order's operating day ends (`order_expiry_utc`) and rejected afterwards with a stable error code, for venues both with and without operating hours. Venue-initiated refunds are not time-limited by Dobar.
- **R01-AC05** — Each refund moves money at most once, and the ledger reflects each refund exactly once. A refund is settled from its own provider result, never from the payment total. Retries replay recorded results and send the reserved amount. Retries of refunds made before deployment reach their original DPE entry.
- **R01-AC06** — Refunds made before the ledger existed appear in history and in dashboard net revenue with their original dates, imported idempotently without moving money.

## Remaining work and handoffs

Planner ordering:

- BE-1 first: other work builds on the ledger.
- BE-2 is independent and must land before the PR #2 refund changes reach production.
- BE-3 and BE-4 need BE-1.
- BE-5 needs BE-1 and a reviewed dry run.
- FE-1 needs BE-3.
- VER-1 runs last.

- **BE-1 (payments + backend), AC05:**
  - Settle each row from a DPE result tied to its idempotency key, and leave unidentifiable rows unresolved.
  - Restore the reservation before retrying a `failed` row.
  - Persist the confirmed result and replay it on a matching retry. Reject a reused key whose parameters changed.
  - Send the reserved amount to DPE.
  - Store integer cents.
  - Add regression tests for the reproduced R$30/R$50 case and for the race. If DPE lacks a lookup by idempotency key, add one (payments).
- **BE-2 (backend + payments), AC05, compatibility:**
  - A staged mapping or legacy raw-key lookup for retries that span the deployment, keeping per-user scoping.
  - A staged requirement for a client-held `X-Idempotency-Key`.
  - A rollback note: an application rollback keeps the table; a schema downgrade needs the ledger exported first.
  - Confirm that no shared database applied the first version of `dob_96`.
- **BE-3 (backend), AC01–AC04:**
  - Customer-cancellable statuses become `{"pending"}`.
  - A paid cancellation triggers a system refund (key `order-cancel:{order_id}`).
  - Add the `refund_requests` model and venue list/approve/decline endpoints (`order:refund`). An approval issues the refund through the ledger.
  - At most one open request per order (D7): enforce it with a partial unique index on `order_id` where the status is open, so concurrent taps cannot create two. After a decline, a new request is allowed inside the window.
  - Requests have no expiry (D6). Keep `created_at` so a later "Expired" view can filter on age.
  - Add the request window check (`order_expiry_utc + 24 h`).
  - Send WS notifications.
  - Remove the consumer branch of `refundable_order` and update `test_refund_authorization.py`.
  - Document all of the above in the FE/BE contract.
- **BE-4 (backend), AC03:** Run regression tests for refund authorization: customer, other venue, inactive member, member without `order:refund`, and custom grant.
- **BE-5 (backend + payments), AC06:**
  - A one-off, idempotent import of DPE refund records that are missing from the ledger, stored as `succeeded`, `source=imported`, with the original `created_at`.
  - Dry-run output reviewed before writing to production.
- **FE-1 (frontend), AC01/AC02/AC04:**
  - The customer cancel action is unchanged. Show "request sent to the venue" when `cancellation_request` is present, and show the window-closed message on the new error code.
  - The cashier sees open requests, which stay listed until resolved, with approve (amount) and decline (reason) actions. The "Expired" tab is deferred (D6).
  - After a decline, the customer's cancel action is available again while the window is open.
  - Show refund status on the order for both sides.
  - Portuguese l10n.
- **VER-1 (verifier):** Run the validation scenarios on PostgreSQL and the provider sandbox, with two browser cashier sessions and one customer device.

## Validation scenarios and evidence

- **Paid `pending` order cancelled by the customer:** the order is cancelled and one full refund issued. Repeat the cancel, and race it with a venue "confirm": either the cancel wins and the order is refunded once, or the confirm wins and the cancel becomes a request.
- **`preparing` order:** the customer's cancel creates one request and the status is unchanged.
  - The venue approves a partial amount: the ledger shows a succeeded refund for that amount, and B04 net revenue drops in the approval period.
  - The venue declines: nothing changes and the customer sees the reason. The customer asks again inside the window and a new request appears; outside the window the request is rejected.
  - The customer taps cancel twice, including concurrently, while a request is open: only one open request exists.
  - A request left unanswered for days is still listed for the cashier and can still be approved.
- **Request window:** a request at `order_expiry_utc + 24 h − 1 min` is accepted; at `+ 24 h + 1 min` it is rejected. A venue refund after the window succeeds. Check venues with and without operating hours.
- **Authorization:** a customer, another venue's owner, an inactive member and a cashier without `order:refund` each call `/payments/v2/refund` and are rejected.
- **Unknown outcomes:** timeouts before and after money moves, two pending refunds settled independently, a retry that spans the deployment, and replay of a confirmed refund while DPE is down.
- **Historical import:** the import dry run equals the DPE records; a re-run is a no-op.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion. Missing provider access is blocked, not a passing mock.

## Delivery and verification

Delivery: ready for planning and implementation. Parts of the ledger exist in PR #2 with the defects listed above; no R01 behavior is complete. Verification: unverified. Only source inspection and one mocked reproduction exist. A passing foundation check validates artifact structure only.

## Source requirements

See [requirement coverage](requirements.json). The source is the product decisions of 2026-11-26 recorded above and in [B04](../mvp-v0.1/B04-business-dashboard.md).
