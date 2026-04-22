# Lovable and Stitch Prompts

## Business Shell (Owner/Staff App)

### Business Settings Page
"Build a premium, high-end Business Settings page for bar owners and administrators.

**OVERALL VIBE:** Professional, authoritative, and clean. Keep our 'Industrial Modern' design language: gritty deep blacks (#0A0A0A), matte gray cards (#121212), and sharp electric gold (#FFDE59) accents.

**PAGE STRUCTURE:**

1. **HEADER (Bar Profile):**
   - Display the active Bar's name as a prominent title.
   - Show the current user's role (e.g., 'Owner', 'Manager') in a subtle badge.
   - Include a 'Switch Bar' or 'View Public Profile' action.

2. **GENERAL SETTINGS SECTION:**
   - **App Appearance:** Theme toggle (Dark/Light) and Language selector.
   - **Business Details:** Edit bar info, contact settings.
   - Use Lucide icons: `Settings`, `Palette`, `Globe`, `Store`.

3. **LEGAL & COMPLIANCE SECTION:**
   - Clean, list-style items for:
     - **Terms of Service**: Link to the business legal framework.
     - **Privacy Policy**: Data handling and transparency.
     - **Operational Rules**: Custom bar rules for digital orders.
   - Use Lucide icons: `FileText`, `ShieldCheck`, `Scale`.

4. **DANGER ZONE (Bottom Section):**
   - A clearly demarcated section with a subtle red glow or distinct border.
   - **Delete Business Data**: Permanent removal of campaign and menu history.
   - **Deactivate Account**: Option to temporarily disable the business access.
   - Visuals: Use `errorRed` (#FF4B4B) for icons and destructive text. 
   - Use Lucide icons: `Trash2`, `AlertTriangle`.

**INTERACTION:**
- Use the same card-based list item pattern found in our Client Profile page (`profile_home_page.dart`).
- Every item should have a chevron-right or a toggle switch.
- The UI must feel like a mission-control center for the business, perfectly readable in high-pressure environments."

---

## Client Shell (Consumer App)

### Check-in Page Redesign
"Build a premium, immersive Check-in experience for a nightlife bar ordering app called **Dobar/Barz**.

**CONTEXT:**
The Check-in feature is the entry point to ordering at a bar. The user either scans a table QR code or uses their GPS to find nearby partner bars. After checking in, they see an active session screen showing the bar name, their table number, and a live session timer. They can then browse the menu or check out (leave the bar).

The current implementation has a working BLoC state machine with 4 states:
- `initial` — shows two action buttons: Scan QR / Find Nearby Bars
- `scanning` — full-screen camera view (QR scanner placeholder)
- `nearbyBars` — list of nearby bars fetched via GPS
- `confirmCheckin` — shows the selected bar's image, table number input, and confirm button
- `activeCheckin` — the active session screen with timer, browse menu, and check-out options

**OVERALL VIBE:** Energetic, dark, premium nightlife. Think: neon-accented dark UI like a VIP club entrance. Use our design tokens:
- Background: #0A0A0A (barzDark)
- Card surfaces: #121212 (barzDarkLight), #1A1A1A (barzDarkCard)
- Gold accent: #FFDE59 (barzGold) — use for CTAs, highlights, glow effects
- Green success: #00B37E (pixGreen) — for the active check-in state
- Typography: Space Grotesk (headings), system default (body)
- Icons: Lucide icon library

**PAGE-BY-PAGE DESIGN:**

1. **INITIAL VIEW (No Check-in yet):**
   - Full-screen dark background with a subtle animated radial gold glow behind the central icon area.
   - Large animated QR code scanner icon (pulse animation) in the center.
   - Main heading: 'Where are you drinking tonight?' in bold Space Grotesk.
   - Subtitle: 'Scan the table QR code or find the bar near you.'
   - Two large pill-shaped buttons stacked vertically:
     - Primary: Gold background, black text — 'Scan QR Code' with `ScanLine` icon
     - Secondary: Dark card border, gold text — 'Find Bars Nearby' with `MapPin` icon
   - At the bottom, a subtle animated radar/pulse graphic to suggest location awareness.

2. **SCANNING VIEW (QR Camera):**
   - Full-screen dark camera overlay with animated corner brackets (gold corners) marking the scan area.
   - A scanning beam animation sweeping top to bottom inside the bracket.
   - Instruction text below the scan area: 'Point at the table QR code'
   - Cancel button at the bottom (ghost style, centered).

3. **NEARBY BARS LIST VIEW:**
   - Top section: Section header 'Bars near you' in bold.
   - Each bar card: Rounded card (#1A1A1A) with the bar's cover image on the left (60x60, rounded corners), bar name (bold), address (muted), and a distance badge (e.g., '120m') in gold pill on the right. Chevron right icon.
   - If empty: Center illustration with `MapPinOff` icon, 'No bars found nearby' heading, and a 'Scan QR instead' ghost button.

4. **CONFIRM CHECK-IN VIEW:**
   - Full-width hero image of the selected bar with a gradient overlay at the bottom.
   - Bar name overlaid on the image in large bold white text.
   - Below image: Bar address in muted text.
   - Table number input field (dark card style, `TableBar` icon prefix, gold focus border).
   - Large CTA button: 'Check In Now' — gold gradient, black text, 56px height.
   - 'Cancel' text link below the button.

5. **ACTIVE CHECK-IN VIEW (Session Active):**
   - Top badge: Green pill badge — '● Checked In' pulsing softly.
   - Bar name in large bold heading.
   - Table chip: 'Table 5' with a `TableBar` icon — dark card pill.
   - Live session timer in monospace font (HH:MM:SS), counting up from check-in time.
   - Two action buttons:
     - Primary: Gold — 'Browse Menu' with `UtensilsCrossed` icon
     - Secondary: Outlined — 'View Cart' with `ShoppingCart` icon
   - At the bottom (danger zone): Red text link 'Check out' with `LogOut` icon — opens a confirmation bottom sheet (not dialog) with a clean dark surface, destructive confirm button.

**ANIMATIONS & MICRO-INTERACTIONS:**
- Initial view: QR icon pulses with a soft gold glow on a loop.
- Scanning view: beam sweeps top to bottom, repeating.
- Active session: green badge pulses every 2 seconds.
- All page transitions: slide-up with fade.
- Buttons: scale down 0.97x on press, spring back on release.

**IMPORTANT:** The UI must be built as Flutter widgets. Match the naming conventions of the existing BLoC states: `CheckinStep.initial`, `CheckinStep.scanning`, `CheckinStep.nearbyBars`, `CheckinStep.confirmCheckin`, `isCheckedIn` (for active session). Keep all strings internationalization-ready (no hardcoded text — use placeholder comments)."

---

### Dobar Pro — Consumer Subscription Modal
"Build a premium, full-screen bottom sheet (modal) that pitches **Dobar Pro** to regular consumer users of the Dobar/Barz app.

**CONTEXT:**
Dobar is a nightlife ordering platform for bars and restaurants. Regular users can order drinks from their table, track their orders live, and pay via PIX or credit card. The **Dobar Pro** consumer tier offers elevated perks for frequent nightlife-goers. This modal appears when a user taps 'Upgrade to Pro' from their profile page.

**BACKEND REFERENCE:**
- Subscription tiers exist at `GET /advertising/plans` (business) and a consumer equivalent will live at `GET /me/pro-plan` (planned).
- For now, show a hardcoded plan with monthly and annual pricing.
- CTA button should show: 'Start 14-Day Free Trial' → will connect to subscription API when ready.

**PRO BENEFITS TO HIGHLIGHT (consumer-facing):**
1. **Priority Ordering** — Your orders jump the queue at peak times.
2. **Cashback Boost** — Earn double cashback on every purchase.
3. **Exclusive Deals** — Access members-only happy hours and flash promotions.
4. **VIP Check-in Badge** — Show your Pro status at partner bars.
5. **Early Access** — Be first to try new partner bars and special events.

**PRICING (show both, highlight annual as best value):**
- Monthly: R$ 14,90/mês
- Annual: R$ 9,90/mês (billed R$ 118,80/year — 'Save 33%' badge)

**OVERALL VIBE:** Premium, aspirational, dark luxury. Night-out energy. Reference vibes: Spotify Premium modal, Apple One upsell screen.

**DESIGN SPECS:**
- Background: #0A0A0A with a subtle dark gradient
- Sheet handle: thin gray pill at top
- Top hero area: A dark card with an animated starfield or floating particles effect behind a large gold crown/star icon + 'PRO' lettering in gold gradient text
- Toggle: monthly / annual billing toggle (pill selector style, gold active state)
- Benefits list: Each benefit in a dark row card (#1A1A1A) with:
  - Left: Lucide icon in a gold-tinted circle container
  - Right: Benefit title (bold) + one-line description
  - A subtle gold shimmer/glow on hover  
- Pricing display: Large price per month, billing note in small muted text below
- CTA: Full-width gold gradient button — 'Start Free Trial (14 days)' — 56px height, black text
- Subtext below CTA: 'Cancel anytime. No commitment.' in small muted gray
- At the very bottom: 'Restore Purchase' and 'Terms & Privacy' text links

**ICONS (Lucide):** `Zap` (priority), `TrendingUp` (cashback), `Tag` (deals), `BadgeCheck` (VIP badge), `CalendarCheck` (early access).

**ANIMATIONS:**
- Sheet slides up with spring animation on appear.
- Crown icon has a subtle floating animation (up/down, 3s loop).
- Gold shimmer sweeps across the CTA button on a loop.
- Benefit rows stagger-animate in from bottom on modal open (50ms delay per row).

**TECHNICAL NOTE:** Build as a static Flutter StatefulWidget (no state management needed at this stage). The billing toggle state is local. CTA button shows a `CircularProgressIndicator` when tapped (for future API hook). Match the existing design system tokens: `barzGold` (#FFDE59), `barzDark` (#0A0A0A), `barzDarkLight` (#121212), `barzDarkCard` (#1A1A1A). Use Lucide icons from the `lucide_icons` package."

---

### Order Tracking Screen
"Build a premium, real-time Order Tracking screen for the Dobar/Barz client app.

**CONTEXT:**
After a user successfully pays for their order, they should be redirected to this screen instead of the home page. This screen allows them to watch the progress of their drinks/food in real-time as the bar staff updates the status in the backend.

**OVERALL VIBE:** Immersive, high-visibility, and reassuring. Keep the 'Industrial Modern' nightlife theme: deep blacks (#0A0A0A) for dark mode and pure whites (#FFFFFF) for light mode, with sharp electric gold (#FFDE59) highlights and glassmorphism. **Must support both Light and Dark themes dynamically.**

**SCREEN STRUCTURE:**

1. **HEADER:**
   - Bar name as the title.
   - Dynamic status badge at the top: '● IN PREPARATION' (pulsing yellow) or '● READY FOR PICKUP' (pulsing green).
   - Use Lucide icons: `Clock`, `GlassWater`.

2. **VISUAL TRACKER (The Core):**
   - A vertical or horizontal 4-stage progress timeline:
     1. **Ordered** — Confirmed by the system.
     2. **Preparing** — Staff is crafting the drinks.
     3. **Ready** — At the counter or waiting for the waiter.
     4. **Served** — Order completed and delivered.
   - **Design:** Completed stages use solid gold markers; the active stage has a soft gold radial glow/pulse; future stages are muted/low-opacity.
   - Animated line connecting the stages that 'fills' with gold as progress moves.

3. **ORDER SUMMARY CARD:**
   - A glassmorphic card (frosted effect with blur).
   - List the items ordered (e.g., '2x Heineken 600ml', '1x Gin Tonic').
   - Total amount paid and payment method (e.g., 'Paid via PIX').
   - Lucide icons: `ClipboardList`, `Receipt`.

4. **VENUE & TABLE INFO:**
   - Small section showing 'Table 42' and a 'Get Directions' or 'Call Waiter' action.
   - Use Lucide icons: `LayoutGrid`, `BellRing`.

5. **FOOTER ACTION:**
   - Primary: 'Back to Home' (Ghost button style, lower priority).
   - Secondary/Support: 'Need help?' (Small text link, opens support chat/bottom sheet).

**ANIMATIONS & MICRO-INTERACTIONS:**
- The active stage icon should pulse gently.
- A golden shimmer should occasionally sweep across the progress line.
- When the status changes to 'Ready', trigger a subtle haptic feedback and a screen-wide celebratory gold confetti blast (subtle).
- Use staggered entrance animations for the order items.

**TECHNICAL NOTE:**
- Use our design tokens: `barzDark` (#0A0A0A), `barzGold` (#FFDE59), `barzGoldSoft` (#FFFFFF for light mode).
- Follow the visual patterns of our existing `cart` and `checkout` pages for the items list and button styles.
- Use the Lucide icon library."