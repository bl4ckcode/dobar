# 🍻 BARZ Advertising Products Catalog

> **Version:** 1.0  
> **Last Updated:** January 7, 2026  
> **Status:** Product Definition  
> **Scope:** Universal (All Markets)

---

## 📋 Document Purpose

This document defines BARZ's **advertising products and features** - what we offer to bar/restaurant partners. Pricing, regulatory compliance, and technical implementation are maintained in separate documents for scalability.

**Related Documents:**
- [PRICING_BY_REGION.md](./PRICING_BY_REGION.md) - Country-specific pricing & regulations
- [ADVERTISING_BACKEND.md](./ADVERTISING_BACKEND.md) - Technical implementation

---

## 🎯 Product Philosophy

> *"Simplicity beats complexity. Predictability beats auctions."*

### Core Principles
1. **Transparent Pricing** - Bar owners know exactly what they pay
2. **Time-Based Control** - Pay for hours, not complicated bidding
3. **Location-First** - All ads are geo-targeted by default
4. **ROI Focused** - Every product designed for measurable returns

### BARZ Differentiation
Unlike food delivery platforms, BARZ targets **bars, breweries, and nightlife**:

| Factor | Food Delivery | BARZ Nightlife |
|--------|---------------|----------------|
| Decision Type | Planned | Impulse/spontaneous |
| Discovery | "What to eat" | "Where to go NOW" |
| Avg Ticket | $25-40 | $40-80 |
| Peak Hours | Lunch, Dinner | Happy Hour, Night |
| Event Impact | Low | High (sports, music) |

---

## 🛍️ Advertising Products

### Product 1: Featured Home Placement

**What:** Premium logo display in home screen's featured section

**User Experience:**
```
┌─────────────────────────────────────┐
│  🍻 Featured Near You               │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐   │
│  │ 🏪  │ │ 🍺  │ │ 🎸  │ │ 🍹  │   │
│  │Logo1│ │Logo2│ │Logo3│ │Logo4│   │
│  └─────┘ └─────┘ └─────┘ └─────┘   │
│  ← scroll →                         │
└─────────────────────────────────────┘
```

**Features:**
| Tier | Logo Size | Tagline | Promo Badge | Video |
|------|-----------|---------|-------------|-------|
| Regular | - | - | - | - |
| Master | Standard | ❌ | ❌ | ❌ |
| VIP | Large | ✅ 50 chars | ✅ | ✅ |

**Targeting Options:**
- Radius: 1km - 50km from venue
- Time: Specific hours/days
- User segments: New users, returning, etc.

**Pricing Model:** CPH (Cost per Hour)  
*See [PRICING_BY_REGION.md](./PRICING_BY_REGION.md) for rates*

---

### Product 2: Sponsored Search Results

**What:** Appear at top of search results when users search

**User Experience:**
```
┌─────────────────────────────────────┐
│  🔍 "craft beer near me"            │
│  ─────────────────────────────────  │
│  ⭐ SPONSORED                        │
│  ┌─────────────────────────────────┐│
│  │ 🍺 Craft Beer House  [Ad]       ││
│  │ ★★★★☆ 0.8km · Happy Hour Now   ││
│  └─────────────────────────────────┘│
│  ─────────────────────────────────  │
│  │ 🏪 Local Pub                    ││
│  │ ★★★★★ 1.2km                     ││
└─────────────────────────────────────┘
```

**Features:**
| Tier | Positions | Category Takeover | Keyword Block |
|------|-----------|-------------------|---------------|
| Regular | - | - | - |
| Master | Top 5 | ❌ | ❌ |
| VIP | Top 3 | ✅ (24h) | ✅ (12h) |

**Targeting Options:**
- Keywords: "craft beer", "happy hour", etc.
- Categories: Bars, Breweries, Cocktail lounges
- Location: Search area radius

**Pricing Models:**
- CPC (Cost per Click) - Pay when users tap
- CPH (Flat Hourly) - Guaranteed position

---

### Product 3: Map Spotlight

**What:** Enhanced visibility on map view

**User Experience:**
```
┌─────────────────────────────────────┐
│           🗺️ MAP VIEW               │
│                                     │
│      📍         ⭐📍 (pulsing)      │
│           📍              📍        │
│                                     │
│   📍           📍                   │
│         [You]                       │
│                                     │
│  ⭐ = Sponsored with animation      │
└─────────────────────────────────────┘
```

**Features:**
| Tier | Icon Size | Animation | Brand Color | Badge |
|------|-----------|-----------|-------------|-------|
| Regular | Standard | ❌ | ❌ | ❌ |
| Master | 1.5x | Pulse | ❌ | Distance |
| VIP | 2x | Custom | ✅ Ring | Hot Now + ETA |

**Targeting Options:**
- Map viewport (dynamic)
- User's current location radius

**Pricing Model:** CPH (Cost per Hour)

---

### Product 4: Promotion Boost

**What:** Amplify promotion visibility beyond organic reach

