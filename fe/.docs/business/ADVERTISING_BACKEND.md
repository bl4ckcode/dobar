# 🛠️ BARZ Advertising Backend Implementation

> **Version:** 1.0  
> **Last Updated:** January 7, 2026  
> **Status:** Technical Specification  
> **Scope:** Universal (All Markets)

---

## 📋 Document Purpose

This document defines the **technical implementation** for BARZ's advertising system. Business logic and pricing are defined separately to allow independent updates.

**Related Documents:**
- [ADVERTISING_PRODUCTS.md](./ADVERTISING_PRODUCTS.md) - Product definitions
- [PRICING_BY_REGION.md](./PRICING_BY_REGION.md) - Country-specific pricing

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    BARZ ADVERTISING SYSTEM                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Partner   │  │   Consumer  │  │   Admin     │         │
│  │  Dashboard  │  │     App     │  │   Panel     │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
│         │                │                │                 │
│         ▼                ▼                ▼                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    API GATEWAY                       │   │
│  │              (FastAPI + Authentication)              │   │
│  └─────────────────────────────────────────────────────┘   │
│         │                │                │                 │
│         ▼                ▼                ▼                 │
│  ┌───────────┐    ┌───────────┐    ┌───────────┐           │
│  │ Campaign  │    │   Ad      │    │ Analytics │           │
│  │ Manager   │    │  Serving  │    │  Engine   │           │
│  └─────┬─────┘    └─────┬─────┘    └─────┬─────┘           │
│        │                │                │                  │
│        ▼                ▼                ▼                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              PostgreSQL (Campaigns, Plans)          │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              MongoDB (Geo-targeting, Real-time)     │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Redis (Caching, Rate Limiting)         │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 Database Models

### PostgreSQL Models

