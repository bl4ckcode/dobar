# Campaign Creation Strategy — Dobar/Barz Business Advertising

## Objective
Design a multi-step campaign creation workflow for bar owners that mirrors big tech ad platforms (Meta Ads Manager, Google Ads, TikTok Ads Manager) — but adapted for the nightlife/bar ecosystem. The goal is to make it intuitive, premium, and powerful while respecting the user's limited time and attention.

---

## References & Inspiration

### Big Tech Campaign Flows Analyzed:

| Platform | Flow Pattern | Key Takeaway |
|----------|-------------|--------------|
| **Meta Ads Manager** | Objective → Audience → Budget/Duration → Creative → Review | Starts with a clear objective (what do you want to achieve) |
| **Google Ads** | Goal → Campaign Type → Budget → Targeting → Ad Creatives | Clear separation between campaign type and budget allocation |
| **TikTok Ads Manager** | Objective → Budget & Schedule → Targeting → Creative → Review | Strong focus on creative preview in the last step |
| **LinkedIn Campaign Manager** | Objective → Audience → Budget → Format → Review | Good at showing cost estimates per step |
| **Apple Search Ads** | Budget → Keywords → Creative → Review | Simplest flow, great for quick setup |

### The Common Pattern (Adapted):
```
Step 1: Define Objective / Placement → What am I advertising?
Step 2: Budget Allocation → How much & where?
Step 3: Schedule → When does it run?
Step 4: Creative & Targeting → What does it look like & who sees it?
Step 5: Review & Launch → Final confirmation before launch
```

---

## Campaign Placements & Pricing Model

Based on the user's requirements, the following **campaign placements** are available:

### 1. **Banner Ads**
- **Where**: Banners across the app (home carousel, category screens, promotional sections)
- **What it does**: Shows your bar's banner image in premium rotation slots throughout the client app
- **Cost model**: CPM (Cost Per Mille — per 1,000 impressions) or CPD (Cost Per Day)
- **Suggested min budget**: R$ 30/day

### 2. **Search Boost**
- **Where**: Search results in the client app
- **What it does**: Your bar appears as the first or among the first results when users search for bars, drinks, or categories
- **Cost model**: CPC (Cost Per Click) — you pay when a user taps on your bar from search
- **Suggested min budget**: R$ 20/day
- **Best for**: Bars in competitive areas with many nearby venues

### 3. **Map Pin Highlight**
- **Where**: The 'Find' (Google Maps-like) tab
- **What it does**: Your bar's pin on the map gets highlighted with a gold glow, larger size, or a special badge — making it stand out among nearby pins
- **Cost model**: CPM or flat daily rate
- **Suggested min budget**: R$ 25/day
- **Best for**: Bars wanting foot traffic from map browsing

### 4. **Featured Bar (Home Carousel)**
- **Where**: Home screen featured carousel (the "hot spots" or "trending now" section)
- **What it does**: Your bar appears in the featured carousel as "hot", "trending", or "recommended"
- **Cost model**: CPC or CPM
- **Suggested min budget**: R$ 40/day
- **Best for**: New bars wanting discovery, or established bars launching promotions

### 5. **Promo Boost (Hottest Drinks / Trending)**
- **Where**: Trending section, promotions tab, "Hottest Drinks" sections
- **What it does**: Boosts specific promotions or drink items to appear as "trending" or "hot right now"
- **Cost model**: CPC
- **Suggested min budget**: R$ 15/day
- **Best for**: Bars running happy hours or promoting specific cocktail/drink items

---

## Budget Distribution Model (The Core Innovation)

Inspired by **Google Ads' budget distribution** across campaigns and **Meta's Ad Set budget allocation**, the Dobar Campaign Budget Distribution allows business owners to:

1. **Set a Total Campaign Budget** (e.g., R$ 500 for 7 days)
2. **Distribute across placements** using sliders or percentage inputs
3. **See real-time cost estimates** per placement (estimated impressions, clicks, reach)
4. **Get smart recommendations** based on their bar type and goals

