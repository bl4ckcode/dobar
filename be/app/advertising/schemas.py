"""
BARZ Advertising Schemas

Pydantic models for request/response validation.
Based on: docs/business/ADVERTISING_BACKEND.md
"""
from datetime import datetime
from decimal import Decimal
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, root_validator, validator
from enum import Enum

from .pricing import (
    CAMPAIGN_TYPE_BY_PLACEMENT,
    CREDIT_BUCKET_BY_PLACEMENT,
    CREDIT_UNIT_BY_BUCKET,
    DEFAULT_MIN_DAILY_BUDGET,
    DEFAULT_REGION_CODE,
    MIN_DAILY_BUDGETS,
    PLACEMENTS,
    PRICING_MODEL_BY_PLACEMENT,
    RATE_UNIT_BY_PRICING_MODEL,
    normalize_distribution,
    normalize_placement,
)


# =============================================================================
# ENUMS (Pydantic compatible)
# =============================================================================

class SubscriptionTierEnum(str, Enum):
    REGULAR = "regular"
    MASTER = "master"
    VIP = "vip"


class SubscriptionStatusEnum(str, Enum):
    ACTIVE = "active"
    PAUSED = "paused"
    CANCELLED = "cancelled"
    EXPIRED = "expired"
    TRIAL = "trial"
    PAST_DUE = "past_due"


class CampaignTypeEnum(str, Enum):
    FEATURED = "featured"
    SEARCH = "search"
    MAP = "map"
    PROMO_BOOST = "promo_boost"
    BANNER = "banner"
    PUSH_NOTIFICATION = "push_notification"


class CampaignStatusEnum(str, Enum):
    DRAFT = "draft"
    SCHEDULED = "scheduled"
    ACTIVE = "active"
    PAUSED = "paused"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class CampaignGoalEnum(str, Enum):
    DISCOVERY = "discovery"
    FOOT_TRAFFIC = "foot_traffic"
    PROMOTION = "promotion"
    FULL_PRESENCE = "full_presence"


class BudgetTypeEnum(str, Enum):
    HOURLY = "hourly"
    CPC = "cpc"
    CPM = "cpm"
    FIXED = "fixed"
    CREDITS = "credits"


class AdActionEnum(str, Enum):
    IMPRESSION = "impression"
    CLICK = "click"
    CONVERSION = "conversion"


# =============================================================================
# SUBSCRIPTION SCHEMAS
# =============================================================================

class CreditsBalance(BaseModel):
    """Current credit balance for a subscription"""
    featured_hours: int = 0
    search_clicks: int = 0
    map_hours: int = 0
    boost_impressions: int = 0


class SubscriptionPlanInfo(BaseModel):
    """Information about a subscription plan"""
    tier: SubscriptionTierEnum
    name: str
    monthly_price: Decimal
    annual_price: Decimal
    commission_rate: Decimal
    credits: CreditsBalance
    features: List[str]


class SubscriptionPlansResponse(BaseModel):
    """Available subscription plans for a region"""
    region_code: str
    currency: str
    plans: Dict[str, SubscriptionPlanInfo]


class SubscriptionResponse(BaseModel):
    """Current subscription details"""
    id: int
    bar_id: int
    tier: SubscriptionTierEnum = SubscriptionTierEnum.REGULAR
    status: SubscriptionStatusEnum = SubscriptionStatusEnum.ACTIVE
    region_code: str = "BR"
    monthly_fee: Decimal = Decimal("0.00")
    commission_rate: Decimal = Decimal("0.1500")
    credits: CreditsBalance = CreditsBalance()
    billing_cycle_start: Optional[datetime] = None
    next_billing_date: Optional[datetime] = None
    created_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class PaymentMethodType(str, Enum):
    CARD = "card"
    PIX = "pix"


class PaymentMethodSchema(BaseModel):
    type: PaymentMethodType = Field(..., description="Payment method type (card or pix)")
    token: Optional[str] = Field(None, description="Payment token for cards")


class CustomerInfo(BaseModel):
    """Customer information for payment processing (required for PIX)"""
    name: str
    email: str
    document: str = Field(..., description="CPF (11 digits) or CNPJ (14 digits), numbers only")
    phone: Optional[str] = None
    type: str = Field(default="individual", pattern="^(individual|company)$")


class SubscribeRequest(BaseModel):
    """Request to subscribe to a plan"""
    tier: SubscriptionTierEnum
    payment_method: PaymentMethodSchema
    billing_cycle: str = Field(default="monthly", pattern="^(monthly|annual)$")
    customer_info: Optional[CustomerInfo] = Field(None, description="Required for PIX payments. CPF/CNPJ document needed.")