```python
# app/advertising/models.py

from sqlalchemy import Column, Integer, String, Numeric, DateTime, Boolean, ForeignKey, Enum, JSON
from sqlalchemy.orm import relationship
from app.database import Base
import enum
from datetime import datetime

# Enums
class SubscriptionTier(enum.Enum):
    REGULAR = "regular"
    MASTER = "master"
    VIP = "vip"

class SubscriptionStatus(enum.Enum):
    ACTIVE = "active"
    PAUSED = "paused"
    CANCELLED = "cancelled"
    EXPIRED = "expired"

class CampaignType(enum.Enum):
    FEATURED = "featured"
    SEARCH = "search"
    MAP = "map"
    PROMO_BOOST = "promo_boost"
    BANNER = "banner"

class CampaignStatus(enum.Enum):
    DRAFT = "draft"
    SCHEDULED = "scheduled"
    ACTIVE = "active"
    PAUSED = "paused"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

class BudgetType(enum.Enum):
    HOURLY = "hourly"       # CPH - Cost per Hour
    CPC = "cpc"             # Cost per Click
    CPM = "cpm"             # Cost per 1000 impressions
    FIXED = "fixed"         # One-time payment
    CREDITS = "credits"     # Use subscription credits

class AdAction(enum.Enum):
    IMPRESSION = "impression"
    CLICK = "click"
    CONVERSION = "conversion"

class InvoiceStatus(enum.Enum):
    PENDING = "pending"
    PAID = "paid"
    OVERDUE = "overdue"
    REFUNDED = "refunded"


# Models
class AdvertisingSubscription(Base):
    """Bar's advertising subscription plan"""
    __tablename__ = "advertising_subscriptions"
    
    id = Column(Integer, primary_key=True, index=True)
    bar_id = Column(Integer, ForeignKey("bars.id"), unique=True, nullable=False)
    
    tier = Column(Enum(SubscriptionTier), default=SubscriptionTier.REGULAR)
    status = Column(Enum(SubscriptionStatus), default=SubscriptionStatus.ACTIVE)
    
    # Pricing (region-specific)
    region_code = Column(String(2), nullable=False)  # "BR", "US", etc.
    monthly_fee = Column(Numeric(10, 2), default=0)
    commission_rate = Column(Numeric(5, 4), nullable=False)  # 0.1500 = 15%
    
    # Credits remaining (JSON for flexibility)
    credits = Column(JSON, default={
        "featured_hours": 0,
        "search_clicks": 0,
        "map_hours": 0,
        "boost_impressions": 0
    })
    
    # Billing
    billing_cycle_start = Column(DateTime, nullable=False)
    next_billing_date = Column(DateTime)
    payment_method_id = Column(String(100))  # Stripe/Gateway reference
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    bar = relationship("Bar", back_populates="advertising_subscription")
    campaigns = relationship("AdvertisingCampaign", back_populates="subscription")


class AdvertisingCampaign(Base):
    """Individual advertising campaign"""
    __tablename__ = "advertising_campaigns"
    
    id = Column(Integer, primary_key=True, index=True)
    subscription_id = Column(Integer, ForeignKey("advertising_subscriptions.id"), nullable=False)
    bar_id = Column(Integer, ForeignKey("bars.id"), nullable=False)
    
    # Campaign details
    name = Column(String(100), nullable=False)
    campaign_type = Column(Enum(CampaignType), nullable=False)
    status = Column(Enum(CampaignStatus), default=CampaignStatus.DRAFT)
    
    # Budget
    budget_type = Column(Enum(BudgetType), nullable=False)
    budget_amount = Column(Numeric(10, 2), nullable=False)
    budget_spent = Column(Numeric(10, 2), default=0)
    
    # Schedule
    start_time = Column(DateTime, nullable=False)
    end_time = Column(DateTime)
    
    # Targeting (JSON for flexibility)
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
    
    # Performance
    impressions = Column(Integer, default=0)
    clicks = Column(Integer, default=0)
    conversions = Column(Integer, default=0)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    subscription = relationship("AdvertisingSubscription", back_populates="campaigns")
    bar = relationship("Bar")
    impressions_log = relationship("AdvertisingImpression", back_populates="campaign")


class AdvertisingImpression(Base):
    """Individual ad impression/click/conversion event"""
    __tablename__ = "advertising_impressions"
    
    id = Column(Integer, primary_key=True, index=True)
    campaign_id = Column(Integer, ForeignKey("advertising_campaigns.id"), nullable=False)
    
    # Event
    action = Column(Enum(AdAction), nullable=False)
    placement = Column(String(50), nullable=False)  # "home", "search", "map"
    
    # User context (optional for anonymous)
    user_id = Column(Integer, ForeignKey("user_profiles.id"), nullable=True)
    session_id = Column(String(100))  # For anonymous tracking
    
    # Location
    latitude = Column(Numeric(9, 6))
    longitude = Column(Numeric(9, 6))
    
    # Timestamp
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    
    # Relationships
    campaign = relationship("AdvertisingCampaign", back_populates="impressions_log")


class AdvertisingInvoice(Base):
    """Billing invoice for advertising spend"""
    __tablename__ = "advertising_invoices"
    
    id = Column(Integer, primary_key=True, index=True)
    bar_id = Column(Integer, ForeignKey("bars.id"), nullable=False)
    
    # Period
    period_start = Column(DateTime, nullable=False)
    period_end = Column(DateTime, nullable=False)
    
    # Amounts
    subscription_amount = Column(Numeric(10, 2), default=0)
    advertising_amount = Column(Numeric(10, 2), default=0)
    tax_amount = Column(Numeric(10, 2), default=0)
    total_amount = Column(Numeric(10, 2), nullable=False)
    currency = Column(String(3), nullable=False)  # "BRL", "USD"
    
    # Status
    status = Column(Enum(InvoiceStatus), default=InvoiceStatus.PENDING)
    
    # Payment
    payment_gateway_ref = Column(String(100))
    paid_at = Column(DateTime)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    bar = relationship("Bar")


class RegionPricing(Base):
    """Region-specific pricing configuration"""
    __tablename__ = "region_pricing"
    
    id = Column(Integer, primary_key=True, index=True)
    region_code = Column(String(2), unique=True, nullable=False)  # "BR", "US"
    currency = Column(String(3), nullable=False)
    
    # Subscriptions
    master_monthly = Column(Numeric(10, 2), nullable=False)
    master_annual = Column(Numeric(10, 2), nullable=False)
    vip_monthly = Column(Numeric(10, 2), nullable=False)
    vip_annual = Column(Numeric(10, 2), nullable=False)
    
    # Commissions (as decimals: 0.15 = 15%)
    regular_commission = Column(Numeric(5, 4), nullable=False)
    master_commission = Column(Numeric(5, 4), nullable=False)
    vip_commission = Column(Numeric(5, 4), nullable=False)
    
    # Advertising pricing
    featured_cph = Column(Numeric(10, 2), nullable=False)  # Per hour
    search_cpc_min = Column(Numeric(10, 2), nullable=False)
    search_cpc_max = Column(Numeric(10, 2), nullable=False)
    map_cph = Column(Numeric(10, 2), nullable=False)
    boost_cpm = Column(Numeric(10, 2), nullable=False)
    
    # Credits per tier
    master_credits = Column(JSON, nullable=False)
    vip_credits = Column(JSON, nullable=False)
    
    # Tax
    default_tax_rate = Column(Numeric(5, 4), default=0)
    tax_included = Column(Boolean, default=False)
    
    # Metadata
    effective_date = Column(DateTime, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
```

