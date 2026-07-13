# 🌐 DOBAR ECOSYSTEM VISION
## The Live Commerce Infrastructure for Mass Events

> **Mission**: Become the universal payment middleware layer that enables instant mobile commerce for 10,000 to 100,000+ simultaneous users at live events worldwide.

---

## 📍 The Problem Space

### Current State of Live Event Commerce (2026)

| Pain Point | Impact |
|------------|--------|
| **Long queues** | 30-45 min wait for drinks/food at peak times |
| **Cash dependency** | Many vendors still cash-only, ATM lines |
| **Fragmented payments** | Each vendor has different POS, no unified experience |
| **Lost sales** | People give up, don't buy, or buy less |
| **No real-time inventory** | Vendors run out, customers disappointed |
| **Internet scarcity** | WiFi/cellular overwhelmed at scale |

### The Numbers

```
Event Size        | Attendees  | Peak Concurrent Buyers | Transactions/Hour
------------------|------------|------------------------|-------------------
Local Show        | 5,000      | 500-1,000              | 3,000-5,000
Medium Festival   | 20,000     | 2,000-4,000            | 12,000-20,000
Lollapalooza BR   | 100,000    | 10,000-20,000          | 60,000-100,000
Rock in Rio       | 100,000+   | 15,000-25,000          | 80,000-120,000
```

**Key Insight**: At peak moments (headliner about to start, halftime, between sets), buying intent is MASSIVE but infrastructure fails.

---

## 💡 The Vision: Dobar as Live Commerce Infrastructure

### Three Pillars

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          DOBAR ECOSYSTEM                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐           │
│   │   DOBAR APP     │   │ DOBAR PAYMENT   │   │  DOBAR CONNECT  │           │
│   │   (Consumer)    │   │    ENGINE       │   │   (Telecom)     │           │
│   │                 │   │   (Middleware)  │   │                 │           │
│   │ • Browse menus  │   │ • Multi-gateway │   │ • Dedicated     │           │
│   │ • Order & pay   │   │ • Real-time     │   │   bandwidth     │           │
│   │ • Get QR pickup │   │ • Failover      │   │ • Event routing │           │
│   │ • Track status  │   │ • Settlement    │   │ • SLA guarantee │           │
│   └────────┬────────┘   └────────┬────────┘   └────────┬────────┘           │
│            │                     │                     │                     │
│            └─────────────────────┼─────────────────────┘                     │
│                                  │                                           │
│                    ┌─────────────▼─────────────┐                             │
│                    │     UNIFIED PLATFORM      │                             │
│                    │  PostgreSQL + MongoDB +   │                             │
│                    │  Fly.io Edge + WebSockets │                             │
│                    └───────────────────────────┘                             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 DOBAR PAYMENT ENGINE: The Core

### What It Is

**The universal middleware between payment intent and payment execution.**

```
┌──────────────┐     ┌─────────────────────────────────┐     ┌──────────────────┐
│              │     │      DOBAR PAYMENT ENGINE       │     │                  │
│   USER       │     │                                 │     │  PAYMENT         │
│   ACTION     │────▶│  ┌─────────────────────────┐   │────▶│  PROVIDERS       │
│              │     │  │  Transaction Router     │   │     │                  │
│ • Tap to pay │     │  │  • Route optimization   │   │     │ • PIX (BCB)      │
│ • QR scan    │     │  │  • Failover logic       │   │     │ • Stripe         │
│ • NFC        │     │  │  • Cost optimization    │   │     │ • PayPal         │
│              │     │  └─────────────────────────┘   │     │ • Mastercard     │
│              │     │                                 │     │ • Visa           │
│              │     │  ┌─────────────────────────┐   │     │ • Apple Pay      │
│              │     │  │  State Machine          │   │     │ • Google Pay     │
│              │     │  │  • Pending → Processing │   │     │ • PagSeguro      │
│              │     │  │  • Processing → Success │   │     │ • Mercado Pago   │
│              │     │  │  • Retry logic          │   │     │                  │
│              │     │  └─────────────────────────┘   │     │                  │
│              │     │                                 │     │                  │
│              │◀────│  ┌─────────────────────────┐   │◀────│                  │
│   RESPONSE   │     │  │  Real-time Sync         │   │     │  CONFIRMATION    │
│              │     │  │  • WebSocket push       │   │     │                  │
│ • Confirmed  │     │  │  • Webhook handling     │   │     │                  │
│ • QR code    │     │  │  • Event sourcing       │   │     │                  │
│ • Pickup #   │     │  └─────────────────────────┘   │     │                  │
└──────────────┘     └─────────────────────────────────┘     └──────────────────┘
```

