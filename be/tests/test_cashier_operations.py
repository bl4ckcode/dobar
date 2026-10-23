import pytest
from httpx import AsyncClient
from app.database import database
from app.bars_and_restaurants.routes.orders import compute_order_expiry_utc
from app.bars_and_restaurants.models.relational_models import (
    Bar as BarModel,
    Order as OrderModel,
)
from app.auth.rbac_models import BarRole, BarStaff
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

TZ = "America/Sao_Paulo"

NORMAL_HOURS = {
    day: {"open": "08:00", "close": "22:00", "is_closed": False}
    for day in ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
}

@pytest.mark.asyncio
class TestCashierOperations:
    async def test_get_live_orders(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        
        response = await client.get(f"/bars/{bar_id}/orders/live", headers=headers)
        
        # If the auth_client is an owner, this will be 200 list
        # We check the endpoint is up and returns correct shape or auth error
        assert response.status_code in [200, 403]
        
        if response.status_code == 200:
            assert isinstance(response.json(), list)

    async def test_update_order_status(self, auth_client, test_bar_in_db, test_order_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        order_id = test_order_in_db["id"]
        
        # We try to update a test order
        response = await client.put(f"/bars/{bar_id}/orders/{order_id}/status", json={
            "status": "preparing"
        }, headers=headers)
        
        assert response.status_code in [200, 400, 403, 404]
        if response.status_code == 200:
            assert response.json()["status"] == "preparing"


class TestOrderExpiryHelper:
    """Unit tests for the operating-day expiry computation (pure function)."""

    def test_normal_day_during_hours_expires_at_close(self):
        # Mon 10:00 local (13:00 UTC), venue open Mon 08:00-22:00.
        hours = {"monday": {"open": "08:00", "close": "22:00", "is_closed": False}}
        created = datetime(2026, 3, 9, 13, 0, tzinfo=timezone.utc)
        expiry = compute_order_expiry_utc(created, hours, TZ)
        assert expiry == datetime(2026, 3, 10, 1, 0, tzinfo=timezone.utc)  # Mon 22:00 local

    def test_normal_day_after_close_is_expired(self):
        # Mon 23:00 local (Tue 02:00 UTC), venue open Mon 08:00-22:00.
        hours = {"monday": {"open": "08:00", "close": "22:00", "is_closed": False}}
        created = datetime(2026, 3, 10, 2, 0, tzinfo=timezone.utc)
        expiry = compute_order_expiry_utc(created, hours, TZ)
        assert expiry == datetime(2026, 3, 10, 1, 0, tzinfo=timezone.utc)  # Mon 22:00 local (past)

    def test_overnight_evening_expires_next_day(self):
        # Mon 23:00 local (Tue 02:00 UTC), venue open Mon 20:00 -> Tue 02:00.
        hours = {"monday": {"open": "20:00", "close": "02:00", "is_closed": False}}
        created = datetime(2026, 3, 10, 2, 0, tzinfo=timezone.utc)
        expiry = compute_order_expiry_utc(created, hours, TZ)
        assert expiry == datetime(2026, 3, 10, 5, 0, tzinfo=timezone.utc)  # Tue 02:00 local

    def test_overnight_early_morning_belongs_to_previous_day(self):
        # Tue 01:00 local (Tue 04:00 UTC) sits inside Monday's 20:00->02:00 shift.
        hours = {
            "monday": {"open": "20:00", "close": "02:00", "is_closed": False},
            "tuesday": {"open": "08:00", "close": "22:00", "is_closed": False},
        }
        created = datetime(2026, 3, 10, 4, 0, tzinfo=timezone.utc)
        expiry = compute_order_expiry_utc(created, hours, TZ)
        assert expiry == datetime(2026, 3, 10, 5, 0, tzinfo=timezone.utc)  # Tue 02:00 local

    def test_missing_hours_keeps_order_live(self):
        created = datetime(2026, 3, 9, 13, 0, tzinfo=timezone.utc)
        assert compute_order_expiry_utc(created, None, TZ) is None
        assert compute_order_expiry_utc(created, {}, TZ) is None

    def test_closed_day_keeps_order_live(self):
        hours = {"monday": {"open": None, "close": None, "is_closed": True}}
        created = datetime(2026, 3, 9, 13, 0, tzinfo=timezone.utc)
        assert compute_order_expiry_utc(created, hours, TZ) is None


@pytest.mark.asyncio
class TestCashierOrderExpiryEndpoint:
    async def _make_owner(self, user, bar_id):
        await database.execute(
            BarStaff.__table__.insert().values(
                user_id=user["id"],
                bar_id=bar_id,
                role=BarRole.OWNER.value,
                is_active=True,
                accepted_at=datetime.now(timezone.utc),
            )
        )

    async def test_expired_order_excluded(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await self._make_owner(user, bar_id)
        await database.execute(
            BarModel.__table__.update()
            .where(BarModel.id == bar_id)
            .values(operating_hours=NORMAL_HOURS)
        )

        past = datetime.now(timezone.utc) - timedelta(days=3)
        past_order_id = await database.execute(
            OrderModel.__table__.insert().values(
                user_id=user["id"],
                bar_id=bar_id,
                status="pending",
                total_price=25.0,
                created_at=past,
                updated_at=past,
            )
        )

        now = datetime.now(timezone.utc)
        live_order_id = await database.execute(
            OrderModel.__table__.insert().values(
                user_id=user["id"],
                bar_id=bar_id,
                status="pending",
                total_price=30.0,
                created_at=now,
                updated_at=now,
            )
        )
        live_expiry = compute_order_expiry_utc(now, NORMAL_HOURS, TZ)
        expect_live = live_expiry is None or now < live_expiry

        response = await client.get(f"/bars/{bar_id}/orders/live", headers=headers)
        assert response.status_code == 200
        ids = [o["id"] for o in response.json()]

        # A 3-day-old order is past any operating-day close and must not show.
        assert past_order_id not in ids
        # A current order shows while still within its operating day.
        assert (live_order_id in ids) == expect_live

    async def test_missing_hours_keeps_order_live(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await self._make_owner(user, bar_id)
        # operating_hours stays None: no expiry configured, previous behavior.

        now = datetime.now(timezone.utc)
        order_id = await database.execute(
            OrderModel.__table__.insert().values(
                user_id=user["id"],
                bar_id=bar_id,
                status="pending",
                total_price=30.0,
                created_at=now,
                updated_at=now,
            )
        )

        response = await client.get(f"/bars/{bar_id}/orders/live", headers=headers)
        assert response.status_code == 200
        ids = [o["id"] for o in response.json()]
        assert order_id in ids
