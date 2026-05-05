# MVP Landing Page + Waitlist Implementation Plan

> **Goal:** Launch a high-converting landing page with waitlist signup to capture leads from our 50+ bar prospects before MVP launch.  
> **Timeline:** 2 weeks (Week 1: Design & Dev, Week 2: Testing & Launch)  
> **Owner:** [Lead Developer]  
> **Status:** Phase 1 ✅ COMPLETE | Phase 2 ✅ COMPLETE (Backend) | Phase 3 🔄 IN PROGRESS (Integration)

---

## 🎯 Overview

### Success Metrics
| Metric | Target | Tracking |
|--------|--------|----------|
| Waitlist Signups | 50+ bars | Form submissions |
| Landing Page Views | 500+ | Analytics |
| Conversion Rate | >10% | Signups / Views |
| Email Open Rate | >40% | Mailjet/SendGrid |
| Email Click Rate | >5% | Mailjet/SendGrid |

### Key Deliverables
1. **Landing Page** (Lovable/Stitch → Web)
2. **Waitlist API** (Backend endpoint)
3. **Admin Dashboard** (View/manage signups)
4. **Outreach Execution** (Email + DM campaigns)

---

## 📋 Phase 1: Design & Prototyping (Days 1-3)

### Day 1: Lovable Prompt & Generation ✅
- [x] Copy the prompt from `lovable_stitch_prompts.md` (Landing Page section)
- [x] Create new project in Lovable.dev
- [x] Paste prompt and generate initial version
- [x] Review generated design against design tokens
- [x] Request revisions if needed (max 2-3 iterations)

**Acceptance Criteria:** ✅
- [x] All sections render correctly (Hero, Features, Form, FAQ, Footer)
- [x] Colors match exactly: `#0A0A0A`, `#FFDE59`, `#121212`
- [x] Form has all required fields: bar name, contact name, email, phone, city
- [x] Responsive on mobile, tablet, desktop
- [x] Animations working (scroll reveal, button shimmer)

### Day 2: Asset Preparation ✅ (FRONT-END COMPLETE)
- [x] Generate Dobar logo in SVG/PNG for landing page
- [x] Create social proof placeholder logos (or use real if permission)
- [x] Prepare favicon set
- [x] Write final FAQ copy
- [x] Review and finalize all Portuguese copy

**Assets Needed:**
```
/assets/landing/
  - dobar-logo-gold.svg
  - dobar-logo-white.svg
  - favicon-16x16.png
  - favicon-32x32.png
  - og-image.png (1200x630 for social sharing)
  - placeholder-bar-1.png
  - placeholder-bar-2.png
  - ... (8 total)
```

### Day 3: Export & Code Review ✅ (COMPLETED - Self-hosted)
- [x] Export from Lovable to GitHub or download ZIP
- [x] Review generated HTML/CSS/JS structure
- [x] Check for accessibility (alt tags, ARIA labels, contrast)
- [x] Verify form submission logic (currently mock)
- [x] Optimize images and assets
- [ ] Run Lighthouse audit (target: 90+ all categories)

---

## 📋 Phase 2: Backend Development (Days 4-7)

### Day 4: Database Schema

**New Table: `waitlist_signups`**
```sql
CREATE TABLE waitlist_signups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bar_name VARCHAR(255) NOT NULL,
    contact_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20),
    city VARCHAR(50) NOT NULL CHECK (city IN ('São Paulo', 'Rio de Janeiro', 'Belo Horizonte', 'Outra')),
    source VARCHAR(50) DEFAULT 'organic', -- 'organic', 'email_outreach', 'instagram', 'whatsapp'
    utm_source VARCHAR(100),
    utm_medium VARCHAR(100),
    utm_campaign VARCHAR(100),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'contacted', 'qualified', 'converted', 'declined')),
    notes TEXT,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX idx_waitlist_city ON waitlist_signups(city);
CREATE INDEX idx_waitlist_status ON waitlist_signups(status);
CREATE INDEX idx_waitlist_source ON waitlist_signups(source);
CREATE INDEX idx_waitlist_created_at ON waitlist_signups(created_at);
```

