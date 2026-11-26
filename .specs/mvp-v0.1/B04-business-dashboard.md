---
id: "B04"
title: "Business dashboard and shortcuts"
owner: "frontend"
areas: ["fe", "be"]
priority: "P1"
depends_on: ["B01"]
source_requirements: ["MVP-B04-01", "MVP-B04-02", "MVP-B04-03", "MVP-PRINCIPLE-04"]
planning_role: "cross-repo-planner"
implementation_roles: ["frontend", "backend"]
skills: ["dobar-spec", "dobar-frontend", "dobar-backend"]
delivery_status: "in_progress"
verification_status: "unverified"
checks: ["foundation", "product-e2e"]
---

# B04: Business dashboard and shortcuts

## Intended behavior

Deliver the business dashboard and shortcuts journey for the Belo Horizonte MVP. Business validation includes responsive browsers. Acceptance criteria below define the required observable outcome.

Members with `analytics:view` (owner, admin and manager by default, or a custom grant) see sales metrics built only from Dobar sales:

- revenue: gross paid sales, refunds and net;
- total orders;
- average ticket;
- top items.

Staff without that permission still use the dashboard for operations (venue status, active orders, shortcuts). Only the financial metrics are withheld from them.

The dashboard makes no profit claim and no savings claim (see D2 and D3).

## Current implementation evidence and gaps

