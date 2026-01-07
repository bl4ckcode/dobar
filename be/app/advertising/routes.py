"""
BARZ Advertising Routes

API endpoints for advertising subscriptions, campaigns, and analytics.
Based on: docs/business/ADVERTISING_BACKEND.md
"""
from datetime import datetime, timezone, date
from decimal import Decimal
from typing import Optional, List
from fastapi import APIRouter, Depends, Query, HTTPException, status, BackgroundTasks, Request
from sqlalchemy import select, and_, func
from sqlalchemy.orm import Session

from app.database import database, get_db
from app.auth.dependencies import get_current_user
from app.errors import APIError

from .models import (
    AdvertisingSubscription, AdvertisingCampaign, AdvertisingImpression,
    AdvertisingInvoice, RegionPricing,
    SubscriptionTier, SubscriptionStatus, CampaignStatus, CampaignType, AdAction
)
from .schemas import (
    SubscriptionTierEnum, SubscriptionStatusEnum, SubscriptionResponse, SubscribeRequest, ChangePlanRequest,
    SubscriptionPlansResponse, SubscriptionPlanInfo, CreditsBalance,
    CampaignCreate, CampaignUpdate, CampaignResponse, CampaignListResponse,
    CampaignStatusEnum, CampaignTypeEnum, CampaignTargeting, CampaignCreative,
    FeaturedAd, SearchAd, MapSpotlight, AdTrackEvent,
    DashboardAnalytics, CampaignAnalytics,
    InvoiceResponse, InvoiceListResponse,
    RegionPricingResponse, BudgetTypeEnum
)
from .services.subscription_service import SubscriptionService
from .services.campaign_service import CampaignService


advertising_router = APIRouter(prefix="/advertising", tags=["Advertising"])


# =============================================================================
# SUBSCRIPTION ENDPOINTS
# =============================================================================

@advertising_router.get("/plans", response_model=SubscriptionPlansResponse)
async def get_available_plans(
    region_code: str = Query(default="BR", description="ISO country code (BR, US, MX, etc.)")
):
    """
    Get available subscription plans for a region.
    Returns pricing and features for Regular, Master, and VIP tiers.
    """
    query = RegionPricing.__table__.select().where(RegionPricing.region_code == region_code.upper())
    pricing = await database.fetch_one(query)
    
    if not pricing:
        raise APIError.not_found(f"Pricing not available for region: {region_code}")
    
    plans = {
        "regular": SubscriptionPlanInfo(
            tier=SubscriptionTierEnum.REGULAR,
            name="Regular",
            monthly_price=Decimal("0.00"),
            annual_price=Decimal("0.00"),
            commission_rate=pricing["regular_commission"],
            credits=CreditsBalance(),
            features=["Basic listing in app", "Order management", "Basic analytics"]
        ),
        "master": SubscriptionPlanInfo(
            tier=SubscriptionTierEnum.MASTER,
            name="Master",
            monthly_price=pricing["master_monthly"],
            annual_price=pricing["master_annual"],
            commission_rate=pricing["master_commission"],
            credits=CreditsBalance(**pricing["master_credits"]),
            features=["Everything in Regular", "Reduced commission rate", "Monthly advertising credits",
                     "Featured Home placement", "Sponsored Search", "Priority support"]
        ),
        "vip": SubscriptionPlanInfo(
            tier=SubscriptionTierEnum.VIP,
            name="VIP",
            monthly_price=pricing["vip_monthly"],
            annual_price=pricing["vip_annual"],
            commission_rate=pricing["vip_commission"],
            credits=CreditsBalance(**pricing["vip_credits"]),
            features=["Everything in Master", "Lowest commission rate", "Maximum advertising credits",
                     "Map Spotlight", "Promotion Boost", "Rich Media Banners", "Verified Badge",
                     "Dedicated account manager"]
        )
    }
    
    return SubscriptionPlansResponse(region_code=region_code.upper(), currency=pricing["currency"], plans=plans)


@advertising_router.get("/my-plan", response_model=SubscriptionResponse)
async def get_my_plan(
    bar_id: int = Query(..., description="Bar ID to get subscription for"),
    current_user = Depends(get_current_user)
):
    """Get current bar's subscription details."""
    subscription = await SubscriptionService.get_subscription(bar_id)
    
    if not subscription:
        subscription = await SubscriptionService.create_default_subscription(bar_id)
    
    return SubscriptionResponse(
        id=subscription["id"], bar_id=subscription["bar_id"],
        tier=SubscriptionTierEnum(subscription["tier"]),
        status=SubscriptionStatusEnum(subscription["status"]),
        region_code=subscription["region_code"], monthly_fee=subscription["monthly_fee"],
        commission_rate=subscription["commission_rate"],
        credits=CreditsBalance(**subscription["credits"]),
        billing_cycle_start=subscription["billing_cycle_start"],
        next_billing_date=subscription["next_billing_date"],
        created_at=subscription["created_at"]
    )


