"""Home promo summary, Happy Hour round-trip, and /bars discovery filters."""
import json
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest

from app.database import database
from app.advertising.models import AdvertisingCampaign
from app.advertising.schemas import CampaignCreative
from app.bars_and_restaurants.models.relational_models import Bar, BarOwner, Promotion
from app.bars_and_restaurants.models.wallet_models import BarWallet, ProCouponStatus, ProCouponUsage, UserWallet
from app.bars_and_restaurants.services import venue_discovery as vd


def _now():
    return datetime.now(timezone.utc)


# ---------------------------------------------------------------- fixtures
@pytest.fixture
async def users(cleanup_database):
    from app.auth.auth_models import User

    out = {}
    for key, tier in (("pro", "pro"), ("reg", "regular")):
        out[key] = await database.execute(User.__table__.insert().values(
            firebase_uid=f"hd_{key}", phone_number=f"+55319111{len(out)}000", email=f"{key}@hd.test",
            is_active=True, subscription_tier=tier, email_verified=False, phone_verified=False,
        ))
    return out


@pytest.fixture
async def venues(users):
    await database.execute(BarOwner.__table__.insert().values(id=9101, name="O", email="o@hd.test"))
    ids = []
    for i, (name, cat, rating) in enumerate((("Alfa", "bar", 4.5), ("Beta", "restaurant_bar", 3.0), ("Gama", "bar", 0.0))):
        ids.append(await database.execute(Bar.__table__.insert().values(
            name=name, address=f"Rua {i}", owner_id=9101, category=cat, rating=rating, country_code="BR",
        )))
    return ids


async def _promo(bar_id, **kw):
    values = dict(bar_id=bar_id, title="P", promotion_type="discount", discount_type="percentage",
                  discount_value=5.0, is_active=True)
    values.update(kw)
    return await database.execute(Promotion.__table__.insert().values(**values))


async def _sub(bar_id):
    from app.advertising.models import AdvertisingSubscription as S

    row = await database.fetch_one(S.__table__.select().where(S.bar_id == bar_id))
    if row:
        return row["id"]
    return await database.execute(S.__table__.insert().values(
        bar_id=bar_id, tier="regular", status="active", region_code="BR", monthly_fee=Decimal("0"),
        commission_rate=Decimal("0.15"), credits={}, created_at=_now(), updated_at=_now(),
    ))


async def _campaign(bar_id, **kw):
    sub_id = await _sub(bar_id)
    values = dict(
        subscription_id=sub_id, bar_id=bar_id, name="C", status="active", budget_type="fixed",
        budget_amount=Decimal("100"), budget_spent=Decimal("0"), created_at=_now(), updated_at=_now(), start_time=_now() - timedelta(days=1),
        end_time=_now() + timedelta(days=1), campaign_goal="promotion", targeting={"radius_km": 10},
        creative={"promote_happy_hour": False},
    )
    values.update(kw)
    return await database.execute(AdvertisingCampaign.__table__.insert().values(**values))


@pytest.fixture(autouse=True)
async def _no_fk(cleanup_database):
    # sqlite test DB does not enforce the subscription FK; campaigns use subscription_id=None
    yield


# ------------------------------------------------------- Happy Hour contract
def test_happy_hour_flag_defaults_false_and_round_trips():
    assert CampaignCreative().promote_happy_hour is False
    c = CampaignCreative(promote_happy_hour=True, promoted_item_id=3)
    again = CampaignCreative(**json.loads(json.dumps(c.model_dump())))
    assert again.promote_happy_hour is True and again.promoted_item_id == 3
    # older stored creative without the flag keeps working
    assert CampaignCreative(**{"logo_url": None, "tagline": "x"}).promote_happy_hour is False


# ------------------------------------------------------------ classification
@pytest.mark.asyncio
async def test_badge_priority_and_no_title_inference(venues):
    a, b, c = venues
    await _promo(a, title="happy hour special")  # title must NOT make it happy hour
    await _promo(a, promotion_type="cashback", benefit_text="10% cashback")
    await _campaign(a, creative={"promote_happy_hour": True, "tagline": "HH!"})
    await database.execute(BarWallet.__table__.insert().values(bar_id=a, available_balance=Decimal("50"), reserved_balance=Decimal("0")))
    await _promo(b, title="Happy Hour")
    snap = await vd.load_promo_snapshot(database, venues, {a: 100.0, b: 100.0, c: None})
    assert snap.venues[a].primary == vd.HAPPY_HOUR and snap.venues[a].text == "HH!"
    assert snap.venues[b].primary == vd.PROMOTION
    assert snap.venues[c].primary is None
    # without campaign: cashback outranks promotion
    await database.execute(AdvertisingCampaign.__table__.delete())
    snap = await vd.load_promo_snapshot(database, venues)
    assert snap.venues[a].primary == vd.CASHBACK


