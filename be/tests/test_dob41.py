import pytest
from httpx import AsyncClient
from unittest.mock import patch, AsyncMock
from datetime import datetime, timezone, timedelta
from decimal import Decimal

from app.database import database
from app.advertising.models import AdvertisingSubscription, SubscriptionTier, SubscriptionStatus
from app.auth.rbac_models import Permission, BarRole, BarStaff

@pytest.mark.asyncio
class TestDOB41:
    async def test_subscribe_pro_plan_dpe_integration(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        
        # Add user as owner first to bypass permission check
        await database.execute(
            BarStaff.__table__.insert().values(
                user_id=user["id"],
                bar_id=bar_id,
                role=BarRole.OWNER.value,
                is_active=True,
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc)
            )
        )
        
        # Ensure pricing exists
        await database.execute(
            "INSERT INTO region_pricing (region_code, currency, master_monthly, master_annual, vip_monthly, vip_annual, "
            "regular_commission, master_commission, vip_commission, featured_cph, search_cpc_min, search_cpc_max, map_cph, boost_cpm, "
            "master_credits, vip_credits, effective_date) "
            "VALUES ('BR', 'BRL', 100.0, 1000.0, 300.0, 3000.0, 0.15, 0.10, 0.05, 10.0, 0.5, 2.0, 5.0, 1.0, '{}', '{}', :now)",
            {"now": datetime.now(timezone.utc)}
        )
        
        # Mock DPE charge to succeed
        with patch("app.advertising.services.subscription_service.get_dpe_client") as mock_get_dpe:
            mock_dpe = AsyncMock()
            mock_dpe.charge.return_value = {
                "status": "succeeded",
                "payment_id": "pi_test_123",
                "message": "Success"
            }
            mock_get_dpe.return_value = mock_dpe
            
            response = await client.post(
                f"/advertising/subscribe?bar_id={bar_id}",
                json={
                    "tier": "master",
                    "payment_method_id": "pm_test_123",
                    "billing_cycle": "monthly"
                },
                headers=headers
            )
            
            assert response.status_code == 200
            data = response.json()
            assert data["tier"] == "master"
            assert data["status"] == "active"
            
            # Verify invoice was created
            invoice = await database.fetch_one("SELECT * FROM advertising_invoices WHERE bar_id = :bar_id", {"bar_id": bar_id})
            assert invoice is not None
            assert invoice["status"] == "paid"
            assert invoice["payment_gateway_ref"] == "pi_test_123"

    async def test_daily_analytics(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        
        # Add user as owner
        await database.execute(
            BarStaff.__table__.insert().values(
                user_id=user["id"],
                bar_id=bar_id,
                role=BarRole.OWNER.value,
                is_active=True,
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc)
            )
        )
        
        # Ensure subscription exists
        await database.execute(
            "INSERT INTO advertising_subscriptions (bar_id, tier, status, region_code, monthly_fee, commission_rate, credits, created_at, updated_at) "
            "VALUES (:bar_id, 'master', 'active', 'BR', 100.0, 0.05, '{}', :now, :now)",
            {"bar_id": bar_id, "now": datetime.now(timezone.utc)}
        )
        
        camp_resp = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}",
            json={
                "name": "Test Analytics Campaign",
                "campaign_type": "featured",
                "budget_type": "hourly",
                "budget_amount": 10.0,
                "start_time": datetime.now(timezone.utc).isoformat()
            },
            headers=headers
        )
        assert camp_resp.status_code == 201
        campaign_id = camp_resp.json()["id"]
        
        # Inject some impressions
        today = datetime.now(timezone.utc).date()
        yesterday = today - timedelta(days=1)
        
        await database.execute(
            "INSERT INTO advertising_impressions (campaign_id, action, timestamp, placement) VALUES "
            "(:c_id, 'impression', :t1, 'home'), "
            "(:c_id, 'impression', :t1, 'home'), "
            "(:c_id, 'click', :t1, 'home'), "
            "(:c_id, 'impression', :t2, 'home')",
            {
                "c_id": campaign_id, 
                "t1": datetime.combine(today, datetime.min.time()), 
                "t2": datetime.combine(yesterday, datetime.min.time())
            }
        )
        
        # Get analytics
        resp = await client.get(
            f"/advertising/analytics/{campaign_id}?bar_id={bar_id}&start_date={yesterday.isoformat()}&end_date={today.isoformat()}",
            headers=headers
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "daily_stats" in data
        assert len(data["daily_stats"]) >= 2
        
        # Check today's stats
        today_stats = next(s for s in data["daily_stats"] if s["date"] == today.isoformat())
        assert today_stats["impressions"] == 2
        assert today_stats["clicks"] == 1
        
        # Check yesterday's stats
        yesterday_stats = next(s for s in data["daily_stats"] if s["date"] == yesterday.isoformat())
        assert yesterday_stats["impressions"] == 1

    async def test_staff_invite_contact_field(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        
        # Set user as owner
        await database.execute(
            BarStaff.__table__.insert().values(
                user_id=user["id"],
                bar_id=bar_id,
                role=BarRole.OWNER.value,
                is_active=True,
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc)
            )
        )
        
        # Invite via email
        resp_email = await client.post(
            f"/bars/{bar_id}/staff/invite",
            json={"contact": "newstaff@test.com", "role": "manager"},
            headers=headers
        )
        assert resp_email.status_code == 200
        assert resp_email.json()["email"] == "newstaff@test.com"
        
        # Invite via phone
        resp_phone = await client.post(
            f"/bars/{bar_id}/staff/invite",
            json={"contact": "+5511999999999", "role": "staff"},
            headers=headers
        )
        assert resp_phone.status_code == 200
        assert resp_phone.json()["phone"] == "+5511999999999"

    async def test_advertising_rbac_enforcement(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        
        # User is NOT staff yet.
        response = await client.get(f"/advertising/my-plan?bar_id={bar_id}", headers=headers)
        assert response.status_code == 403
        
        # Now add as staff WITHOUT ADS_MANAGE
        await database.execute(
            BarStaff.__table__.insert().values(
                user_id=user["id"],
                bar_id=bar_id,
                role=BarRole.STAFF.value,
                is_active=True,
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc)
            )
        )
        
        response = await client.get(f"/advertising/my-plan?bar_id={bar_id}", headers=headers)
        assert response.status_code == 403
        
        # Now promote to Admin
        await database.execute(
            BarStaff.__table__.update().where(BarStaff.user_id == user["id"]).values(role=BarRole.ADMIN.value)
        )
        
        # Now it should work
        response = await client.get(f"/advertising/my-plan?bar_id={bar_id}", headers=headers)
        assert response.status_code == 200