### MongoDB Collections

```javascript
// Geo-indexed active campaigns for fast ad serving
db.active_campaigns = {
    campaign_id: ObjectId,
    bar_id: Number,
    campaign_type: String,  // "featured", "search", "map"
    status: String,
    
    // Geospatial targeting
    location: {
        type: "Point",
        coordinates: [longitude, latitude]
    },
    radius_meters: Number,
    
    // Time targeting
    active_days: [String],  // ["mon", "tue", ...]
    active_hours: { start: Number, end: Number },
    
    // Budget tracking
    budget_remaining: Number,
    
    // Creative
    logo_url: String,
    tagline: String,
    
    // Metadata
    priority: Number,  // VIP gets higher priority
    expires_at: Date
}

// Index for fast geo-queries
db.active_campaigns.createIndex({ location: "2dsphere" })
db.active_campaigns.createIndex({ campaign_type: 1, status: 1 })
db.active_campaigns.createIndex({ expires_at: 1 }, { expireAfterSeconds: 0 })
```

---

## 🔌 API Endpoints

### Router Structure

```python
# app/advertising/routes.py

from fastapi import APIRouter

advertising_router = APIRouter(prefix="/advertising", tags=["Advertising"])
```

### Subscription Endpoints

```python
# GET /advertising/plans
@advertising_router.get("/plans")
async def get_available_plans(region_code: str = Query(...)):
    """Get available subscription plans for a region"""
    # Returns: { regular: {...}, master: {...}, vip: {...} }

# GET /advertising/my-plan
@advertising_router.get("/my-plan")
async def get_my_plan(bar_id: int = Depends(get_current_bar)):
    """Get current bar's subscription details"""
    # Returns: { tier, credits, next_billing, ... }

# POST /advertising/subscribe
@advertising_router.post("/subscribe")
async def subscribe_to_plan(
    tier: SubscriptionTier,
    payment_method_id: str,
    bar_id: int = Depends(get_current_bar)
):
    """Subscribe to a plan or upgrade"""
    # 1. Validate payment method
    # 2. Create/update subscription
    # 3. Charge via payment gateway
    # 4. Provision credits

# PUT /advertising/plan
@advertising_router.put("/plan")
async def change_plan(
    new_tier: SubscriptionTier,
    bar_id: int = Depends(get_current_bar)
):
    """Upgrade or downgrade plan"""
    # Prorated billing logic

# DELETE /advertising/plan
@advertising_router.delete("/plan")
async def cancel_plan(bar_id: int = Depends(get_current_bar)):
    """Cancel subscription (keeps until period end)"""

# GET /advertising/credits
@advertising_router.get("/credits")
async def get_credits(bar_id: int = Depends(get_current_bar)):
    """Check remaining advertising credits"""
```

### Campaign Endpoints