**Migration File:**
- [x] Create migration in `barz-backend/supabase/migrations/` → `migrations/versions/20250503_add_waitlist_signups_table.py`
- [x] Run migration on production
- [x] Verify table creation
- [x] DNS configured: dobar.app → landing page ✅

### Day 5: API Endpoints

**POST /api/v1/waitlist/signup**
```dart
// Request body
{
  "bar_name": "Astor",
  "contact_name": "João Silva",
  "email": "contato@barastor.com.br",
  "phone": "+55 11 94364-3170",
  "city": "São Paulo",
  "source": "email_outreach", // optional
  "utm_params": {
    "source": "email",
    "medium": "outreach",
    "campaign": "mvp_waitlist_may2025"
  }
}

// Response 201 Created
{
  "success": true,
  "data": {
    "id": "uuid",
    "message": "Você está na lista! Entraremos em contato em breve."
  }
}

// Response 409 Conflict (duplicate email)
{
  "success": false,
  "error": {
    "code": "DUPLICATE_EMAIL",
    "message": "Este email já está na nossa lista de espera!"
  }
}
```

**GET /api/v1/admin/waitlist** (Protected, admin only)
```dart
// Query params: ?city=São Paulo&status=pending&limit=50&offset=0
// Response 200
{
  "success": true,
  "data": {
    "signups": [...],
    "total": 150,
    "by_city": {
      "São Paulo": 60,
      "Rio de Janeiro": 45,
      "Belo Horizonte": 35,
      "Outra": 10
    },
    "by_status": {
      "pending": 120,
      "contacted": 20,
      "qualified": 8,
      "converted": 2
    }
  }
}
```

**PATCH /api/v1/admin/waitlist/:id** (Update status/notes)

Tasks:
- [x] Create endpoint handlers → `app/bars_and_restaurants/routes/waitlist.py`
- [x] Add rate limiting (5 requests per IP per hour) → `RateLimits.WAITLIST_SIGNUP`
- [x] Add email validation → Pydantic `EmailStr` validator
- [x] Add phone normalization (E.164 format) → `normalize_phone_e164()`
- [x] Write unit tests → `tests/test_waitlist.py`

### Day 6: Integration & Webhook

**Email Notification on Signup:**
- [x] Configure webhook trigger on new signup → Automatic in route handler ✅
- [x] Send confirmation email to user (SendGrid/Mailjet) → `email_service.py` ✅
- [x] Send notification to admin team → `email_service.py` ✅
- [ ] **⚠️ PENDING: Set environment variables on Fly.io (SENDGRID_API_KEY, ADMIN_EMAIL, FROM_EMAIL)**

**Confirmation Email Template:**
```
Subject: ✅ Você está na lista de espera do Dobar!

Olá [contact_name],

Obrigado por se inscrever! O [bar_name] está oficialmente na nossa 
lista de espera para o lançamento em [city].

O que acontece agora?
1. Nossa equipe vai revisar sua inscrição
2. Entraremos em contato em até 5 dias úteis
3. Se selecionado, você terá acesso antecipado à plataforma

Enquanto isso, segue a gente no Instagram @dobar.oficial para novidades.

Dúvidas? Responda este email ou chame no WhatsApp [número].

Abraço,
Time Dobar
```

### Day 7: Admin Dashboard (Minimal)

Since full admin is not ready, create a simple view:

**Option A: Supabase Dashboard Query**
- Direct SQL queries for team to check signups

**Option B: Simple Flutter Web Admin (1 day hack)**
- Single page: Table of signups
- Filters: city, status, date range
- Actions: Update status, add notes
- Export to CSV

Decision: Start with Option A (Supabase), move to Option B if volume > 100 signups/week.

---

## 📋 Phase 3: Landing Page Integration (Days 8-10)

### Day 8: Connect Form to API

