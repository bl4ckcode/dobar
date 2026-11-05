import asyncio
import os
from datetime import datetime
from decimal import Decimal
from uuid import uuid4

import pytest
from databases import Database
from sqlalchemy import create_engine, text

from app.database import Base
from app.auth.auth_models import User
from app.auth.rbac_models import UserProfile
from app.bars_and_restaurants.models.relational_models import Bar, Order, UserDocument
from app.bars_and_restaurants.models.wallet_models import ProCouponUsage, ProCouponStatus, CashbackLedger, UserWallet
from app.errors import APIError
from app.payment.order_payments import charge_order, settle_order_rewards

pytestmark = pytest.mark.asyncio


@pytest.fixture
async def postgres_payment_db():
    url = os.environ.get("PAYMENT_TEST_DATABASE_URL")
    if not url:
        pytest.skip("PAYMENT_TEST_DATABASE_URL required for PostgreSQL concurrency evidence")
    schema = "payment_" + uuid4().hex
    admin = create_engine(url)
    with admin.begin() as connection:
        connection.execute(text(f'CREATE SCHEMA "{schema}"'))
    engine = create_engine(url, connect_args={"options": f"-csearch_path={schema}"})
    Base.metadata.create_all(engine)
    db = Database(url, server_settings={"search_path": schema})
    await db.connect()
    try:
        await db.execute(User.__table__.insert().values(id=701, email="payer@example.com", phone_number="+5531999999999", email_verified=False, phone_verified=False, is_active=True))
        await db.execute(UserProfile.__table__.insert().values(user_id=701, display_name="Cliente Teste"))
        await db.execute(UserDocument.__table__.insert().values(user_id=701, type="cpf", number="52998224725"))
        await db.execute(Bar.__table__.insert().values(id=801, name="Bar"))
        await db.execute(Order.__table__.insert().values(id=901, user_id=701, bar_id=801,
            total_price=25, status="pending", payment_status="pending"))
        yield db
    finally:
        await db.disconnect()
        engine.dispose()
        with admin.begin() as connection:
            connection.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
        admin.dispose()


async def test_concurrent_different_attempt_cannot_start_second_charge(postgres_payment_db):
    started = asyncio.Event()
    finish = asyncio.Event()
    keys = []
    class Gateway:
        async def charge(self, **kwargs):
            keys.append(kwargs["idempotency_key"])
            started.set()
            await finish.wait()
            return {"payment_id": "pay_one", "status": "pending", "amount": 25.0,
                    "currency": "BRL", "gateway": "stone", "gateway_id": "ch_one",
                    "created_at": "2026-11-03T00:00:00"}
    gateway = Gateway()
    args = (postgres_payment_db, gateway, 701, 901, {"type": "pix"})
    first = asyncio.create_task(charge_order(*args, key="first-attempt"))
    await asyncio.wait_for(started.wait(), timeout=5)
    try:
        with pytest.raises(APIError) as caught:
            await charge_order(*args, key="competing-attempt")
        assert caught.value.status_code == 409
    finally:
        finish.set()
    result = await first
    assert (await charge_order(*args, key="first-attempt"))["payment_id"] == result["payment_id"]
    assert len(keys) == 1


async def test_concurrent_reward_confirmation_has_one_ledger_entry(postgres_payment_db):
    db = postgres_payment_db
    now = datetime.utcnow()
    await db.execute(ProCouponUsage.__table__.insert().values(user_id=701, order_id=901, bar_id=801,
        period_key="2026-11", status=ProCouponStatus.RESERVED, cashback_amount=Decimal("2.50"),
        created_at=now, updated_at=now))
    await db.execute(Order.__table__.update().where(Order.id == 901).values(payment_status="paid"))
    order = await db.fetch_one(Order.__table__.select().where(Order.id == 901))
    await asyncio.gather(settle_order_rewards(db, order), settle_order_rewards(db, order))
    assert len(await db.fetch_all(CashbackLedger.__table__.select())) == 1
    wallet = await db.fetch_one(UserWallet.__table__.select().where(UserWallet.user_id == 701))
    assert wallet["pending_balance"] == Decimal("2.50")