```python
# GET /advertising/campaigns
@advertising_router.get("/campaigns")
async def list_campaigns(
    status: Optional[CampaignStatus] = None,
    bar_id: int = Depends(get_current_bar)
):
    """List all campaigns for the bar"""

# POST /advertising/campaigns
@advertising_router.post("/campaigns")
async def create_campaign(
    campaign: CampaignCreate,
    bar_id: int = Depends(get_current_bar)
):
    """Create a new advertising campaign"""
    # 1. Validate budget (credits or payment)
    # 2. Create campaign record
    # 3. If scheduled, add to MongoDB for serving

# GET /advertising/campaigns/{campaign_id}
@advertising_router.get("/campaigns/{campaign_id}")
async def get_campaign(
    campaign_id: int,
    bar_id: int = Depends(get_current_bar)
):
    """Get campaign details with performance metrics"""

# PUT /advertising/campaigns/{campaign_id}
@advertising_router.put("/campaigns/{campaign_id}")
async def update_campaign(
    campaign_id: int,
    updates: CampaignUpdate,
    bar_id: int = Depends(get_current_bar)
):
    """Update campaign settings"""

# PUT /advertising/campaigns/{campaign_id}/pause
@advertising_router.put("/campaigns/{campaign_id}/pause")
async def pause_campaign(
    campaign_id: int,
    bar_id: int = Depends(get_current_bar)
):
    """Pause an active campaign"""

# PUT /advertising/campaigns/{campaign_id}/resume
@advertising_router.put("/campaigns/{campaign_id}/resume")
async def resume_campaign(
    campaign_id: int,
    bar_id: int = Depends(get_current_bar)
):
    """Resume a paused campaign"""

# DELETE /advertising/campaigns/{campaign_id}
@advertising_router.delete("/campaigns/{campaign_id}")
async def cancel_campaign(
    campaign_id: int,
    bar_id: int = Depends(get_current_bar)
):
    """Cancel campaign and refund unused budget"""
```

### Ad Serving Endpoints (Internal)

```python
# GET /advertising/serve/featured
@advertising_router.get("/serve/featured", include_in_schema=False)
async def serve_featured_ads(
    latitude: float,
    longitude: float,
    limit: int = 10
):
    """Get featured ads for home screen (called by consumer app)"""
    # 1. Query MongoDB for active featured campaigns near location
    # 2. Filter by time targeting
    # 3. Sort by priority (VIP first)
    # 4. Log impressions
    # Returns: [{ bar_id, logo_url, tagline, ... }]

# GET /advertising/serve/search
@advertising_router.get("/serve/search", include_in_schema=False)
async def serve_search_ads(
    latitude: float,
    longitude: float,
    query: Optional[str] = None,
    category: Optional[str] = None,
    limit: int = 3
):
    """Get sponsored search results"""

# GET /advertising/serve/map
@advertising_router.get("/serve/map", include_in_schema=False)
async def serve_map_ads(
    latitude: float,
    longitude: float,
    zoom_level: int,
    limit: int = 5
):
    """Get map spotlight ads"""

# POST /advertising/track
@advertising_router.post("/track", include_in_schema=False)
async def track_ad_event(event: AdEvent):
    """Track impression, click, or conversion"""
    # 1. Log to advertising_impressions
    # 2. Update campaign counters
    # 3. Deduct from budget if CPC
```

### Analytics Endpoints

```python
# GET /advertising/analytics
@advertising_router.get("/analytics")
async def get_analytics_dashboard(
    start_date: date,
    end_date: date,
    bar_id: int = Depends(get_current_bar)
):
    """Get aggregated analytics for all campaigns"""
    # Returns: { impressions, clicks, conversions, spend, roas, ... }

# GET /advertising/analytics/campaign/{campaign_id}
@advertising_router.get("/analytics/campaign/{campaign_id}")
async def get_campaign_analytics(
    campaign_id: int,
    bar_id: int = Depends(get_current_bar)
):
    """Get detailed analytics for a specific campaign"""

# GET /advertising/invoices
@advertising_router.get("/invoices")
async def get_invoices(
    bar_id: int = Depends(get_current_bar)
):
    """Get billing history"""
```

---

## ⚙️ Core Services

### Campaign Manager