@advertising_router.post("/subscribe", response_model=SubscriptionResponse)
async def subscribe_to_plan(
    request: SubscribeRequest,
    bar_id: int = Query(..., description="Bar ID to subscribe"),
    current_user = Depends(get_current_user)
):
    """Subscribe to a plan or upgrade existing subscription."""
    subscription = await SubscriptionService.subscribe(
        bar_id=bar_id, tier=request.tier, payment_method_id=request.payment_method_id,
        billing_cycle=request.billing_cycle
    )
    
    return SubscriptionResponse(
        id=subscription["id"], bar_id=subscription["bar_id"],
        tier=SubscriptionTierEnum(subscription["tier"]),
        status=SubscriptionStatusEnum(subscription["status"]),
        region_code=subscription["region_code"], monthly_fee=subscription["monthly_fee"],
        commission_rate=subscription["commission_rate"],
        credits=CreditsBalance(**subscription["credits"]),
        billing_cycle_start=subscription["billing_cycle_start"],
        next_billing_date=subscription["next_billing_date"],
        created_at=subscription["created_at"]
    )


@advertising_router.get("/credits", response_model=CreditsBalance)
async def get_credits(
    bar_id: int = Query(..., description="Bar ID"),
    current_user = Depends(get_current_user)
):
    """Check remaining advertising credits."""
    subscription = await SubscriptionService.get_subscription(bar_id)
    if not subscription:
        return CreditsBalance()
    return CreditsBalance(**subscription["credits"])


# =============================================================================
# CAMPAIGN ENDPOINTS
# =============================================================================

@advertising_router.get("/campaigns", response_model=CampaignListResponse)
async def list_campaigns(
    bar_id: int = Query(..., description="Bar ID"),
    campaign_status: Optional[CampaignStatusEnum] = Query(None, description="Filter by status"),
    current_user = Depends(get_current_user)
):
    """List all advertising campaigns for the bar."""
    campaigns = await CampaignService.list_campaigns(bar_id, campaign_status)
    return CampaignListResponse(
        campaigns=[_campaign_to_response(c) for c in campaigns],
        total=len(campaigns)
    )


@advertising_router.post("/campaigns", response_model=CampaignResponse, status_code=status.HTTP_201_CREATED)
async def create_campaign(
    campaign: CampaignCreate,
    bar_id: int = Query(..., description="Bar ID"),
    current_user = Depends(get_current_user)
):
    """Create a new advertising campaign."""
    subscription = await SubscriptionService.get_subscription(bar_id)
    if not subscription:
        raise APIError.forbidden("No active subscription. Please subscribe first.")
    
    tier = subscription["tier"]
    campaign_type = campaign.campaign_type.value
    
    allowed_types = _get_allowed_campaign_types(tier)
    if campaign_type not in allowed_types:
        raise APIError.forbidden(f"Campaign type '{campaign_type}' requires a higher subscription tier.")
    
    new_campaign = await CampaignService.create_campaign(
        bar_id=bar_id, subscription_id=subscription["id"], data=campaign
    )
    
    return _campaign_to_response(new_campaign)


@advertising_router.get("/campaigns/{campaign_id}", response_model=CampaignResponse)
async def get_campaign(
    campaign_id: int,
    bar_id: int = Query(..., description="Bar ID"),
    current_user = Depends(get_current_user)
):
    """Get campaign details with performance metrics."""
    campaign = await CampaignService.get_campaign(campaign_id, bar_id)
    if not campaign:
        raise APIError.not_found("Campaign not found")
    return _campaign_to_response(campaign)


@advertising_router.put("/campaigns/{campaign_id}/pause")
async def pause_campaign(
    campaign_id: int,
    bar_id: int = Query(..., description="Bar ID"),
    current_user = Depends(get_current_user)
):
    """Pause an active campaign."""
    await CampaignService.pause_campaign(campaign_id, bar_id)
    return {"message": "Campaign paused successfully"}


@advertising_router.put("/campaigns/{campaign_id}/resume")
async def resume_campaign(
    campaign_id: int,
    bar_id: int = Query(..., description="Bar ID"),
    current_user = Depends(get_current_user)
):
    """Resume a paused campaign."""
    await CampaignService.resume_campaign(campaign_id, bar_id)
    return {"message": "Campaign resumed successfully"}