### Core Capabilities

| Capability | Description | Why It Matters |
|------------|-------------|----------------|
| **Multi-Gateway Routing** | Dynamically route to cheapest/fastest provider | Cost savings, reliability |
| **Automatic Failover** | If PIX fails → Stripe → PayPal → Card | Zero failed transactions |
| **Offline Queue** | Queue transactions when connectivity drops | Works in low-signal areas |
| **Batch Settlement** | Aggregate micro-transactions for vendors | Lower fees, simpler accounting |
| **Real-time Split** | Instant revenue split (venue, vendor, platform) | Transparent, automated |
| **Fraud Detection** | ML-based anomaly detection at scale | Protect all parties |

### Technical Architecture

```python
# Core Transaction Flow
class DobarPaymentEngine:
    """
    The middleware that abstracts all payment complexity.
    """
    
    async def process_payment(self, transaction: Transaction) -> PaymentResult:
        # 1. Validate transaction
        await self.validate(transaction)
        
        # 2. Select optimal gateway based on:
        #    - Cost (PIX = 0%, Card = 2-3%)
        #    - Speed (PIX = instant, Card = 2-5s)
        #    - Availability (health checks)
        gateway = await self.router.select_optimal_gateway(transaction)
        
        # 3. Execute with automatic failover
        result = await self.execute_with_failover(
            transaction=transaction,
            primary=gateway,
            fallbacks=self.get_fallback_gateways(gateway)
        )
        
        # 4. Real-time notification
        await self.notify_all_parties(result)
        
        # 5. Queue for settlement
        await self.settlement_queue.add(result)
        
        return result
```

### Payment Provider Integration Roadmap

| Phase | Provider | Type | Priority | Status |
|-------|----------|------|----------|--------|
| 1 | PIX (Banco Central) | Instant Transfer | 🔴 Critical | Planned |
| 1 | Stripe | Card Processing | 🔴 Critical | Planned |
| 2 | PagSeguro | Brazilian Gateway | 🟡 High | Planned |
| 2 | Mercado Pago | LATAM Gateway | 🟡 High | Planned |
| 3 | PayPal | International | 🟢 Medium | Planned |
| 3 | Apple Pay | Mobile Wallet | 🟢 Medium | Planned |
| 3 | Google Pay | Mobile Wallet | 🟢 Medium | Planned |
| 4 | Mastercard Direct | Card Network | 🔵 Future | Planned |
| 4 | Visa Direct | Card Network | 🔵 Future | Planned |

---

## 📡 DOBAR CONNECT: The Telecom Partnership

### The Internet Scarcity Problem

At large events, standard infrastructure fails:

```
Normal Cell Tower Capacity:  ~1,000 simultaneous data connections
Festival Peak Demand:        ~20,000+ simultaneous connections
Result:                      NETWORK COLLAPSE
```

**Current "Solutions"** (all inadequate):
- Free WiFi → Overloaded in minutes
- "Just use your data" → Cell towers overwhelmed
- Offline modes → Limited functionality, sync issues

### The Dobar Connect Proposition

