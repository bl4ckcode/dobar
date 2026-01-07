# �� BARZ Pricing & Regional Compliance

> **Version:** 1.0  
> **Last Updated:** January 7, 2026  
> **Status:** Financial Strategy  
> **Scope:** Multi-Region (Expandable)

---

## 📋 Document Purpose

This document defines **pricing, commissions, and regulatory compliance** for each market BARZ operates in. Product features are defined separately to allow independent updates.

**Related Documents:**
- [ADVERTISING_PRODUCTS.md](./ADVERTISING_PRODUCTS.md) - Product definitions
- [ADVERTISING_BACKEND.md](./ADVERTISING_BACKEND.md) - Technical implementation

---

## 🌍 Regional Strategy Overview

### Market Expansion Phases

| Phase | Region | Countries | Status | Payment Gateway |
|-------|--------|-----------|--------|-----------------|
| 1 | LATAM Core | 🇧🇷 Brazil | Active | Stone/Pagar.me |
| 2 | LATAM Expansion | 🇦🇷 🇲🇽 🇨🇱 🇨🇴 🇵🇪 | Planned | MercadoPago |
| 3 | North America | 🇺🇸 🇨🇦 | Planned | Stripe |
| 4 | Europe | 🇵�� 🇪🇸 🇬🇧 🇩🇪 | Future | Stripe |
| 5 | APAC | 🇦🇺 🇳🇿 | Future | Stripe |

### Currency & Pricing Philosophy

- **Local Currency First:** All prices displayed in local currency
- **USD Baseline:** Internal accounting in USD for consistency
- **Purchasing Power Parity:** Adjusted pricing for emerging markets
- **Quarterly Reviews:** Prices adjusted for FX and inflation

---

## 🇧🇷 BRAZIL (Phase 1 - Active)

### Regulatory Environment

| Aspect | Requirement | BARZ Compliance |
|--------|-------------|-----------------|
| **Payment Processing** | BACEN regulated | ✅ Stone/Pagar.me (authorized) |
| **Consumer Protection** | CDC (Código de Defesa do Consumidor) | ✅ Clear pricing, refund policy |
| **Advertising** | CONAR guidelines | ✅ "Publicidade" label on ads |
| **Data Protection** | LGPD (Lei Geral de Proteção de Dados) | ✅ Privacy policy, consent |
| **Tax** | NF-e required for B2B | ✅ Invoice generation |
| **Marketplace** | CADE competition rules | ✅ Fair commission practices |

### Payment Gateway: Stone/Pagar.me

| Method | Consumer Fee | BARZ Fee | Settlement |
|--------|--------------|----------|------------|
| Pix | Free | 0.99% | Instant |
| Credit Card | 0% | 3.49% + R$0.39 | D+30 |
| Debit Card | 0% | 1.99% + R$0.39 | D+1 |
| Boleto | R$3.49 | Included | D+2 |

### Subscription Pricing (BRL)

| Tier | Monthly | Annual (20% off) |
|------|---------|------------------|
| Regular | Grátis | Grátis |
| Master BARZ | R$ 199/mês | R$ 1.910/ano |
| VIP BARZ | R$ 599/mês | R$ 5.750/ano |

### Commission Rates

| Tier | Commission | Effective Rate* |
|------|------------|-----------------|
| Regular | 18% | 18% |
| Master | 14% | 10.5% (with sub value) |
| VIP | 10% | 6.8% (with sub value) |

*Effective rate includes subscription amortized over avg monthly orders

### Advertising Pricing (BRL)

#### Featured Home Placement

| Package | Hours | Price (BRL) | Per Hour |
|---------|-------|-------------|----------|
| Starter | 5 | R$ 22,50 | R$ 4,50 |
| Growth | 20 | R$ 80,00 | R$ 4,00 |
| Pro | 50 | R$ 175,00 | R$ 3,50 |
| Enterprise | 100 | R$ 300,00 | R$ 3,00 |

#### Sponsored Search

| Model | Price (BRL) |
|-------|-------------|
| CPC | R$ 0,75 - R$ 2,00 |
| Flat Hourly | R$ 2,25/hora |

