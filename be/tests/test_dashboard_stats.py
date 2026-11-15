"""
GET /bars/{bar_id}/dashboard/stats

* Only members holding ``analytics:view`` at the bar (owner / admin / manager
  by default, or anyone granted it as a custom permission) may read it.
* Revenue counts only paid, non-cancelled orders; the average ticket and the
  top items are computed over exactly those same orders.
* All metrics use the same period window, in the venue's timezone, and the
  previous-period comparison never overlaps the current period.
* The response shape is unchanged.
"""

import json
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import pytest

from conftest import create_test_token, test_database
from app.auth.auth_models import User
from app.auth.rbac_models import BarStaff
from app.bars_and_restaurants.models.cart_models import OrderItem
from app.bars_and_restaurants.models.relational_models import Bar, Menu, MenuItem, Order
from app.bars_and_restaurants.models.financial_models import OrderRefund
from app.bars_and_restaurants.routes import dashboard
import app.payment.routes as payment_routes
from app.payment.order_payments import complete_order_refund, reconcile_pending_refunds
import httpx


pytestmark = pytest.mark.asyncio

SAO_PAULO = ZoneInfo("America/Sao_Paulo")  # UTC-3, no DST since 2019

# Wednesday 2026-03-11 12:00 in Sao Paulo.
NOW = datetime(2026, 3, 11, 15, 0, tzinfo=timezone.utc)
# Period windows at NOW, as naive UTC (how orders are stored).
TODAY_START = datetime(2026, 3, 11, 3, 0)        # Wed 00:00 local
YESTERDAY_START = datetime(2026, 3, 10, 3, 0)    # Tue 00:00 local
YESTERDAY_CUTOFF = datetime(2026, 3, 10, 15, 0)  # Tue 12:00 local (same elapsed time)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_counter = {"n": 0}


def _next():
    _counter["n"] += 1
    return _counter["n"]


@pytest.fixture(autouse=True)
def _dashboard_db(client, monkeypatch):
    """Point the dashboard and payment routes at the test DB and freeze "now"."""
    monkeypatch.setattr(dashboard, "database", test_database)
    monkeypatch.setattr(payment_routes, "database", test_database)
    real_range = dashboard.get_period_range
    monkeypatch.setattr(
        dashboard, "get_period_range",
        lambda period, tz=None, now=None: real_range(period, tz, now or NOW),
    )


async def make_user():
    n = _next()
    user_id = await test_database.execute(User.__table__.insert().values(
        firebase_uid=f"dash-uid-{n}",
        email=f"dash{n}@example.com",
        phone_number=f"+55118{n:08d}",
        is_active=True,
        email_verified=True,
        phone_verified=False,
    ))
    return {"id": user_id}


async def make_bar(tz="America/Sao_Paulo"):
    n = _next()
    return await test_database.execute(Bar.__table__.insert().values(
        name=f"Dash Bar {n}",
        address=f"{n} Dash St",
        phone_number="+5511000000000",
        email=f"dash{n}@bar.test",
        owner_id=1,
        timezone=tz,
    ))


async def add_staff(user_id, bar_id, role, custom_permissions=None, is_active=True):
    await test_database.execute(BarStaff.__table__.insert().values(
        user_id=user_id,
        bar_id=bar_id,
        role=role,
        custom_permissions=json.dumps(custom_permissions) if custom_permissions else None,
        is_active=is_active,
    ))


async def member(bar_id, role="owner", **kwargs):
    user = await make_user()
    await add_staff(user["id"], bar_id, role, **kwargs)
    return user


async def make_menu_item(bar_id, name, price):
    menu_id = await test_database.execute(Menu.__table__.insert().values(name="Menu", bar_id=bar_id))
    return await test_database.execute(MenuItem.__table__.insert().values(
        menu_id=menu_id, name=name, price=price, available=True,
    ))


async def menu_of(menu_item_id):
    return await test_database.fetch_val(
        MenuItem.__table__.select().with_only_columns(MenuItem.menu_id).where(MenuItem.id == menu_item_id)
    )


async def rename_menu_item(client, menu_item_id, name):
    response = await client.put(f"/menus/{await menu_of(menu_item_id)}/items/{menu_item_id}", json={"name": name})
    assert response.status_code == 200, response.text


async def delete_menu_item(client, menu_item_id):
    response = await client.delete(f"/menus/{await menu_of(menu_item_id)}/items/{menu_item_id}")
    assert response.status_code == 200, response.text
    assert await test_database.fetch_one(MenuItem.__table__.select().where(MenuItem.id == menu_item_id)) is None


