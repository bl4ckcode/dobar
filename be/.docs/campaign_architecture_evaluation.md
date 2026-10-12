# Sprint 11 Architecture Evaluation — Campaigns & DPE Alignment Review

## Executive Summary

After thoroughly reviewing all Sprint 11 issues against the three business docs (DOBAR_ECOSYSTEM_VISION.md, ADVERTISING_PRODUCTS.md, ADVERTISING_BACKEND.md) and the BUSINESS_PLAN.md, **DOB-84 (DPE Budget Distribution Billing) needs a fundamental restructuring**. The FE and BE issues are well-aligned with the business vision. Below is the detailed analysis.

---

## 1. DPE Issue (DOB-84) — ❌ MISALIGNED

### Current Problematic Scope (what was proposed)
- Budget reservation per placement inside DPE
- Per-placement consumption tracking
- Pro-rated billing on pause/resume in DPE
- Budget rebalancing in DPE
- Per-placement budget status reports

### Why This Is Wrong

**DPE's Core Role (from DOBAR_ECOSYSTEM_VISION.md):**

> *"The universal middleware between payment intent and payment execution."*

DPE processes payments. It routes transactions to optimal gateways, handles failover, and manages settlement. It is **not** a campaign management system.

**ADVERTISING_BACKEND.md explicitly shows:**

```
┌───────────┐    ┌───────────┐    ┌───────────┐
│ Campaign  │    │   Ad      │    │ Analytics │
│ Manager   │    │  Serving  │    │  Engine   │
└─────┬─────┘    └─────┬─────┘    └─────┬─────┘
      │                │                │
      ▼                ▼                ▼
┌─────────────────────────────────────────────┐
│       PostgreSQL (Campaigns, Plans)         │
└─────────────────────────────────────────────┘
```

All campaign management — budget tracking, invoicing, billing — lives in **barz-backend's PostgreSQL**, not DPE.

The `BillingService` and `CampaignManager` classes in ADVERTISING_BACKEND.md handle:
- Budget deduction (CPC, CPM, Hourly)
- Invoice generation
- Credit refills
- All in **barz-backend**

### What DPE Should Actually Do For Campaigns

| Scenario | What Happens | DPE's Role |
|----------|-------------|------------|
| Bar pays Master subscription (R$ 199) | Standard payment transaction | Process the R$ 199 payment via PIX/card |
| Bar buys ad credits (R$ 500) | Standard payment transaction | Process the R$ 500 payment via PIX/card |
| Bar pays invoice at end of month | Standard payment transaction | Process the invoice payment |
| Budget is consumed by ad serving | CampaignManager deducts from budget | **Nothing** — this is backend logic |
| Campaign budget is exhausted | CampaignManager deactivates campaign | **Nothing** — this is backend logic |

**The pattern**: DPE processes individual payment transactions. Campaign budget management is 100% a backend concern.

### Corrected DPE Issue Scope

DOB-84 should be **replaced** with a corrected issue:

```
[DPE] No changes needed — DPE already handles payments for campaign subscriptions
```

**Rationale:**
- When a bar owner subscribes to Master/VIP → existing subscription payment flow already works
- When a bar owner tops up wallet for ads → existing payment charge flow works
- Campaign budget tracking is barz-backend's responsibility, already designed in ADVERTISING_BACKEND.md
- The only DPE work needed is if we introduce a new payment product (e.g., "Pay per campaign with card"), which would reuse existing charge endpoints

---

## 2. Backend Issues (DOB-82, DOB-83) — ✅ ALIGNED, minor adjustments needed

### DOB-82: Campaign API Extensions

**Alignment check: ✅**

The extended campaign model with `distribution`, `targeting`, `campaign_goal`, and `budget_optimizer_enabled` aligns with ADVERTISING_PRODUCTS.md's product catalog (Featured, Search, Map, Promo Boost, Banner).

**Adjustment needed:** Budget management should follow ADVERTISING_BACKEND.md's `CampaignManager` pattern:

| Current Proposal | Correct Approach |
|-----------------|------------------|
| DPE handles budget reservation | CampaignManager in barz-backend handles budget deductions |
| DPE tracks per-placement consumption | CampaignManager updates `budget_spent` in PostgreSQL |
| DPE does pro-rated billing on pause | CampaignManager calculates remaining budget, stores `paused_at` |

**New columns needed in `advertising_campaigns` table:**
- `campaign_goal` (enum: discovery, foot_traffic, promotion, full_presence)
- `distribution` (JSON: placement → percentage/budget mapping)
- `budget_spent_per_placement` (JSON: placement → amount_spent)
- `is_smart_distribution` (bool)
- `budget_optimizer_enabled` (bool)
- `paused_at` (timestamp, nullable — for pro-ration calculation)
- `estimated_performance` (JSON: daily_reach, clicks, impressions)

### DOB-83: Analytics Endpoint

**Alignment check: ✅**

ADVERTISING_PRODUCTS.md defines the KPIs bar owners care about:
- ROAS (4-6x target)
- CTR (2-5% target)
- Conversion (5-10%)
- Visibility (impressions delivered)

ADVERTISING_BACKEND.md already specifies:
```
GET /advertising/analytics → aggregated analytics
GET /advertising/analytics/campaign/{campaign_id} → per-campaign analytics
```

