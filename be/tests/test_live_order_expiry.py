"""
Live cashier queue expiry (GET /bars/{bar_id}/orders/live).

An order placed during a configured shift expires at that shift's close
(America/Sao_Paulo). Overnight shifts belong to the day they opened on.
Orders outside every configured shift, including all orders at bars without
configured hours, expire 24h after creation.

2025-06-02 is a Monday. Sao Paulo is UTC-3 all year (no DST since 2019).
"""

import os

os.environ.setdefault("DATABASE_URL", "sqlite:///./_unused_test.db")
os.environ.setdefault("MONGO_URI", "mongodb://localhost:1")
os.environ.setdefault("MONGO_DB", "test")

import random
import shutil
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import httpx
import pytest
import sqlalchemy as sa
from databases import Database
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from jose import jwt

from app.auth import rbac_middleware
from app.auth.auth_models import User
from app.auth.rbac_models import BarStaff, UserProfile
from app.bars_and_restaurants.models.cart_models import OrderItem, OrderStatusHistory
from app.bars_and_restaurants.models.relational_models import Bar, BarOwner, Order
from app.bars_and_restaurants.routes import orders as orders_routes
from app.bars_and_restaurants.services.order_expiry import (
    FALLBACK_ORDER_LIFETIME,
    LIVE_ORDER_LOOKBACK,
    is_order_expired,
    order_expiry_utc,
)
from app.errors import APIError

pytestmark = pytest.mark.orders

SP = ZoneInfo("America/Sao_Paulo")
UTC = timezone.utc


def sp(day, hh, mm=0):
    """Sao Paulo local wall time on 2025-06-<day> as an aware UTC datetime."""
    return datetime(2025, 6, day, hh, mm, tzinfo=SP).astimezone(UTC)


def naive_utc(dt):
    """How order timestamps are stored (datetime.utcnow())."""
    return dt.astimezone(UTC).replace(tzinfo=None)


def hours(**days):
    return {d: {"open": o, "close": c, "is_closed": False} for d, (o, c) in days.items()}


# Mon 2 .. Sun 8 June 2025
MON, TUE, WED, THU, FRI, SAT, SUN = range(2, 9)


# ----------------------------------------------------------------------------
# bars without configured hours: 24h
# ----------------------------------------------------------------------------

@pytest.mark.parametrize("config", [
    None,
    {},
    "",
    "not json",
    [],
    # Every day closed or unusable counts as "no configured hours".
    {d: {"is_closed": True} for d in ("monday", "tuesday", "wednesday", "thursday",
                                      "friday", "saturday", "sunday")},
    # Left behind by the dashboard open/closed toggle: no open/close times.
    {"monday": {"is_closed": False, "manual_override": True, "override_reason": None}},
    {"monday": {"open": None, "close": None}},
    {"monday": {"open": "25:00", "close": "99:99"}},
    {"monday": {"open": "18:00", "close": "18:00"}},
    {"monday": "18:00-02:00"},
])
def test_unconfigured_bar_expires_24h_after_creation(config):
    created = sp(MON, 21, 15)
    assert order_expiry_utc(created, config) == created + timedelta(hours=24)


def test_unconfigured_bar_accepts_naive_utc_timestamps():
    created = sp(MON, 21, 15)
    assert order_expiry_utc(naive_utc(created), None) == created + timedelta(hours=24)
    assert not is_order_expired(naive_utc(created), None, now=created + timedelta(hours=23, minutes=59))
    assert is_order_expired(naive_utc(created), None, now=created + timedelta(hours=24))


# ----------------------------------------------------------------------------
# configured hours
# ----------------------------------------------------------------------------

SAME_DAY = hours(monday=("11:00", "23:00"), tuesday=("11:00", "23:00"))
OVERNIGHT = hours(monday=("20:00", "02:00"), tuesday=("20:00", "02:00"))