async def make_order(bar_id, total, *, status="completed", payment_status="paid",
                     created_at=TODAY_START + timedelta(hours=1), items=(), payment_id=None):
    order_id = await test_database.execute(Order.__table__.insert().values(
        bar_id=bar_id,
        status=status,
        payment_status=payment_status,
        payment_id=payment_id,
        total_price=total,
        created_at=created_at,
        updated_at=created_at,
    ))
    for item in items:
        menu_item_id, quantity, unit_price = item[:3]
        if len(item) > 3:
            name = item[3]  # explicit snapshot (None = legacy row without one)
        else:
            # Like checkout: snapshot the menu item's name at order time.
            name = await test_database.fetch_val(
                MenuItem.__table__.select().with_only_columns(MenuItem.name).where(MenuItem.id == menu_item_id)
            )
        await test_database.execute(OrderItem.__table__.insert().values(
            order_id=order_id,
            menu_item_id=menu_item_id,
            menu_item_name=name,
            quantity=quantity,
            unit_price=unit_price,
            total_price=quantity * unit_price,
        ))
    return order_id


def headers_for(user):
    return {"Authorization": f"Bearer {create_test_token(user['id'])}"}


async def get_stats(client, bar_id, user, period=None):
    params = {"period": period} if period else None
    return await client.get(f"/bars/{bar_id}/dashboard/stats", params=params, headers=headers_for(user))


# ---------------------------------------------------------------------------
# Access
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("role", ["owner", "admin", "manager"])
async def test_roles_with_analytics_access_can_read_stats(client, role):
    bar_id = await make_bar()
    user = await member(bar_id, role)

    response = await get_stats(client, bar_id, user)

    assert response.status_code == 200
    assert response.headers["X-Bar-Id"] == str(bar_id)


@pytest.mark.parametrize("role", ["cashier", "staff"])
async def test_roles_without_analytics_access_are_forbidden(client, role):
    bar_id = await make_bar()
    await make_order(bar_id, 100.0)
    user = await member(bar_id, role)

    response = await get_stats(client, bar_id, user)

    assert response.status_code == 403
    assert "revenue" not in response.text


async def test_custom_analytics_permission_grants_access(client):
    bar_id = await make_bar()
    user = await member(bar_id, "staff", custom_permissions=["analytics:view"])

    response = await get_stats(client, bar_id, user)

    assert response.status_code == 200


async def test_role_at_another_bar_does_not_grant_access(client):
    bar_id = await make_bar()
    other_bar_id = await make_bar()
    await make_order(bar_id, 100.0)
    user = await member(other_bar_id, "owner")

    response = await get_stats(client, bar_id, user)

    assert response.status_code == 403


async def test_inactive_membership_is_forbidden(client):
    bar_id = await make_bar()
    user = await member(bar_id, "owner", is_active=False)

    response = await get_stats(client, bar_id, user)

    assert response.status_code == 403


async def test_unauthenticated_request_is_rejected(client):
    bar_id = await make_bar()

    response = await client.get(f"/bars/{bar_id}/dashboard/stats")

    assert response.status_code == 401


async def test_invalid_period_is_rejected(client):
    bar_id = await make_bar()
    user = await member(bar_id)

    response = await get_stats(client, bar_id, user, period="year")

    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Metrics
# ---------------------------------------------------------------------------

async def test_response_shape_is_preserved(client):
    bar_id = await make_bar()
    user = await member(bar_id)

    response = await get_stats(client, bar_id, user)

    assert response.status_code == 200
    assert response.json() == {
        "period": "today",
        "orders": {"total": 0, "pending": 0, "completed": 0, "cancelled": 0, "trend_percent": 0.0},
        "revenue": {"total": 0.0, "currency": "BRL", "trend_percent": 0.0},
        "average_ticket": {"value": 0.0, "currency": "BRL", "trend_percent": 0.0},
        "top_items": [],
    }