#### Map Spotlight

| Package | Hours | Price (BRL) | Per Hour |
|---------|-------|-------------|----------|
| Starter | 5 | R$ 11,25 | R$ 2,25 |
| Growth | 20 | R$ 40,00 | R$ 2,00 |
| Pro | 50 | R$ 87,50 | R$ 1,75 |

#### Promotion Boost

| Reach | Impressions | Price (BRL) |
|-------|-------------|-------------|
| Local | 1.000 | R$ 25,00 |
| Bairro | 5.000 | R$ 100,00 |
| Cidade | 20.000 | R$ 300,00 |
| Metrópole | 50.000 | R$ 625,00 |

### Tax Considerations

| Item | Tax Treatment |
|------|---------------|
| Subscription | ISS (Imposto Sobre Serviços) ~5% |
| Commission | ISS ~5% + PIS/COFINS 9.25% |
| Advertising | ISS ~5% |
| **Note:** | Prices above are NET; taxes added at checkout |

### Required Disclosures (Brazil)

```
Publicidade: Conteúdo patrocinado
Anúncio: Este é um anúncio pago

Footer: BARZ Tecnologia Ltda. CNPJ: XX.XXX.XXX/0001-XX
Atendimento: suporte@barz.app | 0800-XXX-XXXX
```

---

## 🇦🇷 ARGENTINA (Phase 2)

### Regulatory Environment

| Aspect | Requirement | BARZ Compliance |
|--------|-------------|-----------------|
| **Payment** | BCRA regulated | ✅ MercadoPago (authorized) |
| **Consumer** | Ley de Defensa del Consumidor | ✅ Clear terms |
| **Advertising** | CONARP guidelines | ✅ "Publicidad" label |
| **Data** | Ley 25.326 (Data Protection) | ✅ Privacy policy |
| **Tax** | Factura required | ✅ Invoice generation |
| **FX Controls** | Cepo cambiario restrictions | ⚠️ ARS pricing only |

### Payment Gateway: MercadoPago

| Method | Consumer Fee | BARZ Fee | Settlement |
|--------|--------------|----------|------------|
| MP Wallet | Free | 4.99% | D+14 |
| Credit Card | 0% | 5.99% + ARS 15 | D+14 |
| Debit Card | 0% | 3.49% + ARS 10 | D+7 |
| Transferencia | Free | 0.99% | D+2 |

### Subscription Pricing (ARS)

| Tier | Monthly | Annual (20% off) |
|------|---------|------------------|
| Regular | Gratis | Gratis |
| Master BARZ | ARS 39.900/mes | ARS 383.040/año |
| VIP BARZ | ARS 119.900/mes | ARS 1.151.040/año |

*Prices adjusted monthly for inflation (IPC)

### Commission Rates

| Tier | Commission |
|------|------------|
| Regular | 16% |
| Master | 12% |
| VIP | 9% |

*Lower than Brazil due to higher payment processing fees

### Advertising Pricing (ARS)

#### Featured Home Placement

| Package | Hours | Price (ARS) |
|---------|-------|-------------|
| Starter | 5 | ARS 4.500 |
| Growth | 20 | ARS 16.000 |
| Pro | 50 | ARS 35.000 |

#### Special Considerations

- **Inflation Adjustment:** Prices reviewed monthly
- **Dollar Blue:** Monitor parallel exchange rate
- **Payment Timing:** Encourage prepayment due to FX volatility

---

## 🇲🇽 MEXICO (Phase 2)

### Regulatory Environment

| Aspect | Requirement | BARZ Compliance |
|--------|-------------|-----------------|
| **Payment** | Banxico regulated | ✅ MercadoPago/Stripe |
| **Consumer** | PROFECO guidelines | ✅ Clear terms |
| **Advertising** | CONAR México | ✅ "Publicidad" label |
| **Data** | LFPDPPP | ✅ Aviso de privacidad |
| **Tax** | CFDI required | ✅ Invoice generation |
| **Fintech** | Ley Fintech compliance | ✅ Via authorized gateway |

### Payment Gateway: MercadoPago