class PixSubscriptionResponse(BaseModel):
    """Response returned when PIX is selected for subscription"""
    status: str = "waiting_payment"
    pix_qr_code: str
    pix_copia_e_cola: str
    pix_expires_at: datetime
    invoice_id: int


class ChangePlanRequest(BaseModel):
    """Request to change subscription tier"""
    new_tier: SubscriptionTierEnum


# =============================================================================
# CAMPAIGN SCHEMAS
# =============================================================================

class AgeRange(BaseModel):
    """Age range targeting"""
    min: int = Field(default=18, ge=18, le=65)
    max: int = Field(default=45, ge=18, le=65)


class CampaignTargeting(BaseModel):
    """Targeting options for a campaign"""
    radius_km: int = Field(default=10, ge=1, le=100)
    days: List[str] = Field(default=["mon", "tue", "wed", "thu", "fri", "sat", "sun"])
    hours_start: int = Field(default=0, ge=0, le=23)
    hours_end: int = Field(default=24, ge=1, le=24)
    categories: List[str] = []
    keywords: List[str] = []
    peak_hours_only: bool = False
    age_range: Optional["AgeRange"] = None
    
    @validator("days", each_item=True)
    def validate_days(cls, v):
        valid_days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        if v.lower() not in valid_days:
            raise ValueError(f"Invalid day: {v}")
        return v.lower()


class ExtendedTargeting(BaseModel):
    """Extended targeting options for multi-placement campaigns"""
    radius_km: int = Field(default=5, ge=1, le=50)
    peak_hours_only: bool = False
    age_range: Optional[AgeRange] = None

    @root_validator(pre=True, allow_reuse=True)
    def normalize_age_inputs(cls, values):
        if not isinstance(values, dict):
            return values

        values = dict(values)
        age_min = values.pop("age_min", None)
        age_max = values.pop("age_max", None)

        if values.get("age_range") is None and (age_min is not None or age_max is not None):
            values["age_range"] = {
                "min": age_min if age_min is not None else 18,
                "max": age_max if age_max is not None else 65
            }
        return values


class PlacementDistribution(BaseModel):
    """Budget distribution for a single placement"""
    placement: str  # "featured", "search", "map_pin", "promo", "banner"
    percentage: float = Field(ge=0, le=100)
    budget: Decimal = Field(ge=0)

    @validator("placement", pre=True, allow_reuse=True)
    def normalize_placement_name(cls, v):
        normalized = normalize_placement(v)
        if normalized is None:
            raise ValueError(f"Invalid placement '{v}'. Allowed: {', '.join(PLACEMENTS)}")
        return normalized


class CampaignCreative(BaseModel):
    """Creative assets for a campaign"""
    logo_url: Optional[str] = None
    title: Optional[str] = Field(None, max_length=100)
    tagline: Optional[str] = Field(None, max_length=60)
    cta: Optional[str] = Field(None, max_length=40)
    banner_url: Optional[str] = None
    animation_url: Optional[str] = None
    promoted_item_id: Optional[int] = None  # Menu item or promotion to highlight

    @root_validator(pre=True, allow_reuse=True)
    def normalize_cta_alias(cls, values):
        if isinstance(values, dict) and "cta" not in values and "cta_type" in values:
            values = dict(values)
            values["cta"] = values.pop("cta_type")
        return values


class EstimatedPerformance(BaseModel):
    """Estimated performance metrics"""
    daily_reach: int = 0
    estimated_clicks: int = 0
    estimated_impressions: int = 0


def _normalize_campaign_aliases(values: Any) -> Any:
    if not isinstance(values, dict):
        return values

    values = dict(values)
    budget_amount = values.get("budget_amount")

    if "placement_distribution" in values:
        placement_distribution = values.pop("placement_distribution")
        if values.get("distribution") is None:
            values["distribution"] = placement_distribution

    if values.get("distribution") is not None:
        values["distribution"] = normalize_distribution(values["distribution"], budget_amount)

    targeting = values.get("targeting")
    if isinstance(targeting, dict) and "budget_optimizer_enabled" in targeting:
        targeting = dict(targeting)
        optimizer_enabled = targeting.pop("budget_optimizer_enabled")
        if values.get("budget_optimizer_enabled") is None:
            values["budget_optimizer_enabled"] = bool(optimizer_enabled)
        values["targeting"] = targeting

    return values


def _validate_distribution_percentages(distribution):
    if distribution is not None:
        total = sum(d.percentage for d in distribution)
        if abs(total - 100) > 0.5:
            raise ValueError(f"Distribution percentages must total 100%, got {total}%")
    return distribution