@pytest.mark.parametrize("config, created, expected", [
    # Same-day shift: expires at that day's close.
    pytest.param(SAME_DAY, sp(MON, 11, 0), sp(MON, 23, 0), id="same-day-at-open"),
    pytest.param(SAME_DAY, sp(MON, 14, 30), sp(MON, 23, 0), id="same-day-midshift"),
    pytest.param(SAME_DAY, sp(MON, 22, 59), sp(MON, 23, 0), id="same-day-just-before-close"),
    # Overnight shift: evening order expires at the next day's close...
    pytest.param(OVERNIGHT, sp(MON, 20, 0), sp(TUE, 2, 0), id="overnight-at-open"),
    pytest.param(OVERNIGHT, sp(MON, 23, 45), sp(TUE, 2, 0), id="overnight-evening"),
    # ...and an early-morning order belongs to the previous day's shift.
    pytest.param(OVERNIGHT, sp(TUE, 0, 0), sp(TUE, 2, 0), id="overnight-midnight"),
    pytest.param(OVERNIGHT, sp(TUE, 1, 30), sp(TUE, 2, 0), id="overnight-early-morning"),
    # Early morning of a day with no shift of its own still belongs to the
    # previous evening's shift.
    pytest.param(hours(saturday=("22:00", "06:00")), sp(SUN, 5, 0), sp(SUN, 6, 0),
                 id="club-sunday-morning-from-saturday-shift"),
    # Close at midnight, written either way.
    pytest.param(hours(monday=("18:00", "00:00")), sp(MON, 23, 0), sp(TUE, 0, 0), id="close-00:00"),
    pytest.param(hours(monday=("18:00", "24:00")), sp(MON, 23, 0), sp(TUE, 0, 0), id="close-24:00"),
    pytest.param(hours(monday=("18:00:00", "02:00:00")), sp(MON, 19, 0), sp(TUE, 2, 0), id="seconds"),
])
def test_order_expires_at_close_of_its_operating_day(config, created, expected):
    assert order_expiry_utc(created, config) == expected
    assert not is_order_expired(created, config, now=expected - timedelta(seconds=1))
    assert is_order_expired(created, config, now=expected)


@pytest.mark.parametrize("config, created", [
    # Before opening (the shift opens later that day).
    pytest.param(OVERNIGHT, sp(MON, 10, 0), id="before-overnight-open"),
    pytest.param(SAME_DAY, sp(TUE, 9, 0), id="before-same-day-open"),
    # After an overnight close, before the next open.
    pytest.param(OVERNIGHT, sp(TUE, 2, 0), id="exactly-at-overnight-close"),
    pytest.param(OVERNIGHT, sp(TUE, 3, 0), id="after-overnight-close"),
    # After a same-day close, even though the next day has a shift.
    pytest.param(SAME_DAY, sp(MON, 23, 0), id="exactly-at-same-day-close"),
    pytest.param(SAME_DAY, sp(MON, 23, 30), id="after-same-day-close"),
    # Closed days.
    pytest.param(SAME_DAY, sp(TUE, 23, 30), id="closed-days-ahead"),
    pytest.param(hours(friday=("18:00", "02:00")), sp(MON, 12, 0), id="only-friday"),
])
def test_configured_venue_order_outside_shift_expires_after_24h(config, created):
    assert order_expiry_utc(created, config) == created + FALLBACK_ORDER_LIFETIME


def test_configured_shift_is_not_capped_at_24h():
    # Lisbon falls back on Sun 2025-10-26 at 02:00 -> 01:00. A Sat 03:00 ->
    # Sun 02:59 shift is 23h59m on the clock but 24h59m in real time. An
    # order at opening runs to the configured close, not to 24h.
    lisbon = ZoneInfo("Europe/Lisbon")
    config = hours(saturday=("03:00", "02:59"))
    created = datetime(2025, 10, 25, 3, 0, tzinfo=lisbon)
    expected = datetime(2025, 10, 26, 2, 59, tzinfo=lisbon)
    expiry = order_expiry_utc(created, config, "Europe/Lisbon")
    assert expiry == expected.astimezone(UTC)
    assert FALLBACK_ORDER_LIFETIME < expiry - created <= LIVE_ORDER_LOOKBACK


def test_explicitly_closed_day_is_not_a_shift():
    config = {**OVERNIGHT, "tuesday": {"open": "20:00", "close": "02:00", "is_closed": True}}
    # Monday's overnight shift still covers early Tuesday...
    assert order_expiry_utc(sp(TUE, 1, 0), config) == sp(TUE, 2, 0)
    # ...but Tuesday evening is closed, so the 24h fallback applies.
    created = sp(TUE, 21, 0)
    assert order_expiry_utc(created, config) == created + FALLBACK_ORDER_LIFETIME


def test_operating_day_uses_venue_local_time_not_utc():
    # Mon 22:30 in Sao Paulo is already Tuesday 01:30 UTC. The order belongs
    # to Monday's shift and expires at its close (Mon 23:00 local).
    config = hours(monday=("11:00", "23:00"))
    created = sp(MON, 22, 30)
    assert created.weekday() == 1  # Tuesday in UTC
    assert order_expiry_utc(naive_utc(created), config) == sp(MON, 23, 0)


