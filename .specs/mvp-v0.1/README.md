---
owner: product
---

# MVP v0.1 journey backlog

These 25 specs define desired behavior and record inspected implementation gaps. They do not certify existing features. Every journey starts **ready / unverified**; provider, device and product E2E validation remains follow-on work.

The [manifest](manifest.json) is the machine entry point. [requirements.json](requirements.json) maps every source feature atom, product principle and approved launch decision to concrete acceptance criteria. The matrix below groups that mapping; source wording is preserved semantically where the MVP contains typos or outdated state/role language. Mission/vision are directional context, not a measurable claim that the 2030 mission has been achieved.

## Coverage and execution order

| ID | Journey | Areas | Priority | Dependencies | Requirement/criterion mapping |
|---|---|---|---|---|---|
| [C01](C01-customer-authentication.md) | Customer authentication and onboarding | fe, be | P0 | — | MVP-C01-01, MVP-C01-02, MVP-C01-03, LAUNCH-C01-01, MVP-PRINCIPLE-05 → C01-AC01…AC04 |
| [C02](C02-home-discovery.md) | Home discovery and promotions | fe, be | P1 | C01 | MVP-C02-01 → C02-AC01…AC03 |
| [C03](C03-map-navigation.md) | Partner map and navigation | fe, be | P1 | C01, C02 | MVP-C03-01, MVP-C03-02 → C03-AC01…AC03 |
| [C04](C04-profile-privacy.md) | Customer profile, privacy and deletion | fe, be | P1 | C01 | MVP-C04-01 → C04-AC01…AC04 |
| [C05](C05-check-in.md) | Location and table check-in | fe, be | P0 | C01, C03 | MVP-C05-01, MVP-C05-02, MVP-C05-03, MVP-C05-04 → C05-AC01…AC04 |
| [C06](C06-live-menu.md) | Live venue menu | fe, be | P0 | C02 | MVP-C06-01, MVP-C06-02, MVP-C06-03, MVP-C06-04, MVP-C06-05, MVP-C06-06 → C06-AC01…AC04 |
| [C07](C07-cart-revalidation.md) | Cart, promotions and checkout revalidation | fe, be | P0 | C05, C06 | MVP-C07-01, MVP-C07-02, MVP-C07-03 → C07-AC01…AC04 |
| [C08](C08-card-checkout.md) | Brazilian card checkout | fe, be, dpe | P0 | C07 | MVP-C08-01, LAUNCH-C08-01, MVP-PRINCIPLE-01, MVP-PRINCIPLE-03 → C08-AC01…AC05 |
| [C09](C09-pix-checkout.md) | Brazilian Pix checkout | fe, be, dpe | P0 | C07 | MVP-C09-01, LAUNCH-C09-01, MVP-PRINCIPLE-05 → C09-AC01…AC05 |
| [C10](C10-native-wallets.md) | Apple Pay and Google Pay | fe, be, dpe | P1 | C08 | MVP-C10-01, LAUNCH-C10-01 → C10-AC01…AC04 |
| [C11](C11-order-tracking.md) | Customer order tracking | fe, be | P0 | C07 | MVP-C11-01, MVP-C11-02, LAUNCH-C11-01 → C11-AC01…AC04 |
| [B01](B01-business-auth-navigation.md) | Business authentication and navigation | fe, be | P0 | C01 | MVP-B01-01, MVP-B01-02, LAUNCH-B01-01 → B01-AC01…AC04 |
| [B02](B02-venue-onboarding.md) | Resumable venue onboarding | fe, be | P1 | B01 | MVP-B02-01 → B02-AC01…AC04 |
| [B03](B03-ai-menu-import.md) | AI menu import and review | fe, be | P1 | B01 | MVP-B03-01, MVP-PRINCIPLE-01, MVP-PRINCIPLE-02 → B03-AC01…AC04 |
| [B04](B04-business-dashboard.md) | Business dashboard and shortcuts | fe, be | P1 | B01 | MVP-B04-01, MVP-B04-02, MVP-B04-03, MVP-PRINCIPLE-04 → B04-AC01…AC03 |
| [B05](B05-cashier-live-orders.md) | Cashier and live order processing | fe, be | P0 | B01, C07 | MVP-B05-01, MVP-B05-02, MVP-B05-03, MVP-PRINCIPLE-02 → B05-AC01…AC04 |
| [B06](B06-campaign-management.md) | Campaign creation and management | fe, be | P1 | B01 | MVP-B06-01, MVP-B06-02, MVP-B06-03, MVP-B06-04, MVP-B06-05, MVP-B06-06, LAUNCH-B06-01 → B06-AC01…AC05 |
| [B07](B07-staff-invitation.md) | Staff invitation issuance and delivery | fe, be | P0 | B01, B09 | MVP-B07-01, MVP-B07-02, MVP-B07-03, LAUNCH-B07-01 → B07-AC01…AC05 |
| [B08](B08-staff-invitation-acceptance.md) | Staff invitation acceptance pilot | fe, be | P0 | B07, B01 | MVP-B08-01, MVP-B08-02, MVP-B08-03, LAUNCH-B08-01, LAUNCH-B08-02 → B08-AC01…AC06 |
| [B09](B09-staff-permissions.md) | Staff permissions and management | fe, be | P0 | B01 | MVP-B09-01, MVP-B09-02 → B09-AC01…AC04 |
| [B10](B10-business-settings.md) | Business settings, bank and account preferences | fe, be | P1 | B01, B09 | MVP-B10-01, MVP-B10-02, MVP-B10-03, MVP-B10-04 → B10-AC01…AC04 |
| [B11](B11-subscription-purchase.md) | Master and VIP subscription purchase | fe, be, dpe | P0 | B01 | MVP-B11-01, LAUNCH-B11-01 → B11-AC01…AC05 |
| [B12](B12-subscription-management.md) | Business subscription management | fe, be, dpe | P0 | B11 | MVP-B12-01, LAUNCH-B12-01 → B12-AC01…AC04 |
| [S01](S01-design-system.md) | Design-system alignment | fe | P1 | — | MVP-S01-01, MVP-S01-02, MVP-S01-03, MVP-S01-04, LAUNCH-S01-01, MVP-PRINCIPLE-05 → S01-AC01…AC04 |
| [S02](S02-payment-reconciliation.md) | Payment confirmation, reconciliation and error visibility | fe, be, dpe | P0 | — | MVP-S02-01, MVP-S02-02, MVP-S02-03, MVP-S02-04, LAUNCH-S02-01, MVP-PRINCIPLE-01, MVP-PRINCIPLE-03, MVP-PRINCIPLE-04 → S02-AC01…AC05 |

