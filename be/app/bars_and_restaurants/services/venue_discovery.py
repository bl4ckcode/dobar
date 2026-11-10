"""Venue discovery helpers shared by ``GET /home/`` and ``GET /bars/``.

Responsibilities (all server-side, read-only):
- classify the promotions a venue currently offers (Happy Hour -> Cashback ->
  Promotion priority, from stored classifications, never from campaign titles);
- compute the Home promo count from four independent, de-duplicated sources;
- list "ready" venues (menu + bank account) with optional location, name search,
  rating and promotion filters, and offset pagination.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional, Set
from zoneinfo import ZoneInfo

from sqlalchemy import and_, or_, select

from app.advertising.models import AdvertisingCampaign, CampaignStatus
from app.bars_and_restaurants.models.relational_models import Bar as BarModel, Promotion
from app.bars_and_restaurants.models.wallet_models import BarWallet, UserWallet
from app.bars_and_restaurants.services.image_upload import extract_s3_key, generate_presigned_url
from app.bars_and_restaurants.services.pro_coupon_service import get_allowance

DISCOVERY_RADIUS_M = 50_000
DEFAULT_COUNTRY = "BR"
_DEFAULT_TZ = "America/Sao_Paulo"
_DAY_NAMES = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
_DAY_ABBR = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

HAPPY_HOUR = "happy_hour"
CASHBACK = "cashback"
PROMOTION = "promotion"
_PRIORITY = (HAPPY_HOUR, CASHBACK, PROMOTION)


# --------------------------------------------------------------------------
# Time helpers
# --------------------------------------------------------------------------

def _utc_aware(value: Optional[datetime]) -> Optional[datetime]:
    if value is None:
        return None
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def _local_now(now_utc: datetime, tz_name: Optional[str]) -> datetime:
    try:
        return now_utc.astimezone(ZoneInfo(tz_name or _DEFAULT_TZ))
    except Exception:
        return now_utc.astimezone(ZoneInfo(_DEFAULT_TZ))


def _minutes(hhmm: Optional[str]) -> Optional[int]:
    if not hhmm or not isinstance(hhmm, str) or ":" not in hhmm:
        return None
    try:
        h, m = hhmm.split(":")[:2]
        return int(h) * 60 + int(m)
    except ValueError:
        return None


def _in_window(now_min: int, start: Optional[int], end: Optional[int]) -> bool:
    if start is None or end is None or start == end:
        return True
    if start < end:
        return start <= now_min < end
    return now_min >= start or now_min < end  # overnight window


def _day_matches(days: Any, local: datetime) -> bool:
    if not days or not isinstance(days, (list, tuple)):
        return True
    wanted = {str(d).strip().lower() for d in days}
    return _DAY_NAMES[local.weekday()] in wanted or _DAY_ABBR[local.weekday()] in wanted


def promotion_is_live(row: Dict[str, Any], now_utc: datetime, tz_name: Optional[str]) -> bool:
    if not row.get("is_active"):
        return False
    start, end = _utc_aware(row.get("start_date")), _utc_aware(row.get("end_date"))
    if start and start > now_utc:
        return False
    if end and end < now_utc:
        return False
    local = _local_now(now_utc, tz_name)
    if not _day_matches(row.get("recurring_days"), local):
        return False
    return _in_window(local.hour * 60 + local.minute, _minutes(row.get("start_time")), _minutes(row.get("end_time")))


def campaign_is_live(row: Dict[str, Any], now_utc: datetime, tz_name: Optional[str]) -> bool:
    status = row.get("status")
    status = getattr(status, "value", status)
    if status != CampaignStatus.ACTIVE.value:
        return False
    start, end = _utc_aware(row.get("start_time")), _utc_aware(row.get("end_time"))
    if start and start > now_utc:
        return False
    if end and end <= now_utc:
        return False
    if (row.get("budget_spent") or 0) >= (row.get("budget_amount") or 0):
        return False
    targeting = row.get("targeting") if isinstance(row.get("targeting"), dict) else {}
    local = _local_now(now_utc, tz_name)
    if not _day_matches(targeting.get("days"), local):
        return False
    hs, he = targeting.get("hours_start"), targeting.get("hours_end")
    if isinstance(hs, int) and isinstance(he, int) and not (hs == 0 and he in (24, 0)):
        h = local.hour
        if hs < he:
            return hs <= h < he
        return h >= hs or h < he
    return True


def _campaign_kind(row: Dict[str, Any]) -> Optional[str]:
    """Offer classification from stored fields only (never from titles)."""
    creative = row.get("creative") if isinstance(row.get("creative"), dict) else {}
    if creative.get("promote_happy_hour") is True:
        return HAPPY_HOUR
    if row.get("campaign_goal") == "promotion":
        return PROMOTION
    return None


def campaign_in_range(row: Dict[str, Any], distance_m: Optional[float]) -> bool:
    """Apply the campaign's own (narrower) radius when a distance is known."""
    if distance_m is None:
        return True
    targeting = row.get("targeting") if isinstance(row.get("targeting"), dict) else {}
    radius = targeting.get("radius_km")
    limit = DISCOVERY_RADIUS_M
    if isinstance(radius, (int, float)) and radius > 0:
        limit = min(limit, radius * 1000)
    return distance_m <= limit