def test_hours_stored_as_json_string():
    import json
    assert order_expiry_utc(sp(MON, 23, 0), json.dumps(OVERNIGHT)) == sp(TUE, 2, 0)


def test_bar_timezone_is_used_and_unknown_timezone_falls_back_to_sao_paulo():
    config = hours(monday=("11:00", "23:00"))
    created = sp(MON, 14, 0)
    assert order_expiry_utc(created, config, None) == sp(MON, 23, 0)
    assert order_expiry_utc(created, config, "America/Sao_Paulo") == sp(MON, 23, 0)
    assert order_expiry_utc(created, config, "Not/AZone") == sp(MON, 23, 0)
    lisbon = datetime(2025, 6, MON, 23, 0, tzinfo=ZoneInfo("Europe/Lisbon"))
    assert order_expiry_utc(created, config, "Europe/Lisbon") == lisbon


def test_malformed_days_are_ignored_but_valid_days_still_apply():
    config = {
        "monday": {"open": "20:00", "close": "02:00"},
        "tuesday": {"open": "banana", "close": "02:00"},
        "wednesday": None,
        "funday": {"open": "00:00", "close": "23:00"},
    }
    assert order_expiry_utc(sp(MON, 21, 0), config) == sp(TUE, 2, 0)


def test_expiry_is_shift_close_or_24h_fallback():
    rng = random.Random(1234)
    names = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    for _ in range(2000):
        config = {}
        for name in names:
            if rng.random() < 0.3:
                continue
            config[name] = {
                "open": f"{rng.randrange(24):02d}:{rng.choice([0, 15, 30, 45]):02d}",
                "close": f"{rng.randrange(24):02d}:{rng.choice([0, 15, 30, 45]):02d}",
                "is_closed": rng.random() < 0.1,
            }
        created = sp(MON, 0) + timedelta(minutes=rng.randrange(7 * 24 * 60))
        expiry = order_expiry_utc(created, config)
        # Sao Paulo has no DST, so a shift is always under 24h.
        assert created < expiry <= created + FALLBACK_ORDER_LIFETIME, (config, created, expiry)
        if expiry != created + FALLBACK_ORDER_LIFETIME:
            # Not the fallback, so the expiry must be a configured close time.
            local = expiry.astimezone(SP)
            closes = {day["close"] for day in config.values() if not day["is_closed"]}
            assert local.strftime("%H:%M") in closes, (config, created, expiry)


# ----------------------------------------------------------------------------
# GET /bars/{bar_id}/orders/live
# ----------------------------------------------------------------------------

BAR_NO_HOURS, BAR_OVERNIGHT, BAR_OTHER = 1, 2, 3
OWNER, CASHIER, OTHER_OWNER, CUSTOMER = 1, 2, 3, 4

TABLES = [t.__table__ for t in (User, UserProfile, BarOwner, Bar, BarStaff, Order,
                                OrderItem, OrderStatusHistory)]


@pytest.fixture(scope="module")
def schema_template(tmp_path_factory):
    path = tmp_path_factory.mktemp("schema") / "template.db"
    engine = sa.create_engine(f"sqlite:///{path}")
    User.metadata.create_all(engine, tables=TABLES)
    engine.dispose()
    return path


@pytest.fixture
async def db(tmp_path, monkeypatch, schema_template):
    path = tmp_path / "live.db"
    shutil.copy(schema_template, path)
    database = Database(f"sqlite:///{path}")
    await database.connect()
    for module in (orders_routes, rbac_middleware):
        monkeypatch.setattr(module, "database", database)

    await database.execute_many(User.__table__.insert(), [
        {"id": uid, "email": f"u{uid}@example.com", "phone_number": f"+55{uid:09d}",
         "is_active": True, "email_verified": True, "phone_verified": True,
         "subscription_tier": "regular", "country_code": "BR"}
        for uid in (OWNER, CASHIER, OTHER_OWNER, CUSTOMER)
    ])
    await database.execute_many(BarOwner.__table__.insert(), [
        {"id": OWNER, "email": "o@example.com"}, {"id": OTHER_OWNER, "email": "oo@example.com"},
    ])
    await database.execute_many(Bar.__table__.insert(), [
        {"id": BAR_NO_HOURS, "name": "No hours", "owner_id": OWNER},
        {"id": BAR_OVERNIGHT, "name": "Club", "owner_id": OWNER,
         "operating_hours": hours(friday=("22:00", "06:00"), saturday=("22:00", "06:00"))},
        {"id": BAR_OTHER, "name": "Other", "owner_id": OTHER_OWNER},
    ])
    await database.execute_many(BarStaff.__table__.insert(), [
        {"user_id": OWNER, "bar_id": b, "role": "owner", "is_active": True}
        for b in (BAR_NO_HOURS, BAR_OVERNIGHT)
    ] + [
        {"user_id": CASHIER, "bar_id": b, "role": "cashier", "is_active": True}
        for b in (BAR_NO_HOURS, BAR_OVERNIGHT)
    ] + [{"user_id": OTHER_OWNER, "bar_id": BAR_OTHER, "role": "owner", "is_active": True}])
    try:
        yield database
    finally:
        await database.disconnect()


