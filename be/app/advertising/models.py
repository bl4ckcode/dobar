"""
BARZ Advertising Models

Database models for the advertising and subscription system.
Based on: docs/business/ADVERTISING_BACKEND.md
"""
from datetime import datetime, timezone
from decimal import Decimal
from sqlalchemy import (
    Column, Integer, String, Numeric, DateTime, Boolean, 
    ForeignKey, Enum as SQLEnum, Index, Text, JSON
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import enum
import uuid

from app.database import Base


# =============================================================================
# ENUMS
# =============================================================================

class SubscriptionTier(str, enum.Enum):
    """Available subscription tiers for bar owners"""
    REGULAR = "regular"  # Free tier
    MASTER = "master"    # $49/month (varies by region)
    VIP = "vip"          # $149/month (varies by region)


class SubscriptionStatus(str, enum.Enum):
    """Lifecycle status of a subscription"""
    ACTIVE = "active"
    PAUSED = "paused"
    CANCELLED = "cancelled"
    EXPIRED = "expired"


class CampaignGoal(str, enum.Enum):
    """Campaign objective/goal types"""
    DISCOVERY = "discovery"           # New bar wanting to get discovered
    FOOT_TRAFFIC = "foot_traffic"     # Want to increase foot traffic
    PROMOTION = "promotion"           # Running a special offer
    FULL_PRESENCE = "full_presence"   # All placements combined


class CampaignType(str, enum.Enum):
    """Types of advertising campaigns"""
    FEATURED = "featured"      # Featured Home placement
    SEARCH = "search"          # Sponsored Search
    MAP = "map"                # Map Spotlight
    PROMO_BOOST = "promo_boost"  # Promotion Boost
    BANNER = "banner"          # Rich Media Banner
    PUSH_NOTIFICATION = "push_notification"  # 🔔 Targeted Push Notifications


class CampaignStatus(str, enum.Enum):
    """Lifecycle status of a campaign"""
    DRAFT = "draft"
    SCHEDULED = "scheduled"
    ACTIVE = "active"
    PAUSED = "paused"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class BudgetType(str, enum.Enum):
    """Pricing model for campaigns"""
    HOURLY = "hourly"    # CPH - Cost per Hour
    CPC = "cpc"          # Cost per Click
    CPM = "cpm"          # Cost per 1000 impressions
    FIXED = "fixed"      # One-time payment
    CREDITS = "credits"  # Use subscription credits


class AdAction(str, enum.Enum):
    """Types of ad interactions"""
    IMPRESSION = "impression"
    CLICK = "click"
    CONVERSION = "conversion"


class InvoiceStatus(str, enum.Enum):
    """Payment status for invoices"""
    PENDING = "pending"
    WAITING_PAYMENT = "waiting_payment"
    PAID = "paid"
    OVERDUE = "overdue"
    REFUNDED = "refunded"


# =============================================================================
# MODELS
# =============================================================================

class AdvertisingSubscription(Base):
    """
    Bar's advertising subscription plan.
    Each bar has exactly one subscription (defaulting to REGULAR/free).
    """
    __tablename__ = "advertising_subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    bar_id = Column(Integer, ForeignKey("bars.id", ondelete="CASCADE"), unique=True, nullable=False, index=True)
    
    # Plan details
    tier = Column(
        SQLEnum(SubscriptionTier, values_callable=lambda x: [e.value for e in x], create_constraint=False, native_enum=True),
        default=SubscriptionTier.REGULAR,
        nullable=False
    )
    status = Column(
        SQLEnum(SubscriptionStatus, values_callable=lambda x: [e.value for e in x], create_constraint=False, native_enum=True),
        default=SubscriptionStatus.ACTIVE,
        nullable=False
    )
    
    # Pricing (region-specific, fetched from RegionPricing)
    region_code = Column(String(2), nullable=False, default="BR")  # ISO country code
    monthly_fee = Column(Numeric(10, 2), default=Decimal("0.00"))
    commission_rate = Column(Numeric(5, 4), nullable=False, default=Decimal("0.1500"))  # 15% default
    
    # Credits remaining (JSON for flexibility across different credit types)
    credits = Column(JSON, default={
        "featured_hours": 0,
        "search_clicks": 0,
        "map_hours": 0,
        "boost_impressions": 0
    })
    
    # Billing cycle
    billing_cycle_start = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    next_billing_date = Column(DateTime(timezone=True), nullable=True)
    payment_method_id = Column(String(100), nullable=True)  # Gateway reference (Stripe/Stone)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    
    # Relationships
    bar = relationship("Bar", back_populates="advertising_subscription")
    campaigns = relationship("AdvertisingCampaign", back_populates="subscription", cascade="all, delete-orphan")

    # Indexes
    __table_args__ = (
        Index('idx_subscription_tier_status', 'tier', 'status'),
        Index('idx_subscription_next_billing', 'next_billing_date'),
    )

    def __repr__(self):
        return f"<AdvertisingSubscription(bar_id={self.bar_id}, tier={self.tier}, status={self.status})>"


class AdvertisingCampaign(Base):
    """
    Individual advertising campaign.
    Bar owners can create multiple campaigns with different types and budgets.
    """
    __tablename__ = "advertising_campaigns"

    id = Column(Integer, primary_key=True, index=True)
    subscription_id = Column(Integer, ForeignKey("advertising_subscriptions.id", ondelete="CASCADE"), nullable=False, index=True)
    bar_id = Column(Integer, ForeignKey("bars.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Campaign details
    name = Column(String(100), nullable=False)
    # Use create_constraint=False since the enum already exists in the database
    # Use values_callable to use enum values (lowercase) instead of names (UPPERCASE)
    campaign_type = Column(
        SQLEnum(CampaignType, values_callable=lambda x: [e.value for e in x], create_constraint=False, native_enum=True),
        nullable=False
    )
    status = Column(
        SQLEnum(CampaignStatus, values_callable=lambda x: [e.value for e in x], create_constraint=False, native_enum=True),
        default=CampaignStatus.DRAFT,
        nullable=False
    )
    
    # Budget
    budget_type = Column(
        SQLEnum(BudgetType, values_callable=lambda x: [e.value for e in x], create_constraint=False, native_enum=True),
        nullable=False
    )
    budget_amount = Column(Numeric(10, 2), nullable=False)
    budget_spent = Column(Numeric(10, 2), default=Decimal("0.00"))
    
    # Schedule
    start_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True), nullable=True)
    
    # Campaign goal (objective for the campaign)
    campaign_goal = Column(String(50), nullable=True)  # discovery, foot_traffic, promotion, full_presence
    
    # Targeting (flexible JSON structure)
    targeting = Column(JSON, default={
        "radius_km": 10,
        "days": ["mon", "tue", "wed", "thu", "fri", "sat", "sun"],
        "hours_start": 0,
        "hours_end": 24,
        "categories": [],
        "keywords": []
    })
    
    # Creative assets
    creative = Column(JSON, default={
        "logo_url": None,
        "tagline": None,
        "banner_url": None,
        "animation_url": None
    })
    
    # Distribution across placements (for multi-placement campaigns)
    distribution = Column(JSON, default=[])  # [{"placement": "featured", "percentage": 40, "budget": 200.00}, ...]
    
    # Smart distribution flag
    is_smart_distribution = Column(Boolean, default=False, server_default='false')
    
    # Budget optimizer flag
    budget_optimizer_enabled = Column(Boolean, default=False, server_default='false')
    
    # Estimated performance (pre-launch estimates)
    estimated_performance = Column(JSON, default={})  # {"daily_reach": 1200, "estimated_clicks": 85, "estimated_impressions": 4500}
    
    # Performance metrics (denormalized for fast dashboard queries)
    impressions = Column(Integer, default=0)
    clicks = Column(Integer, default=0)
    conversions = Column(Integer, default=0)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    
    # Relationships
    subscription = relationship("AdvertisingSubscription", back_populates="campaigns")
    bar = relationship("Bar")
    impressions_log = relationship("AdvertisingImpression", back_populates="campaign", cascade="all, delete-orphan")

    # Indexes
    __table_args__ = (
        Index('idx_campaign_bar_status', 'bar_id', 'status'),
        Index('idx_campaign_type_status', 'campaign_type', 'status'),
        Index('idx_campaign_schedule', 'start_time', 'end_time'),
    )

    @property
    def ctr(self) -> float:
        """Click-through rate"""
        if self.impressions == 0:
            return 0.0
        return (self.clicks / self.impressions) * 100

    @property
    def budget_remaining(self) -> Decimal:
        """Remaining budget"""
        return self.budget_amount - self.budget_spent

    def __repr__(self):
        return f"<AdvertisingCampaign(id={self.id}, name={self.name}, type={self.campaign_type}, status={self.status})>"


class AdvertisingImpression(Base):
    """
    Individual ad impression/click/conversion event.
    Used for billing (CPC/CPM) and analytics.
    """
    __tablename__ = "advertising_impressions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    campaign_id = Column(Integer, ForeignKey("advertising_campaigns.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Event type
    action = Column(
        SQLEnum(AdAction, values_callable=lambda x: [e.value for e in x], create_constraint=False, native_enum=True),
        nullable=False,
        index=True
    )
    placement = Column(String(50), nullable=False)  # "home", "search", "map", "promo"
    
    # User context (nullable for anonymous users)
    user_id = Column(String(100), nullable=True)  # User ID as string (for anonymous/logged-in users)
    session_id = Column(String(100), nullable=True)  # For anonymous tracking
    
    # Location at time of event
    latitude = Column(Numeric(10, 6), nullable=True)
    longitude = Column(Numeric(10, 6), nullable=True)
    
    # Metadata
    ip_address = Column(String(45), nullable=True)  # IPv4/IPv6 address
    ip_hash = Column(String(64), nullable=True)  # Hashed IP for fraud detection
    user_agent = Column(String(500), nullable=True)
    
    # Timestamp
    timestamp = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True)
    
    # Relationships
    campaign = relationship("AdvertisingCampaign", back_populates="impressions_log")

    # Indexes for analytics queries
    __table_args__ = (
        Index('idx_impression_campaign_action', 'campaign_id', 'action'),
        Index('idx_impression_timestamp', 'timestamp'),
        Index('idx_impression_user_campaign', 'user_id', 'campaign_id'),
    )

    def __repr__(self):
        return f"<AdvertisingImpression(campaign_id={self.campaign_id}, action={self.action})>"