# --------------------------------------------------------------------------
# Promotion data
# --------------------------------------------------------------------------

@dataclass
class VenuePromos:
    kinds: Set[str] = field(default_factory=set)
    texts: Dict[str, str] = field(default_factory=dict)

    @property
    def primary(self) -> Optional[str]:
        return next((k for k in _PRIORITY if k in self.kinds), None)

    @property
    def text(self) -> Optional[str]:
        primary = self.primary
        return self.texts.get(primary) if primary else None


@dataclass
class PromoSnapshot:
    venues: Dict[int, VenuePromos]
    promotion_ids: Dict[int, Set[int]]  # bar_id -> redeemable promotion ids (non-cashback)
    cashback_ids: Dict[int, Set[int]]   # bar_id -> funded cashback promotion ids
    campaign_ids: Dict[int, Set[int]]   # bar_id -> offer campaign ids


async def load_promo_snapshot(
    db, bar_ids: Iterable[int], distances: Optional[Dict[int, Optional[float]]] = None, now_utc: Optional[datetime] = None
) -> PromoSnapshot:
    """Batch-load live promotions/campaigns for ``bar_ids`` (one query each)."""
    ids = list({int(b) for b in bar_ids})
    snap = PromoSnapshot({i: VenuePromos() for i in ids}, {}, {}, {})
    if not ids:
        return snap
    now_utc = now_utc or datetime.now(timezone.utc)
    distances = distances or {}

    tz_rows = await db.fetch_all(select(BarModel.id, BarModel.timezone).where(BarModel.id.in_(ids)))
    tz_map = {r["id"]: r["timezone"] for r in tz_rows}

    funded_rows = await db.fetch_all(
        select(BarWallet.bar_id).where(and_(BarWallet.bar_id.in_(ids), BarWallet.available_balance > 0))
    )
    funded = {r["bar_id"] for r in funded_rows}

    promo_rows = await db.fetch_all(select(Promotion.__table__).where(and_(Promotion.bar_id.in_(ids), Promotion.is_active.is_(True))))
    for r in promo_rows:
        row = dict(r)
        bar_id = row["bar_id"]
        if not promotion_is_live(row, now_utc, tz_map.get(bar_id)):
            continue
        venue = snap.venues[bar_id]
        text = row.get("benefit_text") or row.get("title")
        if row.get("promotion_type") == "cashback":
            if bar_id not in funded:
                continue  # unfunded cashback is not redeemable
            snap.cashback_ids.setdefault(bar_id, set()).add(row["id"])
            kind = CASHBACK
        else:
            snap.promotion_ids.setdefault(bar_id, set()).add(row["id"])
            kind = PROMOTION
        venue.kinds.add(kind)
        venue.texts.setdefault(kind, text)

    camp_rows = await db.fetch_all(
        select(AdvertisingCampaign.__table__).where(
            and_(AdvertisingCampaign.bar_id.in_(ids), AdvertisingCampaign.status == CampaignStatus.ACTIVE)
        )
    )
    for r in camp_rows:
        row = dict(r)
        bar_id = row["bar_id"]
        kind = _campaign_kind(row)
        if kind is None or not campaign_is_live(row, now_utc, tz_map.get(bar_id)):
            continue
        if not campaign_in_range(row, distances.get(bar_id)):
            continue
        creative = row.get("creative") if isinstance(row.get("creative"), dict) else {}
        snap.campaign_ids.setdefault(bar_id, set()).add(row["id"])
        venue = snap.venues[bar_id]
        venue.kinds.add(kind)
        venue.texts.setdefault(kind, creative.get("tagline") or creative.get("title") or row.get("name"))
    return snap


@dataclass
class PromoSummary:
    total: int
    pro_coupons: int
    cashback: int
    promotions: int
    campaigns: int


async def compute_promo_summary(
    db, user_id: int, is_pro: bool, snapshot: Optional[PromoSnapshot]
) -> PromoSummary:
    """Compose the Home promo count. ``snapshot`` is None without location."""
    allowance = await get_allowance(user_id, is_pro)
    pro = allowance["remaining_count"] if is_pro else 0
    wallet = await db.fetch_one(UserWallet.__table__.select().where(UserWallet.user_id == user_id))
    cashback = 1 if wallet and (wallet["available_balance"] or 0) > 0 else 0

    promotions: Set[int] = set()
    campaigns: Set[int] = set()
    if snapshot is not None:
        for ids in snapshot.promotion_ids.values():
            promotions |= ids
        if is_pro:  # cashback promotions are Pro-only
            for ids in snapshot.cashback_ids.values():
                promotions |= ids
        for ids in snapshot.campaign_ids.values():
            campaigns |= ids
    total = pro + cashback + len(promotions) + len(campaigns)
    return PromoSummary(total, pro, cashback, len(promotions), len(campaigns))