Reviewed at `8a35c170` (branch `taiga_sessions_task_4`, PR #2). The PR also carries B05 order-expiry and B07 staff-invitation work. Only the B04-relevant parts are assessed here.

**Delivered (BE stats endpoint), `GET /bars/{bar_id}/dashboard/stats`, in [dashboard.py](../../be/app/bars_and_restaurants/routes/dashboard.py):**

- Requires venue-scoped `analytics:view` (was `bar:view`). It uses the active `bar_staff` row plus custom permissions. Other-venue, inactive and unauthenticated callers are rejected before any query.
- Revenue counts only orders with `payment_status = "paid"` that are not cancelled, net of `order_refunds` rows in `pending`/`succeeded`. Fully refunded orders drop out.
- The average ticket is computed over exactly the orders in revenue (previously revenue divided by *completed* orders).
- Top items use the same order set and the same `[start, end)` window. The previous end boundary was missing. The label is the sold-name snapshot, so items that were renamed or deleted keep their label.
- Periods are venue-local calendar periods (`bars.timezone`, default `America/Sao_Paulo`). The comparison window covers the same elapsed time and is clamped so it never overlaps the current period.
- The response shape is unchanged (`test_response_shape_is_preserved`).

The original task's acceptance is met by deterministic tests: role/custom/venue/inactive authorization, periods, payment/status cases, empty data and venue isolation.

Two parts of this delivery now conflict with product decisions:

- Refunds reduce the period in which the *order* was created, but D4 attributes them to the period of the *refund*.
- A fully refunded order is removed from the order set entirely. Under D4 it stays a sale in its own period and its refund counts in the refund's period.

**Added beyond the task (refund ledger), in [order_payments.py](../../be/app/payment/order_payments.py), [payment/routes.py](../../be/app/payment/routes.py) and [dob_96_order_refunds.py](../../be/migrations/versions/dob_96_order_refunds.py):**

- New `order_refunds` table (migration head `dob_96_order_refunds`). The migration is **not on `main`**. It was edited within the unmerged branch (commits `11958871` then `b2319f7f`), which is acceptable only if no shared database has applied the first version. Confirm this before merge. Amounts are `Float`, not integer cents.
- `POST /payments/v2/refund` now authorizes the caller. On `main`, **any authenticated user could refund any `payment_id`**, so this closes a real hole. The PR allows the paying consumer or venue staff with `order:refund`. D5 removes the consumer path.
- The route now scopes the idempotency key per user (SHA-256), writes a pending row before calling DPE, and returns 504/503 when the refund outcome is unknown.
- A new reconciliation worker runs in the app lifespan.
- Neither the FE/BE nor the BE/DPE contract documents any of these changes.

**Customer cancellation (existing, inspection), in [order_status.py](../../be/app/bars_and_restaurants/services/order_status.py):**

- `CUSTOMER_CANCELLABLE_STATUSES = {"pending", "confirmed"}`.
- `cancel_order_as_customer` sets `cancelled` without refunding. The customer of a paid order loses the money, the venue keeps it, and the dashboard excludes it from revenue.
- This conflicts with D5.

**Open defects (from CodeRabbit on PR #2, re-checked here):**

| Thread | Area | Status here | Effect on B04 |
| --- | --- | --- | --- |
| dashboard.py:138 | Refunds issued before the ledger are not subtracted | Confirmed by inspection. D6 decides the fix (historical import) | Net revenue overstated in periods that had pre-ledger refunds |
| order_payments.py:401 | Reconciliation settles individual rows from the payment's aggregate refunded total | **Reproduced.** On a R$100 order, A=R$30 timed out before moving money and B=R$50 timed out after. Result: A succeeded, B failed, and the dashboard shows **R$70 instead of R$50** | Revenue overstated |
| order_payments.py:393 | A confirmation that lands between the DPE read and settlement causes mis-settlement | Plausible (race). Not reproduced | Revenue misstated |
| order_payments.py:335 | A retry of a `failed` row does not restore the reservation | Confirmed by inspection | Money moved but not deducted |
| routes.py:267 | A full refund sends `amount=None` to DPE while the ledger reserves the remainder | Partly reproduced. In the tested path the total settles correctly (R$0), but rows are misattributed (A marked succeeded without moving money) | Attribution and audit risk |
| routes.py:251 (×2), 257 | The hashed key breaks retries that span the deployment. Callers without a header have no retry key. Confirmed refunds are not replayed | Confirmed by inspection | Double-refund risk. Not a dashboard bug, but it moves money |
| dob_96:51 | Downgrade drops the ledger | Confirmed | Operational |

**Other BE gaps:**

- `GET /bars/{id}/status` and `POST /bars/{id}/status/toggle` use the UTC weekday and time, not the venue timezone ([dashboard.py:463](../../be/app/bars_and_restaurants/routes/dashboard.py#L463), [:478](../../be/app/bars_and_restaurants/routes/dashboard.py#L478)). The open/closed header is wrong from 21:00 to 24:00 in São Paulo. This predates PR #2.

**FE gaps, by inspection of [business_dashboard_page.dart](../../fe/lib/ui/business/business_dashboard_page.dart) and [dashboard_bloc.dart](../../fe/lib/features/bars/presentation/bloc/dashboard_bloc.dart). No FE dashboard tests exist:**

1. **Compatibility regression introduced by the BE change.** `_onLoadDashboard` loads stats, status and orders together in one `Future.wait`. Cashier and staff now get 403 on stats, so the whole load fails. They then see "0 pending", an empty live queue and a default "open" header, where before the change they saw real operational data. `DashboardError` is never rendered.
2. AC03: loading, failure and no-data all render as `R$ 0` / `0`. Refresh failures are silently swallowed.
3. AC01: only revenue, active orders and average ticket are shown. They are gated by **role** (owner/admin) rather than by `analytics:view`, so managers are wrongly hidden from them (D1). There is no total-orders card, no refunds breakdown and no top items. There is no period selector, although the bloc accepts `period`; the labels are fixed to "Today's … vs yesterday". Strings are hard-coded English, not localized Portuguese.
4. AC02: tapping a live-queue order does nothing ([line 601](../../fe/lib/ui/business/business_dashboard_page.dart#L601)). The Cashier shortcut exists. There is no campaign *summary*, only a promote CTA and a "New Promo" chip, and both are gated by role instead of `ads:view`.

## Contracts and compatibility

Dashboard stats and order summaries are scoped by venue and time range. Campaigns require `ads:view`, and financial metrics require `analytics:view`.

- **Stats endpoint (changed):** requires `analytics:view` and returns 403 `Missing permission: analytics:view` otherwise. Deployed FE builds call it for every staff role, so the FE must tolerate this 403 before or together with the BE rollout (FE-1). Record the change in the [FE/BE contract](../../docs/FE_BE_COMMUNICATION.md).
- **Refunds breakdown (D4):** add it as new fields on `revenue`: `gross`, `refunded`, and `total` (which stays the net). Do not repurpose existing fields. `total` may be negative in a period where refunds exceed sales.
- **Cancellation, refund requests and refund-endpoint changes (D5, D6):** owned by [R01](../order-lifecycle/R01-order-cancellation-refunds.md), including the BE/DPE refund contract.

Preserve deployed callers and existing data.

## Acceptance criteria

- **B04-AC01** — The dashboard of a member holding `analytics:view` shows backend-derived revenue (gross paid sales, refunds and net), total orders, average ticket and top items. Each metric shows its period and BRL units, and refunds are attributed to the period in which they occurred. There is no profit or savings figure (D2, D3).
- **B04-AC02** — Order summary opens the selected venue cashier/live orders; campaign summary opens that venue campaigns when ads:view is granted.
- **B04-AC03** — No-data, loading and failed metrics are distinguished from zero, and unauthorized users cannot retrieve financial data by direct API access.

## Product decisions

Decided by product on 2026-11-26:

- **D1 (financial audience):** Financial metrics follow the `analytics:view` permission, not the role. Managers keep it by default. The FE gates on the permission.
- **D2 (profit): dropped for the MVP.** Dobar sees only its own sales and has no ERP or cost integration, so it cannot derive profit. AC01 shows revenue and sales statistics only.
- **D3 (economy): dropped.** The [market analysis](../../docs/q4_2026/Dobar_Market_Analysis_Brazil_2026.pdf) (§3.4, §6.2) shows that Pagar.me card-not-present fees (about 3.5–3.7% blended) are higher than card-machine fees (0.57–2.69%). It recommends against claiming lower fees than a machine. A per-venue "economy versus card machine" figure would therefore be false or would depend on unverifiable assumptions (PDV cost, marketing spend, uplift). The source requirement MVP-B04-01 keeps its text, but AC01 deliberately excludes these figures.
  - **Proposed for later (not in AC01):** a value metric that is factual and backend-derivable, for example *new versus returning customers* in the period. This is the customer-acquisition story the analysis recommends (§4.4). If product wants it in the MVP, add it as a new acceptance ID.
- **D4 (refund attribution):** A refund reduces net revenue in the period when it was requested (`order_refunds.created_at`), not the period of the original order.
  - Gross sales and order counts for past periods do not change after a refund.
  - Pending refunds still count, at their request time.
  - The average ticket and top items use gross paid sales, so refunds do not distort them.
- **D5 (who can cancel or refund):** Customers cannot refund directly. A customer may cancel only while the order is `pending`; a paid `pending` order is refunded in full automatically. After that, the customer's cancel action becomes a request that the venue approves or declines. Specified in [R01](../order-lifecycle/R01-order-cancellation-refunds.md).
- **D6 (refund window and history):**
  - Customers can request a refund only until **24 h after the order's operating day ends** (the B05 `order_expiry_utc`). After that, only the venue can refund.
  - Venues may refund at any time, including approving a request after the window.
  - Refunds made before the ledger existed are kept as history and imported read-only with their original dates.
  - Specified in R01.

## Remaining work and handoffs

Planner ordering:

- BE-1 is done.
- FE-1 must ship with or before the BE stats permission change reaches production.
- FE-3 needs BE-4.
- Net revenue is trustworthy only once R01 BE-1, BE-2 and BE-5 land (refund correctness and the historical import). Until then, B04-AC01 cannot be verified.
- VER-1 runs last.

Refund correctness, cancellation, refund requests, the refund window and the historical import are owned by [R01](../order-lifecycle/R01-order-cancellation-refunds.md). They are not repeated here.

- **BE-1 (backend), B04-AC01/AC03: done.** Stats endpoint authorization, paid/non-cancelled revenue, a consistent order set for average ticket and top items, venue-local periods, and a preserved response shape. Tests: [test_dashboard_stats.py](../../be/tests/test_dashboard_stats.py).
- **BE-2 and BE-3:** moved to R01 as BE-1 (refund settlement correctness) and BE-2 (key compatibility, rollback, `dob_96`, integer cents).
- **BE-4 (backend), B04-AC01, per D4:**
  - Compute gross sales from paid, non-cancelled orders created in the window. Compute refunds as `pending`/`succeeded` ledger rows *created* in the window, so net = gross − refunds.
  - Keep fully refunded orders in gross sales, the order count, the average ticket and top items for their own period.
  - Add `revenue.gross` and `revenue.refunded` (additive). `revenue.total` stays the net.
  - Update the tests: `test_refund_counts_against_the_period_the_order_was_placed_in` inverts, and the full-refund tests change.
  - Document the fields in the FE/BE contract.
- **BE-5 (backend):** Compute venue status and the open/closed toggle in the venue timezone. Document the stats 403 and the refund changes in both contracts.
- **BE-6 and BE-7:** moved to R01 as BE-3 (cancellation, refund requests, window) and BE-5 (historical import).
- **FE-1 (frontend), B04-AC03, compatibility regression, highest priority:**
  - Load stats only when the bar context grants `analytics:view` (the `X-Bar-Permissions` header or the session's bar access).
  - Load status and orders independently, so one failing call cannot blank the dashboard.
  - Derive "Active orders" from `/status` `active_orders_count` or `/orders`, not from stats.
- **FE-2 (frontend), B04-AC03:**
  - Render separate loading, error-with-retry and no-data states. Never show `R$ 0` for an unknown value.
  - Surface refresh failures.
  - Add bloc and widget tests for cashier (no analytics), manager, owner, stats failure and empty data.
- **FE-3 (frontend), B04-AC01, after BE-4:**
  - Add cards for net revenue (with a gross and refunds breakdown), total orders, average ticket and top items, with period/BRL units and a today/week/month selector.
  - Gate by `analytics:view` (D1).
  - Use Portuguese localized strings through the existing l10n setup.
  - Responsive browser layout.
  - Show no profit or economy card.
- **FE-4 (frontend), B04-AC02:**
  - Tapping a live-queue order opens the selected venue's cashier/live orders.
  - Add a campaign summary card (from the advertising analytics routes) that opens the campaigns page, shown only when `ads:view` is granted.
- **FE-5:** moved to R01 as FE-1.
- **Unrelated to B04 (found in the same PR):** `tests/test_pending_invitations.py::test_discovery_failure_is_not_empty_list` (B07) fails on the branch and passes on `main`. The new `sanitized_invitation_errors` raises `APIError(500)` where the test expects `RuntimeError`. Update either the test or the intended behavior under B07.
- **VER-1 (verifier):** After BE-4, BE-5, FE-1 to FE-4 and the R01 refund-correctness tasks, run the validation scenarios below on PostgreSQL and with a browser, and record evidence per criterion.

## Validation scenarios and evidence

- Seed paid/unpaid/refunded orders and campaign data; compare displayed aggregates, shortcuts and selected venue against backend, then test permission denial.
- **Refund attribution:** an order paid yesterday and refunded today counts as gross sales yesterday and as a refund today. Yesterday's numbers do not change.
- **Refund outcomes:** independently verify paid, pending, failed, cancelled, full/partial refund and unknown refund outcomes, imported historical refunds, and failed/retried reconciliation against authoritative provider-backed data. Confirm the item-revenue definition and the behavior for deleted/renamed items.
- **Cancellation:**
  - A customer cancels a paid `pending` order: the order is cancelled and refunded in full.
  - The customer cancels a `confirmed`/`preparing` order: the status is unchanged and a request is visible to the cashier. Approval refunds the order; decline leaves it unchanged.
  - A customer calling `/payments/v2/refund` is rejected.
- **Refund window:** a refund or request at `order_expiry_utc + 24 h − 1 min` is accepted; at `+ 24 h + 1 min` it is rejected. Check venues with and without operating hours.
- **Migration and permissions:** validate the migration and existing-data upgrade on PostgreSQL. Test cross-venue and financial permission boundaries, including manager and custom-permission policy. Test provider sandbox outcomes and concurrent refund reconciliation separately from mocks.
- **Non-financial staff:** log in as a cashier and as staff. The dashboard still shows venue status and active orders, and the stats request is not made or its 403 is handled.
- Run configured foundation checks and affected-area contract/unit checks before product E2E. Record exact commit, command, environment, fixture/account roles, result and artifact references for each criterion.

Evidence at `8a35c170` (macOS, Python 3.12.11, scratch venv with `requirements.txt`, `requirements-test.txt` and `../dpe[all]`; SQLite fixtures, mocked DPE; `be-unit-tests.yml` env vars):

- `pytest tests/test_dashboard_stats.py tests/test_refund_authorization.py`: passed (66).
- `pytest tests --ignore-glob='tests/*_sandbox.py'`: 1167 passed, 46 failed, 41 skipped.
  - 45 of the failures also fail on `main` under the same environment (`test_payment.py`, `test_orders_enhanced.py`, `test_wallet.py`). They are pre-existing.
  - One failure is new (the B07 test above).
  - `test_*_sandbox.py` fails to collect on both `main` and the branch, because `app.payment` no longer exports the gateway classes it imports. Pre-existing.
- Scratch probe outside the repo, using the suite's `FakeDPE`: the BE-2 aggregate-settlement case reproduced (provider refunded R$50, dashboard revenue R$70).
- `python -m tools.agent_workflow validate`: passed (no findings).
- `flutter analyze` on the dashboard page and bloc (Flutter 3.47.1): no issues.
- Not run: PostgreSQL, Redis/Mongo-backed paths, DPE/provider sandbox, browser or device E2E, CI on GitHub.

## Delivery and verification

Delivery: in progress.

- BE-1 (stats endpoint) is delivered. Its refund attribution must change per D4 (BE-4).
- Remaining in B04: refund-date attribution and the breakdown fields (BE-4), venue-timezone status and contract notes (BE-5), state handling (FE-2), metric cards (FE-3) and shortcuts (FE-4).
- Refund-ledger correctness and the historical import are tracked in R01, and net revenue depends on them.
- FE-1 fixes a regression that the BE change introduces for cashier and staff. Ship it with the BE change.

Verification: unverified. The evidence is deterministic tests against SQLite with mocked DPE, plus source inspection. No product E2E, provider or device checks have run. A passing foundation check validates artifact structure only. An independent verifier must assess every criterion before changing the verification status.

## Source requirements

See [requirement coverage](requirements.json) for MVP-B04-01, MVP-B04-02, MVP-B04-03. Source: [MVP](../../docs/q4_2026/Dobar_MVP_v0.1.md) and approved launch decisions in [workflow guide](../../docs/AGENT_WORKFLOW.md). MVP-B04-01's profit and economy items are intentionally excluded by D2 and D3.