### Smart Budget Distribution Example:

```
Total Budget: R$ 500/week

Placement Distribution:
├─ Featured Bar (Home): 40% → R$ 200/week → ~2,500 impressions
├─ Search Boost:        25% → R$ 125/week → ~180 clicks
├─ Map Pin Highlight:   20% → R$ 100/week → ~3,000 map views
├─ Promo Boost:         15% → R$  75/week → ~110 clicks
```

### The "Smart Budget" Feature:
- When users first land on the budget step, show a **"Smart Distribution"** button
- This auto-calculates the best distribution based on:
  - The bar's category (pub vs. club vs. lounge)
  - The bar's location density (competitive vs. low competition)
  - The user's selected objective (discovery vs. foot traffic vs. promotion)
- Users can override and customize manually

---

## Multi-Step Workflow Design

### Step-by-Step Flow:

#### **Step 1: Campaign Goal & Name** (What's the purpose?)
- Show 3-4 clear objective cards:
  1. **"Get Discovered"** — New bar, want people to know I exist → recommends Featured Bar + Map Pin Highlight
  2. **"Attract More Customers"** — Want to increase foot traffic → recommends Search Boost + Map Pin Highlight
  3. **"Promote a Special Offer"** — Running happy hour/today's special → recommends Promo Boost + Banner
  4. **"Full Presence"** — All of the above → recommends balanced distribution across all
- Campaign name field (pre-filled: "{Bar Name} - {Objective} {Date}")
- Visual: Big icon cards like onboarding's role selection

#### **Step 2: Budget & Distribution** (How much & where?)
- **Top section**: Total budget input (large, prominent, numeric only)
- **Duration**: Start date + End date pickers
- **Distribution section**:
  - Each placement as a list item with:
    - Toggle switch (enable/disable)
    - Quick stat: estimated reach/impressions based on current allocation
    - Percentage slider or + / - buttons
    - Cost breakdown row: estimated daily spend, total period spend
    - "Why this?" info tooltip explaining each placement
  - **Smart Budget button** (gold ghost button)
  - **Visual budget chart** (animated bar chart showing distribution)
  - **Total must equal 100%** validation (show warning if not)

#### **Step 3: Creative & Details** (What does it look like?)
- **Banner Image** — Image upload (if banner placement selected)
  - Thumbnail preview
  - Tap to upload (camera/gallery options)
  - Size recommendations: 1200x628px
- **Tagline / Call-to-Action** — Short text, max 60 chars
  - Character counter
  - Preview card showing how it looks
  - CTA button options: "Visite Agora", "Peça Já", "Confira o Cardápio", etc.
- **Bar Specifics** — Which promotion/drink to highlight (optional)
  - Dropdown of recent menu items
  - Quick "Promote Happy Hour" toggle
- If **no banner placement** selected: simplify to tagline + CTA only

#### **Step 4: Targeting** (Who sees it?)
- **Location Radius** — Slider: 1km to 50km around the bar
  - Visual: Small map preview with radius circle (placeholder)
- **Target Audience** — Optional filters:
  - Age range (optional)
  - Peak hours only (Weekend nights, Happy Hour times, etc.)
- **Budget Optimizer** — Toggle: "Optimize budget for best times" (auto-schedule for peak hours)

#### **Step 5: Review & Launch** (Final check)
- **Campaign Summary Card** (like a receipt):
  - Campaign name
  - Duration
  - Total budget
  - Distribution breakdown (placement → percentage → estimated reach)
  - Creative preview (if applicable)
  - Targeting summary
- **Two CTAs**:
  - **"Launch Campaign"** — Gold primary, shows loading → success animation
  - **"Save as Draft"** — Ghost button, saves without launching
- **Estimated Performance** section:
  - Estimated reach per day
  - Estimated clicks
  - Estimated impressions
  *Small disclaimer: "Estimates based on historical performance. Actual results may vary."

