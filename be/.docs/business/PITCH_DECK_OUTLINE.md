# DOBAR PITCH DECK OUTLINE

> **Version:** 1.0  
> **Date:** January 2026  
> **Purpose:** Investor Presentation Structure  
> **Tool Suggestion:** Gamma.app, Pitch.com, or Canva

---

## DECK STRUCTURE (12 Slides)

### Slide 1: Title
**Content:**
- DOBAR logo (centered)
- Tagline: "The Live Commerce Infrastructure for Bars & Events"
- Date / Contact info
- Category: B2B SaaS / Fintech / Marketplace

**Visual:** Clean, dark background with gradient. Logo prominent.

---

### Slide 2: The Problem
**Header:** "The Nightlife Payment Nightmare"

**Content (3 Pain Points):**

| Icon | Problem | Impact |
|------|---------|--------|
| ⏱️ | 30-45 min queues at peak times | Lost sales, frustrated customers |
| 💸 | 15-18% total fees (maquininha + platforms) | Margin erosion |
| 📱 | Fragmented, outdated POS systems | No unified experience |

**Visual:** Photo of crowded bar with long queue. Red X marks on pain points.

---

### Slide 3: The Solution
**Header:** "Dobar: Order & Pay from Your Phone"

**Content (3 Pillars):**

```
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│   DOBAR APP     │   │ PAYMENT ENGINE  │   │ DOBAR CONNECT   │
│   (Consumer)    │   │  (Middleware)   │   │   (Telecom)     │
│                 │   │                 │   │                 │
│ • Order & pay   │   │ • PIX, cards,   │   │ • Event infra   │
│ • QR pickup     │   │   wallets       │   │ • 100K+ users   │
│ • Real-time     │   │ • Multi-gateway │   │ • Low latency   │
└─────────────────┘   └─────────────────┘   └─────────────────┘
```

**Visual:** App mockup showing order flow. Clean, modern UI.

---

### Slide 4: How It Works
**Header:** "Seamless User Journey"

**Content (4 Steps):**

1. **Scan** - User scans QR at table/venue
2. **Browse** - See menu, promotions, availability
3. **Pay** - PIX, Apple Pay, Google Pay, Cards
4. **Pickup** - Receive notification, grab order

**Visual:** 4 phone mockups showing each step. Arrows connecting them.

---

### Slide 5: Market Opportunity
**Header:** "R$ 260B+ Market in Brazil Alone"

**Content:**

| Segment | Size | Annual GMV |
|---------|------|------------|
| Bars | 300K+ venues | R$ 50B+ |
| Restaurants | 600K+ venues | R$ 200B+ |
| Events | 5K+ annually | R$ 10B+ |

**Key Insight:** "Event commerce is growing 25% YoY. Mobile payments up 40% in 2025."

**Visual:** Brazil map with hotspots. Pie chart of market segments.

---

### Slide 6: Business Model
**Header:** "Three Revenue Streams"

**Content:**

| Stream | Description | % Revenue |
|--------|-------------|-----------|
| **Commissions** | 10-18% per transaction | 60% |
| **Subscriptions** | R$ 199-599/month | 25% |
| **Advertising** | Featured placement, promos | 15% |

**Unit Economics:**
- Avg GMV/venue: R$ 25K/month
- Avg Revenue/venue: R$ 3,849/month
- CAC: R$ 1,500 | LTV: R$ 50K+ | LTV:CAC: 33:1

**Visual:** Revenue waterfall chart. Clean icons for each stream.

---

### Slide 7: Why Now?
**Header:** "Perfect Storm of Opportunity"

**Content (4 Factors):**

1. **PIX Adoption** - 70% of Brazilians use PIX daily (instant, free for consumers)
2. **Post-COVID Behavior** - Contactless ordering is expected, not novel
3. **High Payment Fees** - Venue owners actively seeking alternatives
4. **Event Boom** - Record attendance at festivals post-pandemic

**Visual:** Timeline showing convergence of factors in 2025-2026.

---

### Slide 8: Traction
**Header:** "Early Momentum"

**Content:**

| Metric | Current | 6-Month Target |
|--------|---------|----------------|
| Active Venues | [X] | 100 |
| Monthly GMV | [X] | R$ 850K |
| Monthly Orders | [X] | 5,000 |
| NPS | [X] | 50+ |

**Milestones:**
- ✅ MVP launched
- ✅ Payment engine v1
- ✅ First paying customers
- 🔄 Event pilot in progress

**Visual:** Growth chart (even if early). Customer logos if available.

---

### Slide 9: Competitive Landscape
**Header:** "Built for Nightlife, Not Delivery"

**Content:**

