"""
BARZ Subscription Service

Handles subscription lifecycle, billing, and credit management.
"""
from datetime import datetime, timezone, timedelta
from decimal import Decimal
from typing import Optional, Dict, Any
import json
import logging

from app.database import database
from app.errors import APIError
from app.advertising.models import (
    AdvertisingSubscription, RegionPricing,
    SubscriptionTier, SubscriptionStatus,
    AdvertisingInvoice, InvoiceStatus
)
from app.advertising.pricing import (
    CREDIT_BUCKETS, DEFAULT_CREDITS, DEFAULT_REGION_CODE, as_decimal
)
from app.bars_and_restaurants.models.relational_models import Bar
from app.payment.dpe_client import get_dpe_client


logger = logging.getLogger(__name__)


def normalize_subscription_row(result: Any) -> Dict[str, Any]:
    if result is None:
        return None

    data = dict(result)

    for enum_field in ("tier", "status"):
        value = data.get(enum_field)
        if hasattr(value, "value"):
            data[enum_field] = value.value

    credits = data.get("credits")
    if isinstance(credits, str):
        try:
            credits = json.loads(credits)
        except (TypeError, ValueError):
            credits = None

    if isinstance(credits, dict):
        normalized = dict(credits)
        for bucket in CREDIT_BUCKETS:
            try:
                normalized[bucket] = int(normalized.get(bucket) or 0)
            except (TypeError, ValueError):
                normalized[bucket] = 0
        data["credits"] = normalized
    else:
        data["credits"] = dict(DEFAULT_CREDITS)

    data["monthly_fee"] = as_decimal(data.get("monthly_fee"))
    data["commission_rate"] = as_decimal(data.get("commission_rate"), Decimal("0.1500"))
    if not data.get("region_code"):
        data["region_code"] = DEFAULT_REGION_CODE

    return data


def build_default_subscription(bar_id: int, region_code: str = DEFAULT_REGION_CODE) -> Dict[str, Any]:
    now = datetime.now(timezone.utc)
    return {
        "id": 0,
        "bar_id": bar_id,
        "tier": SubscriptionTier.REGULAR.value,
        "status": SubscriptionStatus.ACTIVE.value,
        "region_code": region_code or DEFAULT_REGION_CODE,
        "monthly_fee": Decimal("0.00"),
        "commission_rate": Decimal("0.1500"),
        "credits": dict(DEFAULT_CREDITS),
        "billing_cycle_start": None,
        "next_billing_date": None,
        "created_at": None,
        "updated_at": now,
        "is_default": True,
    }


