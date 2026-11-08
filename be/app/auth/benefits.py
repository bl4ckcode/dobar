"""Authenticated inventory of the caller's owned benefits and their eligible venues.

Benefit kinds (no other earning/redemption rules are invented here):
- ``pro_coupon``: the Dobar Pro monthly cashback-coupon allowance (5 per
  America/Sao_Paulo calendar month, no rollover). Redeemable only on active,
  venue-funded ``cashback`` promotions, mirroring checkout validation in
  ``pro_coupon_service``.
- ``cashback``: the wallet balance. Redemption is wallet-wide today, so venue
  eligibility is NOT defined; the venues endpoint refuses instead of guessing.

Reading never reserves, redeems or applies anything.
"""
from datetime import datetime
from decimal import Decimal
from typing import List, Literal, Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import and_, or_, select

from app.bars_and_restaurants.models.relational_models import Bar, Promotion
from app.bars_and_restaurants.models.wallet_models import BarWallet, CashbackLedger, CashbackStatus, CashbackType, UserWallet
from app.bars_and_restaurants.services.pro_coupon_service import get_allowance
from app.database import database
from app.errors import APIError
from .rbac_middleware import AuthUser, get_current_user

benefits_router = APIRouter(prefix="/me/benefits", tags=["Profile"])

CASHBACK_ID = "cashback_wallet"
PRO_COUPON_PREFIX = "pro_coupon:"


class BenefitQuantity(BaseModel):
    unit: Literal["coupon", "brl_cents"]
    remaining: int
    limit: Optional[int] = None
    used: Optional[int] = None
    reserved: Optional[int] = None
    pending: Optional[int] = None


class BenefitEligibility(BaseModel):
    # False: the backend has no authoritative venue rule for this benefit.
    venue_filter_supported: bool
    venue_count: Optional[int] = None


class Benefit(BaseModel):
    id: str
    kind: Literal["pro_coupon", "cashback"]
    status: Literal["active", "unavailable"]
    unavailable_reason: Optional[
        Literal["pro_required", "allowance_exhausted", "no_eligible_venues", "zero_balance", "pending_clearance"]
    ] = None
    quantity: BenefitQuantity
    expires_at: Optional[datetime] = None
    conditions: List[str]
    eligibility: BenefitEligibility


class BenefitsResponse(BaseModel):
    benefits: List[Benefit]
    active_count: int
    currency: str = "BRL"


class EligiblePromotion(BaseModel):
    id: int
    title: str
    benefit_text: Optional[str] = None
    terms: Optional[str] = None
    discount_type: str
    discount_value: float
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    recurring_days: Optional[list] = None
    ends_at: Optional[datetime] = None


class EligibleVenue(BaseModel):
    bar_id: int
    name: Optional[str] = None
    address: Optional[str] = None
    category: Optional[str] = None
    logo_url: Optional[str] = None
    promotions: List[EligiblePromotion]


class BenefitVenuesResponse(BaseModel):
    benefit_id: str
    conditions: List[str]
    venues: List[EligibleVenue]
    total: int
    limit: int
    offset: int


def _cents(value) -> int:
    return int((Decimal(str(value or 0)) * 100).to_integral_value())


def _funded_promotion_filter():
    now = datetime.utcnow()  # promotions.start_date/end_date are naive UTC
    return and_(
        Promotion.promotion_type == "cashback",
        Promotion.is_active.is_(True),
        or_(Promotion.start_date.is_(None), Promotion.start_date <= now),
        or_(Promotion.end_date.is_(None), Promotion.end_date >= now),
        BarWallet.available_balance > 0,
    )


async def _eligible_pro_venue_count() -> int:
    q = (
        select(Promotion.bar_id)
        .join(BarWallet, BarWallet.bar_id == Promotion.bar_id)
        .join(Bar, Bar.id == Promotion.bar_id)
        .where(_funded_promotion_filter())
        .distinct()
    )
    return len(await database.fetch_all(q))


def pro_coupon_id(period_key: str) -> str:
    return f"{PRO_COUPON_PREFIX}{period_key}"