@pytest.mark.asyncio
async def test_unfunded_cashback_and_inactive_or_future_promos_excluded(venues):
    a = venues[0]
    await _promo(a, promotion_type="cashback")  # no wallet funds
    await _promo(a, is_active=False)
    await _promo(a, start_date=datetime.utcnow() + timedelta(days=2))
    await _promo(a, end_date=datetime.utcnow() - timedelta(days=2))
    snap = await vd.load_promo_snapshot(database, [a])
    assert snap.venues[a].kinds == set()


@pytest.mark.asyncio
async def test_schedule_and_campaign_status_budget_dates(venues):
    a = venues[0]
    other_day = vd._DAY_NAMES[(datetime.now(vd.ZoneInfo("America/Sao_Paulo")).weekday() + 1) % 7]
    await _promo(a, recurring_days=[other_day])  # wrong weekday
    await _campaign(a, status="paused")
    await _campaign(a, budget_spent=Decimal("100"))
    await _campaign(a, start_time=_now() + timedelta(days=1), end_time=_now() + timedelta(days=2))
    await _campaign(a, end_time=_now() - timedelta(hours=1), start_time=_now() - timedelta(days=2))
    await _campaign(a, campaign_goal="discovery")  # generic venue advertising, not an offer
    await _campaign(a, targeting={"radius_km": 1})  # out of narrower radius at 5 km
    snap = await vd.load_promo_snapshot(database, [a], {a: 5000.0})
    assert snap.venues[a].kinds == set()
    # same radius campaign is kept when distance unknown
    snap = await vd.load_promo_snapshot(database, [a], {a: None})
    assert len(snap.campaign_ids.get(a, set())) == 1


# ----------------------------------------------------------------- counts
@pytest.mark.asyncio
async def test_count_composition_and_pro_exclusions(users, venues):
    a, b, _ = venues
    await _promo(a)
    await _promo(a)  # distinct id
    cash = await _promo(b, promotion_type="cashback")
    await database.execute(BarWallet.__table__.insert().values(bar_id=b, available_balance=Decimal("10"), reserved_balance=Decimal("0")))
    await _campaign(a, creative={"promote_happy_hour": True})
    await _campaign(b)  # promotion goal
    await database.execute(UserWallet.__table__.insert().values(user_id=users["pro"], available_balance=Decimal("1.5"), pending_balance=Decimal("0")))
    snap = await vd.load_promo_snapshot(database, venues, {a: 10.0, b: 10.0})

    s = await vd.compute_promo_summary(database, users["pro"], True, snap)
    assert (s.pro_coupons, s.cashback, s.promotions, s.campaigns, s.total) == (5, 1, 3, 2, 11)

    s = await vd.compute_promo_summary(database, users["reg"], False, snap)
    assert (s.pro_coupons, s.cashback, s.promotions, s.campaigns, s.total) == (0, 0, 2, 2, 4)
    assert cash  # cashback promo excluded for non-Pro


@pytest.mark.asyncio
async def test_exhausted_reserved_coupons_and_unavailable_cashback(users):
    from app.bars_and_restaurants.services.pro_coupon_service import current_period_bounds

    key, _, _ = current_period_bounds()
    for i, st in enumerate([ProCouponStatus.REDEEMED] * 3 + [ProCouponStatus.RESERVED] * 2):
        vals = dict(user_id=users["pro"], period_key=key, status=st, created_at=_now(), updated_at=_now())
        await database.execute(ProCouponUsage.__table__.insert().values(**vals))
    s = await vd.compute_promo_summary(database, users["pro"], True, None)
    assert s.pro_coupons == 0 and s.cashback == 0 and s.total == 0  # no location: owned only


@pytest.mark.asyncio
async def test_no_location_counts_owned_benefits_only(users, venues):
    await _promo(venues[0])
    s = await vd.compute_promo_summary(database, users["pro"], True, None)
    assert s.promotions == 0 and s.campaigns == 0 and s.total == 5


# ------------------------------------------------------------- /bars routes
@pytest.fixture
def located(monkeypatch, venues):
    a, b, c = venues
    nearby = [  # deliberately not distance-ordered
        {"bar_id": b, "approximateLocation": 900.0, "image_url": None, "latitude": 0, "longitude": 0},
        {"bar_id": a, "approximateLocation": 300.0, "image_url": None, "latitude": 0, "longitude": 0},
        {"bar_id": c, "approximateLocation": 4000.0, "image_url": None, "latitude": 0, "longitude": 0},
    ]
    import app.bars_and_restaurants.services.places_service as ps

    async def _near(lat, lon, max_distance):
        return [n for n in nearby if n["approximateLocation"] <= max_distance]

    async def _geo(lat, lon):
        return "BR"

    async def _ready(db, ids):
        return set(ids)

    monkeypatch.setattr(ps, "find_bars_near_location", _near)
    monkeypatch.setattr(ps, "reverse_geocode", _geo)
    monkeypatch.setattr(vd, "ready_bar_ids", _ready)
    return venues


