"""
BARZ Advertising Routes

API endpoints for advertising subscriptions, campaigns, and analytics.
Based on: docs/business/ADVERTISING_BACKEND.md
"""
from datetime import datetime, timezone, date
from decimal import Decimal
from typing import Optional, List, Union
from fastapi import APIRouter, Depends, Query, HTTPException, status, BackgroundTasks, Request

from app.database import database
from app.auth.dependencies import get_optional_user
from app.auth.rbac_middleware import BarAuthContext, require_bar_permission
from app.auth.rbac_models import Permission
from app.errors import APIError

from .models import (
    AdvertisingSubscription, AdvertisingCampaign, AdvertisingImpression,
    AdvertisingInvoice, RegionPricing,
    SubscriptionTier, SubscriptionStatus, CampaignStatus, CampaignType, AdAction
)
from .schemas import (
    SubscriptionTierEnum, SubscriptionStatusEnum, SubscriptionResponse, SubscribeRequest, PixSubscriptionResponse, ChangePlanRequest,
    SubscriptionPlansResponse, SubscriptionPlanInfo, CreditsBalance,
    CampaignCreate, CampaignUpdate, CampaignResponse, CampaignListResponse,
    CampaignStatusEnum, CampaignTypeEnum, CampaignTargeting, CampaignCreative,
    FeaturedAd, SearchAd, MapSpotlight, AdTrackEvent,
    DashboardAnalytics, CampaignAnalytics,
    InvoiceResponse, InvoiceListResponse,
    RegionPricingResponse, BudgetTypeEnum,
    ExtendedCampaignResponse, CampaignPublishResponse, CampaignSummaryResponse,
    CampaignsAnalyticsSummaryResponse, TrendAnalytics,
    CampaignGoalEnum, ExtendedTargeting, PlacementDistribution, EstimatedPerformance,
    CancelCampaignResponse, AdRateCardResponse, PlacementRateCard
)
from .pricing import (
    CAMPAIGN_TYPE_BY_PLACEMENT, CREDIT_BUCKETS, CREDIT_UNIT_BY_BUCKET, DEFAULT_MIN_DAILY_BUDGET,
    DEFAULT_REGION_CODE, ESTIMATION_DAYS, MIN_DAILY_BUDGETS, PRICING_MODEL_BY_PLACEMENT,
    RATE_UNIT_BY_PRICING_MODEL, REGION_RATE_FIELDS, allowed_budget_types_for_placement, as_decimal,
    credit_bucket_for_placement, ensure_credits, infer_campaign_type, normalize_placement,
    placement_for_campaign_type
)
from .services.subscription_service import SubscriptionService, build_default_subscription
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
    Plans are ordered by tier priority: Regular → Master → VIP.
    """
    query = RegionPricing.__table__.select().where(RegionPricing.region_code == region_code.upper())
    pricing = await database.fetch_one(query)
    
    if not pricing:
        raise APIError.not_found(f"Pricing not available for region: {region_code}")
    
    # Convert DB record to dict so .get() works (Record objects lack .get())
    pricing = dict(pricing)
    
    # Feature keys from DB — frontend translates these via i18n maps
    # Use DB values if they exist and have correct content, otherwise fall back to hardcoded defaults
    regular_features = pricing.get("regular_features") or [
        "feature_basic_listing",
        "feature_order_management",
        "feature_basic_analytics",
    ]
    master_features = pricing.get("master_features") or [
        "feature_everything_regular",
        "feature_reduced_commission",
        "feature_monthly_credits",
        "feature_featured_home",
        "feature_sponsored_search",
        "feature_priority_support",
    ]
    vip_features = pricing.get("vip_features") or [
        "feature_everything_master",
        "feature_lowest_commission",
        "feature_max_credits",
        "feature_map_spotlight",
        "feature_promotion_boost",
        "feature_rich_media_banners",
        "feature_verified_badge",
        "feature_dedicated_manager",
    ]
    
    # Ensure features lists contain string entries (handle potential JSON parsing edge cases)
    if not isinstance(regular_features, list):
        regular_features = ["feature_basic_listing", "feature_order_management", "feature_basic_analytics"]
    if not isinstance(master_features, list):
        master_features = ["feature_everything_regular", "feature_reduced_commission", "feature_monthly_credits", "feature_featured_home", "feature_sponsored_search", "feature_priority_support"]
    if not isinstance(vip_features, list):
        vip_features = ["feature_everything_master", "feature_lowest_commission", "feature_max_credits", "feature_map_spotlight", "feature_promotion_boost", "feature_rich_media_banners", "feature_verified_badge", "feature_dedicated_manager"]
    
    # Default credits for regular (free) tier
    regular_credits = {"featured_hours": 0, "search_clicks": 0, "map_hours": 0, "boost_impressions": 0}
    
    # Ensure credits JSON is a dict (handle potential string-from-DB or None edge cases)
    master_credits_raw = pricing.get("master_credits") or regular_credits
    if isinstance(master_credits_raw, str):
        import json
        try:
            master_credits_raw = json.loads(master_credits_raw)
        except:
            master_credits_raw = regular_credits
    master_credits = CreditsBalance(**master_credits_raw) if isinstance(master_credits_raw, dict) else CreditsBalance()
    
    vip_credits_raw = pricing.get("vip_credits") or regular_credits
    if isinstance(vip_credits_raw, str):
        import json
        try:
            vip_credits_raw = json.loads(vip_credits_raw)
        except:
            vip_credits_raw = regular_credits
    vip_credits = CreditsBalance(**vip_credits_raw) if isinstance(vip_credits_raw, dict) else CreditsBalance()
    
    # Build plans ordered by tier priority (Regular → Master → VIP)
    plans = {
        "regular": SubscriptionPlanInfo(
            tier=SubscriptionTierEnum.REGULAR,
            name="Regular",
            monthly_price=Decimal("0.00"),
            annual_price=Decimal("0.00"),
            commission_rate=pricing["regular_commission"],
            credits=CreditsBalance(),
            features=regular_features
        ),
        "master": SubscriptionPlanInfo(
            tier=SubscriptionTierEnum.MASTER,
            name="Master",
            monthly_price=pricing["master_monthly"],
            annual_price=pricing["master_annual"] if pricing["master_annual"] else Decimal("0.00"),
            commission_rate=pricing["master_commission"],
            credits=master_credits,
            features=master_features
        ),
        "vip": SubscriptionPlanInfo(
            tier=SubscriptionTierEnum.VIP,
            name="VIP",
            monthly_price=pricing["vip_monthly"],
            annual_price=pricing["vip_annual"] if pricing["vip_annual"] else Decimal("0.00"),
            commission_rate=pricing["vip_commission"],
            credits=vip_credits,
            features=vip_features
        )
    }
    
    return SubscriptionPlansResponse(region_code=region_code.upper(), currency=pricing["currency"], plans=plans)


@advertising_router.get("/my-plan", response_model=SubscriptionResponse)
async def get_my_plan(
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_VIEW))
):
    """
    Get current bar's subscription details.
    Auto-provisions the free Regular tier when the bar has no subscription row yet,
    so this endpoint always answers 200 instead of failing on sparse legacy rows.
    """
    bar_id = auth.bar_id
    subscription = await SubscriptionService.get_subscription(bar_id)
    
    if not subscription:
        subscription = await SubscriptionService.create_default_subscription(bar_id)
    
    return _subscription_to_response(subscription, bar_id)


@advertising_router.post("/subscribe", response_model=Union[SubscriptionResponse, PixSubscriptionResponse])
async def subscribe_to_plan(
    request: SubscribeRequest,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_MANAGE))
):
    """Subscribe to a plan or upgrade existing subscription."""
    bar_id = auth.bar_id
    customer_info = request.customer_info.model_dump() if request.customer_info else None
    
    result = await SubscriptionService.subscribe(
        bar_id=bar_id, tier=request.tier, payment_method=request.payment_method.model_dump(),
        billing_cycle=request.billing_cycle, customer_info=customer_info
    )
    
    # If it's a PIX payment, return the PixSubscriptionResponse data
    if result.get("status") == "waiting_payment":
        return PixSubscriptionResponse(**result)
    
    # Otherwise return the standard SubscriptionResponse
    return _subscription_to_response(result, bar_id)


@advertising_router.get("/credits", response_model=CreditsBalance)
async def get_credits(
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_VIEW))
):
    """Check remaining advertising credits."""
    bar_id = auth.bar_id
    subscription = await SubscriptionService.get_subscription(bar_id)
    return CreditsBalance(**ensure_credits((subscription or {}).get("credits")))


@advertising_router.get("/rates", response_model=AdRateCardResponse)
async def get_rate_card(
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_VIEW))
):
    """
    Rate card for the active bar: CPC / CPM / CPH rates, minimum daily budgets,
    credit buckets consumed per placement and the bar's current credit balances.
    """
    bar_id = auth.bar_id
    subscription = await SubscriptionService.get_subscription(bar_id)
    if not subscription:
        subscription = await SubscriptionService.create_default_subscription(bar_id)
    subscription = subscription or build_default_subscription(bar_id)

    region_code = (subscription.get("region_code") or DEFAULT_REGION_CODE).upper()
    pricing = await database.fetch_one(
        RegionPricing.__table__.select().where(RegionPricing.region_code == region_code)
    )
    pricing = dict(pricing) if pricing else {}

    tier = _safe_enum(SubscriptionTierEnum, subscription.get("tier"), SubscriptionTierEnum.REGULAR)
    # `usable` mirrors the create endpoint's tier gate so the FE can grey out placements the
    # bar's tier cannot buy (additive field — see .docs/FE_BE_COMMUNICATION.md §4/§10).
    allowed_campaign_types = _get_allowed_campaign_types(tier.value)

    placements = {}
    for placement, (rate_field, rate_max_field) in REGION_RATE_FIELDS.items():
        pricing_model = PRICING_MODEL_BY_PLACEMENT[placement]
        credit_bucket = credit_bucket_for_placement(placement)
        rate = as_decimal(pricing.get(rate_field))
        rate_max = as_decimal(pricing.get(rate_max_field)) if rate_max_field else None

        # Same builder as POST /advertising/campaigns validation: emits the API-legal budget_type
        # token (`hourly`, never `cph`), the metered token only when the region has a rate > 0.
        allowed_budget_types = allowed_budget_types_for_placement(placement, has_rate=rate > 0)

        placements[placement] = PlacementRateCard(
            placement=placement,
            campaign_type=CAMPAIGN_TYPE_BY_PLACEMENT[placement],
            pricing_model=pricing_model,
            rate=rate,
            rate_max=rate_max,
            rate_unit=RATE_UNIT_BY_PRICING_MODEL[pricing_model],
            credit_bucket=credit_bucket,
            credit_unit=CREDIT_UNIT_BY_BUCKET.get(credit_bucket) if credit_bucket else None,
            credit_backed=bool(credit_bucket),
            min_daily_budget=MIN_DAILY_BUDGETS.get(placement, DEFAULT_MIN_DAILY_BUDGET),
            allowed_budget_types=allowed_budget_types,
            usable=CAMPAIGN_TYPE_BY_PLACEMENT[placement] in allowed_campaign_types,
        )

    return AdRateCardResponse(
        region_code=region_code,
        currency=pricing.get("currency") or "BRL",
        tier=tier,
        placements=placements,
        credit_buckets=list(CREDIT_BUCKETS),
        credits_by_tier={
            "master": CreditsBalance(**ensure_credits(pricing.get("master_credits"))),
            "vip": CreditsBalance(**ensure_credits(pricing.get("vip_credits"))),
        },
        credits_available=CreditsBalance(**ensure_credits(subscription.get("credits"))),
        generated_at=datetime.now(timezone.utc),
    )


# =============================================================================
# CAMPAIGN ENDPOINTS
# =============================================================================

@advertising_router.get("/campaigns", response_model=CampaignListResponse)
async def list_campaigns(
    status: Optional[str] = Query(None, description="Filter by status: draft, active, paused, completed, all"),
    sort: Optional[str] = Query(None, description="Sort by: created_at, budget_amount, performance"),
    search: Optional[str] = Query(None, description="Search by campaign name"),
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_VIEW))
):
    """List all advertising campaigns for the bar with optional filtering and sorting."""
    bar_id = auth.bar_id
    campaigns = await CampaignService.list_campaigns(bar_id, status, sort, search)
    return CampaignListResponse(
        campaigns=[_campaign_to_response(c) for c in campaigns],
        total=len(campaigns)
    )


@advertising_router.post("/campaigns", response_model=CampaignResponse, status_code=status.HTTP_201_CREATED)
async def create_campaign(
    campaign: CampaignCreate,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_MANAGE))
):
    """Create a new advertising campaign. For multi-placement campaigns, use campaign_goal and distribution."""
    bar_id = auth.bar_id
    subscription = await SubscriptionService.get_subscription(bar_id)
    if not subscription:
        subscription = await SubscriptionService.create_default_subscription(bar_id)
    subscription = subscription or build_default_subscription(bar_id)
    
    # Multi-placement campaigns derive their gating type from the primary placement
    effective_campaign_type = (
        campaign.campaign_type.value if campaign.campaign_type else infer_campaign_type(campaign.distribution)
    )
    # Fail closed: a payload with neither `campaign_type` nor a resolvable `placement_distribution`
    # previously skipped the tier gate entirely (fail-open by omission) — such a campaign can be
    # neither gated, priced nor served, so reject it instead of letting it bypass the check.
    if effective_campaign_type is None:
        raise APIError.bad_request(
            "campaign_type or placement_distribution is required: the campaign type could not be "
            "determined, so tier gating cannot be applied."
        )
    allowed_types = _get_allowed_campaign_types(subscription["tier"])
    if effective_campaign_type not in allowed_types:
        raise APIError.forbidden(
            f"Campaign type '{effective_campaign_type}' requires a higher subscription tier."
        )

    # Enforce the rate card's `allowed_budget_types` server-side (the FE-doc sentence was
    # aspirational before): the budget_type must be accepted for every placement the campaign buys.
    await _validate_budget_type(campaign, subscription)

    # Validate distribution minimum budgets if provided (cash budgets only)
    if campaign.distribution:
        await _validate_distribution_minimums(
            campaign.distribution, campaign.budget_type, campaign.start_time, campaign.end_time
        )
    
    new_campaign = await CampaignService.create_campaign(
        bar_id=bar_id, subscription_id=subscription["id"], data=campaign
    )
    
    return _campaign_to_response(new_campaign)


@advertising_router.get("/campaigns/summary", response_model=dict)
async def get_campaigns_summary(
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_VIEW))
):
    """Get aggregated stats for all campaigns of a bar."""
    return await CampaignService.get_campaigns_summary(auth.bar_id)


@advertising_router.get("/campaigns/analytics-summary", response_model=CampaignsAnalyticsSummaryResponse)
async def get_campaigns_analytics_summary(
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_VIEW))
):
    """Get aggregated analytics summary for all campaigns of a bar (DOB-83)."""
    return await CampaignService.get_campaigns_analytics_summary(auth.bar_id)


@advertising_router.put("/campaigns/{campaign_id}", response_model=CampaignResponse)
async def update_campaign(
    campaign_id: int,
    updates: CampaignUpdate,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_MANAGE))
):
    """
    Update campaign settings.
    Can update draft campaigns and republish them.
    Can reallocate budget distribution.
    """
    bar_id = auth.bar_id
    # Validate distribution minimums if being updated (cash budgets only)
    if updates.distribution:
        existing = await CampaignService.get_campaign(campaign_id, bar_id)
        if not existing:
            raise APIError.not_found("Campaign not found")
        await _validate_distribution_minimums(
            updates.distribution, existing.get("budget_type"),
            existing.get("start_time"), updates.end_time or existing.get("end_time")
        )
    
    updated_campaign = await CampaignService.update_campaign(campaign_id, bar_id, updates)
    if not updated_campaign:
        raise APIError.not_found("Campaign not found")
    return _campaign_to_response(updated_campaign)


@advertising_router.post("/campaigns/{campaign_id}/publish", response_model=CampaignPublishResponse)
async def publish_campaign(
    campaign_id: int,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_MANAGE))
):
    """
    Convert draft → active.
    Trigger budget reservation.
    Return estimated_performance.
    """
    published = await CampaignService.publish_campaign(campaign_id, auth.bar_id)
    if not published:
        raise APIError.not_found("Campaign not found or cannot be published")
    return published


@advertising_router.get("/campaigns/{campaign_id}", response_model=CampaignResponse)
async def get_campaign(
    campaign_id: int,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_VIEW))
):
    """Get campaign details with performance metrics."""
    campaign = await CampaignService.get_campaign(campaign_id, auth.bar_id)
    if not campaign:
        raise APIError.not_found("Campaign not found")
    return _campaign_to_response(campaign)


@advertising_router.post("/campaigns/{campaign_id}/pause", response_model=CampaignResponse)
async def pause_campaign(
    campaign_id: int,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_MANAGE))
):
    """Pause an active campaign with pro-ration tracking."""
    campaign = await CampaignService.pause_campaign(campaign_id, auth.bar_id)
    return _campaign_to_response(campaign)


@advertising_router.post("/campaigns/{campaign_id}/resume", response_model=CampaignResponse)
async def resume_campaign(
    campaign_id: int,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_MANAGE))
):
    """Resume a paused campaign (auto-extends end_time)."""
    campaign = await CampaignService.resume_campaign(campaign_id, auth.bar_id)
    return _campaign_to_response(campaign)


@advertising_router.delete("/campaigns/{campaign_id}", response_model=CancelCampaignResponse)
async def cancel_campaign(
    campaign_id: int,
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_MANAGE))
):
    """Cancel campaign and refund unused budget/credits."""
    refund = await CampaignService.cancel_campaign(campaign_id, auth.bar_id)
    return CancelCampaignResponse(**refund)


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


@advertising_router.get("/serve/map", response_model=List[MapSpotlight], include_in_schema=False)
async def serve_map_ads(
    latitude: float = Query(..., ge=-90, le=90),
    longitude: float = Query(..., ge=-180, le=180),
    zoom_level: int = Query(default=15, ge=5, le=20),
    limit: int = Query(default=5, ge=1, le=10)
):
    """Get map spotlight ads (highlighted pins)."""
    return await CampaignService.serve_map(latitude, longitude, zoom_level, limit)


@advertising_router.post("/track", include_in_schema=False)
async def track_ad_event(
    event: AdTrackEvent,
    background_tasks: BackgroundTasks,
    request: Request,
    current_user = Depends(get_optional_user)
):
    """Track impression, click, or conversion. Auth optional."""
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
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_VIEW))
):
    """Get aggregated analytics for all campaigns."""
    return await CampaignService.get_dashboard_analytics(auth.bar_id, start_date, end_date)


from datetime import timedelta

@advertising_router.get("/analytics/{campaign_id}", response_model=CampaignAnalytics)
async def get_single_campaign_analytics(
    campaign_id: int,
    start_date: Optional[date] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date (YYYY-MM-DD)"),
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_VIEW))
):
    """Get analytics for a specific campaign."""
    bar_id = auth.bar_id

    s_date = start_date or (datetime.now(timezone.utc) - timedelta(days=30)).date()
    e_date = end_date or datetime.now(timezone.utc).date()
    
    analytics = await CampaignService.get_campaign_analytics(campaign_id, bar_id, s_date, e_date)
    if not analytics:
        raise APIError.not_found("Analytics for campaign not found")
        
    return analytics


@advertising_router.get("/invoices", response_model=InvoiceListResponse)
async def get_invoices(
    auth: BarAuthContext = Depends(require_bar_permission(Permission.ADS_VIEW))
):
    """Get billing history for the bar."""
    bar_id = auth.bar_id
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

def _safe_enum(enum_cls, value, fallback=None):
    if value is None:
        return fallback
    try:
        return enum_cls(value)
    except ValueError:
        return fallback


def _subscription_to_response(subscription: Optional[dict], bar_id: Optional[int] = None) -> SubscriptionResponse:
    if not subscription:
        subscription = build_default_subscription(bar_id or 0)

    return SubscriptionResponse(
        id=subscription.get("id") or 0,
        bar_id=subscription.get("bar_id") or bar_id or 0,
        tier=_safe_enum(SubscriptionTierEnum, subscription.get("tier"), SubscriptionTierEnum.REGULAR),
        status=_safe_enum(SubscriptionStatusEnum, subscription.get("status"), SubscriptionStatusEnum.ACTIVE),
        region_code=subscription.get("region_code") or DEFAULT_REGION_CODE,
        monthly_fee=as_decimal(subscription.get("monthly_fee")),
        commission_rate=as_decimal(subscription.get("commission_rate"), Decimal("0.1500")),
        credits=CreditsBalance(**ensure_credits(subscription.get("credits"))),
        billing_cycle_start=subscription.get("billing_cycle_start"),
        next_billing_date=subscription.get("next_billing_date"),
        created_at=subscription.get("created_at"),
    )


def _get_allowed_campaign_types(tier: str) -> List[str]:
    """
    Get allowed campaign types for a subscription tier.

    Ground truth for promo: .docs/q4_2026/Dobar_Market_Analysis_Brazil_2026.pdf §5.2 gates
    Promotion Boost at Master + VIP — `promo_boost` was added to the `master` list on 2026-10-06
    (it used to be VIP-only). `banner` and `map` remain VIP-only deliberately: no pricing document
    covers them for Master. An empty list 403s every campaign_type for `regular`.
    """
    if tier == "vip":
        return ["featured", "search", "map", "promo_boost", "banner", "push_notification"]
    elif tier == "master":
        return ["featured", "search", "push_notification", "promo_boost"]
    else:
        return []


async def _validate_budget_type(campaign: "CampaignCreate", subscription: dict) -> None:
    """
    Reject a `budget_type` the campaign's placements do not accept, using exactly the rule that
    builds the rate card (allowed_budget_types_for_placement), so
    `allowed_budget_types` in GET /advertising/rates is *enforced*, not aspirational:
    `credits` only for credit-backed placements, metered tokens (`hourly` / `cpc` / `cpm`) only for
    the matching pricing model *and* only when the region has a configured rate > 0,
    `fixed` everywhere. Checked against every placement the campaign buys.
    """
    budget_type = campaign.budget_type.value

    placements = set()
    if campaign.campaign_type:
        placement = placement_for_campaign_type(campaign.campaign_type.value)
        if placement:
            placements.add(placement)
    for dist in campaign.distribution or []:
        placement = normalize_placement(dist.placement)
        if placement:
            placements.add(placement)

    region_code = (subscription.get("region_code") or DEFAULT_REGION_CODE).upper()
    pricing_row = await database.fetch_one(
        RegionPricing.__table__.select().where(RegionPricing.region_code == region_code)
    )
    pricing = dict(pricing_row) if pricing_row else {}

    for placement in sorted(placements):
        rate_field = REGION_RATE_FIELDS[placement][0]
        allowed = allowed_budget_types_for_placement(
            placement, has_rate=as_decimal(pricing.get(rate_field)) > 0
        )
        if budget_type not in allowed:
            raise APIError.bad_request(
                f"budget_type '{budget_type}' is not accepted for placement '{placement}'. "
                f"Allowed budget types: {', '.join(allowed)}."
            )


def _campaign_to_response(campaign: dict) -> CampaignResponse:
    """Convert database campaign to response schema"""
    budget_amount = as_decimal(campaign.get("budget_amount"))
    budget_spent = as_decimal(campaign.get("budget_spent"))
    impressions = campaign.get("impressions") or 0
    clicks = campaign.get("clicks") or 0
    ctr = (clicks / impressions * 100) if impressions > 0 else 0.0

    targeting = campaign.get("targeting") if isinstance(campaign.get("targeting"), dict) else {}
    creative = campaign.get("creative") if isinstance(campaign.get("creative"), dict) else {}

    return CampaignResponse(
        id=campaign["id"], bar_id=campaign["bar_id"], name=campaign.get("name") or "",
        campaign_type=_safe_enum(CampaignTypeEnum, campaign.get("campaign_type")),
        status=_safe_enum(CampaignStatusEnum, campaign.get("status"), CampaignStatusEnum.DRAFT),
        budget_type=_safe_enum(BudgetTypeEnum, campaign.get("budget_type"), BudgetTypeEnum.FIXED),
        budget_amount=budget_amount, budget_spent=budget_spent,
        budget_remaining=budget_amount - budget_spent, start_time=campaign["start_time"],
        end_time=campaign.get("end_time"),
        targeting=CampaignTargeting(**targeting),
        creative=CampaignCreative(**creative),
        impressions=impressions, clicks=clicks,
        conversions=campaign.get("conversions") or 0, ctr=ctr,
        created_at=campaign.get("created_at") or datetime.now(timezone.utc),
        updated_at=campaign.get("updated_at") or datetime.now(timezone.utc)
    )


def _campaign_duration_days(start_time, end_time) -> Decimal:
    if not start_time or not end_time:
        return Decimal(str(ESTIMATION_DAYS))
    try:
        days = (end_time - start_time).days
    except TypeError:
        return Decimal(str(ESTIMATION_DAYS))
    return Decimal(str(max(days, 1)))


async def _validate_distribution_minimums(
    distribution: List[PlacementDistribution],
    budget_type=None,
    start_time=None,
    end_time=None
) -> None:
    """
    Validate that each placement in distribution meets minimum daily budget requirements.
    Credit campaigns are expressed in credits (not currency), so the currency minimums
    only apply to cash-funded budget types.
    """
    budget_type_value = budget_type.value if hasattr(budget_type, "value") else budget_type
    if str(budget_type_value).lower() == "credits":
        return

    days = _campaign_duration_days(start_time, end_time)

    for dist in distribution:
        placement = normalize_placement(dist.placement) or dist.placement
        min_budget = MIN_DAILY_BUDGETS.get(placement, DEFAULT_MIN_DAILY_BUDGET)
        daily_placement_budget = as_decimal(dist.budget) / days
        if daily_placement_budget < min_budget:
            raise APIError.bad_request(
                f"Placement '{placement}' requires minimum daily budget of R$ {min_budget}. "
                f"Current allocation: R$ {daily_placement_budget:.2f}/day"
            )