class SubscriptionService:
    """Service for managing advertising subscriptions"""
    
    @staticmethod
    async def get_subscription(bar_id: int) -> Optional[Dict[str, Any]]:
        """Get subscription for a bar"""
        query = AdvertisingSubscription.__table__.select().where(
            AdvertisingSubscription.bar_id == bar_id
        )
        result = await database.fetch_one(query)
        return normalize_subscription_row(result)
    
    @staticmethod
    async def get_subscription_by_id(subscription_id: int) -> Optional[Dict[str, Any]]:
        """Get subscription by its ID (used by CampaignService for credit restoration)"""
        query = AdvertisingSubscription.__table__.select().where(
            AdvertisingSubscription.id == subscription_id
        )
        result = await database.fetch_one(query)
        return normalize_subscription_row(result)
    
    @staticmethod
    async def create_default_subscription(bar_id: int, region_code: str = DEFAULT_REGION_CODE) -> Dict[str, Any]:
        """Create a default REGULAR (free) subscription for a bar"""
        region_code = region_code or DEFAULT_REGION_CODE

        pricing_query = RegionPricing.__table__.select().where(
            RegionPricing.region_code == region_code
        )
        pricing = await database.fetch_one(pricing_query)
        
        commission_rate = Decimal("0.1500")  # Default 15%
        if pricing:
            commission_rate = as_decimal(dict(pricing).get("regular_commission"), commission_rate)
        
        now = datetime.now(timezone.utc)
        
        insert_query = AdvertisingSubscription.__table__.insert().values(
            bar_id=bar_id,
            tier=SubscriptionTier.REGULAR.value,
            status=SubscriptionStatus.ACTIVE.value,
            region_code=region_code,
            monthly_fee=Decimal("0.00"),
            commission_rate=commission_rate,
            credits=dict(DEFAULT_CREDITS),
            billing_cycle_start=now,
            next_billing_date=None,  # No billing for free tier
            created_at=now,
            updated_at=now
        )
        
        try:
            await database.execute(insert_query)
        except Exception as exc:
            logger.warning(
                "Could not persist default subscription for bar %s, serving in-memory default: %s",
                bar_id, exc
            )
            return build_default_subscription(bar_id, region_code)
        
        subscription = await SubscriptionService.get_subscription(bar_id)
        if subscription is None:
            return build_default_subscription(bar_id, region_code)
        return subscription
    
    @staticmethod
    async def subscribe(
        bar_id: int,
        tier: str,
        payment_method: Dict[str, Any],
        billing_cycle: str = "monthly",
        region_code: str = "BR",
        customer_info: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Subscribe to a paid plan"""
        # Get region pricing
        import sys
        print(f"DEBUG: Starting subscribe for bar_id={bar_id}, tier={tier}", file=sys.stderr)
        
        pricing_query = RegionPricing.__table__.select().where(
            RegionPricing.region_code == region_code
        )
        pricing = await database.fetch_one(pricing_query)
        
        if not pricing:
            print(f"DEBUG: Pricing not found for {region_code}", file=sys.stderr)
            raise APIError.not_found(f"Pricing not available for region: {region_code}")
        
        print(f"DEBUG: Pricing found: {pricing['currency']}", file=sys.stderr)
        
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

        # Ensure credits is a dict
        if isinstance(credits, str):
            import json
            try:
                credits = json.loads(credits)
            except:
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

        # Format DPE payload based on payment method type
        if hasattr(payment_method, "model_dump"):
            pm_dict = payment_method.model_dump()
        elif hasattr(payment_method, "dict"):
            pm_dict = payment_method.dict()
        else:
            pm_dict = payment_method
            
        pm_type = pm_dict.get("type", "card")
        if hasattr(pm_type, "value"):
            pm_type = pm_type.value
            
        dpe_pm = {}
        
        if pm_type == "pix":
            dpe_pm = {
                "type": "pix",
                "expires_in": 3600
            }
        else:
            dpe_pm = {
                "type": "card",
                "token": pm_dict.get("token"),
                "provider": "saved"
            }
        # Process payment via DPE
        dpe = get_dpe_client()
        
        metadata = {
            "type": "subscription",
            "tier": tier_value,
            "billing_cycle": billing_cycle,
            "bar_id": bar_id,
            "invoice_id": invoice_id
        }
        
        # Build customer_info: prefer the one passed from frontend, fall back to bar owner data
        if not customer_info:
            bar_data = dict(bar)
            if bar_data.get("owner_id"):
                try:
                    from app.bars_and_restaurants.models.relational_models import BarOwner as BarOwnerModel
                    owner_query = BarOwnerModel.__table__.select().where(BarOwnerModel.id == bar_data["owner_id"])
                    owner = await database.fetch_one(owner_query)
                    if owner:
                        owner_data = dict(owner)
                        raw_document = str(bar_data.get("business_id") or "")
                        # Keep only digits (strip punctuation like dots, dashes, slashes)
                        document = "".join(c for c in raw_document if c.isdigit())
                        name = owner_data.get("name") or bar_data.get("name")
                        if owner_data.get("email") and document and name and len(document) in (11, 14):
                            # 14-digit = CNPJ (company), 11-digit = CPF (individual)
                            doc_type = "company" if len(document) == 14 else "individual"
                            customer_info = {
                                "name": name,
                                "email": owner_data["email"],
                                "document": document,
                                "type": doc_type,
                                "phone": owner_data.get("phone_number") or bar_data.get("phone_number"),
                            }
                except Exception:
                    # If owner lookup fails, proceed without customer_info
                    pass
        
        payment_result = await dpe.charge(
            order_id=f"inv_{invoice_id}",
            user_id=bar["owner_id"],
            bar_id=bar_id,
            amount=float(monthly_fee),
            currency=pricing["currency"],
            country=region_code,
            payment_method=dpe_pm,
            idempotency_key=f"sub_{bar_id}_{int(now.timestamp())}",
            description=f"Barz {tier_value.capitalize()} Subscription",
            customer_info=customer_info,
            metadata=metadata
        )

        if payment_result["status"] == "error":
            raise APIError.payment_declined(f"Payment failed: {payment_result.get('message', 'Unknown error')}")

        # Handle PIX (Async payment)
        if pm_type == "pix":
            # Update invoice to WAITING_PAYMENT
            invoice_update = AdvertisingInvoice.__table__.update().where(
                AdvertisingInvoice.id == invoice_id
            ).values(
                status=InvoiceStatus.WAITING_PAYMENT.value,
                payment_gateway_ref=payment_result["payment_id"]
            )
            await database.execute(invoice_update)
            
            return {
                "status": "waiting_payment",
                "pix_qr_code": payment_result.get("pix_qr_code") or payment_result.get("pix_copia_e_cola"),
                "pix_copia_e_cola": payment_result.get("pix_copia_e_cola") or payment_result.get("pix_qr_code"),
                "pix_qr_code_url": payment_result.get("pix_qr_code_url"),
                "pix_expires_at": payment_result.get("pix_expires_at"),
                "invoice_id": invoice_id
            }

        # Handle Credit Card (Immediate success if succeeded)
        if payment_result["status"] != "succeeded":
             raise APIError.payment_declined(f"Payment declined: {payment_result.get('message', 'Unknown error')}")

        # Activation call
        return await SubscriptionService.activate_subscription(
            bar_id=bar_id,
            tier=tier_value,
            billing_cycle=billing_cycle,
            invoice_id=invoice_id,
            payment_id=payment_result["payment_id"]
        )
    
    @staticmethod
    async def activate_subscription(
        bar_id: int,
        tier: str,
        billing_cycle: str,
        invoice_id: int,
        payment_id: str
    ) -> Dict[str, Any]:
        """Activate a subscription after successful payment (sync or async)"""
        now = datetime.now(timezone.utc)
        
        # Get bar info for region settings
        from app.bars_and_restaurants.models.relational_models import Bar as BarModel
        query = BarModel.__table__.select().where(BarModel.id == bar_id)
        bar = await database.fetch_one(query)
        if not bar:
            raise APIError.not_found("Bar not found")
            
        region_code = bar["region_code"] if "region_code" in dict(bar._mapping) else "BR"
        
        # Get region pricing
        pricing_query = RegionPricing.__table__.select().where(RegionPricing.region_code == region_code)
        pricing = await database.fetch_one(pricing_query)
        if not pricing:
             raise APIError.not_found(f"Pricing not available for region: {region_code}")

        # Map tier to values
        tier_value = tier.value if hasattr(tier, 'value') else tier
        tier_map = {
           "master": {
               "fee": pricing["master_monthly"] if billing_cycle == "monthly" else pricing["master_annual"] / 12,
               "commission": pricing["master_commission"],
               "credits": pricing["master_credits"]
           },
           "vip": {
               "fee": pricing["vip_monthly"] if billing_cycle == "monthly" else pricing["vip_annual"] / 12,
               "commission": pricing["vip_commission"],
               "credits": pricing["vip_credits"]
           }
        }
        
        plan = tier_map.get(tier_value)
        if not plan:
            raise APIError.bad_request(f"Invalid tier for paid subscription: {tier_value}")

        monthly_fee = plan["fee"]
        commission_rate = plan["commission"]
        credits = plan["credits"]
        
        # Ensure credits is a dict (handle potential string from some DB drivers)
        if isinstance(credits, str):
            import json
            try:
                credits = json.loads(credits)
            except:
                credits = {}
        
        next_billing = now + timedelta(days=365 if billing_cycle == "annual" else 30)

        # Update invoice
        invoice_update = AdvertisingInvoice.__table__.update().where(
            AdvertisingInvoice.id == invoice_id
        ).values(
            status=InvoiceStatus.PAID.value,
            payment_gateway_ref=payment_id,
            paid_at=now
        )
        await database.execute(invoice_update)

        # Update or Create subscription
        existing = await SubscriptionService.get_subscription(bar_id)
        if existing:
            update_query = AdvertisingSubscription.__table__.update().where(
                AdvertisingSubscription.bar_id == bar_id
            ).values(
                tier=tier_value,
                status=SubscriptionStatus.ACTIVE.value,
                monthly_fee=monthly_fee,
                commission_rate=commission_rate,
                credits=credits,
                billing_cycle_start=now,
                next_billing_date=next_billing,
                updated_at=now
            )
            await database.execute(update_query)
        else:
            insert_query = AdvertisingSubscription.__table__.insert().values(
                bar_id=bar_id,
                tier=tier_value,
                status=SubscriptionStatus.ACTIVE.value,
                region_code=region_code,
                monthly_fee=monthly_fee,
                commission_rate=commission_rate,
                credits=credits,
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