# --------------------------------------------------------------------------
# Venue listing
# --------------------------------------------------------------------------

def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 6371000 * 2 * math.asin(math.sqrt(a))


def _sign(url: Optional[str]) -> Optional[str]:
    if not url:
        return None
    try:
        return generate_presigned_url(extract_s3_key(url))
    except Exception:
        return None


async def ready_bar_ids(db, bar_ids: List[int]) -> Set[int]:
    from app.bars_and_restaurants.models.bank_account import BarBankAccount
    from app.bars_and_restaurants.models.relational_models import Menu

    if not bar_ids:
        return set()
    menus = await db.fetch_all(select(Menu.bar_id).where(and_(Menu.bar_id.in_(bar_ids), Menu.is_active.is_(True))))
    banks = await db.fetch_all(select(BarBankAccount.bar_id).where(BarBankAccount.bar_id.in_(bar_ids)))
    return {r["bar_id"] for r in menus} & {r["bar_id"] for r in banks}


async def located_ready_venues(
    db, latitude: float, longitude: float, max_distance: float = DISCOVERY_RADIUS_M, category: Optional[str] = None
) -> List[Dict[str, Any]]:
    """Ready venues near a point, nearest first (independent of ad tiers)."""
    from app.bars_and_restaurants.services.places_service import find_bars_near_location, reverse_geocode

    nearby = await find_bars_near_location(latitude, longitude, max_distance)
    if not nearby:
        return []
    ids = [int(n["bar_id"]) for n in nearby]
    rows = await db.fetch_all(select(BarModel.__table__).where(BarModel.id.in_(ids)))
    pg = {r["id"]: dict(r) for r in rows}
    detected = await reverse_geocode(latitude, longitude)
    ready = await ready_bar_ids(db, list(pg))
    out = []
    for n in nearby:
        bar = pg.get(int(n["bar_id"]))
        if not bar or bar["id"] not in ready:
            continue
        if detected and (bar.get("country_code") or DEFAULT_COUNTRY) != detected:
            continue
        if category and bar.get("category") != category:
            continue
        bar["approximateLocation"] = n.get("approximateLocation")
        bar["image_url"] = _sign(n.get("image_url")) or _sign(bar.get("logo_url"))
        bar["latitude"] = n.get("latitude", bar.get("latitude"))
        bar["longitude"] = n.get("longitude", bar.get("longitude"))
        out.append(bar)
    out.sort(key=lambda b: (b["approximateLocation"] is None, b["approximateLocation"] or 0, b["id"]))
    return out


async def country_ready_venues(
    db, country_code: Optional[str], category: Optional[str] = None, limit: Optional[int] = None
) -> List[Dict[str, Any]]:
    """Ready venues for a country without distances, ordered by name then id."""
    q = select(BarModel.__table__).where(BarModel.country_code == (country_code or DEFAULT_COUNTRY))
    if category:
        q = q.where(BarModel.category == category)
    q = q.order_by(BarModel.name.asc(), BarModel.id.asc())
    rows = [dict(r) for r in await db.fetch_all(q)]
    ready = await ready_bar_ids(db, [r["id"] for r in rows])
    out = []
    for bar in rows:
        if bar["id"] not in ready:
            continue
        bar["approximateLocation"] = None
        bar["image_url"] = _sign(bar.get("logo_url") or bar.get("cover_url"))
        out.append(bar)
        if limit and len(out) >= limit:
            break
    return out


def apply_filters(
    venues: List[Dict[str, Any]],
    snapshot: Optional[PromoSnapshot],
    q: Optional[str] = None,
    min_rating: Optional[float] = None,
    has_promotions: bool = False,
) -> List[Dict[str, Any]]:
    needle = (q or "").strip().casefold()
    out = []
    for v in venues:
        if needle and needle not in (v.get("name") or "").casefold():
            continue
        if min_rating is not None and (v.get("rating") or 0.0) < min_rating:
            continue
        if has_promotions and not (snapshot and snapshot.venues.get(v["id"]) and snapshot.venues[v["id"]].kinds):
            continue
        out.append(v)
    return out


def annotate(venues: List[Dict[str, Any]], snapshot: Optional[PromoSnapshot]) -> List[Dict[str, Any]]:
    for v in venues:
        vp = snapshot.venues.get(v["id"]) if snapshot else None
        v["rating"] = float(v.get("rating") or 0.0)
        v["primary_promotion"] = vp.primary if vp else None
        v["promotion_text"] = vp.text if vp else None
        v["has_promotions"] = bool(vp and vp.kinds)
    return venues