Dependencies are directed prerequisite relationships, not an instruction to implement the entire backlog at once. Start with contract/security findings (S02, B09), authentication/context (C01/B01), and the B07 → B08 invitation pilot; prioritize ordering/payment blockers before broader polish. C11 and B05 validate together once both sides exist, without creating a circular implementation dependency.

## Pilot and handoff

Published pilot: [DOB-89](https://linear.app/dobarecosystem/issue/DOB-89/b08-staff-invitation-acceptance-pilot), frontend [DOB-90](https://linear.app/dobarecosystem/issue/DOB-90/b08fe-resume-and-accept-staff-invitation-in-flutter), backend [DOB-91](https://linear.app/dobarecosystem/issue/DOB-91/b08be-bind-atomic-invitation-acceptance-to-verified-recipient). [Confirmed identifiers](pilot/linear-issues.json) record the team, labels, parent relationships and readback verification. These issues remain Backlog; publishing them does not implement or validate the feature. The remaining specs have local drafts only.

The first reviewable delivery is [B08](B08-staff-invitation-acceptance.md), its [Lovable React prompt](pilot/lovable-staff-invitation.md), [real source export handoff](pilot/react-source-handoff.md), [FE/BE tasks](pilot/implementation-tasks.md) and [independent checklist](pilot/validation-checklist.md). B07 owns pending-only issuance and delivery. Lovable generation/export is a human handoff; no fake repository revision or automatic paid-model invocation is permitted.

## Known contradictions requiring evidence

- Pix standalone generation hardcodes a recipient and labels encoded text as PNG; provider charge adapter exposes different real QR fields (C09).
- Saved-card UI fabricates a timestamp token (C08); native wallet selectors do not prove provider capability (C10).
- Check-in currently uses local userId 0, a 5km search and hardcoded UI distance instead of proven <10m eligibility (C05).
- Invite issuance grants existing accounts immediate membership; acceptance lacks recipient binding and has FE/BE request/response mismatches (B07/B08).
- Order screen status variants and older source wording disagree; preserve compatibility while presenting the confirmed shared four states (C11/B05).
- Historical communication-document “complete” claims are not fresh E2E evidence. Findings are backlog, not permission to silently rewrite interfaces.

## Evidence policy

`delivery_status` tracks the work artifact; `verification_status` tracks demonstrated behavior. All current evidence is source inspection on the repository snapshot used to author these specs. Foundation checks cannot establish provider success, legal/PCI certification, native device readiness or product acceptance. Record failed, blocked and skipped checks separately; do not promote unexecuted criteria to validated. The canonical workflow guide defines commands, role assignments and evidence handling.