```python
# app/advertising/services/campaign_manager.py

class CampaignManager:
    """Manages campaign lifecycle and budget"""
    
    async def create_campaign(self, bar_id: int, data: CampaignCreate) -> Campaign:
        """Create and optionally activate a campaign"""
        # 1. Validate bar has active subscription
        # 2. Validate budget source (credits or payment)
        # 3. Create campaign in PostgreSQL
        # 4. If start_time is now, activate in MongoDB
        
    async def activate_campaign(self, campaign_id: int):
        """Move campaign to active status"""
        # 1. Update PostgreSQL status
        # 2. Insert into MongoDB active_campaigns
        # 3. Schedule deactivation if end_time set
        
    async def deactivate_campaign(self, campaign_id: int):
        """Stop serving campaign"""
        # 1. Remove from MongoDB
        # 2. Update PostgreSQL status
        
    async def process_budget(self, campaign_id: int, action: AdAction):
        """Deduct from budget based on pricing model"""
        # For CPC: Deduct on click
        # For CPM: Deduct on every 1000 impressions
        # For Hourly: Scheduled deduction
        # Check budget exhaustion and deactivate if needed
```

### Ad Serving Engine

```python
# app/advertising/services/ad_server.py

class AdServer:
    """High-performance ad serving"""
    
    async def get_featured_ads(
        self,
        lat: float,
        lon: float,
        limit: int = 10
    ) -> List[FeaturedAd]:
        """Get featured ads for home screen"""
        # 1. Query MongoDB with geo filter
        geo_query = {
            "campaign_type": "featured",
            "status": "active",
            "location": {
                "$near": {
                    "$geometry": {"type": "Point", "coordinates": [lon, lat]},
                    "$maxDistance": 50000  # 50km max
                }
            }
        }
        
        # 2. Filter by time (current day/hour)
        # 3. Sort by priority (VIP > Master)
        # 4. Return top N
        
    async def log_impression(self, campaign_id: int, placement: str, user_id: int = None):
        """Log ad impression asynchronously"""
        # Use background task for performance
```

### Billing Service

```python
# app/advertising/services/billing.py

class BillingService:
    """Handles subscription billing and invoicing"""
    
    async def process_subscription(self, bar_id: int, tier: SubscriptionTier):
        """Charge for subscription via payment gateway"""
        # 1. Get pricing for region
        # 2. Create payment intent
        # 3. Process payment
        # 4. Update subscription
        # 5. Provision credits
        
    async def refill_credits(self, subscription_id: int):
        """Monthly credit refill for paid tiers"""
        # Called by scheduler at billing_cycle_start
        
    async def generate_invoice(self, bar_id: int, period_start: date, period_end: date):
        """Generate monthly invoice"""
        # 1. Sum subscription charges
        # 2. Sum advertising spend
        # 3. Apply taxes
        # 4. Create invoice record
```

---

## 📡 Event Processing

### Background Tasks

```python
# app/advertising/tasks.py

from celery import Celery

celery_app = Celery("advertising")

@celery_app.task
def process_hourly_campaigns():
    """Deduct hourly budget from active CPH campaigns"""
    # Run every hour
    # 1. Get all active hourly campaigns
    # 2. Deduct 1 hour from budget
    # 3. Deactivate if budget exhausted
    
@celery_app.task
def activate_scheduled_campaigns():
    """Activate campaigns that are due to start"""
    # Run every minute
    # 1. Query campaigns with status=scheduled and start_time <= now
    # 2. Activate each
    
@celery_app.task
def expire_campaigns():
    """Deactivate campaigns past end_time"""
    # Run every minute
    
@celery_app.task
def monthly_billing():
    """Process monthly subscription renewals"""
    # Run on 1st of each month
    # 1. Find subscriptions due for renewal
    # 2. Charge via payment gateway
    # 3. Refill credits
    # 4. Generate invoices
```

---

## 🔒 Security & Rate Limiting

### Authentication

```python
# Bar owners must be authenticated
async def get_current_bar(token: str = Depends(oauth2_scheme)) -> int:
    """Validate JWT and return bar_id"""
    # Uses existing auth middleware
```

### Rate Limiting

