"""
BARZ Advertising Schemas

Pydantic models for request/response validation.
Based on: docs/business/ADVERTISING_BACKEND.md
"""
from datetime import datetime
from decimal import Decimal
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, validator
from enum import Enum


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


class CampaignTypeEnum(str, Enum):
    FEATURED = "featured"
    SEARCH = "search"
    MAP = "map"
    PROMO_BOOST = "promo_boost"
    BANNER = "banner"


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
    tier: SubscriptionTierEnum
    status: SubscriptionStatusEnum
    region_code: str
    monthly_fee: Decimal
    commission_rate: Decimal
    credits: CreditsBalance
    billing_cycle_start: datetime
    next_billing_date: Optional[datetime]
    created_at: datetime
    
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

class CampaignTargeting(BaseModel):
    """Targeting options for a campaign"""
    radius_km: int = Field(default=10, ge=1, le=100)
    days: List[str] = Field(default=["mon", "tue", "wed", "thu", "fri", "sat", "sun"])
    hours_start: int = Field(default=0, ge=0, le=23)
    hours_end: int = Field(default=24, ge=1, le=24)
    categories: List[str] = []
    keywords: List[str] = []
    
    @validator("days", each_item=True)
    def validate_days(cls, v):
        valid_days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        if v.lower() not in valid_days:
            raise ValueError(f"Invalid day: {v}")
        return v.lower()


class AgeRange(BaseModel):
    """Age range targeting"""
    min: int = Field(default=18, ge=18, le=65)
    max: int = Field(default=45, ge=18, le=65)


class ExtendedTargeting(BaseModel):
    """Extended targeting options for multi-placement campaigns"""
    radius_km: int = Field(default=5, ge=1, le=50)
    peak_hours_only: bool = False
    age_range: Optional[AgeRange] = None


class PlacementDistribution(BaseModel):
    """Budget distribution for a single placement"""
    placement: str  # "featured", "search", "map_pin", "promo", "banner"
    percentage: int = Field(ge=0, le=100)
    budget: Decimal = Field(ge=0)


class CampaignCreative(BaseModel):
    """Creative assets for a campaign"""
    logo_url: Optional[str] = None
    tagline: Optional[str] = Field(None, max_length=60)
    banner_url: Optional[str] = None
    animation_url: Optional[str] = None
    promoted_item_id: Optional[int] = None  # Menu item or promotion to highlight


class EstimatedPerformance(BaseModel):
    """Estimated performance metrics"""
    daily_reach: int = 0
    estimated_clicks: int = 0
    estimated_impressions: int = 0


class CampaignCreate(BaseModel):
    """Request to create a new campaign"""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    campaign_type: Optional[CampaignTypeEnum] = None  # Optional for multi-placement campaigns
    campaign_goal: CampaignGoalEnum
    budget_type: BudgetTypeEnum = BudgetTypeEnum.FIXED
    budget_amount: Decimal = Field(..., gt=0)
    start_time: datetime
    end_time: Optional[datetime] = None
    targeting: Optional[ExtendedTargeting] = None
    creative: Optional[CampaignCreative] = None
    distribution: Optional[List[PlacementDistribution]] = None
    is_smart_distribution: bool = False
    budget_optimizer_enabled: bool = False
    
    @validator("end_time")
    def end_after_start(cls, v, values):
        if v and "start_time" in values and v <= values["start_time"]:
            raise ValueError("end_time must be after start_time")
        return v
    
    @validator("distribution")
    def validate_distribution_total(cls, v):
        if v is not None:
            total = sum(d.percentage for d in v)
            if total != 100:
                raise ValueError(f"Distribution percentages must total 100%, got {total}%")
        return v


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
    
    @validator("distribution")
    def validate_distribution_total(cls, v):
        if v is not None:
            total = sum(d.percentage for d in v)
            if total != 100:
                raise ValueError(f"Distribution percentages must total 100%, got {total}%")
        return v


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
    start_time: datetime
    end_time: Optional[datetime]
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
    start_time: datetime
    end_time: Optional[datetime]
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