class CampaignCreate(BaseModel):
    """Request to create a new campaign"""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    campaign_type: Optional[CampaignTypeEnum] = None  # Optional for multi-placement campaigns
    campaign_goal: Optional[CampaignGoalEnum] = None  # Optional, inferred from campaign_type if not provided
    budget_type: BudgetTypeEnum = BudgetTypeEnum.FIXED
    budget_amount: Decimal = Field(..., gt=0)
    start_time: datetime
    end_time: Optional[datetime] = None
    targeting: Optional[ExtendedTargeting] = None
    creative: Optional[CampaignCreative] = None
    distribution: Optional[List[PlacementDistribution]] = None
    is_smart_distribution: bool = False
    budget_optimizer_enabled: bool = False
    
    @root_validator(pre=True, allow_reuse=True)
    def normalize_fe_aliases(cls, values):
        return _normalize_campaign_aliases(values)
    
    @validator("end_time")
    def end_after_start(cls, v, values):
        if v and "start_time" in values and v <= values["start_time"]:
            raise ValueError("end_time must be after start_time")
        return v
    
    @validator("distribution")
    def validate_distribution_total(cls, v):
        return _validate_distribution_percentages(v)


class CampaignUpdate(BaseModel):
    """Request to update a campaign"""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    budget_amount: Optional[Decimal] = Field(None, gt=0)
    end_time: Optional[datetime] = None
    targeting: Optional[ExtendedTargeting] = None
    creative: Optional[CampaignCreative] = None
    distribution: Optional[List[PlacementDistribution]] = None
    campaign_goal: Optional[CampaignGoalEnum] = None
    budget_optimizer_enabled: Optional[bool] = None
    
    @root_validator(pre=True, allow_reuse=True)
    def normalize_fe_aliases(cls, values):
        return _normalize_campaign_aliases(values)
    
    @validator("distribution")
    def validate_distribution_total(cls, v):
        return _validate_distribution_percentages(v)


class CampaignResponse(BaseModel):
    """Campaign details response"""
    id: int
    bar_id: int
    name: str
    campaign_type: Optional[CampaignTypeEnum] = None
    status: CampaignStatusEnum
    budget_type: BudgetTypeEnum
    budget_amount: Decimal
    budget_spent: Decimal
    budget_remaining: Decimal
    start_time: datetime
    end_time: Optional[datetime]
    targeting: CampaignTargeting
    creative: CampaignCreative
    impressions: int
    clicks: int
    conversions: int
    ctr: float
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class CampaignListResponse(BaseModel):
    """List of campaigns"""
    campaigns: List[CampaignResponse]
    total: int


# =============================================================================
# EXTENDED CAMPAIGN SCHEMAS (DOB-82)
# =============================================================================

class CancelCampaignResponse(BaseModel):
    """Response after cancelling a campaign"""
    amount: float = 0
    credits: Dict[str, float] = {}


class ExtendedCampaignResponse(BaseModel):
    """Extended campaign details response with distribution and estimated performance"""
    id: int
    bar_id: int
    name: str
    campaign_type: Optional[CampaignTypeEnum] = None
    campaign_goal: Optional[CampaignGoalEnum] = None
    status: CampaignStatusEnum
    budget_type: BudgetTypeEnum
    budget_amount: Decimal
    budget_spent: Decimal
    budget_remaining: Decimal
    budget_spent_per_placement: Optional[Dict[str, float]] = None
    start_time: datetime
    end_time: Optional[datetime]
    paused_at: Optional[datetime] = None
    targeting: ExtendedTargeting
    creative: CampaignCreative
    distribution: Optional[List[PlacementDistribution]] = None
    is_smart_distribution: bool = False
    budget_optimizer_enabled: bool = False
    estimated_performance: Optional[EstimatedPerformance] = None
    impressions: int
    clicks: int
    conversions: int
    ctr: float
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class CampaignPublishResponse(BaseModel):
    """Response after publishing a draft campaign"""
    id: int
    status: CampaignStatusEnum
    estimated_performance: EstimatedPerformance
    message: str = "Campaign published successfully"


class CampaignSummaryResponse(BaseModel):
    """Campaign summary for listing with minimal fields"""
    id: int
    bar_id: int
    name: str
    campaign_goal: Optional[CampaignGoalEnum] = None
    status: CampaignStatusEnum
    budget_amount: Decimal
    budget_spent: Decimal
    budget_remaining: Decimal
    budget_spent_per_placement: Optional[Dict[str, float]] = None
    start_time: datetime
    end_time: Optional[datetime]
    paused_at: Optional[datetime] = None
    distribution: Optional[List[PlacementDistribution]] = None
    estimated_performance: Optional[EstimatedPerformance] = None
    created_at: datetime


# =============================================================================
# ANALYTICS SUMMARY SCHEMAS (DOB-83)
# =============================================================================