```python
# Prevent abuse of ad serving endpoints
@advertising_router.get("/serve/featured")
@limiter.limit("100/minute")  # Per IP
async def serve_featured_ads(...):
    pass
```

### Fraud Prevention

```python
# app/advertising/services/fraud_detection.py

class FraudDetector:
    """Detect and prevent click fraud"""
    
    async def validate_click(self, campaign_id: int, user_id: int, ip: str) -> bool:
        """Check if click is legitimate"""
        # 1. Check for duplicate clicks (same user/IP in short window)
        # 2. Check for suspicious patterns (bot behavior)
        # 3. Check for invalid geo (click from different country)
        
    async def flag_suspicious_activity(self, campaign_id: int, reason: str):
        """Flag campaign for review"""
```

---

## 📦 Deployment

### Database Migrations

```python
# migrations/versions/advertising_tables.py

def upgrade():
    op.create_table('advertising_subscriptions', ...)
    op.create_table('advertising_campaigns', ...)
    op.create_table('advertising_impressions', ...)
    op.create_table('advertising_invoices', ...)
    op.create_table('region_pricing', ...)
    
    # Seed default region pricing
    op.execute("""
        INSERT INTO region_pricing (region_code, currency, ...) VALUES
        ('BR', 'BRL', ...),
        ('US', 'USD', ...),
        ...
    """)

def downgrade():
    op.drop_table('region_pricing')
    op.drop_table('advertising_invoices')
    op.drop_table('advertising_impressions')
    op.drop_table('advertising_campaigns')
    op.drop_table('advertising_subscriptions')
```

### Environment Variables

```bash
# .env additions for advertising
ADVERTISING_ENABLED=true
ADVERTISING_CACHE_TTL=300  # 5 minutes
ADVERTISING_MAX_CAMPAIGNS_PER_BAR=50
ADVERTISING_FRAUD_DETECTION=true
```

---

## 🧪 Testing

### Unit Tests

```python
# tests/test_advertising.py

class TestCampaignManager:
    async def test_create_campaign_with_credits(self):
        """Test creating campaign using subscription credits"""
        
    async def test_create_campaign_without_subscription(self):
        """Test that regular tier cannot create campaigns"""
        
    async def test_budget_exhaustion(self):
        """Test campaign deactivates when budget runs out"""

class TestAdServer:
    async def test_geo_filtering(self):
        """Test ads only served within radius"""
        
    async def test_time_filtering(self):
        """Test ads only served during active hours"""
        
    async def test_priority_ordering(self):
        """Test VIP ads appear before Master ads"""
```

---

## 📊 Monitoring

### Metrics to Track

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| Ad Serve Latency | Time to serve ads | >100ms |
| Impression Rate | Impressions/minute | <100 (low traffic) |
| Click Fraud Rate | Flagged clicks % | >5% |
| Budget Errors | Failed deductions | Any |
| Payment Failures | Failed charges | >2% |

### Logging

```python
import structlog

logger = structlog.get_logger("advertising")

# Log all significant events
logger.info("campaign_created", campaign_id=123, bar_id=456, type="featured")
logger.info("ad_served", campaign_id=123, placement="home", lat=..., lon=...)
logger.warn("budget_exhausted", campaign_id=123)
logger.error("payment_failed", bar_id=456, error=str(e))
```

---

## 🚀 Rollout Checklist

### Phase 1: Foundation
- [ ] Database models created and migrated
- [ ] Subscription endpoints implemented
- [ ] Region pricing seeded for Brazil
- [ ] Basic partner dashboard

### Phase 2: Core Ads
- [ ] Campaign CRUD endpoints
- [ ] Featured ad serving
- [ ] Search ad serving
- [ ] Impression tracking
- [ ] Basic analytics

### Phase 3: Advanced
- [ ] Map spotlight
- [ ] Promotion boost
- [ ] Rich media banners
- [ ] Fraud detection
- [ ] Advanced analytics

### Phase 4: Scale
- [ ] Caching layer (Redis)
- [ ] Background job processing (Celery)
- [ ] Real-time analytics
- [ ] A/B testing framework

---

**Document Prepared By:** BARZ Engineering Team  
**Architecture Review:** [Pending]  
**Security Review:** [Pending]