@pytest.fixture
def freeze_now(monkeypatch):
    def freeze(moment):
        class Frozen(datetime):
            @classmethod
            def now(cls, tz=None):
                return moment.astimezone(tz) if tz else naive_utc(moment)

        monkeypatch.setattr(orders_routes, "datetime", Frozen)
    return freeze


@pytest.fixture
async def client(db):
    app = FastAPI()

    @app.exception_handler(APIError)
    async def _api_error(request: Request, exc: APIError):
        return JSONResponse(status_code=exc.status_code,
                            content=exc.to_response().model_dump(exclude_none=True))

    app.include_router(orders_routes.bar_orders_router)
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as c:
        yield c


def auth(user_id):
    token = jwt.encode({"sub": str(user_id)}, rbac_middleware.SECRET_KEY,
                       algorithm=rbac_middleware.ALGORITHM)
    return {"Authorization": f"Bearer {token}"}


async def make_order(db, bar_id, created, status="pending", is_priority=False):
    ts = naive_utc(created)
    return await db.execute(Order.__table__.insert().values(
        user_id=CUSTOMER, bar_id=bar_id, status=status, total_price=10.0, subtotal=10.0,
        order_type="pickup", payment_method="pix", created_at=ts, updated_at=ts,
        is_priority=is_priority,
    ))


async def live_ids(client, bar_id, user_id=CASHIER):
    r = await client.get(f"/bars/{bar_id}/orders/live", headers=auth(user_id))
    assert r.status_code == 200, r.text
    return [o["id"] for o in r.json()]


async def test_live_bar_without_hours_drops_orders_after_24h(client, db, freeze_now):
    now = sp(WED, 15, 0)
    freeze_now(now)
    old = await make_order(db, BAR_NO_HOURS, now - timedelta(hours=24, minutes=1))
    edge = await make_order(db, BAR_NO_HOURS, now - timedelta(hours=24))
    recent = await make_order(db, BAR_NO_HOURS, now - timedelta(hours=23, minutes=59))
    fresh = await make_order(db, BAR_NO_HOURS, now - timedelta(minutes=5))
    await make_order(db, BAR_NO_HOURS, now - timedelta(minutes=5), status="completed")
    await make_order(db, BAR_NO_HOURS, now - timedelta(minutes=5), status="cancelled")

    ids = await live_ids(client, BAR_NO_HOURS)
    assert ids == [recent, fresh]
    assert old not in ids and edge not in ids


async def test_live_overnight_shift_across_midnight(client, db, freeze_now):
    # Friday 22:00 -> Saturday 06:00 and Saturday 22:00 -> Sunday 06:00.
    fri_evening = await make_order(db, BAR_OVERNIGHT, sp(FRI, 23, 30))
    sat_small_hours = await make_order(db, BAR_OVERNIGHT, sp(SAT, 3, 0))   # Friday's shift

    # Saturday 05:59: Friday's shift is still open, including the after-midnight order.
    freeze_now(sp(SAT, 5, 59))
    assert await live_ids(client, BAR_OVERNIGHT) == [fri_evening, sat_small_hours]

    # Saturday 06:00: Friday's shift has closed.
    freeze_now(sp(SAT, 6, 0))
    assert await live_ids(client, BAR_OVERNIGHT) == []

    # Saturday night: only orders from Saturday's shift are live.
    sat_evening = await make_order(db, BAR_OVERNIGHT, sp(SAT, 22, 30))
    sun_small_hours = await make_order(db, BAR_OVERNIGHT, sp(SUN, 1, 0))
    freeze_now(sp(SUN, 2, 0))
    assert await live_ids(client, BAR_OVERNIGHT) == [sat_evening, sun_small_hours]

    # Sunday 06:00: Saturday's shift has closed.
    freeze_now(sp(SUN, 6, 0))
    assert await live_ids(client, BAR_OVERNIGHT) == []