In the exported Lovable code:
```javascript
// Form submission handler
async function submitWaitlist(formData) {
  const payload = {
    bar_name: formData.barName,
    contact_name: formData.contactName,
    email: formData.email,
    phone: formData.phone,
    city: formData.city,
    source: 'organic',
    utm_params: extractUTMParams() // from URL
  };

  try {
    const response = await fetch('https://api.dobar.com.br/api/v1/waitlist/signup', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    
    if (response.status === 201) {
      showSuccessState();
      fireConfetti();
    } else if (response.status === 409) {
      showDuplicateMessage();
    }
  } catch (error) {
    showErrorMessage();
  }
}
```

Tasks:
- [ ] Replace mock form submission with real API call
- [ ] Add loading state to submit button
- [ ] Add error handling with user-friendly messages
- [ ] Test success flow end-to-end
- [ ] Test duplicate email handling

### Day 9: Deployment Setup

**Static Hosting Options:**
1. **Vercel** (Recommended) - Free, fast, easy
2. **Netlify** - Similar to Vercel
3. **GitHub Pages** - Free but no server-side functions
4. **Firebase Hosting** - Good if using Firebase

**Recommended Stack:**
- Vercel for landing page hosting
- API remains on existing backend (Fly.io)
- Custom domain: `dobar.com.br` or `waitlist.dobar.com.br`