async def build_benefits(user_id: int, is_pro: bool) -> List[Benefit]:
    allowance = await get_allowance(user_id, is_pro)
    venue_count = await _eligible_pro_venue_count() if is_pro else 0
    reason = None
    if not is_pro:
        reason = "pro_required"
    elif allowance["remaining_count"] <= 0:
        reason = "allowance_exhausted"
    elif venue_count == 0:
        # Quota remains but nowhere to use it: not an active benefit.
        reason = "no_eligible_venues"
    pro = Benefit(
        id=pro_coupon_id(allowance["period_key"]),
        kind="pro_coupon",
        status="unavailable" if reason else "active",
        unavailable_reason=reason,
        quantity=BenefitQuantity(
            unit="coupon",
            remaining=allowance["remaining_count"],
            limit=allowance["monthly_limit"],
            used=allowance["used_count"],
            reserved=allowance["reserved_count"],
        ),
        expires_at=datetime.fromisoformat(allowance["period_resets_at"]),
        conditions=["pro_required", "monthly_limit_no_rollover", "cashback_promotions_only", "venue_funded_only"],
        eligibility=BenefitEligibility(venue_filter_supported=True, venue_count=venue_count),
    )

    wallet = await database.fetch_one(UserWallet.__table__.select().where(UserWallet.user_id == user_id))
    available = _cents(wallet["available_balance"]) if wallet else 0
    pending = _cents(wallet["pending_balance"]) if wallet else 0
    expiry_row = await database.fetch_one(
        select(CashbackLedger.expires_at)
        .where(
            (CashbackLedger.user_id == user_id)
            & (CashbackLedger.type == CashbackType.EARN)
            & (CashbackLedger.status == CashbackStatus.AVAILABLE)
            & (CashbackLedger.expires_at.isnot(None))
        )
        .order_by(CashbackLedger.expires_at.asc())
        .limit(1)
    )
    cash_reason = None
    if available <= 0:
        cash_reason = "pending_clearance" if pending > 0 else "zero_balance"
    cashback = Benefit(
        id=CASHBACK_ID,
        kind="cashback",
        status="unavailable" if cash_reason else "active",
        unavailable_reason=cash_reason,
        quantity=BenefitQuantity(unit="brl_cents", remaining=available, pending=pending),
        expires_at=expiry_row["expires_at"] if expiry_row else None,
        conditions=["wallet_balance"],
        eligibility=BenefitEligibility(venue_filter_supported=False, venue_count=None),
    )
    return [pro, cashback]


@benefits_router.get("", response_model=BenefitsResponse)
async def list_benefits(current_user: AuthUser = Depends(get_current_user)):
    benefits = await build_benefits(current_user.id, current_user.is_pro())
    return BenefitsResponse(benefits=benefits, active_count=sum(1 for b in benefits if b.status == "active"))


@benefits_router.get("/{benefit_id}/venues", response_model=BenefitVenuesResponse)
async def list_benefit_venues(
    benefit_id: str,
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    current_user: AuthUser = Depends(get_current_user),
):
    """Eligible venues for one benefit owned by the caller. Never redeems."""
    benefits = {b.id: b for b in await build_benefits(current_user.id, current_user.is_pro())}
    benefit = benefits.get(benefit_id)
    if benefit is None:
        raise APIError.not_found("Benefit not found")
    if benefit.kind == "cashback":
        raise APIError.conflict("Venue eligibility is not defined for wallet cashback")
    if benefit.unavailable_reason == "pro_required":
        raise APIError.pro_subscription_required()
    if benefit.status != "active":
        raise APIError.conflict("Benefit is not currently available")

    rows = await database.fetch_all(
        select(
            Promotion.id.label("promo_id"),
            Promotion.bar_id,
            Promotion.title,
            Promotion.benefit_text,
            Promotion.terms,
            Promotion.discount_type,
            Promotion.discount_value,
            Promotion.start_time,
            Promotion.end_time,
            Promotion.recurring_days,
            Promotion.end_date,
            Bar.name.label("bar_name"),
            Bar.address,
            Bar.category,
            Bar.logo_url,
        )
        .join(BarWallet, BarWallet.bar_id == Promotion.bar_id)
        .join(Bar, Bar.id == Promotion.bar_id)
        .where(_funded_promotion_filter())
        .order_by(Bar.name.asc(), Bar.id.asc(), Promotion.id.asc())
    )
    grouped: dict = {}
    for r in rows:
        v = grouped.setdefault(
            r["bar_id"],
            EligibleVenue(
                bar_id=r["bar_id"], name=r["bar_name"], address=r["address"], category=r["category"],
                logo_url=r["logo_url"], promotions=[],
            ),
        )
        v.promotions.append(
            EligiblePromotion(
                id=r["promo_id"], title=r["title"], benefit_text=r["benefit_text"], terms=r["terms"],
                discount_type=r["discount_type"], discount_value=r["discount_value"],
                start_time=r["start_time"], end_time=r["end_time"], recurring_days=r["recurring_days"],
                ends_at=r["end_date"],
            )
        )
    venues = list(grouped.values())
    return BenefitVenuesResponse(
        benefit_id=benefit_id,
        conditions=benefit.conditions,
        venues=venues[offset: offset + limit],
        total=len(venues),
        limit=limit,
        offset=offset,
    )