class TrendAnalytics(BaseModel):
    """Trend data for a single day"""
    date: str  # ISO date YYYY-MM-DD
    impressions: int = 0
    clicks: int = 0
    spend: Decimal = Decimal("0.00")


class CampaignsAnalyticsSummaryResponse(BaseModel):
    """Aggregated analytics summary for all campaigns of a bar"""
    total_impressions: int
    total_clicks: int
    average_ctr: float
    total_spent: Decimal
    active_campaigns: int
    total_campaigns: int
    budget_remaining: Decimal
    daily_avg_spend: Decimal
    best_performing_placement: Optional[str] = None
    trend: List[TrendAnalytics] = []


# =============================================================================
# AD SERVING SCHEMAS
# =============================================================================

class FeaturedAd(BaseModel):
    """Featured ad for home screen"""
    bar_id: int
    bar_name: str
    logo_url: Optional[str]
    tagline: Optional[str]
    distance_km: float
    campaign_id: int


class SearchAd(BaseModel):
    """Sponsored search result"""
    bar_id: int
    bar_name: str
    logo_url: Optional[str]
    tagline: Optional[str]
    position: int  # 0 = top of results
    campaign_id: int


class MapSpotlight(BaseModel):
    """Map spotlight ad"""
    bar_id: int
    bar_name: str
    latitude: float
    longitude: float
    logo_url: Optional[str]
    campaign_id: int


class AdTrackEvent(BaseModel):
    """Track an ad interaction event"""
    campaign_id: int
    action: AdActionEnum
    placement: Optional[str] = Field(default="unknown", pattern="^(home|search|map|promo|unknown)$")
    session_id: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


# =============================================================================
# ANALYTICS SCHEMAS
# =============================================================================

class DailyAnalytics(BaseModel):
    """Analytics for a single day"""
    date: str  # ISO date YYYY-MM-DD
    impressions: int = 0
    clicks: int = 0
    conversions: int = 0
    spend: Decimal = Decimal("0.00")


class CampaignAnalytics(BaseModel):
    """Analytics for a single campaign"""
    campaign_id: int
    campaign_name: str
    impressions: int
    clicks: int
    conversions: int
    ctr: float
    spend: Decimal
    period_start: datetime
    period_end: datetime
    daily_stats: List[DailyAnalytics] = []


class DashboardAnalytics(BaseModel):
    """Aggregated analytics dashboard"""
    total_impressions: int
    total_clicks: int
    total_conversions: int
    total_spend: Decimal
    average_ctr: float
    campaigns: List[CampaignAnalytics]
    daily_stats: List[DailyAnalytics] = []
    period_start: datetime
    period_end: datetime


# =============================================================================
# INVOICE SCHEMAS
# =============================================================================

class InvoiceResponse(BaseModel):
    """Invoice details"""
    id: int
    bar_id: int
    period_start: datetime
    period_end: datetime
    subscription_amount: Decimal
    advertising_amount: Decimal
    tax_amount: Decimal
    total_amount: Decimal
    currency: str
    status: str
    paid_at: Optional[datetime]
    created_at: datetime
    
    class Config:
        from_attributes = True


class InvoiceListResponse(BaseModel):
    """List of invoices"""
    invoices: List[InvoiceResponse]
    total: int


# =============================================================================
# REGION PRICING SCHEMAS
# =============================================================================

class PlacementRateCard(BaseModel):
    """Rate card entry for a single ad placement"""
    placement: str
    campaign_type: str
    pricing_model: str
    rate: Decimal
    rate_max: Optional[Decimal] = None
    rate_unit: str
    credit_bucket: Optional[str] = None
    credit_unit: Optional[str] = None
    credit_backed: bool
    min_daily_budget: Decimal
    allowed_budget_types: List[str]


class AdRateCardResponse(BaseModel):
    """Region rate card consumed by the bar campaign wizard"""
    region_code: str
    currency: str
    tier: SubscriptionTierEnum
    placements: Dict[str, PlacementRateCard]
    credit_buckets: List[str]
    credits_by_tier: Dict[str, CreditsBalance]
    credits_available: CreditsBalance
    generated_at: datetime


class RegionPricingResponse(BaseModel):
    """Region-specific pricing configuration"""
    region_code: str
    currency: str
    master_monthly: Decimal
    master_annual: Decimal
    vip_monthly: Decimal
    vip_annual: Decimal
    regular_commission: Decimal
    master_commission: Decimal
    vip_commission: Decimal
    featured_cph: Decimal
    search_cpc_min: Decimal
    search_cpc_max: Decimal
    map_cph: Decimal
    boost_cpm: Decimal
    master_credits: CreditsBalance
    vip_credits: CreditsBalance
    
    class Config:
        from_attributes = True