"""
BARZ Subscription Service

Handles subscription lifecycle, billing, and credit management.
"""
from datetime import datetime, timezone, timedelta
from decimal import Decimal
from typing import Optional, Dict, Any

from app.database import database
from app.errors import APIError
from app.advertising.models import (
    AdvertisingSubscription, RegionPricing,
    SubscriptionTier, SubscriptionStatus,
    AdvertisingInvoice, InvoiceStatus
)
from app.bars_and_restaurants.models.relational_models import Bar
from app.payment.dpe_client import get_dpe_client


class SubscriptionService:
    """Service for managing advertising subscriptions"""
    
    @staticmethod
    async def get_subscription(bar_id: int) -> Optional[Dict[str, Any]]:
        """Get subscription for a bar"""
        query = AdvertisingSubscription.__table__.select().where(
            AdvertisingSubscription.bar_id == bar_id
        )
        result = await database.fetch_one(query)
        return dict(result) if result else None
    
    @staticmethod
    async def create_default_subscription(bar_id: int, region_code: str = "BR") -> Dict[str, Any]:
        """Create a default REGULAR (free) subscription for a bar"""
        # Get region pricing for commission rate
        pricing_query = RegionPricing.__table__.select().where(
            RegionPricing.region_code == region_code
        )
        pricing = await database.fetch_one(pricing_query)
        
        commission_rate = Decimal("0.1500")  # Default 15%
        if pricing:
            commission_rate = pricing["regular_commission"]
        
        now = datetime.now(timezone.utc)
        
        insert_query = AdvertisingSubscription.__table__.insert().values(
            bar_id=bar_id,
            tier=SubscriptionTier.REGULAR.value,
            status=SubscriptionStatus.ACTIVE.value,
            region_code=region_code,
            monthly_fee=Decimal("0.00"),
            commission_rate=commission_rate,
            credits={
                "featured_hours": 0,
                "search_clicks": 0,
                "map_hours": 0,
                "boost_impressions": 0
            },
            billing_cycle_start=now,
            next_billing_date=None,  # No billing for free tier
            created_at=now,
            updated_at=now
        )
        
        subscription_id = await database.execute(insert_query)
        
        # Fetch and return the created subscription
        return await SubscriptionService.get_subscription(bar_id)
    
    @staticmethod
    async def subscribe(
        bar_id: int,
        tier: str,
        payment_method_id: str,
        billing_cycle: str = "monthly",
        region_code: str = "BR"
    ) -> Dict[str, Any]:
        """Subscribe to a paid plan"""
        # Get region pricing
        pricing_query = RegionPricing.__table__.select().where(
            RegionPricing.region_code == region_code
        )
        pricing = await database.fetch_one(pricing_query)
        
        if not pricing:
            raise APIError.not_found(f"Pricing not available for region: {region_code}")
        
        # Determine pricing and commission based on tier
        tier_value = tier.value if hasattr(tier, 'value') else tier
        
        if tier_value == "master":
            monthly_fee = pricing["master_monthly"] if billing_cycle == "monthly" else pricing["master_annual"] / 12
            commission_rate = pricing["master_commission"]
            credits = pricing["master_credits"]
        elif tier_value == "vip":
            monthly_fee = pricing["vip_monthly"] if billing_cycle == "monthly" else pricing["vip_annual"] / 12
            commission_rate = pricing["vip_commission"]
            credits = pricing["vip_credits"]
        else:
            monthly_fee = Decimal("0.00")
            commission_rate = pricing["regular_commission"]
            credits = {"featured_hours": 0, "search_clicks": 0, "map_hours": 0, "boost_impressions": 0}
        
        now = datetime.now(timezone.utc)
        next_billing = now + timedelta(days=30 if billing_cycle == "monthly" else 365)
        
        # Get bar info for owner_id and currency
        bar_query = Bar.__table__.select().where(Bar.id == bar_id)
        bar = await database.fetch_one(bar_query)
        if not bar:
            raise APIError.not_found(f"Bar not found: {bar_id}")

        # Create PENDING invoice
        invoice_insert = AdvertisingInvoice.__table__.insert().values(
            bar_id=bar_id,
            period_start=now,
            period_end=next_billing,
            subscription_amount=monthly_fee,
            advertising_amount=Decimal("0.00"),
            tax_amount=Decimal("0.00"),
            total_amount=monthly_fee,
            currency=pricing["currency"],
            status=InvoiceStatus.PENDING.value,
            created_at=now
        )
        invoice_id = await database.execute(invoice_insert)

        # Process payment via DPE
        dpe = get_dpe_client()
        try:
            payment_result = await dpe.charge(
                order_id=invoice_id,
                user_id=bar["owner_id"],
                bar_id=bar_id,
                amount=float(monthly_fee),
                currency=pricing["currency"],
                country=region_code,
                payment_method={"type": "card", "token": payment_method_id},
                idempotency_key=f"sub_{bar_id}_{int(now.timestamp())}",
                description=f"Barz {tier_value.capitalize()} Subscription"
            )

            if payment_result["status"] != "succeeded":
                raise APIError.payment_required(f"Payment failed: {payment_result.get('message', 'Unknown error')}")

            # Payment succeeded - update invoice
            invoice_update = AdvertisingInvoice.__table__.update().where(
                AdvertisingInvoice.id == invoice_id
            ).values(
                status=InvoiceStatus.PAID.value,
                payment_gateway_ref=payment_result["payment_id"],
                paid_at=datetime.now(timezone.utc)
            )
            await database.execute(invoice_update)

        except Exception as e:
            if isinstance(e, APIError):
                raise e
            raise APIError.internal_error(f"Payment processing error: {str(e)}")

        # Check if subscription exists and update/create
        existing = await SubscriptionService.get_subscription(bar_id)
        
        if existing:
            # Update existing subscription
            update_query = AdvertisingSubscription.__table__.update().where(
                AdvertisingSubscription.bar_id == bar_id
            ).values(
                tier=tier_value,
                status=SubscriptionStatus.ACTIVE.value,
                monthly_fee=monthly_fee,
                commission_rate=commission_rate,
                credits=credits,
                payment_method_id=payment_method_id,
                billing_cycle_start=now,
                next_billing_date=next_billing,
                updated_at=now
            )
            await database.execute(update_query)
        else:
            # Create new subscription
            insert_query = AdvertisingSubscription.__table__.insert().values(
                bar_id=bar_id,
                tier=tier_value,
                status=SubscriptionStatus.ACTIVE.value,
                region_code=region_code,
                monthly_fee=monthly_fee,
                commission_rate=commission_rate,
                credits=credits,
                payment_method_id=payment_method_id,
                billing_cycle_start=now,
                next_billing_date=next_billing,
                created_at=now,
                updated_at=now
            )
            await database.execute(insert_query)
        
        return await SubscriptionService.get_subscription(bar_id)
    
    @staticmethod
    async def change_tier(bar_id: int, new_tier: str) -> Dict[str, Any]:
        """Change subscription tier (upgrade/downgrade)"""
        existing = await SubscriptionService.get_subscription(bar_id)
        
        if not existing:
            raise APIError.not_found("No subscription found for this bar")
        
        tier_value = new_tier.value if hasattr(new_tier, 'value') else new_tier
        
        # Get region pricing
        pricing_query = RegionPricing.__table__.select().where(
            RegionPricing.region_code == existing["region_code"]
        )
        pricing = await database.fetch_one(pricing_query)
        
        if not pricing:
            raise APIError.internal_error("Pricing configuration error")
        
        # Determine new pricing
        if tier_value == "master":
            monthly_fee = pricing["master_monthly"]
            commission_rate = pricing["master_commission"]
            credits = pricing["master_credits"]
        elif tier_value == "vip":
            monthly_fee = pricing["vip_monthly"]
            commission_rate = pricing["vip_commission"]
            credits = pricing["vip_credits"]
        else:
            monthly_fee = Decimal("0.00")
            commission_rate = pricing["regular_commission"]
            credits = {"featured_hours": 0, "search_clicks": 0, "map_hours": 0, "boost_impressions": 0}
        
        now = datetime.now(timezone.utc)
        
        # TODO: Handle prorated billing for upgrades
        
        update_query = AdvertisingSubscription.__table__.update().where(
            AdvertisingSubscription.bar_id == bar_id
        ).values(
            tier=tier_value,
            monthly_fee=monthly_fee,
            commission_rate=commission_rate,
            credits=credits,
            updated_at=now
        )
        await database.execute(update_query)
        
        return await SubscriptionService.get_subscription(bar_id)
    
    @staticmethod
    async def cancel(bar_id: int) -> None:
        """Cancel subscription (keeps until period end)"""
        existing = await SubscriptionService.get_subscription(bar_id)
        
        if not existing:
            raise APIError.not_found("No subscription found for this bar")
        
        if existing["tier"] == "regular":
            raise APIError.bad_request("Cannot cancel free tier subscription")
        
        now = datetime.now(timezone.utc)
        
        update_query = AdvertisingSubscription.__table__.update().where(
            AdvertisingSubscription.bar_id == bar_id
        ).values(
            status=SubscriptionStatus.CANCELLED.value,
            updated_at=now
        )
        await database.execute(update_query)
    
    @staticmethod
    async def deduct_credits(bar_id: int, credit_type: str, amount: int) -> bool:
        """Deduct credits from subscription"""
        subscription = await SubscriptionService.get_subscription(bar_id)
        
        if not subscription:
            return False
        
        credits = subscription["credits"]
        
        if credit_type not in credits:
            return False
        
        if credits[credit_type] < amount:
            return False
        
        credits[credit_type] -= amount
        
        update_query = AdvertisingSubscription.__table__.update().where(
            AdvertisingSubscription.bar_id == bar_id
        ).values(
            credits=credits,
            updated_at=datetime.now(timezone.utc)
        )
        await database.execute(update_query)
        
        return True
    
    @staticmethod
    async def refill_credits(bar_id: int) -> None:
        """Refill credits for a new billing period"""
        subscription = await SubscriptionService.get_subscription(bar_id)
        
        if not subscription or subscription["tier"] == "regular":
            return
        
        # Get region pricing for credit amounts
        pricing_query = RegionPricing.__table__.select().where(
            RegionPricing.region_code == subscription["region_code"]
        )
        pricing = await database.fetch_one(pricing_query)
        
        if not pricing:
            return
        
        tier = subscription["tier"]
        if tier == "master":
            new_credits = pricing["master_credits"]
        elif tier == "vip":
            new_credits = pricing["vip_credits"]
        else:
            return
        
        now = datetime.now(timezone.utc)
        next_billing = now + timedelta(days=30)
        
        update_query = AdvertisingSubscription.__table__.update().where(
            AdvertisingSubscription.bar_id == bar_id
        ).values(
            credits=new_credits,
            billing_cycle_start=now,
            next_billing_date=next_billing,
            updated_at=now
        )
        await database.execute(update_query)
