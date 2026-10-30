from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional
from zoneinfo import ZoneInfo

from app.database import database
from app.errors import APIError
from app.bars_and_restaurants.models.relational_models import Promotion
from app.bars_and_restaurants.models.wallet_models import ProCouponUsage, ProCouponStatus, FundingSource

SAO_PAULO_TZ = ZoneInfo("America/Sao_Paulo")
PRO_MONTHLY_LIMIT = 5


def current_period_bounds(now_utc: Optional[datetime] = None):
    if now_utc is None:
        now_utc = datetime.now(timezone.utc)
    now_sp = now_utc.astimezone(SAO_PAULO_TZ)
    period_key = now_sp.strftime("%Y-%m")
    period_start = now_sp.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if now_sp.month == 12:
        next_month = now_sp.replace(year=now_sp.year + 1, month=1, day=1, hour=0, minute=0, second=0, microsecond=0)
    else:
        next_month = now_sp.replace(month=now_sp.month + 1, day=1, hour=0, minute=0, second=0, microsecond=0)
    return period_key, period_start.astimezone(timezone.utc), next_month.astimezone(timezone.utc)


async def get_allowance(user_id: int, is_pro: bool, period_key: Optional[str] = None):
    monthly_limit = PRO_MONTHLY_LIMIT if is_pro else 0
    if period_key is None:
        period_key, _, _ = current_period_bounds()

    redeemed_rows = await database.fetch_all(
        ProCouponUsage.__table__.select().where(
            (ProCouponUsage.user_id == user_id) &
            (ProCouponUsage.period_key == period_key) &
            (ProCouponUsage.status == ProCouponStatus.REDEEMED)
        )
    )
    used_count = len(redeemed_rows)

    reserved_rows = await database.fetch_all(
        ProCouponUsage.__table__.select().where(
            (ProCouponUsage.user_id == user_id) &
            (ProCouponUsage.period_key == period_key) &
            (ProCouponUsage.status == ProCouponStatus.RESERVED)
        )
    )
    reserved_count = len(reserved_rows)
    remaining_count = max(0, monthly_limit - used_count - reserved_count)
    _, _, period_resets_at = current_period_bounds()
    return {
        "is_pro": is_pro,
        "period_key": period_key,
        "timezone": "America/Sao_Paulo",
        "period_resets_at": period_resets_at.isoformat(),
        "monthly_limit": monthly_limit,
        "used_count": used_count,
        "reserved_count": reserved_count,
        "remaining_count": remaining_count,
    }


async def validate_and_partition_promotions(
    user_id: int,
    is_pro: bool,
    bar_id: int,
    subtotal: Decimal,
    active_promotion_ids: list,
    strict: bool
):
    if not active_promotion_ids:
        return {"discount_amount": Decimal("0.00"), "cashback_amount": Decimal("0.00"), "accepted_promotion_ids": [], "rejected_promotion_ids": [], "validation_issues": []}

    deduped_ids = list(dict.fromkeys(active_promotion_ids))
    promos_map = {}
    rows = await database.fetch_all(Promotion.__table__.select().where(Promotion.id.in_(deduped_ids)))
    for p in rows:
        promos_map[p["id"]] = dict(p)

    period_key, _, _ = current_period_bounds()
    allowance = await get_allowance(user_id, is_pro, period_key)

    discount_amount = Decimal("0.00")
    cashback_amount = Decimal("0.00")
    accepted_ids = []
    rejected_ids = []
    validation_issues = []
    cashback_slots_needed = 0
    now_utc = datetime.now(timezone.utc)

    from app.bars_and_restaurants.services.wallet_service import WalletService
    from app.database import SessionLocal

    for promo_id in deduped_ids:
        if promo_id not in promos_map:
            if strict:
                raise APIError.promotion_not_applicable(f"Promotion {promo_id} not found")
            rejected_ids.append(promo_id)
            validation_issues.append({"severity": "warning", "message": f"Promotion {promo_id} not found", "related_field": "active_promotion_ids"})
            continue

        promo = promos_map[promo_id]
        if promo["bar_id"] != bar_id:
            if strict:
                raise APIError.promotion_not_applicable("Promotion belongs to a different venue")
            rejected_ids.append(promo_id)
            validation_issues.append({"severity": "warning", "message": f"Promotion {promo_id} cross-venue", "related_field": "active_promotion_ids"})
            continue

        if not promo.get("is_active"):
            if strict:
                raise APIError.promotion_expired(f"Promotion '{promo['title']}' not active")
            rejected_ids.append(promo_id)
            validation_issues.append({"severity": "warning", "message": f"Promotion '{promo['title']}' not active", "related_field": "active_promotion_ids"})
            continue

        if promo.get("start_date") and promo["start_date"] > now_utc:
            if strict:
                raise APIError.promotion_expired(f"Promotion '{promo['title']}' not started")
            rejected_ids.append(promo_id)
            validation_issues.append({"severity": "warning", "message": f"Promotion '{promo['title']}' not started", "related_field": "active_promotion_ids"})
            continue

        if promo.get("end_date") and promo["end_date"] < now_utc:
            if strict:
                raise APIError.promotion_expired(f"Promotion '{promo['title']}' ended")
            rejected_ids.append(promo_id)
            validation_issues.append({"severity": "warning", "message": f"Promotion '{promo['title']}' ended", "related_field": "active_promotion_ids"})
            continue

        promo_type = promo.get("promotion_type", "discount")
        discount_type = promo.get("discount_type", "percentage")
        dval = Decimal(str(promo.get("discount_value", 0)))

        if promo_type == "cashback":
            if not is_pro:
                if strict:
                    raise APIError.pro_subscription_required()
                rejected_ids.append(promo_id)
                validation_issues.append({"severity": "warning", "message": "Dobar Pro required", "related_field": "active_promotion_ids"})
                continue

            cb_amt = subtotal * (dval / 100) if discount_type == "percentage" else min(dval, subtotal)

            db = SessionLocal()
            try:
                funded = WalletService.validate_promotion_funding(db, bar_id, cb_amt, FundingSource.BAR)
            finally:
                db.close()

            if not funded:
                if strict:
                    raise APIError.promotion_not_applicable("Cashback not funded")
                rejected_ids.append(promo_id)
                validation_issues.append({"severity": "warning", "message": f"Promotion '{promo['title']}' not funded", "related_field": "active_promotion_ids"})
                continue

            cashback_slots_needed += 1
            if cashback_slots_needed > allowance["remaining_count"]:
                if strict:
                    raise APIError.pro_coupon_quota_exceeded()
                rejected_ids.append(promo_id)
                validation_issues.append({"severity": "warning", "message": "Pro coupon allowance exhausted", "related_field": "active_promotion_ids"})
                continue

            cashback_amount += cb_amt
            accepted_ids.append(promo_id)
        else:
            disc_amt = subtotal * (dval / 100) if discount_type == "percentage" else min(dval, subtotal)
            discount_amount += disc_amt
            accepted_ids.append(promo_id)

    return {"discount_amount": discount_amount, "cashback_amount": cashback_amount, "accepted_promotion_ids": accepted_ids, "rejected_promotion_ids": rejected_ids, "validation_issues": validation_issues}