@advertising_router.delete("/campaigns/{campaign_id}")
async def cancel_campaign(
    campaign_id: int,
    bar_id: int = Query(..., description="Bar ID"),
    current_user = Depends(get_current_user)
):
    """Cancel campaign and refund unused budget/credits."""
    refund = await CampaignService.cancel_campaign(campaign_id, bar_id)
    return {"message": "Campaign cancelled", "refunded_amount": refund.get("amount", 0)}


# =============================================================================
# AD SERVING ENDPOINTS (Internal - called by consumer app)
# =============================================================================

@advertising_router.get("/serve/featured", response_model=List[FeaturedAd], include_in_schema=False)
async def serve_featured_ads(
    latitude: float = Query(..., ge=-90, le=90),
    longitude: float = Query(..., ge=-180, le=180),
    limit: int = Query(default=10, ge=1, le=20)
):
    """Get featured ads for home screen."""
    return await CampaignService.serve_featured(latitude, longitude, limit)


@advertising_router.get("/serve/search", response_model=List[SearchAd], include_in_schema=False)
async def serve_search_ads(
    latitude: float = Query(..., ge=-90, le=90),
    longitude: float = Query(..., ge=-180, le=180),
    query: Optional[str] = None,
    category: Optional[str] = None,
    limit: int = Query(default=3, ge=1, le=5)
):
    """Get sponsored search results."""
    return await CampaignService.serve_search(latitude, longitude, query, category, limit)


@advertising_router.post("/track", include_in_schema=False)
async def track_ad_event(
    event: AdTrackEvent,
    background_tasks: BackgroundTasks,
    request: Request,
    current_user = Depends(get_current_user)
):
    """Track impression, click, or conversion."""
    user_id = current_user.get("id") if current_user else None
    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")
    
    background_tasks.add_task(
        CampaignService.track_event,
        campaign_id=event.campaign_id, action=event.action, placement=event.placement,
        user_id=user_id, session_id=event.session_id, latitude=event.latitude,
        longitude=event.longitude, ip_address=ip_address, user_agent=user_agent
    )
    
    return {"status": "tracked"}


# =============================================================================
# ANALYTICS ENDPOINTS
# =============================================================================

@advertising_router.get("/analytics", response_model=DashboardAnalytics)
async def get_analytics_dashboard(
    start_date: date = Query(..., description="Start date (YYYY-MM-DD)"),
    end_date: date = Query(..., description="End date (YYYY-MM-DD)"),
    bar_id: int = Query(..., description="Bar ID"),
    current_user = Depends(get_current_user)
):
    """Get aggregated analytics for all campaigns."""
    return await CampaignService.get_dashboard_analytics(bar_id, start_date, end_date)


@advertising_router.get("/invoices", response_model=InvoiceListResponse)
async def get_invoices(
    bar_id: int = Query(..., description="Bar ID"),
    current_user = Depends(get_current_user)
):
    """Get billing history for the bar."""
    query = AdvertisingInvoice.__table__.select().where(
        AdvertisingInvoice.bar_id == bar_id
    ).order_by(AdvertisingInvoice.created_at.desc())
    
    invoices = await database.fetch_all(query)
    return InvoiceListResponse(
        invoices=[InvoiceResponse(**dict(inv)) for inv in invoices],
        total=len(invoices)
    )


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def _get_allowed_campaign_types(tier: str) -> List[str]:
    """Get allowed campaign types for a subscription tier"""
    if tier == "vip":
        return ["featured", "search", "map", "promo_boost", "banner"]
    elif tier == "master":
        return ["featured", "search"]
    else:
        return []


def _campaign_to_response(campaign: dict) -> CampaignResponse:
    """Convert database campaign to response schema"""
    budget_remaining = Decimal(str(campaign["budget_amount"])) - Decimal(str(campaign["budget_spent"]))
    impressions = campaign.get("impressions", 0) or 0
    clicks = campaign.get("clicks", 0) or 0
    ctr = (clicks / impressions * 100) if impressions > 0 else 0.0
    
    return CampaignResponse(
        id=campaign["id"], bar_id=campaign["bar_id"], name=campaign["name"],
        campaign_type=CampaignTypeEnum(campaign["campaign_type"]),
        status=CampaignStatusEnum(campaign["status"]),
        budget_type=BudgetTypeEnum(campaign["budget_type"]),
        budget_amount=campaign["budget_amount"], budget_spent=campaign["budget_spent"],
        budget_remaining=budget_remaining, start_time=campaign["start_time"],
        end_time=campaign.get("end_time"),
        targeting=CampaignTargeting(**campaign.get("targeting", {})),
        creative=CampaignCreative(**campaign.get("creative", {})),
        impressions=impressions, clicks=clicks,
        conversions=campaign.get("conversions", 0) or 0, ctr=ctr,
        created_at=campaign["created_at"], updated_at=campaign["updated_at"]
    )
