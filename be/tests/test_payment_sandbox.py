import pytest
from httpx import AsyncClient
from unittest.mock import patch, AsyncMock
from datetime import datetime, timezone, timedelta
from decimal import Decimal

from app.database import database
from app.advertising.models import (
    AdvertisingSubscription, AdvertisingInvoice, InvoiceStatus,
    SubscriptionStatus, SubscriptionTier
)
from app.auth.rbac_models import BarStaff, BarRole
from app.payment.dpe_client import DPE_SERVICE_SECRET

@pytest.mark.asyncio
class TestPaymentSandbox:
    async def setup_data(self, user_id, bar_id):
        # Add user as owner
        await database.execute(
            BarStaff.__table__.insert().values(
                user_id=user_id,
                bar_id=bar_id,
                role=BarRole.OWNER.value,
                is_active=True,
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc)
            )
        )
        
        # Ensure pricing exists
        await database.execute(
            """INSERT INTO region_pricing (
                region_code, currency, master_monthly, master_annual, vip_monthly, vip_annual, 
                regular_commission, master_commission, vip_commission, featured_cph, search_cpc_min, search_cpc_max, map_cph, boost_cpm, 
                master_credits, vip_credits, effective_date
            ) VALUES (
                'BR', 'BRL', 100.0, 1000.0, 300.0, 3000.0, 0.15, 0.10, 0.05, 10.0, 0.5, 2.0, 5.0, 1.0, 
                :master_credits, :vip_credits, :now
            )""",
            {
                "now": datetime.now(timezone.utc),
                "master_credits": '{"featured_hours": 10, "search_clicks": 0, "map_hours": 0, "boost_impressions": 0}',
                "vip_credits": '{"featured_hours": 30, "search_clicks": 0, "map_hours": 0, "boost_impressions": 0}'
            }
        )

    async def test_subscribe_pix_flow(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await self.setup_data(user["id"], bar_id)
        
        # Mock DPE to return PIX pending
        with patch("app.advertising.services.subscription_service.get_dpe_client") as mock_get_dpe:
            mock_dpe = AsyncMock()
            mock_dpe.charge.return_value = {
                "status": "pending",
                "payment_id": "pay_pix_123",
                "pix_qr_code": "mock_qr_token",
                "pix_copia_e_cola": "mock_copy_paste",
                "pix_expires_at": (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
            }
            mock_get_dpe.return_value = mock_dpe
            
            response = await client.post(
                f"/advertising/subscribe?bar_id={bar_id}",
                json={
                    "tier": "master",
                    "payment_method": {"type": "pix"},
                    "billing_cycle": "monthly"
                },
                headers=headers
            )
            
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "waiting_payment"
            assert "pix_qr_code" in data
            assert data["invoice_id"] is not None
            
            # Verify invoice is WAITING_PAYMENT
            invoice = await database.fetch_one(
                "SELECT * FROM advertising_invoices WHERE id = :id", 
                {"id": data["invoice_id"]}
            )
            assert invoice["status"] == "waiting_payment"
            
            # Verify subscription is NOT active or not updated to Master yet if it was regular
            existing_sub = await database.fetch_one(
                "SELECT * FROM advertising_subscriptions WHERE bar_id = :bar_id",
                {"bar_id": bar_id}
            )
            # Default is regular
            if existing_sub:
                assert existing_sub["tier"] == "regular"

            # 2. Mock Webhook Confirmation
            webhook_payload = {
                "event": "payment.succeeded",
                "payment_id": "pay_pix_123",
                "order_id": f"inv_{data['invoice_id']}",
                "status": "succeeded",
                "metadata": {
                    "type": "subscription",
                    "tier": "master",
                    "billing_cycle": "monthly",
                    "bar_id": bar_id,
                    "invoice_id": data["invoice_id"]
                }
            }
            
            webhook_response = await client.post(
                "/payments/webhook",
                json=webhook_payload,
                headers={"X-Service-Auth": DPE_SERVICE_SECRET}
            )
            
            assert webhook_response.status_code == 200
            assert webhook_response.json()["type"] == "subscription_activated"
            
            # Verify invoice is PAID
            invoice = await database.fetch_one(
                "SELECT * FROM advertising_invoices WHERE id = :id", 
                {"id": data["invoice_id"]}
            )
            assert invoice["status"] == "paid"
            
            # Verify subscription is ACTIVE and MASTER
            sub = await database.fetch_one(
                "SELECT * FROM advertising_subscriptions WHERE bar_id = :bar_id",
                {"bar_id": bar_id}
            )
            assert sub["tier"] == "master"
            assert sub["status"] == "active"

    async def test_subscribe_cc_immediate_flow(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        # Skip setup_data if already done by previous test or clean up
        await database.execute("DELETE FROM region_pricing")
        await database.execute("DELETE FROM bar_staff")
        await self.setup_data(user["id"], bar_id)
        
        # Mock DPE to return Success
        with patch("app.advertising.services.subscription_service.get_dpe_client") as mock_get_dpe:
            mock_dpe = AsyncMock()
            mock_dpe.charge.return_value = {
                "status": "succeeded",
                "payment_id": "pay_cc_123",
                "message": "Success"
            }
            mock_get_dpe.return_value = mock_dpe
            
            response = await client.post(
                f"/advertising/subscribe?bar_id={bar_id}",
                json={
                    "tier": "vip",
                    "payment_method": {"type": "card", "token": "tok_visa"},
                    "billing_cycle": "monthly"
                },
                headers=headers
            )
            
            assert response.status_code == 200
            data = response.json()
            assert data["tier"] == "vip"
            assert data["status"] == "active"
            
            # Verify invoice is PAID
            invoice = await database.fetch_one(
                "SELECT * FROM advertising_invoices WHERE bar_id = :bar_id AND status = 'paid' ORDER BY created_at DESC", 
                {"bar_id": bar_id}
            )
            assert invoice is not None
            assert invoice["payment_gateway_ref"] == "pay_cc_123"