**Partner with telecoms (Vivo, Claro, TIM, Oi) to provide dedicated event infrastructure.**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DOBAR CONNECT MODEL                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌──────────────────┐                      ┌──────────────────┐            │
│   │   EVENT VENUE    │                      │  TELECOM PARTNER │            │
│   │                  │                      │                  │            │
│   │  Lollapalooza    │◀────── CONTRACT ────▶│  VIVO / CLARO    │            │
│   │  Rock in Rio     │                      │                  │            │
│   │  The Town        │                      │  Provides:       │            │
│   │  Local Shows     │                      │  • Mobile COWs   │            │
│   │                  │                      │  • Dedicated AP  │            │
│   │  Needs:          │                      │  • Priority QoS  │            │
│   │  • Fast payments │                      │  • Edge servers  │            │
│   │  • No queues     │                      │                  │            │
│   │  • Happy fans    │                      │                  │            │
│   └────────┬─────────┘                      └────────┬─────────┘            │
│            │                                         │                       │
│            └──────────────────┬──────────────────────┘                       │
│                               │                                              │
│                               ▼                                              │
│                    ┌─────────────────────┐                                   │
│                    │    DOBAR PLATFORM   │                                   │
│                    │                     │                                   │
│                    │  • Payment Engine   │                                   │
│                    │  • Consumer App     │                                   │
│                    │  • Vendor Dashboard │                                   │
│                    │  • Analytics        │                                   │
│                    │                     │                                   │
│                    │  REVENUE SHARE:     │                                   │
│                    │  Venue: 85%         │                                   │
│                    │  Dobar: 10%         │                                   │
│                    │  Telecom: 5%        │                                   │
│                    └─────────────────────┘                                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Why Telecoms Will Partner

| Telecom Pain Point | Dobar Solution |
|--------------------|----------------|
| Stagnant revenue growth | New B2B2C revenue stream |
| Unused event infrastructure | Monetize COWs (Cell on Wheels) |
| No differentiation | "Powered by Vivo + Dobar" branding |
| Complex billing for events | Dobar handles all payment complexity |

### Technical Requirements for Event Connectivity

```yaml
# Minimum viable event infrastructure
event_connectivity:
  small_event:  # 5,000 people
    mobile_cows: 1
    access_points: 10
    dedicated_bandwidth: 100 Mbps
    edge_server: 1x Fly.io machine
    
  medium_event:  # 20,000 people
    mobile_cows: 2-3
    access_points: 30
    dedicated_bandwidth: 500 Mbps
    edge_server: 3x Fly.io machines (load balanced)
    
  large_event:  # 100,000 people
    mobile_cows: 5-8
    access_points: 100+
    dedicated_bandwidth: 2 Gbps
    edge_server: 10x Fly.io machines (geo-distributed)
    backup_satellite: 1 (emergency failover)
```

---

## 🎯 Product Roadmap

### Phase 1: Foundation (Current - Q2 2026)
**Focus: Bar & Restaurant MVP**

- [x] Core ordering flow
- [x] Real-time updates (WebSocket)
- [x] PostgreSQL + MongoDB hybrid
- [x] Menu management
- [ ] Payment engine v1 (PIX + Stripe)
- [ ] Vendor dashboard
- [ ] QR code pickup system

### Phase 2: Scale (Q3-Q4 2026)
**Focus: Multi-venue & Events**

- [ ] Multi-vendor support (food courts, events)
- [ ] Payment engine v2 (failover, multi-gateway)
- [ ] Offline transaction queue
- [ ] Batch settlement system
- [ ] Inventory sync across vendors
- [ ] First event pilot (local show, 5k people)

### Phase 3: Infrastructure (2027)
**Focus: Telecom Partnerships**

- [ ] Dobar Connect pilot with one telecom
- [ ] Edge computing deployment
- [ ] 20k+ concurrent user testing
- [ ] SLA framework for events
- [ ] First major festival partnership

### Phase 4: Platform (2028+)
**Focus: Ecosystem Expansion**

- [ ] White-label payment engine API
- [ ] Self-service event onboarding
- [ ] International expansion (LATAM first)
- [ ] Direct card network integration
- [ ] Dobar as a Service (DaaS)

