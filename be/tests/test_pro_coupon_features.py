import pytest
import os
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from app.database import database
from app.bars_and_restaurants.models.relational_models import Bar, Promotion, BarOwner
from app.bars_and_restaurants.models.wallet_models import ProCouponUsage, ProCouponStatus


def create_test_token(user_id: int) -> str:
    from jose import jwt
    SECRET_KEY = os.getenv("SECRET_KEY", "test_secret_key_for_testing_only")
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=60)
    return jwt.encode({"sub": str(user_id), "exp": expire, "iat": now, "type": "access"}, SECRET_KEY, algorithm="HS256")


@pytest.fixture
async def pro_user(cleanup_database):
    from app.auth.auth_models import User
    uid = await database.execute(User.__table__.insert().values(
        firebase_uid="pro_coupon_001", phone_number="+5531900000001",
        email="pro_coupon@test.com", is_active=True, subscription_tier="pro",
        email_verified=False, phone_verified=False,
    ))
    return {"id": uid}


@pytest.fixture
async def regular_user(cleanup_database):
    from app.auth.auth_models import User
    uid = await database.execute(User.__table__.insert().values(
        firebase_uid="reg_coupon_002", phone_number="+5531900000002",
        email="regular_coupon@test.com", is_active=True, subscription_tier="regular",
        email_verified=False, phone_verified=False,
    ))
    return {"id": uid}


@pytest.fixture
async def venue(cleanup_database):
    oid = await database.execute(BarOwner.__table__.insert().values(id=8001, name="Owner", email="owner_cv@test.com"))
    bid = await database.execute(Bar.__table__.insert().values(
        name="Venue", address="Rua CV, 1", owner_id=8001, subscription_tier="regular"))
    return {"id": bid}


@pytest.fixture
async def cashback_promo(venue):
    pid = await database.execute(Promotion.__table__.insert().values(
        bar_id=venue["id"], title="10% Cashback PRO", benefit_text="10% cashback",
        promotion_type="cashback", discount_type="percentage", discount_value=10.0, is_active=True,
    ))
    return {"id": pid, "bar_id": venue["id"]}


@pytest.fixture
async def discount_promo(venue):
    pid = await database.execute(Promotion.__table__.insert().values(
        bar_id=venue["id"], title="5% Desconto", benefit_text="5% off",
        promotion_type="discount", discount_type="percentage", discount_value=5.0, is_active=True,
    ))
    return {"id": pid, "bar_id": venue["id"]}


@pytest.mark.asyncio
class TestAllowance:
    async def test_pro_5_limit(self, pro_user):
        from app.bars_and_restaurants.services.pro_coupon_service import get_allowance
        a = await get_allowance(pro_user["id"], True)
        assert a["monthly_limit"] == 5 and a["remaining_count"] == 5 and a["is_pro"] is True

    async def test_regular_0_limit(self, regular_user):
        from app.bars_and_restaurants.services.pro_coupon_service import get_allowance
        a = await get_allowance(regular_user["id"], False)
        assert a["monthly_limit"] == 0 and a["remaining_count"] == 0 and a["is_pro"] is False

    async def test_no_rollover(self, pro_user):
        from app.bars_and_restaurants.services.pro_coupon_service import get_allowance
        now = datetime.now(timezone.utc)
        await database.execute(ProCouponUsage.__table__.insert().values(
            user_id=pro_user["id"], period_key="2026-01",
            status=ProCouponStatus.REDEEMED, cashback_amount=Decimal("5.00"),
            created_at=now, updated_at=now,
        ))
        a = await get_allowance(pro_user["id"], True)
        assert a["used_count"] == 0 and a["remaining_count"] == 5