async def reserve_coupons_for_order(user_id: int, order_id: int, bar_id: int, accepted_promotion_ids: list, cashback_amount: Decimal):
    period_key, _, _ = current_period_bounds()
    now = datetime.now(timezone.utc)
    if not accepted_promotion_ids:
        return []

    rows = await database.fetch_all(
        Promotion.__table__.select().where(
            Promotion.id.in_(accepted_promotion_ids) &
            (Promotion.promotion_type == "cashback")
        )
    )
    cashback_promos = [dict(r) for r in rows]
    if not cashback_promos:
        return []

    per_slot = cashback_amount / max(len(cashback_promos), 1)
    usage_ids = []
    for promo in cashback_promos:
        usage_id = await database.execute(
            ProCouponUsage.__table__.insert().values(
                user_id=user_id, promotion_id=promo["id"], order_id=order_id,
                bar_id=bar_id, period_key=period_key, status=ProCouponStatus.RESERVED,
                cashback_amount=per_slot, created_at=now, updated_at=now,
            )
        )
        usage_ids.append(usage_id)
    return usage_ids


async def redeem_reserved_coupons(order_id: int, cashback_ledger_id: Optional[int] = None):
    now = datetime.now(timezone.utc)
    rows = await database.fetch_all(
        ProCouponUsage.__table__.select().where(
            (ProCouponUsage.order_id == order_id) &
            (ProCouponUsage.status == ProCouponStatus.RESERVED)
        )
    )
    if not rows:
        return 0
    ids = [r["id"] for r in rows]
    update_vals = {"status": ProCouponStatus.REDEEMED, "updated_at": now}
    if cashback_ledger_id is not None:
        update_vals["cashback_ledger_id"] = cashback_ledger_id
    await database.execute(
        ProCouponUsage.__table__.update().where(ProCouponUsage.id.in_(ids)).values(**update_vals)
    )
    return len(ids)


async def release_reserved_coupons(order_id: int):
    now = datetime.now(timezone.utc)
    rows = await database.fetch_all(
        ProCouponUsage.__table__.select().where(
            (ProCouponUsage.order_id == order_id) &
            (ProCouponUsage.status == ProCouponStatus.RESERVED)
        )
    )
    if not rows:
        return 0
    ids = [r["id"] for r in rows]
    await database.execute(
        ProCouponUsage.__table__.update().where(ProCouponUsage.id.in_(ids)).values(status=ProCouponStatus.RELEASED, updated_at=now)
    )
    return len(ids)


async def refund_redeemed_coupons(order_id: int):
    now = datetime.now(timezone.utc)
    rows = await database.fetch_all(
        ProCouponUsage.__table__.select().where(
            (ProCouponUsage.order_id == order_id) &
            (ProCouponUsage.status == ProCouponStatus.REDEEMED)
        )
    )
    if not rows:
        return {"refunded_count": 0, "cashback_ledger_ids": []}
    ids = [r["id"] for r in rows]
    ledger_ids = [r["cashback_ledger_id"] for r in rows if r["cashback_ledger_id"]]
    await database.execute(
        ProCouponUsage.__table__.update().where(ProCouponUsage.id.in_(ids)).values(status=ProCouponStatus.REFUNDED, updated_at=now)
    )
    return {"refunded_count": len(ids), "cashback_ledger_ids": ledger_ids}