---

## 💰 Business Model

### Revenue Streams

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DOBAR REVENUE MODEL                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   1. TRANSACTION FEES                                                        │
│      └── 1-3% per transaction (varies by payment method)                    │
│                                                                              │
│   2. PLATFORM SUBSCRIPTION                                                   │
│      └── Monthly fee for vendors (R$ 99-499/month based on volume)          │
│                                                                              │
│   3. EVENT LICENSING                                                         │
│      └── Per-event fee for large events (R$ 10k-100k based on size)         │
│                                                                              │
│   4. PAYMENT ENGINE API (Future)                                            │
│      └── Usage-based pricing for third-party integrations                   │
│                                                                              │
│   5. DATA & ANALYTICS (Future)                                              │
│      └── Anonymized consumption insights for brands                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Unit Economics (Projected)

```
Event: Lollapalooza Brazil (100,000 attendees)

Average spend per person:     R$ 150
Total GMV:                    R$ 15,000,000
Dobar take rate (2%):         R$ 300,000

Cost structure:
  - Fly.io infrastructure:    R$ 15,000
  - Payment processing:       R$ 75,000 (passed to user)
  - Support team:             R$ 30,000
  - Telecom revenue share:    R$ 15,000
  
Net revenue per event:        R$ 240,000
```

---

## 🏗️ Technical Architecture for Scale

### System Design for 100k Concurrent Users

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     HIGH-SCALE EVENT ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   USERS (100,000)                                                            │
│        │                                                                     │
│        ▼                                                                     │
│   ┌─────────────────────────────────────────────────────────────────┐       │
│   │                    EDGE LAYER (Fly.io)                          │       │
│   │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐            │       │
│   │  │ Edge 1  │  │ Edge 2  │  │ Edge 3  │  │ Edge N  │            │       │
│   │  │ (GRU)   │  │ (GRU)   │  │ (GRU)   │  │ (GRU)   │            │       │
│   │  │ 10k usr │  │ 10k usr │  │ 10k usr │  │ 10k usr │            │       │
│   │  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘            │       │
│   │       └────────────┼────────────┼────────────┘                  │       │
│   └────────────────────┼────────────┼───────────────────────────────┘       │
│                        │            │                                        │
│                        ▼            ▼                                        │
│   ┌─────────────────────────────────────────────────────────────────┐       │
│   │                    MESSAGE QUEUE (Redis Streams)                │       │
│   │                    • Order queue                                │       │
│   │                    • Payment queue                              │       │
│   │                    • Notification queue                         │       │
│   └─────────────────────────────────────────────────────────────────┘       │
│                        │            │                                        │
│            ┌───────────┘            └───────────┐                           │
│            ▼                                    ▼                            │
│   ┌─────────────────────┐          ┌─────────────────────┐                  │
│   │   ORDER SERVICE     │          │  PAYMENT ENGINE     │                  │
│   │   (Stateless)       │          │  (Stateless)        │                  │
│   │   • N replicas      │          │  • N replicas       │                  │
│   └──────────┬──────────┘          └──────────┬──────────┘                  │
│              │                                 │                             │
│              ▼                                 ▼                             │
│   ┌─────────────────────┐          ┌─────────────────────┐                  │
│   │   PostgreSQL        │          │   MongoDB           │                  │
│   │   (Primary + Read   │          │   (Replica Set)     │                  │
│   │    Replicas)        │          │                     │                  │
│   └─────────────────────┘          └─────────────────────┘                  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Technical Decisions

| Decision | Rationale |
|----------|-----------|
| **Fly.io Edge Deployment** | Sub-100ms latency, auto-scaling |
| **PostgreSQL for Transactions** | ACID compliance, financial data integrity |
| **MongoDB for Real-time** | Flexible schema, fast reads |
| **Redis Streams for Queues** | Handle burst traffic, decouple services |
| **WebSockets for Updates** | Real-time order status, no polling |
| **Event Sourcing for Payments** | Full audit trail, replay capability |