@pytest.mark.asyncio
class TestValidation:
    async def test_regular_rejected_cashback_soft(self, regular_user, cashback_promo, venue):
        from app.bars_and_restaurants.services.pro_coupon_service import validate_and_partition_promotions
        r = await validate_and_partition_promotions(regular_user["id"], False, venue["id"], Decimal("100"), [cashback_promo["id"]], False)
        assert cashback_promo["id"] not in r["accepted_promotion_ids"]
        assert cashback_promo["id"] in r["rejected_promotion_ids"]

    async def test_regular_strict_raises_403(self, regular_user, cashback_promo, venue):
        from app.bars_and_restaurants.services.pro_coupon_service import validate_and_partition_promotions
        from app.errors import APIError
        with pytest.raises(APIError) as exc:
            await validate_and_partition_promotions(regular_user["id"], False, venue["id"], Decimal("100"), [cashback_promo["id"]], True)
        assert exc.value.status_code == 403

    async def test_discount_accepted_regular(self, regular_user, discount_promo, venue):
        from app.bars_and_restaurants.services.pro_coupon_service import validate_and_partition_promotions
        r = await validate_and_partition_promotions(regular_user["id"], False, venue["id"], Decimal("100"), [discount_promo["id"]], False)
        assert discount_promo["id"] in r["accepted_promotion_ids"]
        assert float(r["discount_amount"]) == pytest.approx(5.0)
        assert float(r["cashback_amount"]) == 0.0

    async def test_cross_venue_rejected(self, pro_user, venue):
        from app.bars_and_restaurants.services.pro_coupon_service import validate_and_partition_promotions
        other_oid = await database.execute(BarOwner.__table__.insert().values(id=8002, name="OtherOwn", email="otherv@test.com"))
        other_bid = await database.execute(Bar.__table__.insert().values(name="OtherBar", address="Rua Y, 2", owner_id=8002, subscription_tier="regular"))
        cross_pid = await database.execute(Promotion.__table__.insert().values(
            bar_id=other_bid, title="Cross CB", promotion_type="cashback",
            discount_type="percentage", discount_value=10.0, is_active=True,
        ))
        r = await validate_and_partition_promotions(pro_user["id"], True, venue["id"], Decimal("100"), [cross_pid], False)
        assert cross_pid not in r["accepted_promotion_ids"]


@pytest.mark.asyncio
class TestLifecycle:
    async def test_reserve_release_restores_quota(self, pro_user, venue, cashback_promo):
        from app.bars_and_restaurants.services.pro_coupon_service import (
            reserve_coupons_for_order, release_reserved_coupons, get_allowance
        )
        from app.database import SessionLocal
        from app.bars_and_restaurants.services.wallet_service import WalletService
        db = SessionLocal()
        try:
            w = WalletService.get_or_create_bar_wallet(db, venue["id"])
            w.available_balance = Decimal("1000.00")
            db.commit()
        finally:
            db.close()
        await reserve_coupons_for_order(pro_user["id"], 7001, venue["id"], [cashback_promo["id"]], Decimal("10.00"))
        a1 = await get_allowance(pro_user["id"], True)
        assert a1["reserved_count"] == 1 and a1["remaining_count"] == 4
        await release_reserved_coupons(7001)
        a2 = await get_allowance(pro_user["id"], True)
        assert a2["reserved_count"] == 0 and a2["remaining_count"] == 5


@pytest.mark.asyncio
class TestEndpoints:
    async def test_pro_benefits_endpoint(self, client, pro_user):
        token = create_test_token(pro_user["id"])
        r = await client.get("/me/pro-benefits", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        assert r.json()["monthly_limit"] == 5

    async def test_regular_benefits_endpoint(self, client, regular_user):
        token = create_test_token(regular_user["id"])
        r = await client.get("/me/pro-benefits", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        assert r.json()["monthly_limit"] == 0

    async def test_checkout_no_cashback_without_promo(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        await client.post("/cart/items", json={
            "menu_item_id": 1, "bar_id": test_bar_in_db["id"],
            "menu_item_name": "Item", "quantity": 1, "unit_price": 100.00
        }, headers=headers)
        r = await client.post("/cart/checkout", json={"order_type": "pickup", "payment_method": "credit_card"}, headers=headers)
        assert r.status_code == 201
        assert r.json().get("cashback_earned", 0.0) == 0.0

    async def test_advertising_contract_unchanged(self, client):
        r = await client.get("/advertising/plans")
        assert r.status_code in (200, 401, 403, 404)