async def test_revenue_only_counts_paid_non_cancelled_orders(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    await make_order(bar_id, 100.0, status="completed", payment_status="paid")
    await make_order(bar_id, 50.0, status="preparing", payment_status="paid")
    # Not collected: must not count as revenue.
    await make_order(bar_id, 1000.0, status="pending", payment_status="pending")
    await make_order(bar_id, 2000.0, status="completed", payment_status="failed")
    await make_order(bar_id, 3000.0, status="completed", payment_status="refunded")
    await make_order(bar_id, 4000.0, status="completed", payment_status=None)
    await make_order(bar_id, 5000.0, status="cancelled", payment_status="paid")

    body = (await get_stats(client, bar_id, user)).json()

    assert body["revenue"]["total"] == 150.0
    # Average over the same two paid orders, not over "completed" orders.
    assert body["average_ticket"]["value"] == 75.0
    assert body["orders"] == {
        "total": 7, "pending": 1, "completed": 4, "cancelled": 1, "trend_percent": 100.0,
    }


async def test_other_bars_and_other_periods_are_excluded(client):
    bar_id = await make_bar()
    other_bar_id = await make_bar()
    user = await member(bar_id)
    await make_order(bar_id, 40.0)
    await make_order(other_bar_id, 999.0)
    await make_order(bar_id, 999.0, created_at=TODAY_START - timedelta(seconds=1))  # yesterday
    await make_order(bar_id, 999.0, created_at=NOW.replace(tzinfo=None) + timedelta(minutes=5))  # future

    body = (await get_stats(client, bar_id, user)).json()

    assert body["orders"]["total"] == 1
    assert body["revenue"]["total"] == 40.0


async def test_today_follows_the_venue_timezone(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    # 01:00 UTC on the 11th is still the 10th (22:00) in Sao Paulo.
    await make_order(bar_id, 70.0, created_at=datetime(2026, 3, 11, 1, 0))
    # 04:00 UTC on the 11th is 01:00 local on the 11th.
    await make_order(bar_id, 30.0, created_at=datetime(2026, 3, 11, 4, 0))

    body = (await get_stats(client, bar_id, user)).json()

    assert body["revenue"]["total"] == 30.0


async def test_trends_compare_against_the_same_elapsed_time_yesterday(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    await make_order(bar_id, 150.0)
    await make_order(bar_id, 50.0)
    await make_order(bar_id, 100.0, created_at=YESTERDAY_START + timedelta(hours=2))
    # Yesterday afternoon is after the comparison cutoff and is ignored.
    await make_order(bar_id, 900.0, created_at=YESTERDAY_CUTOFF + timedelta(minutes=1))

    body = (await get_stats(client, bar_id, user)).json()

    assert body["orders"]["trend_percent"] == 100.0       # 2 vs 1
    assert body["revenue"]["trend_percent"] == 100.0      # 200 vs 100
    assert body["average_ticket"]["trend_percent"] == 0.0  # 100 vs 100


async def test_top_items_use_the_revenue_orders_of_the_period(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    beer = await make_menu_item(bar_id, "Beer", 10.0)
    wine = await make_menu_item(bar_id, "Wine", 30.0)
    await make_order(bar_id, 50.0, items=[(beer, 2, 10.0), (wine, 1, 30.0)])
    await make_order(bar_id, 30.0, items=[(beer, 3, 10.0)])
    # Unpaid, cancelled and previous-period orders do not count.
    await make_order(bar_id, 300.0, payment_status="pending", items=[(wine, 10, 30.0)])
    await make_order(bar_id, 300.0, status="cancelled", items=[(wine, 10, 30.0)])
    await make_order(bar_id, 300.0, created_at=YESTERDAY_START, items=[(wine, 10, 30.0)])

    body = (await get_stats(client, bar_id, user)).json()

    assert body["top_items"] == [
        {"name": "Beer", "quantity": 5, "revenue": 50.0},
        {"name": "Wine", "quantity": 1, "revenue": 30.0},
    ]


async def test_top_items_keep_the_name_the_item_was_sold_under(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    beer = await make_menu_item(bar_id, "Beer", 10.0)
    await make_order(bar_id, 30.0, items=[(beer, 3, 10.0)])

    await rename_menu_item(client, beer, "Craft Lager")

    body = (await get_stats(client, bar_id, user)).json()
    assert body["top_items"] == [{"name": "Beer", "quantity": 3, "revenue": 30.0}]


async def test_item_renamed_during_the_period_is_one_entry_under_its_latest_sold_name(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    beer = await make_menu_item(bar_id, "Beer", 10.0)
    await make_order(bar_id, 30.0, items=[(beer, 3, 10.0)], created_at=TODAY_START + timedelta(hours=1))
    await rename_menu_item(client, beer, "Craft Lager")
    await make_order(bar_id, 24.0, items=[(beer, 2, 12.0)], created_at=TODAY_START + timedelta(hours=2))

    body = (await get_stats(client, bar_id, user)).json()
    assert body["top_items"] == [{"name": "Craft Lager", "quantity": 5, "revenue": 54.0}]


async def test_latest_sold_name_follows_order_time_not_insertion_order(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    beer = await make_menu_item(bar_id, "Beer", 10.0)
    # Recorded out of order (e.g. a late sync): the later sale decides the name.
    await make_order(bar_id, 10.0, items=[(beer, 1, 10.0, "Craft Lager")], created_at=TODAY_START + timedelta(hours=5))
    await make_order(bar_id, 10.0, items=[(beer, 1, 10.0, "Beer")], created_at=TODAY_START + timedelta(hours=1))

    body = (await get_stats(client, bar_id, user)).json()
    assert body["top_items"] == [{"name": "Craft Lager", "quantity": 2, "revenue": 20.0}]


async def test_latest_sold_name_only_comes_from_counted_sales(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    beer = await make_menu_item(bar_id, "Beer", 10.0)
    await make_order(bar_id, 10.0, items=[(beer, 1, 10.0)], created_at=TODAY_START + timedelta(hours=1))
    await rename_menu_item(client, beer, "Craft Lager")
    # Newer, but never paid / cancelled: not a sale, so it does not relabel.
    await make_order(bar_id, 10.0, payment_status="pending", items=[(beer, 1, 10.0)],
                     created_at=TODAY_START + timedelta(hours=2))
    await make_order(bar_id, 10.0, status="cancelled", items=[(beer, 1, 10.0)],
                     created_at=TODAY_START + timedelta(hours=3))

    body = (await get_stats(client, bar_id, user)).json()
    assert body["top_items"] == [{"name": "Beer", "quantity": 1, "revenue": 10.0}]


async def test_different_menu_items_with_the_same_name_are_separate_entries(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    draft = await make_menu_item(bar_id, "House Beer", 10.0)
    bottle = await make_menu_item(bar_id, "House Beer", 15.0)
    await make_order(bar_id, 75.0, items=[(draft, 3, 10.0), (bottle, 3, 15.0)])

    body = (await get_stats(client, bar_id, user)).json()
    assert sorted((i["quantity"], i["revenue"]) for i in body["top_items"]) == [(3, 30.0), (3, 45.0)]
    assert [i["name"] for i in body["top_items"]] == ["House Beer", "House Beer"]


async def test_deleted_menu_items_stay_in_the_ranking(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    beer = await make_menu_item(bar_id, "Beer", 10.0)
    wine = await make_menu_item(bar_id, "Wine", 30.0)
    await make_order(bar_id, 110.0, items=[(beer, 2, 10.0), (wine, 3, 30.0)])

    await delete_menu_item(client, wine)

    body = (await get_stats(client, bar_id, user)).json()
    assert body["top_items"] == [
        {"name": "Wine", "quantity": 3, "revenue": 90.0},
        {"name": "Beer", "quantity": 2, "revenue": 20.0},
    ]
    # The revenue total and the ranking still describe the same sales.
    assert body["revenue"]["total"] == 110.0


async def test_snapshot_is_preferred_over_newer_rows_without_one(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    beer = await make_menu_item(bar_id, "Beer", 10.0)
    await make_order(bar_id, 10.0, items=[(beer, 1, 10.0)], created_at=TODAY_START + timedelta(hours=1))
    await rename_menu_item(client, beer, "Craft Lager")
    await make_order(bar_id, 10.0, items=[(beer, 1, 10.0, None)], created_at=TODAY_START + timedelta(hours=2))

    body = (await get_stats(client, bar_id, user)).json()
    assert body["top_items"] == [{"name": "Beer", "quantity": 2, "revenue": 20.0}]


async def test_legacy_rows_only_use_the_current_menu_name(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    beer = await make_menu_item(bar_id, "Beer", 10.0)
    await make_order(bar_id, 20.0, items=[(beer, 2, 10.0, None)])
    await rename_menu_item(client, beer, "Craft Lager")

    body = (await get_stats(client, bar_id, user)).json()
    assert body["top_items"] == [{"name": "Craft Lager", "quantity": 2, "revenue": 20.0}]


async def test_order_items_without_a_snapshot_fall_back_to_the_menu_item_name(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    beer = await make_menu_item(bar_id, "Beer", 10.0)
    await make_order(bar_id, 20.0, items=[(beer, 2, 10.0, None)])  # legacy row
    await make_order(bar_id, 10.0, items=[(beer, 1, 10.0)])        # snapshot "Beer"

    body = (await get_stats(client, bar_id, user)).json()
    assert body["top_items"] == [{"name": "Beer", "quantity": 3, "revenue": 30.0}]


async def test_unnamed_deleted_items_are_kept_apart(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    gone_a = await make_menu_item(bar_id, "Gone A", 10.0)
    gone_b = await make_menu_item(bar_id, "Gone B", 5.0)
    await make_order(bar_id, 40.0, items=[(gone_a, 2, 10.0, None), (gone_b, 4, 5.0, None)])
    await delete_menu_item(client, gone_a)
    await delete_menu_item(client, gone_b)

    body = (await get_stats(client, bar_id, user)).json()
    assert body["top_items"] == [
        {"name": f"Item #{gone_b}", "quantity": 4, "revenue": 20.0},
        {"name": f"Item #{gone_a}", "quantity": 2, "revenue": 20.0},
    ]


async def test_week_and_month_periods(client):
    bar_id = await make_bar()
    user = await member(bar_id)
    # Monday 2026-03-09 00:30 local: in this week and this month.
    await make_order(bar_id, 10.0, created_at=datetime(2026, 3, 9, 3, 30))
    # Sunday 2026-03-01 12:00 local: last week, but this month.
    await make_order(bar_id, 20.0, created_at=datetime(2026, 3, 1, 15, 0))
    # February: neither.
    await make_order(bar_id, 40.0, created_at=datetime(2026, 2, 27, 15, 0))

    week = (await get_stats(client, bar_id, user, period="week")).json()
    month = (await get_stats(client, bar_id, user, period="month")).json()

    assert week["period"] == "week"
    assert week["revenue"]["total"] == 10.0
    assert month["period"] == "month"
    assert month["revenue"]["total"] == 30.0


async def test_unknown_bar_is_forbidden_not_leaked(client):
    bar_id = await make_bar()
    user = await member(bar_id)

    response = await get_stats(client, bar_id + 1000, user)

    assert response.status_code == 403


# ---------------------------------------------------------------------------
# Period windows
# ---------------------------------------------------------------------------

def test_period_range_today_uses_local_midnight():
    now = datetime(2026, 3, 11, 1, 0, tzinfo=timezone.utc)  # Mar 10 22:00 local
    cur_start, cur_end, prev_start, prev_end = dashboard.get_period_range("today", SAO_PAULO, now)

    assert cur_start == datetime(2026, 3, 10, 3, 0)
    assert cur_end == datetime(2026, 3, 11, 1, 0)
    assert prev_start == datetime(2026, 3, 9, 3, 0)
    assert prev_end == datetime(2026, 3, 10, 1, 0)


def test_period_range_week_starts_on_local_monday():
    cur_start, _, prev_start, prev_end = dashboard.get_period_range("week", SAO_PAULO, NOW)

    assert cur_start == datetime(2026, 3, 9, 3, 0)
    assert prev_start == datetime(2026, 3, 2, 3, 0)
    assert prev_end == datetime(2026, 3, 4, 15, 0)


def test_previous_month_window_never_overlaps_current_month():
    now = datetime(2026, 3, 31, 23, 0, tzinfo=timezone.utc)  # Mar 31 20:00 local
    cur_start, cur_end, prev_start, prev_end = dashboard.get_period_range("month", SAO_PAULO, now)

    assert cur_start == datetime(2026, 3, 1, 3, 0)
    assert prev_start == datetime(2026, 2, 1, 3, 0)
    # February is shorter than the 30+ days elapsed in March: stop at its end.
    assert prev_end == cur_start
    assert prev_end <= cur_start < cur_end


def test_period_range_defaults_to_utc():
    cur_start, _, _, _ = dashboard.get_period_range("today", now=NOW)

    assert cur_start == datetime(2026, 3, 11, 0, 0)


# ---------------------------------------------------------------------------
# Refunds issued through POST /payments/v2/refund
# ---------------------------------------------------------------------------

class FakeDPE:
    """Stands in for the payment engine: refunds are idempotent per key (a key
    reused with a different amount is a 409), a missing amount refunds what is
    left, over-refunds are rejected. ``fail_next`` injects one failure:
    "timeout_after" (refunds, then times out), "timeout_before", or
    "server_error" (502, nothing refunded). ``get_payment`` reports the
    refunded total, like the real API."""

    def __init__(self, payments):
        self.payments = dict(payments)  # payment_id -> amount charged
        self.refunded = {}
        self.by_key = {}
        self.calls = 0
        self.fail_next = None
        self.unavailable = False
        self.on_refund = None  # hook called with the payment id before refunding

    async def refund(self, payment_id, amount=None, reason=None, idempotency_key=None):
        self.calls += 1
        if self.on_refund:
            await self.on_refund(payment_id)
        failure, self.fail_next = self.fail_next, None
        if failure == "timeout_before":
            raise httpx.ReadTimeout("timed out")
        if failure == "server_error":
            return {"status": "error", "http_status": 502, "message": "Bad gateway"}
        if idempotency_key in self.by_key:
            cached, cached_amount = self.by_key[idempotency_key]
            if amount is not None and cached_amount is not None and amount != cached_amount:
                return {"status": "error", "http_status": 409, "message": "Idempotency key reused with different parameters"}
            return cached
        if payment_id not in self.payments:
            return {"status": "error", "http_status": 404, "message": "Payment not found"}
        remaining = round(self.payments[payment_id] - self.refunded.get(payment_id, 0.0), 2)
        requested = amount
        amount = remaining if amount is None else amount
        if amount > remaining:
            return {"status": "error", "http_status": 400, "message": "Refund exceeds captured amount"}
        self.refunded[payment_id] = round(self.refunded.get(payment_id, 0.0) + amount, 2)
        result = {
            "status": "succeeded",
            "refund_id": f"re_{len(self.by_key) + 1}_{payment_id}",
            "payment_id": payment_id,
            "amount": amount,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        self.by_key[idempotency_key] = (result, requested)
        if failure == "timeout_after":
            raise httpx.ReadTimeout("timed out after processing")
        return result

    async def get_payment(self, payment_id):
        if self.unavailable:
            raise httpx.ConnectError("payment engine unreachable")
        return {
            "status": "found",
            "payment_id": payment_id,
            "refunded_amount": self.refunded.get(payment_id, 0.0),
        }


@pytest.fixture
def dpe(monkeypatch):
    fake = FakeDPE({})
    monkeypatch.setattr(payment_routes, "get_dpe_client", lambda: fake)
    return fake


async def paid_order(dpe, bar_id, total, payment_id, **kwargs):
    dpe.payments[payment_id] = total
    return await make_order(bar_id, total, payment_id=payment_id, **kwargs)


async def refund(client, user, payment_id, amount=None, key=None):
    body = {"payment_id": payment_id, "reason": "customer complaint"}
    if amount is not None:
        body["amount"] = amount
    headers = headers_for(user)
    if key:
        headers["X-Idempotency-Key"] = key
    return await client.post("/payments/v2/refund", json=body, headers=headers)


async def test_full_refund_removes_the_order_from_revenue(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    beer = await make_menu_item(bar_id, "Beer", 10.0)
    wine = await make_menu_item(bar_id, "Wine", 30.0)
    await paid_order(dpe, bar_id, 20.0, "pay_kept", items=[(beer, 2, 10.0)])
    refunded_id = await paid_order(dpe, bar_id, 90.0, "pay_refunded", items=[(wine, 3, 30.0)])

    response = await refund(client, user, "pay_refunded")

    assert response.status_code == 200
    assert response.json()["amount"] == 90.0
    # The payment itself still succeeded: the order is not re-opened for
    # payment, and the refund is tracked separately.
    order = await test_database.fetch_one(Order.__table__.select().where(Order.id == refunded_id))
    assert order["payment_status"] == "paid"

    body = (await get_stats(client, bar_id, user)).json()
    assert body["revenue"]["total"] == 20.0
    assert body["average_ticket"]["value"] == 20.0
    assert body["top_items"] == [{"name": "Beer", "quantity": 2, "revenue": 20.0}]
    # The order still happened; it just earned nothing.
    assert body["orders"]["total"] == 2
    assert body["orders"]["completed"] == 2


async def test_partial_refund_is_subtracted_from_revenue(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    beer = await make_menu_item(bar_id, "Beer", 10.0)
    await paid_order(dpe, bar_id, 100.0, "pay_a", items=[(beer, 10, 10.0)])
    await paid_order(dpe, bar_id, 50.0, "pay_b")

    assert (await refund(client, user, "pay_a", amount=30.0)).status_code == 200

    body = (await get_stats(client, bar_id, user)).json()
    assert body["revenue"]["total"] == 120.0
    assert body["average_ticket"]["value"] == 60.0
    # Refunds are not tied to items: the partially refunded order's items stay.
    assert body["top_items"] == [{"name": "Beer", "quantity": 10, "revenue": 100.0}]


async def test_partial_refunds_adding_up_to_the_total_count_as_full_refund(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 0.3, "pay_small")
    await paid_order(dpe, bar_id, 10.0, "pay_other")

    assert (await refund(client, user, "pay_small", amount=0.1)).status_code == 200
    assert (await refund(client, user, "pay_small", amount=0.2)).status_code == 200

    body = (await get_stats(client, bar_id, user)).json()
    assert body["revenue"]["total"] == 10.0
    assert body["average_ticket"]["value"] == 10.0


async def test_retried_refund_is_only_counted_once(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_retry")

    first = await refund(client, user, "pay_retry", amount=40.0, key="refund-key-1")
    second = await refund(client, user, "pay_retry", amount=40.0, key="refund-key-1")

    assert first.status_code == second.status_code == 200
    assert first.json()["refund_id"] == second.json()["refund_id"]
    rows = await test_database.fetch_all(OrderRefund.__table__.select())
    assert len(rows) == 1
    body = (await get_stats(client, bar_id, user)).json()
    assert body["revenue"]["total"] == 60.0


async def test_rejected_refund_changes_nothing(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_rejected")

    response = await refund(client, user, "pay_rejected", amount=500.0)

    assert response.status_code == 400
    # Kept as an audit trail, but marked failed: it is not subtracted.
    [row] = await test_database.fetch_all(OrderRefund.__table__.select())
    assert row["status"] == "failed"
    body = (await get_stats(client, bar_id, user)).json()
    assert body["revenue"]["total"] == 100.0


async def test_payment_without_an_order_cannot_be_refunded(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    dpe.payments["pay_subscription_invoice"] = 199.0

    response = await refund(client, user, "pay_subscription_invoice")

    assert response.status_code == 404
    assert dpe.calls == 0
    assert await test_database.fetch_all(OrderRefund.__table__.select()) == []


async def test_refund_is_recorded_against_the_order_it_paid(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    order_id = await paid_order(dpe, bar_id, 80.0, "pay_ledger")

    await refund(client, user, "pay_ledger", amount=25.0)

    row = await test_database.fetch_one(OrderRefund.__table__.select())
    assert row["order_id"] == order_id
    assert row["bar_id"] == bar_id
    assert row["payment_id"] == "pay_ledger"
    assert row["amount"] == 25.0
    assert row["reason"] == "customer complaint"
    assert row["requested_by_user_id"] == user["id"]


async def test_refund_counts_against_the_period_the_order_was_placed_in(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_today")
    await paid_order(dpe, bar_id, 100.0, "pay_yesterday", created_at=YESTERDAY_START + timedelta(hours=1))

    await refund(client, user, "pay_yesterday", amount=50.0)

    body = (await get_stats(client, bar_id, user)).json()
    assert body["revenue"]["total"] == 100.0
    assert body["revenue"]["trend_percent"] == 100.0  # 100 today vs 50 net yesterday


# ---------------------------------------------------------------------------
# Revenue is never overstated, whatever fails around a refund
# ---------------------------------------------------------------------------

async def refund_rows():
    return await test_database.fetch_all(OrderRefund.__table__.select().order_by(OrderRefund.id))


async def revenue(client, bar_id, user):
    return (await get_stats(client, bar_id, user)).json()["revenue"]["total"]


async def reconcile(dpe, minutes_later=11):
    return await reconcile_pending_refunds(
        test_database, dpe, now=datetime.utcnow() + timedelta(minutes=minutes_later)
    )


def broken(*args, **kwargs):
    async def fail(*a, **k):
        raise RuntimeError("database unavailable")
    return fail


async def test_refund_is_recorded_before_the_payment_engine_moves_money(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_order")
    seen = []

    async def check_recorded(payment_id):
        rows = await test_database.fetch_all(OrderRefund.__table__.select().where(OrderRefund.payment_id == payment_id))
        seen.append([(r["status"], r["amount"]) for r in rows])

    dpe.on_refund = check_recorded

    await refund(client, user, "pay_order", amount=30.0)

    assert seen == [[("pending", 30.0)]]


async def test_if_the_refund_cannot_be_recorded_no_money_moves(client, dpe, monkeypatch):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_no_record")
    monkeypatch.setattr(payment_routes, "begin_order_refund", broken())

    with pytest.raises(RuntimeError):
        await refund(client, user, "pay_no_record")

    assert dpe.calls == 0
    assert dpe.refunded == {}
    assert await revenue(client, bar_id, user) == 100.0


async def test_if_the_confirmation_cannot_be_stored_revenue_still_excludes_the_refund(client, dpe, monkeypatch):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_lost")
    monkeypatch.setattr(payment_routes, "complete_order_refund", broken())

    response = await refund(client, user, "pay_lost", amount=30.0, key="key-lost")

    # The money moved; an error would invite a retry that refunds it again.
    assert response.status_code == 200
    assert dpe.refunded == {"pay_lost": 30.0}
    [row] = await refund_rows()
    assert (row["status"], row["amount"]) == ("pending", 30.0)
    assert await revenue(client, bar_id, user) == 70.0

    # A retry with the same key settles it without refunding again.
    monkeypatch.setattr(payment_routes, "complete_order_refund", complete_order_refund)
    retry = await refund(client, user, "pay_lost", amount=30.0, key="key-lost")

    assert retry.status_code == 200
    assert dpe.refunded == {"pay_lost": 30.0}
    [row] = await refund_rows()
    assert (row["status"], row["amount"]) == ("succeeded", 30.0)
    assert row["gateway_refund_id"] == retry.json()["refund_id"]
    assert await revenue(client, bar_id, user) == 70.0


async def test_lost_confirmation_without_retry_is_settled_by_reconciliation(client, dpe, monkeypatch):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_lost")
    monkeypatch.setattr(payment_routes, "complete_order_refund", broken())
    await refund(client, user, "pay_lost", amount=30.0)

    assert await reconcile(dpe) == {"succeeded": 1, "failed": 0}

    [row] = await refund_rows()
    assert row["status"] == "succeeded"
    assert await revenue(client, bar_id, user) == 70.0


async def test_timeout_after_the_refund_went_through(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_slow")
    dpe.fail_next = "timeout_after"

    response = await refund(client, user, "pay_slow")

    assert response.status_code == 504
    assert dpe.refunded == {"pay_slow": 100.0}
    assert await revenue(client, bar_id, user) == 0.0  # pending full refund already subtracted
    assert await reconcile(dpe) == {"succeeded": 1, "failed": 0}
    assert await revenue(client, bar_id, user) == 0.0


async def test_timeout_before_the_refund_went_through(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_slow")
    dpe.fail_next = "timeout_before"

    response = await refund(client, user, "pay_slow", amount=40.0)

    assert response.status_code == 504
    assert dpe.refunded == {}
    # Unknown outcome: erring low (60) rather than high (100).
    assert await revenue(client, bar_id, user) == 60.0
    assert await reconcile(dpe) == {"succeeded": 0, "failed": 1}
    assert await revenue(client, bar_id, user) == 100.0


async def test_payment_engine_server_error_leaves_the_refund_pending(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_5xx")
    dpe.fail_next = "server_error"

    response = await refund(client, user, "pay_5xx", amount=40.0)

    assert response.status_code == 400
    [row] = await refund_rows()
    assert row["status"] == "pending"
    assert await revenue(client, bar_id, user) == 60.0
    assert await reconcile(dpe) == {"succeeded": 0, "failed": 1}
    assert await revenue(client, bar_id, user) == 100.0


async def test_error_on_a_retry_does_not_uncount_a_refund_that_went_through(client, dpe, monkeypatch):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_retry")
    monkeypatch.setattr(payment_routes, "complete_order_refund", broken())
    await refund(client, user, "pay_retry", amount=30.0, key="key-1")  # refunded, left pending
    monkeypatch.setattr(payment_routes, "complete_order_refund", complete_order_refund)

    # Same key, different amount: the engine rejects the retry (409).
    response = await refund(client, user, "pay_retry", amount=50.0, key="key-1")

    assert response.status_code == 400
    [row] = await refund_rows()
    assert row["status"] == "pending"  # not "failed": the first attempt refunded 30
    assert await revenue(client, bar_id, user) == 70.0
    assert await reconcile(dpe) == {"succeeded": 1, "failed": 0}
    assert await revenue(client, bar_id, user) == 70.0


async def test_full_refund_after_a_pending_partial_requests_the_remainder(client, dpe, monkeypatch):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_two")
    monkeypatch.setattr(payment_routes, "complete_order_refund", broken())
    await refund(client, user, "pay_two", amount=30.0)
    monkeypatch.setattr(payment_routes, "complete_order_refund", complete_order_refund)

    response = await refund(client, user, "pay_two")

    assert response.status_code == 200
    assert [(r["status"], r["amount"]) for r in await refund_rows()] == [("pending", 30.0), ("succeeded", 70.0)]
    assert await revenue(client, bar_id, user) == 0.0


async def test_reconciliation_credits_refunded_money_to_the_oldest_pending_refunds(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_multi")
    dpe.fail_next = "timeout_after"
    await refund(client, user, "pay_multi", amount=30.0)   # went through
    dpe.fail_next = "timeout_before"
    await refund(client, user, "pay_multi", amount=50.0)   # did not
    assert await revenue(client, bar_id, user) == 20.0

    assert await reconcile(dpe) == {"succeeded": 1, "failed": 1}

    assert [(r["status"], r["amount"]) for r in await refund_rows()] == [("succeeded", 30.0), ("failed", 50.0)]
    assert await revenue(client, bar_id, user) == 70.0


async def test_reconciliation_waits_while_a_refund_may_still_be_in_flight(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_recent")
    dpe.fail_next = "timeout_before"
    await refund(client, user, "pay_recent", amount=40.0)

    assert await reconcile(dpe, minutes_later=5) == {"succeeded": 0, "failed": 0}
    [row] = await refund_rows()
    assert row["status"] == "pending"
    assert await revenue(client, bar_id, user) == 60.0


async def test_reconciliation_keeps_refunds_pending_if_the_engine_is_unreachable(client, dpe):
    bar_id = await make_bar()
    user = await member(bar_id)
    await paid_order(dpe, bar_id, 100.0, "pay_down")
    dpe.fail_next = "timeout_before"
    await refund(client, user, "pay_down", amount=40.0)
    dpe.unavailable = True

    assert await reconcile(dpe) == {"succeeded": 0, "failed": 0}
    [row] = await refund_rows()
    assert row["status"] == "pending"
    assert await revenue(client, bar_id, user) == 60.0


async def test_same_client_key_from_different_users_are_different_refunds(client, dpe):
    bar_id = await make_bar()
    owner = await member(bar_id)
    admin = await member(bar_id, "admin")
    await paid_order(dpe, bar_id, 100.0, "pay_a")
    await paid_order(dpe, bar_id, 100.0, "pay_b")

    first = await refund(client, owner, "pay_a", amount=10.0, key="same-key")
    second = await refund(client, admin, "pay_b", amount=20.0, key="same-key")

    assert first.status_code == second.status_code == 200
    assert first.json()["refund_id"] != second.json()["refund_id"]
    assert dpe.refunded == {"pay_a": 10.0, "pay_b": 20.0}
    assert await revenue(client, bar_id, owner) == 170.0