---

## 🤝 Key Partnerships to Pursue

### Tier 1: Critical (2026)

| Partner | Type | Value Proposition |
|---------|------|-------------------|
| **PIX/Banco Central** | Payment | Instant, zero-fee payments |
| **Stripe Brazil** | Payment | Card processing, reliability |
| **Fly.io** | Infrastructure | Edge computing, global scale |

### Tier 2: Strategic (2026-2027)

| Partner | Type | Value Proposition |
|---------|------|-------------------|
| **Vivo** | Telecom | Event connectivity, reach |
| **Claro** | Telecom | Event connectivity, backup |
| **Rock in Rio** | Event | Flagship event, proof point |
| **Time for Fun (T4F)** | Event | Event network, volume |

### Tier 3: Growth (2027+)

| Partner | Type | Value Proposition |
|---------|------|-------------------|
| **Ambev** | Beverage | Inventory integration, sponsorship |
| **Heineken** | Beverage | Inventory integration, sponsorship |
| **iFood** | Delivery | Hybrid model, last-mile |

---

## 📊 Success Metrics

### North Star Metric
**Gross Merchandise Volume (GMV)** processed through Dobar platform

### Supporting Metrics

| Metric | Target (2026) | Target (2027) |
|--------|---------------|---------------|
| Monthly Active Venues | 100 | 1,000 |
| Monthly Transactions | 50,000 | 500,000 |
| GMV | R$ 5M/month | R$ 50M/month |
| Event Partnerships | 5 | 50 |
| Average Transaction Time | < 3 seconds | < 2 seconds |
| Payment Success Rate | 99.5% | 99.9% |

---

## 🚀 Next Steps

### Immediate (This Week)
1. [ ] Finalize PIX integration architecture
2. [ ] Design payment engine database schema
3. [ ] Create dobar-payment-engine repository structure
4. [ ] Define API contracts between services

### Short Term (This Month)
1. [ ] Implement PIX payment flow (sandbox)
2. [ ] Implement Stripe payment flow (test mode)
3. [ ] Build transaction routing logic
4. [ ] Create vendor settlement reports

### Medium Term (This Quarter)
1. [ ] Launch payment engine v1
2. [ ] Pilot with 3-5 venues
3. [ ] Gather feedback, iterate
4. [ ] Prepare event pilot proposal

---

## 📝 Notes & Ideas Parking Lot

*Capture ideas for future exploration:*

- [ ] Cryptocurrency payments (stablecoins for international events?)
- [ ] Biometric payment (face recognition at kiosks?)
- [ ] Pre-loaded event wallets (buy credits before event)
- [ ] Social ordering (group orders, split bills)
- [ ] Gamification (rewards, loyalty points)
- [ ] Dynamic pricing (surge pricing for peak times?)
- [ ] Carbon offset integration (sustainability angle)

---

## 🔒 Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Payment provider API changes | High | Medium | Multi-provider, abstraction layer |
| Telecom partnership falls through | High | Medium | Multiple telecom outreach |
| Competitor with more capital | High | High | First-mover, network effects |
| Regulatory changes (PIX, payments) | Medium | Low | Legal counsel, compliance team |
| Technical failure at major event | Critical | Low | Redundancy, failover, testing |

---

## 💭 Closing Thoughts

> "We're not building an app. We're building infrastructure for the future of live commerce."

The combination of:
1. **Universal Payment Middleware** (abstract all payment complexity)
2. **Telecom Partnerships** (solve the connectivity problem)
3. **Real-time Architecture** (WebSocket, edge computing)
4. **Event-First Design** (built for 100k concurrent users)

...creates a moat that's extremely hard to replicate.

**Barz started as a bar ordering app. Dobar becomes the Stripe for live events.**

---

*Document Version: 1.0*
*Created: January 8, 2026*
*Authors: Barz Team*
*Status: Vision Draft - For Internal Discussion*