| Method | Consumer Fee | BARZ Fee | Settlement |
|--------|--------------|----------|------------|
| MP Wallet | Free | 3.99% | D+14 |
| Credit Card | 0% | 3.99% + MXN 4 | D+14 |
| Debit Card | 0% | 2.99% + MXN 4 | D+7 |
| OXXO | MXN 12 | Included | D+3 |
| SPEI | Free | 0.99% | D+1 |

### Subscription Pricing (MXN)

| Tier | Monthly | Annual (20% off) |
|------|---------|------------------|
| Regular | Gratis | Gratis |
| Master BARZ | MXN 899/mes | MXN 8.630/año |
| VIP BARZ | MXN 2.699/mes | MXN 25.910/año |

### Commission Rates

| Tier | Commission |
|------|------------|
| Regular | 17% |
| Master | 13% |
| VIP | 10% |

---

## 🇺🇸 UNITED STATES (Phase 3)

### Regulatory Environment

| Aspect | Requirement | BARZ Compliance |
|--------|-------------|-----------------|
| **Payment** | PCI-DSS compliance | ✅ Stripe (Level 1 PCI) |
| **Consumer** | FTC guidelines | ✅ Clear disclosures |
| **Advertising** | FTC Act Section 5 | ✅ "#ad" / "Sponsored" labels |
| **Data** | CCPA (California) | ✅ Privacy policy, opt-out |
| **Tax** | Sales tax by state | ✅ TaxJar integration |
| **Alcohol** | TTB/State regulations | ⚠️ No direct alcohol sales |

### Payment Gateway: Stripe

| Method | Consumer Fee | BARZ Fee | Settlement |
|--------|--------------|----------|------------|
| Credit Card | 0% | 2.9% + $0.30 | D+2 |
| Debit Card | 0% | 2.9% + $0.30 | D+2 |
| Apple Pay | 0% | 2.9% + $0.30 | D+2 |
| Google Pay | 0% | 2.9% + $0.30 | D+2 |
| ACH | 0% | 0.8% (max $5) | D+5 |

### Subscription Pricing (USD)

| Tier | Monthly | Annual (20% off) |
|------|---------|------------------|
| Regular | Free | Free |
| Master BARZ | $49/month | $470/year |
| VIP BARZ | $149/month | $1,430/year |

### Commission Rates

| Tier | Commission |
|------|------------|
| Regular | 15% |
| Master | 12% |
| VIP | 8% |

### Advertising Pricing (USD)

#### Featured Home Placement

| Package | Hours | Price (USD) | Per Hour |
|---------|-------|-------------|----------|
| Starter | 5 | $4.50 | $0.90 |
| Growth | 20 | $16.00 | $0.80 |
| Pro | 50 | $35.00 | $0.70 |
| Enterprise | 100 | $60.00 | $0.60 |

#### Sponsored Search

| Model | Price (USD) |
|-------|-------------|
| CPC | $0.15 - $0.40 |
| Flat Hourly | $0.45/hour |

#### Map Spotlight

| Package | Hours | Price (USD) | Per Hour |
|---------|-------|-------------|----------|
| Starter | 5 | $2.25 | $0.45 |
| Growth | 20 | $8.00 | $0.40 |
| Pro | 50 | $17.50 | $0.35 |

### State-Specific Considerations

| State | Sales Tax | Special Rules |
|-------|-----------|---------------|
| California | 7.25%+ | CCPA privacy rights |
| Texas | 6.25%+ | No state income tax |
| New York | 8%+ | NYC additional tax |
| Florida | 6% | Tourism-focused marketing |

### Required Disclosures (US)

```
Sponsored Content | #ad | Paid Partnership

Footer: BARZ Inc. 
Terms of Service | Privacy Policy | Do Not Sell My Info (CCPA)
```

---

## 🇨🇦 CANADA (Phase 3)

### Regulatory Environment

| Aspect | Requirement | BARZ Compliance |
|--------|-------------|-----------------|
| **Payment** | FINTRAC regulated | ✅ Stripe (compliant) |
| **Consumer** | Competition Act | ✅ Fair practices |
| **Advertising** | Ad Standards Canada | ✅ Clear labels |
| **Data** | PIPEDA | ✅ Privacy policy |
| **Languages** | Bilingual (FR/EN) | ✅ App localization |
| **Tax** | GST/HST/PST | ✅ Tax calculation |