---

## Visual Design Language

### Design Tokens (Same as existing Dobar system):
```
Background:      #0A0A0A (barzDark)
Card Surfaces:   #121212 (barzDarkLight), #1A1A1A (barzDarkCard)
Gold Accent:     #FFDE59 (barzGold)
Gold Grad:       #FFFFDF73 → #FFFFC000
Error:           #FF4B4B (errorRed)
Success:         #00B37E (pixGreen)
Text Primary:    #FFFFFF
Text Secondary:  #B0B0B0
Font:            Space Grotesk (headings), system (body)
Icons:           Lucide icon library
```

### Step Indicator Design:
- **Horizontal progress bar** at the top showing 5 steps
- Each step is a dot/circle with step number
- Current step: filled gold circle with white number
- Completed steps: checkmark in gold circle
- Future steps: muted gray circle
- Step labels below each dot (Goal, Budget, Creative, Targeting, Review)
- Animated transitions between steps (slide left/right)
- **Gesture support**: Swipe left/right to navigate between steps
- **Step validation**: Can't proceed to next step until current step is valid
- **Back navigation**: Chevron left arrow in top-left, or tap on previous step indicator

### Step Container Layout:
- Full-screen dark container (overlay or page)
- **Header**: Step number + title + back button (if applicable)
- **Body**: Scrollable content for the step
- **Footer**: "Continue" button (gold gradient) + "Back" ghost link
- On the last step, "Continue" becomes "Launch Campaign"

---

## Mobile-First Considerations

- Single column layout always
- Large touch targets (min 48px height for buttons, 44px for sliders)
- Keyboard-friendly for budget inputs
- Bottom sheet pattern for selections (date picker, image upload)
- Loading states with shimmer animations
- Error states inline (not snackbars) for validation
- Scrollable steps (content can exceed viewport)
- Sticky footer with primary action button

---

## Success & Error States

### Success Flow:
1. User taps "Launch Campaign"
2. Button shows loading spinner
3. Brief (1.5s) animation: campaign creation progress with checkmarks
4. Transitions to a "Campaign Launched!" celebration screen
5. Shows:
   - Campaign name
   - Total budget
   - Duration
   - "View Campaign" button → navigates to campaign details
   - "Create Another" button → restarts flow
   - Dismiss (X) → returns to campaigns list

### Error States:
- **Validation Error**: Inline red text below the field, field border turns red
- **API Error**: Bottom sheet with error message + retry button
- **Network Error**: Persistent banner at top "Connection lost. Changes saved locally."
- **Budget Exceeded**: Warning if total budget is too low for selected placements

---

## Analytics & Performance (Post-Launch)

After launch, the campaigns page should show:
- **Active badge** for running campaigns
- **Budget spent %** progress bar
- **Estimated vs actual** performance comparison
- **"Optimize" button** — suggests budget rebalancing based on performance data
- **Pause/Resume** quick action

---

## Required Data Model Updates

New model additions needed to support this flow:

```json
{
  "campaign_goal": "discovery | foot_traffic | promotion | full_presence",
  "distribution": [
    {"placement": "featured", "percentage": 40, "budget": 200.00},
    {"placement": "search",   "percentage": 25, "budget": 125.00},
    {"placement": "map_pin",  "percentage": 20, "budget": 100.00},
    {"placement": "promo",    "percentage": 15, "budget":  75.00}
  ],
  "is_smart_distribution": true,
  "targeting": {
    "radius_km": 5,
    "peak_hours_only": true,
    "age_range": {"min": 18, "max": 45}
  },
  "creative": {
    "banner_url": "...",
    "tagline": "Happy hour ate 20h!",
    "cta_type": "visit_now",
    "promoted_item_id": null
  },
  "budget_optimizer_enabled": true,
  "estimated_performance": {
    "daily_reach": 1200,
    "estimated_clicks": 85,
    "estimated_impressions": 4500
  },
  "status": "draft | active | paused | completed"
}