| | iFood | Rappi | Goomer | DOBAR |
|--|-------|-------|--------|-------|
| Focus | Delivery | Multi | Restaurants | **Nightlife** |
| Take Rate | 25-30% | 25-30% | 10-15% | **10-18%** |
| Payment Engine | No | No | No | **Yes** |
| Event Scale | No | No | No | **Yes (100K)** |
| Real-time | No | Partial | No | **Yes** |

**Key Differentiator:** "We're building the Stripe for live events."

**Visual:** 2x2 matrix positioning Dobar in unique quadrant.

---

### Slide 10: Technology Moat
**Header:** "Built for Scale from Day 1"

**Content:**

```
┌────────────────────────────────────────────────────────────┐
│                   DOBAR ARCHITECTURE                        │
│                                                             │
│   ┌─────────┐    ┌─────────┐    ┌─────────┐               │
│   │ Flutter │    │ FastAPI │    │ Fly.io  │               │
│   │   App   │───▶│ Backend │───▶│  Edge   │               │
│   └─────────┘    └─────────┘    └─────────┘               │
│                       │                                     │
│           ┌───────────┼───────────┐                        │
│           ▼           ▼           ▼                        │
│   ┌─────────┐   ┌─────────┐   ┌─────────┐                 │
│   │PostgreSQL│   │ MongoDB │   │  Redis  │                 │
│   │(Transact)│   │(Realtime)│   │ (Cache) │                 │
│   └─────────┘   └─────────┘   └─────────┘                 │
│                                                             │
│   Key Metrics:                                              │
│   • <100ms API latency (edge deployment)                   │
│   • 99.9% uptime target                                    │
│   • Designed for 100K concurrent users                     │
└────────────────────────────────────────────────────────────┘
```

**Visual:** Architecture diagram. Tech stack logos.

---

### Slide 11: The Ask
**Header:** "Seed Round: R$ 1M"

**Content:**

| Use of Funds | Amount | Purpose |
|--------------|--------|---------|
| Engineering | R$ 600K | 3 FTE (12 months) |
| Infrastructure | R$ 120K | Scaling, reliability |
| Sales & Marketing | R$ 200K | Customer acquisition |
| Operations | R$ 80K | Support, legal, admin |

**Milestones This Round:**
- [ ] 100 active venues
- [ ] R$ 5M monthly GMV
- [ ] First major event partnership
- [ ] Payment engine v2 (multi-gateway)

**Visual:** Pie chart of fund allocation. Timeline of milestones.

---

### Slide 12: Team
**Header:** "Built by Engineers Who Love Nightlife"

**Content:**

| Role | Name | Background |
|------|------|------------|
| CEO/Founder | [Name] | [Background - business, vision] |
| CTO | [Name] | [Background - tech architecture] |
| Advisor | [Name] | [Industry expertise] |

**Hiring:**
- Full-stack developer (FastAPI/Flutter)
- Sales lead (B2B nightlife)
- Customer success

**Visual:** Professional headshots. LinkedIn icons.

---

### Slide 13: Contact (Appendix)
**Header:** "Let's Talk"

**Content:**
- Email: contato@dobar.app
- Website: https://dobar.app
- Demo: Available upon request

**Visual:** QR code linking to demo or calendar booking.

---

## APPENDIX SLIDES (Optional)

### A1: Financial Projections Detail
- Monthly breakdown for 2026-2027
- Scenario analysis (conservative/base/aggressive)

### A2: Product Roadmap
- Q1-Q4 2026 feature timeline
- Future products (Dobar Connect, API licensing)

### A3: Customer Testimonials
- Quotes from early venues
- Screenshots of positive feedback

### A4: Technical Deep Dive
- Scalability architecture
- Payment gateway integration details

---

## DESIGN GUIDELINES

### Color Palette
- Primary: Deep purple (#6B21A8)
- Secondary: Electric blue (#3B82F6)
- Accent: Vibrant orange (#F97316)
- Background: Dark gray (#1F2937)
- Text: White (#FFFFFF)

### Typography
- Headers: Inter Bold or Outfit
- Body: Inter Regular
- Code/Technical: JetBrains Mono

### Imagery
- High-quality bar/event photos
- App mockups (use Figma or screenshots)
- Icons from Lucide or Phosphor

### Tone
- Confident but not arrogant
- Data-driven with visuals
- Clear value proposition on every slide

---

## TOOLS FOR CREATION

| Tool | Best For | Cost |
|------|----------|------|
| **Gamma.app** | AI-generated slides from outline | Free tier |
| **Pitch.com** | Collaborative, modern templates | Free tier |
| **Canva Pro** | Custom design, brand kit | $13/mo |
| **Figma** | High-fidelity mockups | Free tier |
| **Beautiful.ai** | Smart formatting | $12/mo |

### Recommended Workflow:
1. Use this outline in **Gamma.app** to generate first draft
2. Export to **Figma** or **Canva** for polish
3. Create PDF for sharing, keep editable version

---

*This outline is ready for immediate use with AI presentation tools like Gamma.app*