### Subscription Pricing (CAD)

| Tier | Monthly | Annual (20% off) |
|------|---------|------------------|
| Regular | Free | Free |
| Master BARZ | CAD 65/month | CAD 624/year |
| VIP BARZ | CAD 195/month | CAD 1,872/year |

### Commission Rates

| Tier | Commission |
|------|------------|
| Regular | 15% |
| Master | 12% |
| VIP | 8% |

---

## 📊 Cross-Region Price Comparison

### Subscription (USD Equivalent)

| Tier | 🇧🇷 Brazil | 🇦🇷 Argentina | 🇲🇽 Mexico | 🇺🇸 USA | 🇨🇦 Canada |
|------|-----------|--------------|-----------|---------|-----------|
| Master | ~$40 | ~$35 | ~$50 | $49 | ~$48 |
| VIP | ~$120 | ~$105 | ~$150 | $149 | ~$145 |

*PPP-adjusted for local purchasing power

### Commission Comparison

| Tier | 🇧🇷 | 🇦🇷 | 🇲🇽 | 🇺🇸 | 🇨🇦 |
|------|-----|-----|-----|-----|-----|
| Regular | 18% | 16% | 17% | 15% | 15% |
| Master | 14% | 12% | 13% | 12% | 12% |
| VIP | 10% | 9% | 10% | 8% | 8% |

*Varies based on payment processing costs

---

## 🔧 Price Configuration System

### Backend Configuration

```python
# Region-specific pricing stored in database
class RegionPricing(Base):
    region_code: str  # "BR", "AR", "US", etc.
    currency: str     # "BRL", "ARS", "USD"
    
    # Subscriptions
    master_monthly: Decimal
    master_annual: Decimal
    vip_monthly: Decimal
    vip_annual: Decimal
    
    # Commissions
    regular_commission: Decimal  # 0.18 = 18%
    master_commission: Decimal
    vip_commission: Decimal
    
    # Advertising
    featured_cph_base: Decimal
    search_cpc_min: Decimal
    search_cpc_max: Decimal
    map_cph_base: Decimal
    boost_cpm: Decimal
    
    # Tax
    sales_tax_rate: Decimal
    tax_included: bool
    
    # Metadata
    effective_date: DateTime
    updated_at: DateTime
```

### Price Update Process

1. **Quarterly Review:** Finance team reviews FX, inflation, competitive pricing
2. **Proposal:** Draft new prices with justification
3. **Approval:** Leadership sign-off
4. **Communication:** 30-day notice to partners
5. **Implementation:** Backend config update
6. **Monitoring:** Track churn, adoption, revenue impact

---

## 📋 Compliance Checklist by Region

### Before Launch in New Region

- [ ] Legal entity established (or partner)
- [ ] Payment gateway integrated and tested
- [ ] Privacy policy localized
- [ ] Terms of service localized
- [ ] Advertising disclosure labels ready
- [ ] Tax calculation configured
- [ ] Invoice/receipt generation working
- [ ] Customer support in local language
- [ ] Regulatory filings complete (if required)
- [ ] Partner contracts reviewed by local counsel

### Ongoing Compliance

- [ ] Monthly tax filings
- [ ] Quarterly pricing reviews
- [ ] Annual privacy policy audit
- [ ] Regulatory change monitoring
- [ ] Consumer complaint handling

---

## 📞 Regional Contacts

| Region | Legal | Finance | Operations |
|--------|-------|---------|------------|
| Brazil | [TBD] | [TBD] | [TBD] |
| Argentina | [TBD] | [TBD] | [TBD] |
| Mexico | [TBD] | [TBD] | [TBD] |
| USA | [TBD] | [TBD] | [TBD] |
| Canada | [TBD] | [TBD] | [TBD] |

---

**Next:** See [ADVERTISING_BACKEND.md](./ADVERTISING_BACKEND.md) for technical implementation details.