def _hdr(uid):
    import os
    from jose import jwt

    now = datetime.now(timezone.utc)
    token = jwt.encode({"sub": str(uid), "exp": now + timedelta(minutes=60), "iat": now, "type": "access"},
                       os.getenv("SECRET_KEY", "test_secret_key_for_testing_only"), algorithm="HS256")
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_bars_listing_filters_pagination_and_order(client, users, located):
    a, b, c = located
    await _promo(b, benefit_text="2x1")
    h = _hdr(users["reg"])
    base = {"latitude": -19.9, "longitude": -43.9, "limit": 2}
    r = await client.get("/bars/", params=base, headers=h)
    assert r.status_code == 200
    data = r.json()
    assert [x["id"] for x in data] == [a, b]  # nearest first, rating present
    assert data[0]["rating"] == 4.5 and data[0]["approximateLocation"] == 300.0
    assert r.headers["x-total-count"] == "3" and r.headers["x-has-more"] == "true"
    r2 = await client.get("/bars/", params={**base, "offset": 2}, headers=h)
    assert [x["id"] for x in r2.json()] == [c] and r2.headers["x-has-more"] == "false"
    # filters apply before pagination
    r = await client.get("/bars/", params={**base, "has_promotions": True}, headers=h)
    assert [x["id"] for x in r.json()] == [b] and r.json()[0]["primary_promotion"] == "promotion"
    assert r.headers["x-total-count"] == "1"
    r = await client.get("/bars/", params={**base, "min_rating": 4}, headers=h)
    assert [x["id"] for x in r.json()] == [a]
    r = await client.get("/bars/", params={**base, "q": "ga"}, headers=h)
    assert [x["id"] for x in r.json()] == [c]
    r = await client.get("/bars/", params={**base, "max_distance": 1000}, headers=h)
    assert [x["id"] for x in r.json()] == [a, b]
    r = await client.get("/bars/", params={**base, "category": "restaurant_bar"}, headers=h)
    assert [x["id"] for x in r.json()] == [b]


@pytest.mark.asyncio
async def test_bars_without_location_uses_country_name_order_and_null_distance(client, users, venues, monkeypatch):
    async def _ready(db, ids):
        return set(ids)

    monkeypatch.setattr(vd, "ready_bar_ids", _ready)
    r = await client.get("/bars/", params={"limit": 20}, headers=_hdr(users["reg"]))
    assert r.status_code == 200
    names = [x["name"] for x in r.json()]
    assert names == sorted(names) and len(names) == 3
    assert all(x["approximateLocation"] is None for x in r.json())


@pytest.mark.asyncio
async def test_bars_legacy_call_still_returns_list(client, users, located, monkeypatch):
    import app.bars_and_restaurants.routes.bars as br

    async def _near(lat, lon, max_distance):
        return []

    monkeypatch.setattr(br, "find_bars_near_location", _near)
    r = await client.get("/bars/", params={"latitude": 1, "longitude": 1}, headers=_hdr(users["reg"]))
    assert r.status_code == 200 and r.json() == []
    assert "x-total-count" not in r.headers


@pytest.mark.asyncio
async def test_home_aggregate_nearest_ignores_ranking_and_nullable_distance(client, users, located, monkeypatch):
    import app.bars_and_restaurants.routes.home as home

    monkeypatch.setattr(home, "database", database)
    await database.execute(Bar.__table__.update().where(Bar.id == located[2]).values(subscription_tier="vip"))
    r = await client.get("/home/", params={"latitude": -19.9, "longitude": -43.9}, headers=_hdr(users["pro"]))
    assert r.status_code == 200
    d = r.json()
    assert d["nearest_venue"]["id"] == located[0] and d["nearest_venue"]["distance_meters"] == 300.0
    assert d["promo_summary"]["total"] >= 5
    assert [b["id"] for b in d["nearby_bars"]][0] == located[0]
    # older payload fields remain
    for k in ("user_status", "nearby_bars", "trending_drinks", "active_promotions", "location_mismatch"):
        assert k in d
    r = await client.get("/home/", headers=_hdr(users["pro"]))
    d = r.json()
    assert d["nearest_venue"] is None and d["promo_summary"]["promotions"] == 0
    assert all(b["distance_meters"] is None for b in d["nearby_bars"])
    r = await client.get("/home/")  # anonymous: no summary -> plain greeting
    assert r.json()["promo_summary"] is None