**DNS & SSL:**
- [ ] Configure subdomain if needed
- [ ] Set up SSL certificate (Let's Encrypt via Vercel)
- [ ] Configure redirects (www → non-www or vice versa)

### Day 10: Analytics & Tracking

**Tools to Add:**
- [ ] Google Analytics 4 (gtag.js)
- [ ] Facebook Pixel (if running ads)
- [ ] Hotjar (heatmaps, recordings) - optional
- [ ] UTM parameter tracking in signup records

**Events to Track:**
```javascript
// GA4 events
gtag('event', 'page_view', { page_location: '/waitlist' });
gtag('event', 'begin_checkout', { /* form start */ });
gtag('event', 'signup_start', { city: selectedCity });
gtag('event', 'signup_complete', { city: selectedCity, source: utmSource });
gtag('event', 'scroll', { percent: 25|50|75|90 });
```

**Verify:**
- [ ] Events firing correctly in GA4 DebugView
- [ ] UTM params being captured in database
- [ ] Conversion funnel visible in GA4

---

## 📋 Phase 4: Testing & QA (Days 11-12)

### Day 11: Functional Testing

**Test Cases:**
| Test | Expected Result | Status |
|------|-----------------|--------|
| Submit with valid data | Success message, email sent, record in DB | ⬜ |
| Submit duplicate email | Friendly "already registered" message | ⬜ |
| Submit invalid email | Validation error, no submission | ⬜ |
| Submit without required fields | Inline validation errors | ⬜ |
| Mobile responsive (iPhone SE) | All elements visible, form usable | ⬜ |
| Mobile responsive (iPhone 14 Pro) | All elements visible, form usable | ⬜ |
| Desktop (Chrome) | Full layout, animations working | ⬜ |
| Desktop (Safari) | Full layout, animations working | ⬜ |
| UTM params in URL | Captured in signup record | ⬜ |
| Confirmation email received | Within 2 minutes, correct content | ⬜ |
| Admin notification received | Slack/email alert working | ⬜ |
| GA4 events firing | All events in DebugView | ⬜ |

### Day 12: Performance & Security

**Performance:**
- [ ] Lighthouse score > 90 (mobile & desktop)
- [ ] First Contentful Paint < 1.5s
- [ ] Time to Interactive < 3.5s
- [ ] Image optimization (WebP, lazy loading)

**Security:**
- [ ] No secrets in client-side code
- [ ] API rate limiting working
- [ ] CORS configured correctly
- [ ] No SQL injection vulnerabilities (use parameterized queries)
- [ ] Email validation (regex + MX check if possible)

---

## 📋 Phase 5: Outreach & Launch (Days 13-14)

### Day 13: Soft Launch

**Internal Testing:**
- [ ] Share landing page with team
- [ ] Get feedback on copy and design
- [ ] Test form with team emails
- [ ] Fix any critical issues

**Soft Launch to 5 Warm Leads:**
- [ ] Select 5 friendly bar owners from leads list
- [ ] Send personalized emails (use templates)
- [ ] Monitor for issues
- [ ] Collect feedback

### Day 14: Full Launch

**Morning - Final Checks:**
- [ ] All systems operational
- [ ] Landing page loading fast
- [ ] Form submissions working
- [ ] Emails being sent

**Launch Sequence:**
| Time | Action | Owner |
|------|--------|-------|
| 09:00 | Send batch 1: São Paulo bars (10 leads) | [Owner] |
| 11:00 | Monitor metrics, check for issues | [Owner] |
| 14:00 | Send batch 2: Rio de Janeiro bars (10 leads) | [Owner] |
| 16:00 | Send batch 3: Belo Horizonte bars (10 leads) | [Owner] |
| 17:00 | Daily metrics review | Team |

**Day 14+ Follow-up:**
- [ ] Day 3: Send follow-up to non-openers
- [ ] Day 7: Send second follow-up
- [ ] Day 10: Instagram/WhatsApp DM to non-responders
- [ ] Day 14: Final call email to remaining leads

---

## 🛠️ Technical Stack Summary

| Component | Technology |
|-----------|------------|
| Landing Page | HTML/CSS/JS (Lovable export) |
| Hosting | Vercel |
| Backend API | Dart/Frog (existing) |
| Database | Supabase PostgreSQL |
| Email Service | SendGrid or Mailjet |
| Analytics | Google Analytics 4 |
| CRM/Admin | Supabase Dashboard (MVP) |

---

## 📁 File Structure

```
barz/
├── lovable_stitch_prompts.md          # ✅ Landing page prompt added
├── mvp_outreach_templates.md          # ✅ Email + DM templates
├── mvp_landing_page_implementation_plan.md  # ✅ This file
├── landing/                           # ✅ React + Vite + Tailwind (Self-hosted on Fly.io)
│   ├── src/
│   │   ├── components/dobar/          # Hero, Features, Pricing, FAQ, etc.
│   │   ├── components/ui/             # Button, Accordion
│   │   ├── lib/i18n.ts                # All Portuguese copy
│   │   ├── pages/Index.tsx
│   │   └── App.tsx
│   ├── public/
│   │   └── dobar-logo.gif             # Animated logo
│   ├── index.html
│   ├── Dockerfile
│   ├── fly.toml
│   └── package.json
│
barz-backend/
├── supabase/
│   └── migrations/
│       └── 20250503_add_waitlist_table.sql
├── routes/
│   └── api/v1/waitlist/
│       ├── signup.dart               # POST endpoint
│       └── admin/
│           └── index.dart            # GET/ PATCH admin endpoints
├── lib/
│   └── services/
│       └── waitlist_service.dart
```

---

## ⚠️ Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Lovable export has bugs | High | Have backup plan: manual HTML or use Framer |
| Backend API delays | Medium | Start with form → Google Sheets → manual import |
| Low conversion rate | High | A/B test headline, add video testimonial |
| Email deliverability issues | Medium | Use SendGrid, verify domain, warm up IP |
| Spam complaints | Medium | Clear unsubscribe, only contact relevant leads |

---

## ✅ Success Checklist (Post-Launch)

- [ ] 50+ waitlist signups
- [ ] Landing page conversion >10%
- [ ] Email open rate >40%
- [ ] Zero critical bugs
- [ ] All 50 leads contacted
- [ ] 5+ bars moved to "qualified" status
- [ ] 1+ bar converted to active setup

---

## 📝 Next Steps After MVP

1. **Onboarding Flow:** Build self-service bar setup
2. **Referral Program:** "Indique um bar amigo" with rewards
3. **Landing Page V2:** Add video, testimonials, case studies
4. **Multi-language:** English version for international expansion
5. **AB Testing:** Optimize conversion continuously

---

*Plan created: May 3, 2025*  
*Review date: May 10, 2025*