**Suggestion:** Merge DOB-83 into DOB-82 as a single "Campaign API Extensions" issue since the analytics endpoint is a natural extension of the campaign CRUD work.

---

## 3. Frontend Issues (DOB-77 through DOB-81) — ✅ WELL-ALIGNED

### DOB-77: Campaigns Page Refactor

**Alignment: ✅ Strong**

The refactored page with filters (active, paused, completed, drafts), search, and analytics overview directly serves the business need of giving bar owners **ROI visibility**.

From ADVERTISING_PRODUCTS.md:
> *"ROI Focused - Every product designed for measurable returns"*

The campaign cards showing impressions, clicks, CTR, and budget progress directly deliver on this principle.

### DOB-78: Multi-Step Campaign Wizard

**Alignment: ✅ Strong**

The 5-step wizard maps perfectly to ADVERTISING_PRODUCTS.md's product catalog:

| Wizard Step | Maps To |
|-------------|---------|
| Step 1: Goal (discovery, foot_traffic, promotion, full_presence) | Business philosophy — "Simplicity beats complexity" |
| Step 2: Budget & Distribution | Pricing models (CPH, CPC, CPM, Credits) across 5 products |
| Step 3: Creative & Details | Creative guidelines from ADVERTISING_PRODUCTS.md |
| Step 4: Targeting | Geo-targeting, time targeting, audience segments |
| Step 5: Review & Launch | Transparent pricing — "Predictability beats auctions" |

**Minor adjustment:** The wizard uses "daily budget" language but ADVERTISING_PRODUCTS.md uses CPH (Cost Per Hour) as primary. The wizard should support both:
- **Hourly**: "Show my ad for 20 hours this week" (CPH model — aligns with Featured, Map)
- **Daily**: "R$ 50/day budget" (CPC/CPM model — aligns with Search, Promo Boost)

### DOB-79: Data Model Extensions

**Alignment: ✅ Strong**

All proposed fields (`campaignGoal`, `distribution`, `extendedTargeting`, etc.) map directly to ADVERTISING_BACKEND.md's existing `CampaignCreate` schema and ADVERTISING_PRODUCTS.md's feature matrix.

### DOB-80: Smart Budget Distribution

**Alignment: ✅ Strong**

This feature embodies the product philosophy:
> *"Simplicity beats complexity"*

Automating budget distribution based on goals makes the complex ad products accessible to non-technical bar owners.

### DOB-81: Launch Flow

**Alignment: ✅ Strong**

The celebration screen and error states directly serve the business need of:
> *"Transparent Pricing — Bar owners know exactly what they pay"*

The receipt-style summary and performance estimates give bar owners confidence before they commit budget.

---

## 4. Cross-Repo Responsibility Matrix (Corrected)

| Concern | Repo | Correct? |
|---------|------|----------|
| Campaign CRUD | barz-be | ✅ |
| Campaign budget tracking | barz-be (CampaignManager) | ✅ |
| Per-placement distribution | barz-be (JSON column) | ✅ |
| Budget deductions (CPC/CPM/CPH) | barz-be (CampaignManager) | ✅ |
| Ad serving engine | barz-be (AdServer → MongoDB) | ✅ |
| Analytics aggregation | barz-be (Analytics Engine) | ✅ |
| Invoice generation | barz-be (BillingService) | ✅ |
| Payment processing (subscriptions, top-ups) | DPE | ✅ (existing flows) |
| Payment processing (per-campaign charges) | DPE | ✅ (reuses existing charge endpoints) |
| Campaign UI (list, wizard, analytics) | barz-fe | ✅ |
| Campaign data models (FE) | barz-fe | ✅ |

---

## 5. Recommended Changes to Sprint 11 Issues

### Action: Delete/Archive DOB-84, replace with no-op or very narrow scope

**DOB-84 should be marked as "Not Planned"** with this reasoning:

> *"Campaign budget management is a backend (barz-backend) concern, not a payment engine concern. DPE's role is processing individual payment transactions (subscriptions, top-ups, invoices). The budget distribution, consumption tracking, and pro-rated billing should be handled by barz-backend's CampaignManager as specified in ADVERTISING_BACKEND.md. When DPE is needed for a payment event (e.g., charging a card for a campaign), it reuses existing charge endpoints."*

### Action: Merge DOB-83 into DOB-82

The analytics summary endpoint is part of the campaign API extensions. It's tightly coupled and doesn't warrant a separate issue.

### Recommended Final Sprint 11 Backlog:

| Issue | Title | Repo | Priority |
|-------|-------|------|----------|
| DOB-77 | Campaigns Page Refactor — New layout + filters + analytics overview | barz-fe | Urgent |
| DOB-78 | Multi-Step Campaign Creation Wizard — 5-Step Flow | barz-fe | Urgent |
| DOB-79 | Campaign Data Model Extensions (FE) | barz-fe | High |
| DOB-80 | Smart Budget Distribution Engine | barz-fe | High |
| DOB-81 | Campaign Launch Flow + Success/Error states | barz-fe | High |
| DOB-82 | Campaign API Extensions (includes analytics endpoint) | barz-be | Urgent |
| — | DOB-84 REMOVED — budget tracking is barz-be concern | DPE | N/A |