class AdvertisingInvoice(Base):
    """
    Billing invoice for subscription and advertising spend.
    Generated monthly or on-demand.
    """
    __tablename__ = "advertising_invoices"

    id = Column(Integer, primary_key=True, index=True)
    bar_id = Column(Integer, ForeignKey("bars.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Billing period
    period_start = Column(DateTime(timezone=True), nullable=False)
    period_end = Column(DateTime(timezone=True), nullable=False)
    
    # Amount breakdown
    subscription_amount = Column(Numeric(10, 2), default=Decimal("0.00"))
    advertising_amount = Column(Numeric(10, 2), default=Decimal("0.00"))
    tax_amount = Column(Numeric(10, 2), default=Decimal("0.00"))
    total_amount = Column(Numeric(10, 2), nullable=False)
    currency = Column(String(3), nullable=False, default="BRL")
    
    # Status
    status = Column(
        SQLEnum(InvoiceStatus, values_callable=lambda x: [e.value for e in x], create_constraint=False, native_enum=True),
        default=InvoiceStatus.PENDING,
        nullable=False
    )
    
    # Payment info
    payment_gateway_ref = Column(String(100), nullable=True)
    paid_at = Column(DateTime(timezone=True), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    # Relationships
    bar = relationship("Bar")

    # Indexes
    __table_args__ = (
        Index('idx_invoice_bar_status', 'bar_id', 'status'),
        Index('idx_invoice_period', 'period_start', 'period_end'),
    )

    def __repr__(self):
        return f"<AdvertisingInvoice(bar_id={self.bar_id}, total={self.total_amount}, status={self.status})>"


class RegionPricing(Base):
    """
    Region-specific pricing configuration.
    Allows different pricing for different markets (BR, US, MX, etc.).
    """
    __tablename__ = "region_pricing"

    id = Column(Integer, primary_key=True, index=True)
    region_code = Column(String(2), unique=True, nullable=False, index=True)  # ISO country code
    currency = Column(String(3), nullable=False)
    
    # Subscription pricing
    master_monthly = Column(Numeric(10, 2), nullable=False)
    master_annual = Column(Numeric(10, 2), nullable=False)
    vip_monthly = Column(Numeric(10, 2), nullable=False)
    vip_annual = Column(Numeric(10, 2), nullable=False)
    
    # Commission rates (as decimals: 0.15 = 15%)
    regular_commission = Column(Numeric(5, 4), nullable=False)
    master_commission = Column(Numeric(5, 4), nullable=False)
    vip_commission = Column(Numeric(5, 4), nullable=False)
    
    # Advertising pricing
    featured_cph = Column(Numeric(10, 2), nullable=False)  # Cost per hour
    search_cpc_min = Column(Numeric(10, 2), nullable=False)
    search_cpc_max = Column(Numeric(10, 2), nullable=False)
    map_cph = Column(Numeric(10, 2), nullable=False)
    boost_cpm = Column(Numeric(10, 2), nullable=False)
    
    # Monthly credits per tier (JSON for flexibility)
    master_credits = Column(JSON, nullable=False, default={
        "featured_hours": 4,
        "search_clicks": 200,
        "map_hours": 2,
        "boost_impressions": 5000
    })
    vip_credits = Column(JSON, nullable=False, default={
        "featured_hours": 12,
        "search_clicks": 1000,
        "map_hours": 8,
        "boost_impressions": 25000
    })
    
    # Plan features (JSON arrays of string keys for FE i18n)
    # Nullable for backward compatibility — code falls back to hardcoded keys when absent
    regular_features = Column(JSON, nullable=True, default=None)
    master_features = Column(JSON, nullable=True, default=None)
    vip_features = Column(JSON, nullable=True, default=None)
    
    # Tax configuration
    default_tax_rate = Column(Numeric(5, 4), default=Decimal("0.0000"))
    tax_included = Column(Boolean, default=False)
    
    # Validity
    effective_date = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    def __repr__(self):
        return f"<RegionPricing(region={self.region_code}, currency={self.currency})>"