async def test_live_order_placed_while_closed_uses_24h_fallback(client, db, freeze_now):
    # Placed 2h before the club opens: not inside any shift, so it stays
    # live for 24h, past the close of that night's shift.
    early = await make_order(db, BAR_OVERNIGHT, sp(FRI, 20, 0))
    freeze_now(sp(SAT, 6, 0))
    assert await live_ids(client, BAR_OVERNIGHT) == [early]
    freeze_now(sp(SAT, 19, 59))
    assert await live_ids(client, BAR_OVERNIGHT) == [early]
    freeze_now(sp(SAT, 20, 0))
    assert await live_ids(client, BAR_OVERNIGHT) == []


async def test_live_configured_venue_after_close_uses_24h_fallback(client, db, freeze_now):
    await db.execute(Bar.__table__.update().where(Bar.__table__.c.id == BAR_NO_HOURS)
                     .values(operating_hours=SAME_DAY))   # Mon/Tue 11:00-23:00
    in_shift = await make_order(db, BAR_NO_HOURS, sp(MON, 22, 0))
    freeze_now(sp(MON, 22, 30))   # during Monday's shift
    assert await live_ids(client, BAR_NO_HOURS) == [in_shift]

    after_close = await make_order(db, BAR_NO_HOURS, sp(MON, 23, 30))

    freeze_now(sp(MON, 23, 45))   # Monday's shift has closed; placed after close
    assert await live_ids(client, BAR_NO_HOURS) == [after_close]
    freeze_now(sp(TUE, 23, 0))    # Tuesday's shift closes; the order isn't tied to it
    assert await live_ids(client, BAR_NO_HOURS) == [after_close]
    freeze_now(sp(TUE, 23, 30))   # 24h after the order
    assert await live_ids(client, BAR_NO_HOURS) == []


async def test_live_keeps_priority_ordering(client, db, freeze_now):
    now = sp(WED, 15, 0)
    freeze_now(now)
    first = await make_order(db, BAR_NO_HOURS, now - timedelta(hours=2))
    priority = await make_order(db, BAR_NO_HOURS, now - timedelta(hours=1), is_priority=True)
    assert await live_ids(client, BAR_NO_HOURS) == [priority, first]


async def test_live_is_scoped_to_bar_staff(client, db, freeze_now):
    freeze_now(sp(WED, 15, 0))
    r = await client.get(f"/bars/{BAR_NO_HOURS}/orders/live", headers=auth(OTHER_OWNER))
    assert r.status_code == 403


# ----------------------------------------------------------------------------
# compatibility: routes.orders.compute_order_expiry_utc
# ----------------------------------------------------------------------------

def test_route_module_keeps_compute_order_expiry_utc():
    from app.bars_and_restaurants.routes.orders import _DAYS, compute_order_expiry_utc

    assert _DAYS == ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    cases = [
        (naive_utc(sp(MON, 23, 45)), OVERNIGHT, "America/Sao_Paulo"),
        (naive_utc(sp(TUE, 1, 30)), OVERNIGHT, "America/Sao_Paulo"),
        (naive_utc(sp(MON, 14, 0)), SAME_DAY, None),
        (naive_utc(sp(MON, 14, 0)), {}, "America/Sao_Paulo"),
        (naive_utc(sp(MON, 14, 0)), None, None),
    ]
    for created, config, tz_name in cases:
        # Same positional call shape as before.
        assert compute_order_expiry_utc(created, config, tz_name) == order_expiry_utc(created, config, tz_name)
    assert compute_order_expiry_utc(sp(MON, 23, 45), OVERNIGHT) == sp(TUE, 2, 0)


async def test_live_endpoint_goes_through_compute_order_expiry_utc(client, db, freeze_now, monkeypatch):
    now = sp(WED, 15, 0)
    freeze_now(now)
    kept = await make_order(db, BAR_NO_HOURS, now - timedelta(hours=1))
    dropped = await make_order(db, BAR_NO_HOURS, now - timedelta(hours=2))
    calls = []

    def fake(created_at, operating_hours, tz_name):
        calls.append(created_at)
        return now - timedelta(seconds=1) if created_at == naive_utc(now - timedelta(hours=2)) else None

    monkeypatch.setattr(orders_routes, "compute_order_expiry_utc", fake)
    assert await live_ids(client, BAR_NO_HOURS) == [kept]
    assert len(calls) == 2 and dropped