**User Experience:**
```
┌─────────────────────────────────────┐
│  🔥 Hot Promotions                  │
│  ─────────────────────────────────  │
│  ┌─────────────────────────────────┐│
│  │ 🍺 2x1 Happy Hour    [Boosted] ││
│  │ Craft Beer House · Ends 8pm    ││
│  │ 🔥 127 people interested        ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ 🎵 Live Jazz Tonight            ││
│  │ Blue Note Bar · 9pm             ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

**Features:**
| Tier | Organic Reach | Boost Available | Push Notify |
|------|---------------|-----------------|-------------|
| Regular | Followers only | ❌ | ❌ |
| Master | +Local area | ✅ | ❌ |
| VIP | +City wide | ✅ Priority | ✅ |

**Targeting Options:**
- Reach tiers: Local → District → City → Metro
- Interest targeting: Beer lovers, cocktail fans, etc.

**Pricing Model:** CPM (Cost per 1000 impressions)

---

### Product 5: Rich Media Banners

**What:** Custom images/animations in premium placements

**Placements:**
| Location | Format | Visibility |
|----------|--------|------------|
| Home Carousel | 1200x400 | High scroll position |
| Search Interstitial | 600x400 | Between results |
| Post-Order | 800x600 | Captive audience |
| Push Notification | 400x200 | Device notification |

**Features:**
| Tier | Static | Animated | Video | Push |
|------|--------|----------|-------|------|
| Regular | ❌ | ❌ | ❌ | ❌ |
| Master | ✅ | ❌ | ❌ | ❌ |
| VIP | ✅ | ✅ GIF/Lottie | ✅ 15s | ✅ |

**Pricing Model:** CPM + Minimum spend

---

### Product 6: Promotional Badges

**What:** Visual badges on venue listings

**Badge Types:**
| Badge | Icon | Trigger |
|-------|------|---------|
| Hot Deal | 🔥 | Active discount >20% |
| Flash Sale | ⚡ | Time-limited (<2h) |
| Happy Hour | 🍺 | During HH times |
| Live Music | 🎵 | Event scheduled |
| Sports | ⚽ | Game day |
| New | ✨ | First 30 days |
| Verified | ✓ | VIP tier |

**Features:**
| Tier | Auto Badges | Manual Toggle | Custom Badge |
|------|-------------|---------------|--------------|
| Regular | ✅ | ❌ | ❌ |
| Master | ✅ | ✅ 3 types | ❌ |
| VIP | ✅ | ✅ All | ✅ Request |

**Pricing Model:** Included in tier (no extra cost)

---

## 💎 Subscription Tiers

### Tier Comparison Matrix

| Feature | Regular (Free) | Master | VIP |
|---------|----------------|--------|-----|
| **Listing & Menu** | ✅ | ✅ | ✅ |
| **Order Receiving** | ✅ | ✅ | ✅ |
| **Basic Analytics** | ✅ | ✅ | ✅ |
| **Advanced Analytics** | ❌ | ✅ | ✅ |
| **Active Promotions** | 3 max | Unlimited | Unlimited |
| **Featured Placement** | ❌ | ✅ Credits | ✅ Credits+ |
| **Sponsored Search** | ❌ | ✅ Credits | ✅ Credits+ |
| **Map Spotlight** | ❌ | ✅ Credits | ✅ Credits+ |
| **Promo Boost** | ❌ | ✅ Buy | ✅ Credits |
| **Rich Media** | ❌ | Static only | Full |
| **Badges** | Auto only | + Manual | + Custom |
| **Verified Badge** | ❌ | ❌ | ✅ |
| **API Access** | ❌ | ❌ | ✅ |
| **Priority Support** | ❌ | Email | Phone + Chat |
| **Account Manager** | ❌ | ❌ | 50+ orders/day |

### Monthly Credits by Tier

| Product | Master Credits | VIP Credits |
|---------|----------------|-------------|
| Featured Home | 5 hours | 20 hours |
| Sponsored Search | 100 clicks | 500 clicks |
| Map Spotlight | 3 hours | 15 hours |
| Promo Boost | - | 5,000 impressions |

---

## 📊 Success Metrics (KPIs)

### For Bar Owners
| Metric | Description | Target |
|--------|-------------|--------|
| ROAS | Ad spend vs revenue generated | 4-6x |
| CTR | Click-through rate | 2-5% |
| Conversion | Clicks to orders | 5-10% |
| Visibility | Impressions delivered | As purchased |

### For BARZ
| Metric | Description | Target |
|--------|-------------|--------|
| Attach Rate | % partners buying ads | 30%+ |
| ARPU | Avg revenue per partner | $100+/mo |
| Churn | Partner cancellation | <5%/mo |
| NPS | Partner satisfaction | 50+ |

---

## 🎨 Creative Guidelines

### Logo Requirements
- Format: PNG, JPG, WebP
- Size: 400x400px minimum
- Background: Transparent preferred
- File size: <500KB

### Banner Requirements
| Placement | Dimensions | Format | Max Size |
|-----------|------------|--------|----------|
| Home Carousel | 1200x400 | PNG/JPG/GIF | 1MB |
| Search Interstitial | 600x400 | PNG/JPG | 500KB |
| Post-Order | 800x600 | PNG/JPG/MP4 | 2MB |

### Animation Guidelines
- Duration: 3-5 seconds loop
- Frame rate: 24-30 fps
- Formats: GIF, Lottie JSON, MP4 (VIP)

---

## 📝 Glossary

| Term | Definition |
|------|------------|
| CPH | Cost per Hour - pay for time-based visibility |
| CPC | Cost per Click - pay when users tap |
| CPM | Cost per Mille - pay per 1,000 impressions |
| ROAS | Return on Ad Spend - revenue / ad cost |
| CTR | Click-through Rate - clicks / impressions |
| Impression | One view of an ad by a user |
| Conversion | Desired action (order, visit, etc.) |

---

**Next:** See [PRICING_BY_REGION.md](./PRICING_BY_REGION.md) for country-specific pricing and regulatory requirements.
