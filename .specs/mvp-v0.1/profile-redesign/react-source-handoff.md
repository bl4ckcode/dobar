---
owner: heavy-ui
spec: C04
artifact: react-source-handoff
status: partial
---

# C04 React → Flutter source handoff

| Field | Evidence |
|---|---|
| Repository | https://github.com/bl4ckcode/pixel-perfect-replica |
| Immutable revision | `2a32eb05a8702bba1e9c8dd1ada8fb817b613f52` |
| Inspected checkout | `/private/tmp/dobar-profile-lovable`; cloned from the user-supplied repository |
| Authorization | User requested profile implementation from this export, with home, badges and toolbars deferred |
| Entrypoints | `src/routes/perfil.index.tsx`, `perfil.conta.tsx`, `perfil.configuracoes.tsx`, `perfil.pedidos.tsx`, `perfil.pagamentos.tsx`, `perfil.beneficios.tsx` |
| Shared source | `src/components/dobar/shell.tsx`, `src/prototype/i18n.ts`, `src/prototype/fixtures.ts`, `src/styles.css` |
| Assets | Lucide icons and CSS; no exported image assets copied |
| Approval limits | User supplied a dark profile screenshot; no device or browser visual acceptance inferred |

## Translation map

| React surface | Flutter destination / behavior |
|---|---|
| Perfil / Group / RowLink | `ProfileWireframe`, `ProfileFrame`, `ProfileGroup`, `ProfileRow`; existing customer shell retained |
| Conta | `ProfileEditPage` + route-owned `ProfileAccountCubit`; authenticated account load/update/delete |
| Configurações | `ProfileSettingsPage` + `ProfileSettingsCubit`; notification preferences via UserUsecase, language via existing LocaleCubit |
| Pedidos | `OrdersPage` + existing OrderBloc; real history, load-more and existing matching tracker |
| Pagamentos | Existing `PaymentMethodsPage` + PaymentBloc/tokenizer; create replacement before deleting original |
| Benefícios / Onde usar | `ProfileBenefitsPage` and `ProfileBenefitVenuesPage` with route-owned cubits over `/me/benefits*`; Pro coupons only, cashback shown but not navigable |
| Prototype terms/privacy/logout | Existing legal routes and SessionBloc.signOut; prototype legal text and fake signed-out state excluded |
| Mock state/debug route | Excluded from Flutter production code |

## Deliberate deviations and dependencies

- The React badge counted fixtures. Flutter shows the backend `active_count` on the benefits row only after the authenticated inventory loads; none while loading, failed or signed out.
- `/me/pro-benefits` stays an allowance count. `/me/benefits` adds the inventory and venues without fixtures; React's "Onde usar" per-benefit venue lists are only real for Pro coupons. Cashback venue eligibility and venue-participation promotions need product decisions and are not invented.
- OS checks alone cannot establish wallet readiness. The Flutter capability gate hides wallets until config, backend advertisement and an OS probe agree; the probe is stubbed unavailable. The explanatory text in saved cards remains. C10 native authorization is blocked.
- Order history shows the venue name only when the backend supplies `bar_name`; no fallback label is manufactured.
- The mobile React column is capped at 448px. Flutter uses a 600px maximum content width on larger screens to fit the existing responsive shell. Both use a single column.
- Contact editing is blocked: `be/app/auth/profile.py:update_profile` writes auth User email/phone and clears verification, contradicting the React claim that login is unaffected. Flutter displays contacts read-only and sends name-only updates. A verified contact-change contract must be planned before enabling edits.
- Account avatar UI is removed; existing server/avatar storage fields are retained and omitted from update payloads.
- Privacy preferences/release deletion-retention evidence remain existing C04 obligations; this change keeps legal/deletion access and does not certify those obligations.
- React simulates replacement. Flutter uses existing authenticated card APIs. Add failure keeps original; removal failure retains both and offers removal on the old card. Network-uncertain add outcomes still require provider/API reconciliation before blindly repeating submission.

See [acceptance and validation](validation-checklist.md) for actual outcomes and [implementation dependencies](implementation-plan.md) for the remaining contract work.
