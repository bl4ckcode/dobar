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

---

## Landing Page + Waitlist (MVP Launch)

### Bar Owner Landing Page with Waitlist Signup
"Build a premium, high-converting landing page for **Dobar** (also known as Barz) — a nightlife ordering platform for bars and restaurants. This is the MVP launch landing page targeting bar owners and managers to join our exclusive early-access waitlist.

**CONTEXT:**
Dobar is 'The Pulse of the Brewery' — the default operating system for nightlife commerce. We empower bar owners with seamless payments, high-impact marketing tools, and a complete digital ordering ecosystem. This landing page needs to convince bar owners to join our waitlist for early access to the platform.

**OVERALL VIBE:** Bold, energetic, premium nightlife. Think: high-end craft brewery meets Silicon Valley tech. Industrial Modern aesthetic with gritty deep blacks and electric gold accents. The page must feel like a VIP invitation to the future of bar management.

**DESIGN TOKENS (STRICT - Use exactly these):**
- **Background (Dark Mode Primary):** `#0A0A0A` (barzDark - Deep Onyx Black)
- **Card Surfaces:** `#121212` (barzDarkLight - Matte), `#1A1A1A` (barzDarkCard)
- **Primary Accent:** `#FFDE59` (barzGold - Dobar Electric Yellow)
- **Gold Gradient:** Start `#FFFFDF73`, End `#FFFFC000`
- **Success/PIX Green:** `#00B37E` (pixGreen)
- **Text on Dark:** `#FFFFFF` (textOnDark)
- **Secondary Text:** `#B0B0B0` (muted gray)
- **Error/Destructive:** `#FF4B4B` (errorRed)
- **Font Family:** Inter (Google Fonts) - use font-weight 400, 600, 700

**PAGE STRUCTURE (Single Page, Scrolling Sections):**

1. **HERO SECTION (Above the Fold):**
   - **Background:** Full dark (#0A0A0A) with subtle animated golden particle network or radial glow effect emanating from center.
   - **Logo:** 'dobar' wordmark in gold (#FFDE59), large and centered at top. Use Inter font, bold weight. The 'd' and 'b' should mirror each other stylistically.
   - **Headline:** 'O Futuro dos Pedidos no Bar Começa Aqui' (The Future of Bar Orders Starts Here) — Large, bold, white text with gold highlight on key word.
   - **Subheadline:** 'Seja um dos primeiros bares do Brasil a revolucionar a experiência dos seus clientes com pedidos digitais, pagamento instantâneo via PIX e ferramentas de marketing poderosas.' (Be among the first bars in Brazil to revolutionize your customer experience...)
   - **Primary CTA Button:** Large pill-shaped button, gold gradient (#FFFFDF73 → #FFFFC000), black text: 'Entrar na Lista de Espera' (Join Waitlist). Size: 56px height, full width on mobile, max-width 400px on desktop. Add subtle shimmer animation on hover.
   - **Secondary Link:** 'Já tem convite? Faça login' (Already have an invite? Log in) — ghost text link in muted gray below CTA.
   - **Scroll indicator:** Animated chevron-down icon pulsing at bottom.

2. **SOCIAL PROOF SECTION:**
   - **Background:** Slightly elevated surface (#121212).
   - **Headline:** 'Bares de Confiança Já Estão Dentro' (Trusted Bars Are Already In) — in white.
   - **Logo Bar:** Horizontal scrolling infinite marquee of bar logo placeholders (use circular gray placeholders with initials). Show 6-8 placeholder bar logos.
   - **Stats Row:** 4 stat cards in a row:
     - '50+' bars on waitlist
     - '3' cities launching (São Paulo, Rio, BH)
     - 'R$145+' economia/mês (No maquininha rental fees — save R$145+/month)
     - '0% taxa de setup' (0% setup fee — limited time)
   - Each stat: large number in gold, label in white, centered.

3. **FEATURES SECTION (The 'Why Dobar'):**
   - **Background:** #0A0A0A.
   - **Headline:** 'Tudo Que Seu Bar Precisa. Nada Que Não Precisa.' (Everything Your Bar Needs. Nothing It Doesn't.)
   - **Subheadline:** Muted gray, brief description.
   - **Feature Cards (4 columns on desktop, 2x2 grid on tablet, stacked on mobile):
     - **Card 1 - 'Pedidos Sem Fila' (Queue-Free Orders):**
       - Icon: `Smartphone` in gold circle container
       - Title: White, bold
       - Description: 'Clientes pedem direto da mesa. Sem app para instalar. Sem filas no balcão.' (Customers order from table. No app to install. No lines.)
     - **Card 2 - 'Pagamento Instantâneo' (Instant Payment):**
       - Icon: `Zap` in gold circle container
       - Title: White, bold
       - Description: 'PIX integrado. Dinheiro na conta em segundos. Sem aluguel de maquininha (economia de R$145+/mês), sem taxas escondidas.' (Integrated PIX. Money in account in seconds. No card machine rental fees, no hidden charges.)
     - **Card 3 - 'Taxas Menores' (Lower Fees):**
       - Icon: `Wallet` in gold circle container
       - Title: White, bold
       - Description: 'Sem aluguel de maquininha (economia de R$145+/mês). PIX com taxas menores que cartão. Google Pay, Apple Pay e cartão integrados.' (No card machine rental. Lower PIX fees than credit cards. Google Pay, Apple Pay integrated.)
     - **Card 4 - 'Marketing Automático' (Automatic Marketing):**
       - Icon: `TrendingUp` in gold circle container
       - Title: White, bold
       - Description: 'Campanhas inteligentes, happy hours digitais e retenção de clientes sem esforço.' (Smart campaigns, digital happy hours...)
   - Cards: Dark surface (#1A1A1A), rounded corners (12px), subtle border (#2C2C2C), padding 24px. Hover: slight gold glow border. Grid: 4 columns desktop, 2x2 tablet, stacked mobile.

4. **HOW IT WORKS SECTION:**
   - **Background:** #0A0A0A with subtle diagonal gold gradient lines pattern (very subtle, 5% opacity).
   - **Headline:** 'Em 3 Passos, Seu Bar Está Pronto' (In 3 Steps, Your Bar Is Ready)
   - **Steps Timeline (Vertical on mobile, horizontal on desktop):**
     1. **Step 1:** Number '01' in gold, large. Title 'Cadastre-se' (Sign Up). Description: 'Reserve sua vaga na lista de espera em 30 segundos.'
     2. **Step 2:** Number '02' in gold. Title 'Receba Acesso' (Get Access). Description: 'Nossa equipe entrará em contato para onboarding personalizado.'
     3. **Step 3:** Number '03' in gold. Title 'Comece a Vender' (Start Selling). Description: 'Configure seu cardápio digital e comece a receber pedidos no mesmo dia.'
   - Connect steps with a gold gradient line or dotted path.

5. **WAITLIST FORM SECTION (The Conversion Point):**
   - **Background:** Elevated card (#121212) with a subtle gold border glow.
   - **Headline:** 'Garanta Sua Vaga Agora' (Secure Your Spot Now)
   - **Subheadline:** 'Vagas limitadas para o lançamento. Cadastro 100% gratuito.' (Limited spots for launch. 100% free signup.)
   - **Form Fields:**
     - Bar Name input: Dark input (#1A1A1A), gold focus border, `Store` icon prefix.
     - Your Name input: `User` icon prefix.
     - Email input: `Mail` icon prefix.
     - WhatsApp input: `Phone` icon prefix, masked for Brazilian format.
     - City dropdown: Select from 'São Paulo', 'Rio de Janeiro', 'Belo Horizonte', 'Outra' (Other).
   - **Submit Button:** Full-width gold gradient CTA, 'Entrar na Lista de Espera', 56px height. Show loading spinner on submit.
   - **Trust Badges:** Below form — `ShieldCheck` icon + 'Seus dados estão seguros' (Your data is secure), `Lock` icon + 'Sem spam, prometemos' (No spam, we promise).
   - **Success State:** After submit, show green success card with `CheckCircle` icon, 'Você está na lista!' message, and 'Compartilhe com outros donos de bar' share buttons (WhatsApp, Instagram).

6. **FAQ SECTION:**
   - **Background:** #0A0A0A.
   - **Headline:** 'Perguntas Frequentes' (FAQ)
   - **Accordion Items (5 questions):**
     1. 'Quanto custa para usar o Dobar?' → Answer explaining: no monthly fees, no maquininha rental (saves R$145+/mês), lower transaction fees than traditional card machines (PIX rates vs 2-3% credit card fees), transparent per-transaction pricing.
     2. 'Preciso de equipamento especial?' → No, works on any smartphone/tablet.
     3. 'Como funciona o pagamento?' → PIX instant, credit card next-day.
     4. 'E se eu já tiver outro sistema?' → Easy migration, dual-run possible.
     5. 'Quando o lançamento oficial?' → Expected Q2 2025, waitlist gets early access.
   - Style: Dark cards (#1A1A1A), white question text, muted answer text. Chevron rotates on expand.

7. **FOOTER:**
   - **Background:** #0A0A0A with top border (#2C2C2C).
   - Logo small, centered.
   - Links row: 'Sobre', 'Termos', 'Privacidade', 'Contato' — in muted gray.
   - Social icons: Instagram, LinkedIn (placeholder).
   - Copyright: '© 2025 Dobar. Todos os direitos reservados.'

**ANIMATIONS & MICRO-INTERACTIONS:**
- Hero: Subtle floating particle network animation in gold (low opacity) behind content.
- Hero CTA: Shimmer sweep animation on the gold button (loop every 3s).
- Feature cards: Stagger fade-in from bottom on scroll (Intersection Observer).
- Stats numbers: Count-up animation when scrolled into view.
- FAQ accordion: Smooth height transition + chevron rotation.
- Form inputs: Gold border glow on focus.
- Submit button: Scale down 0.97x on press, spring back.
- Success state: Confetti burst (subtle, gold particles) on form submission.

**RESPONSIVE BEHAVIOR:**
- Desktop: Max-width 1200px, centered. Multi-column layouts.
- Tablet: 2-column grids where applicable.
- Mobile: Single column, full-width elements. Stacked navigation. Hamburger menu if needed (simple anchor links for single-page).

**TECHNICAL NOTES:**
- Build as responsive HTML/CSS/JS (for Lovable/Stitch).
- Use Lucide icons throughout.
- Form submission: POST to `/api/waitlist` endpoint (mock for now, show success state).
- All animations should be CSS-based with minimal JS for performance.
- Dark mode only — no light mode toggle needed for landing page.
- Copy should be in Brazilian Portuguese (pt-BR).
- Keep all strings in a config object for easy editing (i18n-ready structure).

**CALL-TO-ACTION HIERARCHY:**
Primary: Join Waitlist (gold button, appears 3x on page)
Secondary: Share with other bar owners (social share)
Tertiary: Login (for those with existing invites)"


---

### Business Details Editing Form
"Build a premium, full-screen Business Details editing form for bar owners and administrators in the **Dobar/Barz** business app.

**CONTEXT:**
This form appears when a bar owner taps 'Business Details' from the Business Settings page. It allows them to view and edit their bar's core profile information. The data is fetched from `GET /bars/{bar_id}/details` and saved via `PUT /bars/{bar_id}/details`.

**BACKEND DATA MODEL (Bar table):**
The bar model stores the following fields that the user can edit:

| Field | Type | Description |
|-------|------|-------------|
| `bar_name` | String | Bar name / establishment name |
| `description` | String | Bar description (free text, for profile) |
| `category` | String | `bar`, `restaurant`, `club`, `lounge`, `pub`, `brewery` |
| `address` | String | Full street address |
| `city` | String | City |
| `state` | String | State/province |
| `country_code` | String | ISO 3166-1 alpha-2 (e.g. 'BR', 'US') |
| `latitude` | Float | GPS latitude |
| `longitude` | Float | GPS longitude |
| `timezone` | String | IANA timezone (e.g. 'America/Sao_Paulo') |
| `business_id` | String | CNPJ (Brazil), NIF, EIN, etc. |
| `business_id_type` | String | Type: 'CNPJ', 'NIF', 'EIN', 'CIF', etc. |
| `state_registration` | String | Inscrição Estadual (Brazil-specific) |
| `logo_url` | String? | Logo image URL |
| `cover_url` | String? | Cover photo URL |
| `photo_urls` | String[]? | Gallery photos |
| `operating_hours` | JSON | Per-day schedule with open/close times |
| `location_method` | String | `table_number`, `spot_list`, `free_text` |

**OVERALL VIBE**: Professional, authoritative, and clean. 'Industrial Modern' design language — deep blacks (#0A0A0A), matte gray cards (#121212), and electric gold (#FFDE59) accents. The form should feel like a mission-control dashboard for the bar's identity.

**DESIGN SPECS:**

1. **HEADER:**
   - Back arrow to return to Settings page.
   - Title: 'Business Details' in bold.
   - 'Save' button (gold, text only) in the top-right — disabled until changes are detected.
   - Show an unsaved changes indicator (yellow dot or '● UNSAVED' badge) when form has pending edits.

2. **PROFILE IMAGE SECTION (Hero Area):**
   - Large circular cover image placeholder at top (use a `Camera` icon overlay if no image).
   - Below it, a smaller circular logo placeholder.
   - Tapping either opens an action sheet: 'Take Photo', 'Choose from Gallery', 'Remove Photo'.
   - On hover: subtle gold glow border around the images.

3. **BASIC INFORMATION SECTION:**
   - **Bar Name** — Large title input, Space Grotesk font, bold.
   - **Description** — Multi-line text area, character counter (max 500), hint: 'Describe your bar's atmosphere...'
   - **Category** — Dropdown/selector with options: Bar, Restaurant, Club, Lounge, Pub, Brewery. Use `Tag` icon.
   - **Phone** — Phone input with country code prefix, `Phone` icon.
   - **Email** — Email input, `Mail` icon.

4. **LOCATION SECTION:**
   - **Address** — Full address text input, `MapPin` icon.
   - **City** — Text input.
   - **State** — Dropdown or text input.
   - **Country** — Read-only display of current country code with flag emoji.
   - **Coordinates** — Small row showing latitude/longitude with a 'Pin on Map' gold ghost button. On tap, show a map picker modal (placeholder for now — show a dark container with 'Map integration coming soon' text).

5. **BUSINESS REGISTRATION SECTION:**
   - **Business ID (CNPJ/NIF/EIN)** — Masked input, format depends on country. Show the type badge next to it (e.g. 'CNPJ', 'NIF'). Use `FileText` icon.
   - **State Registration** — Optional text input, `ScrollText` icon.
   - **Verification Status** — Read-only pill badge: green '✅ Verified', yellow '⏳ Pending Review', red '❌ Rejected', gray '⬜ Not Submitted'.

6. **MEDIA GALLERY SECTION:**
   - Horizontal scrollable row of photo cards (120x120px, rounded corners 8px).
   - Each card: thumbnail with a small '×' remove button in the top-right corner.
   - Last card: dashed border 'Add Photo' placeholder with `Plus` icon.
   - Show up to 6 photos.

7. **OPERATING HOURS SECTION:**
   - Toggle: 'Same hours every day' (default: off).
   - When off: Show all 7 days as rows. Each row: day name (bold) → open time picker → close time picker → 'Closed' toggle.
   - When 'Same hours every day' is on: Show a single row for 'General Hours' with open/close time pickers.
   - Time pickers: Tap opens a time selector (HH:MM format, 24h). Use `Clock` icon.
   - Closed days: grayed out row with a 'Closed' badge.

8. **PLACE LOCATION LOGIC SECTION:**
   - **Location Method** — Dropdown: 'Table Number' (default), 'Spot List', 'Free Text'.
   - If 'Table Number' selected: subtitle hint 'Customers enter their table number manually.'
   - If 'Spot List' selected: show an editable list of spots (e.g. 'VIP Area', 'Terrace', 'Counter'). Each spot has a name + delete button. Add new spot input at bottom with `Plus` icon.
   - If 'Free Text' selected: subtitle hint 'Customers describe where they are sitting.'

**INTERACTIONS & RESPONSIVE BEHAVIOR:**
- Form adapts to screen width: single column on mobile, two-column grid on desktop for paired fields (City + State, Open + Close times).
- All text inputs use dark card style (#121212 background, gold focus border, 12px border radius).
- Unsaved changes prompt: If user tries to go back with unsaved changes, show a bottom sheet 'Discard changes?' with Cancel/Discard buttons.
- On save success: show a green snackbar 'Business details updated successfully!'
- On save error: show red snackbar with error message.
- Loading state: shimmer placeholders for all fields while data is fetching.
- Error state: centered error message with retry button.

**ICONS (Lucide):** `Store`, `MapPin`, `Phone`, `Mail`, `Tag`, `Clock`, `Image`, `Camera`, `Plus`, `FileText`, `ScrollText`, `Map`, `Globe`, `CheckCircle`, `X`.

**ANIMATIONS:**
- Sections stagger-fade in from bottom on page load (100ms delay between each section).
- Input focus: gold border animates in (200ms ease).
- Save button: shows `CircularProgressIndicator` while saving, then checkmark animation on success.
- Photo cards: scale up 1.02x on hover/tap.

**TECHNICAL NOTE:**
- Build as a Flutter `StatefulWidget` with form state management (use `GlobalKey<FormState>`).
- Use our design tokens: `barzGold` (#FFDE59), `barzDark` (#0A0A0A), `barzDarkLight` (#121212), `barzDarkCard` (#1A1A1A), `textOnDark` (#FFFFFF), `textSecondary` (#B0B0B0), `errorRed` (#FF4B4B), `successGreen` (#28A745).
- All strings must use our i18n system via `AppLocalizations.of(context)!` (placeholder: use comments `// i18n`).
- Use Lucide icons from the `lucide_icons` package.
- Match the existing `_SettingItem` pattern from our Business Settings page for consistency."

---

### Contact Settings Editing Form
"Build a premium, full-screen Contact Settings editing form for bar owners and administrators in the **Dobar/Barz** business app.

**CONTEXT:**
This form appears when a bar owner taps 'Contact Settings' from the Business Settings page. It allows them to manage how customers can reach their bar. Data is fetched from `GET /bars/{bar_id}/contact` and saved via `PUT /bars/{bar_id}/contact`.

**BACKEND DATA MODEL (Contact fields):**
The following contact fields should be editable in this form:

| Field | Type | Description |
|-------|------|-------------|
| `phone` | String | Primary phone number (for calls) |
| `email` | String | Contact email address |
| `website` | String? | Bar's website URL |
| `instagram` | String? | Instagram handle (e.g. '@baxibar') |
| `facebook` | String? | Facebook page name |
| `whatsapp` | String? | WhatsApp number for orders |
| `whatsapp_enabled` | Boolean | Whether WhatsApp ordering is active |

**OVERALL VIBE**: Clean, professional, and approachable. Same 'Industrial Modern' design language: deep blacks (#0A0A0A), matte gray cards (#121212), and electric gold (#FFDE59) accents. This should feel like configuring your bar's communication hub.

**DESIGN SPECS:**

1. **HEADER:**
   - Back arrow to return to Settings page.
   - Title: 'Contact Settings' in bold.
   - 'Save' button (gold, text only) in the top-right — disabled until changes are detected.
   - Show '● UNSAVED' badge when form has pending edits.

2. **PHONE & EMAIL SECTION:**
   - **Phone Number** — Full phone input with country code selector and `Phone` icon. E.164 format.
   - **Email** — Email input with `Mail` icon. Validation: must be valid email format.
   - Each field as a dark card (#121212) row with icon on left, input on right.

3. **SOCIAL MEDIA SECTION:**
   - Section header: 'Social Media' with `Share2` icon — subtitle: 'Connect with customers on social platforms.'
   - **Website** — URL input with `Globe` icon. Placeholder: 'https://yourbar.com'.
   - **Instagram** — Text input with `Camera` icon. Prepend '@' symbol automatically. Placeholder: '@yourbar'.
   - **Facebook** — Text input with `Facebook` icon. Placeholder: 'yourbarofficial'.
   - Each row: dark card with platform-branded icon on the left, input field on the right.
   - Below each input: small muted text showing how it will appear to customers (e.g. 'Customers will see @yourbar on your bar profile').

4. **WHATSAPP ORDERING SECTION:**
   - Special highlighted card with a subtle green tint (WhatsApp brand color #25D366 at 5% opacity) and green left border accent.
   - **WhatsApp Number** — Phone input with `MessageCircle` icon (WhatsApp green color for the icon).
   - **Enable WhatsApp Orders** — Toggle switch `ToggleRight` icon. When enabled:
     - Show a green success pill: '● WhatsApp Orders Active'
     - Show a preview chip showing how the WhatsApp button will appear to customers.
     - Subtitle: 'Customers can start an order conversation via WhatsApp.'
   - When disabled: show a muted gray state with 'WhatsApp ordering is disabled' text.

5. **CONTACT VISIBILITY SECTION:**
   - Section header: 'Contact Visibility' with `Eye` icon.
   - **Show Phone on Profile** — Toggle switch. Default: on.
   - **Show Email on Profile** — Toggle switch. Default: on.
   - Each toggle: dark card row with icon + label + switch.
   - Below each toggle: 'Your phone number will be visible to customers browsing your bar.'

6. **CONTACT PREVIEW CARD:**
   - At the bottom of the form, a live preview card showing how the contact info will appear on the customer-facing bar profile.
   - Use glassmorphism effect: frosted background with slight blur.
   - Display:
     - Phone icon + formatted phone number
     - Mail icon + email
     - Globe icon + website link
     - Instagram icon + handle
     - WhatsApp green button (only if enabled)
   - This preview updates in real-time as the user types.

**INTERACTIONS & RESPONSIVE BEHAVIOR:**
- Input fields use dark card style (#121212 background, gold focus border, 12px border radius).
- Phone fields use masked input with country code (Brazil +55 default).
- Instagram field auto-prepends '@'.
- Website field auto-prepends 'https://' if missing on save.
- Unsaved changes prompt: bottom sheet if user navigates back with pending edits.
- On save success: green snackbar 'Contact settings updated!'
- On save error: red snackbar with error.
- Loading state: shimmer placeholders.
- Error state: centered error with retry button.

**ICONS (Lucide):** `Phone`, `Mail`, `Globe`, `Camera`, `Facebook`, `MessageCircle`, `Eye`, `EyeOff`, `ToggleRight`, `Share2`, `CheckCircle`, `Save`.

**ANIMATIONS:**
- WhatsApp section: when toggle is switched on, the preview card and green pill animate in with a slide-down + fade (300ms).
- Preview card updates: crossfade animation when contact fields change.
- Input focus: gold border animates (200ms ease).
- Save button: loading spinner → checkmark on success.

**TECHNICAL NOTE:**
- Build as a Flutter `StatefulWidget` with `GlobalKey<FormState>`.
- Use design tokens: `barzGold` (#FFDE59), `barzDark` (#0A0A0A), `barzDarkLight` (#121212), `barzDarkCard` (#1A1A1A), `whatsappGreen` (#25D366), `textOnDark` (#FFFFFF), `textSecondary` (#B0B0B0).
- All strings must use our i18n system via `AppLocalizations.of(context)!` (placeholder: use comments `// i18n`).
- Use Lucide icons from the `lucide_icons` package.
- Match the existing `_SettingItem` pattern from our Business Settings page for consistency with the section layout."

---

### Menu Reader Page Redesign
"Build a premium, high-tech Menu Reader page for bar owners and staff in the **Dobar/Barz** business app.

**CONTEXT:**
Bar owners use this tool to digitize their physical menus. They can scan a paper menu using their camera, upload an image from their gallery/PC, or provide a URL (e.g., to a PDF or Instagram menu). The backend uses AI to extract products, prices, and descriptions.

**OVERALL VIBE:** High-tech, precise, and premium. Industrial Modern aesthetic: deep blacks (#0A0A0A) for dark mode and soft cream/white (#FFFDE7) for light mode, with electric gold (#FFDE59) accents. The UI should feel like an advanced scanner/vision tool.

**PAGE STRUCTURE:**

1. **HEADER:**
   - Title: 'Import Menu' or 'Menu AI Scanner'.
   - Subtle back button.
   - Use Lucide icons: `ScanLine`, `Maximize`.

2. **INITIAL STATE (Input Selection):**
   - **Hero Area:** A stylized, high-end scanner icon (Lucide `ScanEye` or `Sparkles`) with a soft gold radial glow.
   - **Main Heading:** 'How would you like to digitize your menu?'
   - **Action Cards:** Three large, modern cards for the main input methods:
     - **Camera:** 'Scan Physical Menu' — uses `Camera` icon.
     - **Gallery/PC:** 'Upload Image' — uses `ImagePlus` icon.
     - **URL Link:** 'Import from URL' — uses `Link2` icon.
   - Each card should feel premium, with a subtle gold border on hover and a clear description.

3. **URL INPUT VIEW:**
   - If URL is selected, show a sleek input field within a dark/light card.
   - Input: Gold focus border, `Globe` icon prefix.
   - Subtext: 'Supports Instagram, PDF links, and website menus.'
   - CTA: 'Analyze Menu' — gold gradient button.

4. **IMAGE PREVIEW VIEW:**
   - Once a photo is taken or selected, show it in a large, rounded container with 'scanning' artifacts (e.g., animated gold corner brackets).
   - Primary CTA: 'Extract Menu Data' (Gold background).
   - Secondary: 'Retake Photo' (Ghost button).

5. **ANALYZING STATE (Loading):**
   - A sophisticated 'AI Analysis' screen.
   - Animation: A golden beam sweeping across a document icon or a pulse effect.
   - Text: 'Our AI is reading your menu... this usually takes 10-20 seconds.'
   - Lucide icon: `BrainCircuit` or `Sparkles`.

6. **TIPS SECTION (Bottom):**
   - A 'Pro Tips for Best Results' section with a lightbulb icon.
   - Tips: 'Ensure good lighting', 'Keep the menu flat', 'Avoid glare'.
   - Design: Minimalist list with small gold bullet points.

**ANIMATIONS & MICRO-INTERACTIONS:**
- Staggered entrance for the selection cards.
- When an image is being 'analyzed', show a scanner beam animation (top to bottom) over the preview.
- Smooth transitions between the option cards and the input views.
- Buttons scale down slightly on press.

**TECHNICAL NOTE:**
- Support both **Light** and **Dark** themes.
- Use our design tokens: `barzGold` (#FFDE59), `barzDark` (#0A0A0A), `barzDarkLight` (#121212).
- Use Lucide icon library.
- Preserves the existing functionality: camera capture, gallery selection, and URL input.
- Match the naming conventions from the existing implementation: `ExtractMenuFromImage`, `ExtractMenuFromUrl`."

---

### Cart Best Prompt We Made So Far
"Build me a premium shopping cart component for a bar/nightlife ordering app.

I want a dark and gold aesthetic with these exact colors:
- Gold/Yellow: #FFDE59 (for prices, accents, primary buttons)
- Black: #0A0A0A (dark mode background)
- Cream white: #FFFDE7 (light mode background)
- Card surfaces: Pure white #FFFFFF with very subtle shadows

The cart should have:

CART ITEMS SECTION:
- Each item is a white card with rounded corners (16px radius)
- Product thumbnail on the left (80x80px, rounded 12px)
- Name in bold black text next to image
- Short description underneath in gray
- Price displayed in the gold color
- A quantity control on the right side with circular + and - buttons that have a gold border
- The number between the buttons
- Way to remove items (trash icon or swipe gesture)

COUPON CODE SECTION:
- A text input where users can type coupon codes
- "Apply" button next to it, gold background with black text
- When a coupon is applied, show the discount with a checkmark

ACTIVE PROMOTIONS:
- Show any cashback or promotions the user has activated
- Each as a small card with toggle switch
- Show the benefit (like "5% cashback")

BOTTOM AREA:
- Order summary with subtotal, any discounts, and final total
- Big gold "Checkout" or "Proceed to Payment" button

Make it support both light and dark mode. The aesthetic should feel premium and modern, like a high-end fintech app meets nightlife energy."

---

### Subscription Plans Page — Premium Refinement (NEW)
"Build me a premium, animated subscription plans page for bar owners in the Dobar/Barz nightlife ordering app. This is the business-facing 'Choose Your Plan' page where bar owners pick their subscription tier (Regular, Master, VIP) to unlock advertising features, lower commission rates, and marketing tools.

I want a dark luxury nightlife aesthetic — think high-end fintech meets VIP club. Use these exact colors:
- Background: #0A0A0A (dark mode deep black)
- Card surfaces: #121212 (matte dark gray), #1A1A1A (card dark)
- Gold accent: #FFDE59 (for prices, CTAs, highlights, active states)
- Gold gradient: #FFFFDF73 → #FFFFC000
- Success green: #00B37E (for checkmarks, active status)
- Error red: #FF4B4B (for destructive actions)
- Text primary: #FFFFFF (white)
- Text secondary: #B0B0B0 (muted gray)
- Icons: Lucide icon library

The page should have these sections:

1. **HEADER:**
   - Page title 'Subscription Plans' in bold white
   - Back button (chevron-left)
   - Right action: 'Try Pro Free' ghost gold text button (opens the free trial modal)
   - Subtle gold gradient underline below the header

2. **CURRENT PLAN STATUS CARD (if user has active subscription):**
   - Dark card (#121212) with rounded corners (12px)
   - Green check-circle icon + 'Your Current Plan' label
   - Plan name badge in gold pill on the right (e.g. 'MASTER')
   - Valid until date in muted text
   - Animated border: subtle gold pulse on the card edge when near renewal

3. **TRIAL STATUS CARD (if user has active trial):**
   - Dark card (#121212) with a subtle gold left border accent (3px)
   - 'Free Trial Active' heading
   - Trial end date in muted text
   - 'Capture Payment' button — gold outlined, becomes primary when trial is about to expire
   - Countdown timer showing days remaining in trial (e.g. '3 days left' in gold, 'Expired' in red)

4. **PLANS LIST — THREE TIER CARDS (Regular, Master, VIP):**
   Each plan card should be a dark card (#1A1A1A) with rounded corners (16px) and subtle border (#2C2C2C). The VIP card should have a gold border (2px) and a 'Most Popular' gold banner at the top.

   Each card layout:
   - **Top banner** (only for VIP): 'MOST POPULAR' in gold background, black bold text — slight shimmer animation
   - **Plan name** in bold white (20px) — left side
   - **Price** in gold bold (24px) + '/mo' in muted text — right side
   - **Commission rate** in muted text below price (e.g. 'Commission: 5%')
   - **Feature list** with gold check-mark icons:
     - Each feature on its own row
     - Green check-circle icon on the left (18px)
     - Feature text in white on the right
     - Subtle staggered entrance animation (each feature fades in with 50ms delay)
   - **Annual pricing toggle**: When toggled, show 'R$ XX/mês (billed annually)' — highlight savings with a green 'Save 20%' badge.
   - **CTA button** at bottom:
     - If current plan: disabled outlined button showing 'Current Plan'
     - If not current: full-width gold gradient button (for VIP) or dark button (for Master/Regular) with white text
     - Button text: 'Choose {Plan Name}' or 'Upgrade to {Plan Name}' if upgrading

5. **PLAN COMPARISON SECTION** (expandable below the cards):
   - Collapsed state: 'Compare all features' text link with chevron-down icon
   - Expanded state: a table comparing all 3 tiers side by side
   - Rows: commission rate, advertising credits, support level, search boost, map spotlight, dedicated manager
   - Each cell: checkmark (green) or dash (gray)
   - Animated expand/collapse with smooth height transition (300ms)

6. **PRO UPSEL BANNER** (for non-subscribed users):
   - Full-width gradient banner (gold gradient)
   - 'Unlock the full power of Dobar' heading in black text
   - 'Boost your bar's visibility, lower your costs, and attract more customers.' subtitle
   - 'View Plans' ghost button (dark background, white text)

7. **FREE TRIAL MODAL** (full-screen bottom sheet):
   - Slides up with spring animation (bouncy iOS-style)
   - Sheet handle: thin gray pill at top
   - Hero area: Gold gradient crown icon with 'Try Dobar Pro Free' heading
   - Plan selector: horizontal pill toggle — 'Master' | 'VIP' (gold active state)
   - Payment method section:
     - 'Payment Method' label
     - Card input row: saved cards dropdown (if any) or 'Add New Card' option
     - PIX option with QR code generation (when selected, show a PIX QR code placeholder with 'Pay via PIX' label)
     - Credit/Debit card option with card number, expiry, CVV fields in dark card style
   - Terms acceptance: small checkbox + 'I agree to the Terms of Service and authorize the card validation' text
   - Primary CTA: 'Start 7-Day Free Trial' — full-width gold gradient button, 56px height, black text
   - Subtext: 'No charge today. Your card will only be validated, not charged.'
   - Bottom links: 'Restore Purchase' · 'Terms & Privacy' in small muted text

8. **UPGRADE CONFIRMATION MODAL** (when selecting a higher tier):
   - Slide-up bottom sheet (not a dialog)
   - 'Upgrade Plan' title
   - Current plan info row (muted) with arrow icon pointing to new plan (gold)
   - Proration credit calculation breakdown:
     - Remaining days in current cycle
     - Prorated credit amount in green (e.g. '-R$ 33,30')
     - New plan price
     - Final amount due in bold gold
   - Payment method selector (same as trial modal)
   - 'Confirm Upgrade' gold gradient CTA button
   - 'Cancel' ghost text link

9. **PAYMENT REQUIRED DIALOG** (error state when payment is needed):
   - Dark bottom sheet with alert icon in red circle
   - 'Payment Required' heading
   - Error description
   - 'Update Payment Method' gold button
   - 'Retry' ghost button
   - 'Close' text link

**ANIMATIONS & MICRO-INTERACTIONS (CRITICAL):**
- Plan cards should stagger-animate in from bottom on page load (100ms delay per card)
- VIP card should have a subtle gold shimmer sweeping across the 'Most Popular' banner on a loop (3s cycle)
- Price toggle (monthly/annual): crossfade animation when switching (200ms)
- Feature items: fade in from left with staggered delay (50ms each)
- Trial countdown: animate number changes with a flip animation when days decrease
- Plan selection: selected card scales up 1.02x with a soft gold glow border
- Buttons: scale down 0.97x on press, spring back on release (250ms spring)
- Modal transitions: slide-up with spring animation, background overlay fades in (300ms)
- Upgrade proration: numbers should count up/down with an animated counter
- Payment method toggle: crossfade between card form and PIX QR code (300ms)
- Success state after upgrade/subscription: brief checkmark animation + confetti burst (gold particles)
- All micro-interactions should feel premium and polished — like a fintech app (Nubank, Revolut) meets nightlife energy

**ADDITIONAL DETAILS:**
- Support both **PIX** and **Credit/Debit Card** as payment methods — show them as horizontal pill toggles with icons (PIX icon + CreditCard icon)
- When PIX is selected, show a full-width QR code placeholder with 'Copia e Cola' text input below
- When Card is selected, show a modern card input form (card number masked, expiry, CVV) in dark card style
- Show a small 'saved cards' row if the user has previously saved payment methods — each as a small pill with last 4 digits and brand icon
- The page should feel like a premium checkout experience, not a basic settings form
- Use Lucide icons: `Crown`, `Star`, `Award`, `Zap`, `Check`, `CreditCard`, `QrCode`, `ChevronLeft`, `ChevronDown`, `ChevronUp`, `ArrowRight`, `Clock`, `Shield`, `Lock`, `Sparkles`, `Wallet`, `TrendingUp`, `BadgeCheck`, `Percent`, `Calendar`, `AlertCircle`, `CheckCircle`

Make it bright and eye-catching. The aesthetic should feel like upgrading to a premium nightlife experience — exclusive, powerful, and worth every cent."

---

### Campaigns Management Page (List + Analytics)
"Build a premium, high-impact Campaigns Management page for bar owners and administrators in the **Dobar/Barz** business app.

**CONTEXT:**
Dobar/Barz is a nightlife ordering platform where bar owners can run advertising campaigns to promote their venues. This page is the **mission control center** for all their campaigns — they list active and past campaigns, view performance at a glance, and tap into individual campaign analytics. The current implementation uses a simple bottom sheet for campaign creation; we are replacing that with a full multi-step campaign creation flow (see Prompt 2).

**OVERALL VIBE:** Professional, data-driven, and authoritative. Industrial Modern design: deep blacks (#0A0A0A), matte gray cards (#121212), sharp electric gold (#FFDE59) accents. Should feel like a high-end ad dashboard (think: Meta Ads Manager meets Google Analytics) but with nightlife energy.

**PAGE STRUCTURE:**

### 1. HEADER SECTION
- **Left**: Container with megaphone icon in gold gradient background + 'Campanhas' title + 'Gerencie suas campanhas de marketing' subtitle
- **Right (desktop) / Bottom (mobile)**: Account balance / credits chip showing available budget (e.g., 'Saldo: R$ 1.200,00')

### 2. VIP UPSELL BANNER (existing component, keep as-is)
- The VIP upsell banner for non-subscribed bars stays exactly where it is

### 3. CAMPAIGN FILTERS & ACTIONS BAR
- **Search**: Text input with search icon, placeholder 'Buscar campanhas...'
- **Filter chips**: Horizontal scrollable row — 'Todas' (default), 'Ativas', 'Pausadas', 'Concluídas', 'Rascunhos'
- **Sort**: Dropdown — 'Mais recentes', 'Orçamento (maior)', 'Orçamento (menor)', 'Performance'
- **Create Campaign CTA**: Gold gradient button 'Nova Campanha' with Plus icon (replaces the FAB on mobile, desktop has both)

### 4. CAMPAIGN GRID / LIST
Each campaign card shows:
- **Status badge** at top-right: green pill '● Ativa', yellow '● Pausada', gray '● Concluída', purple '● Rascunho'
- **Campaign name** in bold white text, 18px
- **Campaign type icons row**: small icons representing which placements are active (Star for featured, Search for search boost, MapPin for map, Flame for promo boost, Image for banner)
- **Budget progress bar**: thin animated bar showing % spent — gold fill for healthy, red fill if over 90% spent
- **Key metrics row** in small muted text: '1.2k impressões · 89 cliques · 4.2% CTR'
- **Two action buttons**: 'Analytics' ghost button with BarChart3 icon + '...' more options dropdown (Pause/Resume/Duplicate/Delete)
- **Card background**: #1A1A1A with rounded corners 12px, subtle border #2C2C2C
- **Hover state**: slight gold glow border
- **Empty state**: Large megaphone icon in gold (60% opacity), 'Nenhuma campanha ativa', subtitle 'Crie sua primeira campanha e comece a atrair mais clientes!', gold ghost CTA 'Criar Campanha'

### 5. EMPTY STATE (if no campaigns)
- Full-width illustration: large megaphone icon in gold, 80px
- 'Nenhuma campanha ainda' heading
- 'Crie sua primeira campanha para aparecer em destaque para milhares de clientes.' subtitle
- Gold gradient CTA button 'Criar Primeira Campanha'

### 6. ANALYTICS OVERVIEW SECTION (collapsible, below campaign list)
- Quick stats row: 4 metric cards in a row:
  - Total de impressões (large number, gold)
  - Total de cliques (number, white)
  - CTR médio (% , white)
  - Total investido (R$, gold)
- Each stat card: dark surface #121212, rounded 10px, small label in muted text below number

**INTERACTIONS:**
- Tapping a campaign card navigates to the campaign details/analytics view
- Tapping 'Nova Campanha' opens the multi-step campaign creation flow (Prompt 2)
- Status filter chips should animate active state with gold underline
- Empty state has a subtle floating animation on the megaphone icon (3s loop)
- Grid: responsive — 2 columns on wide screens, single column on narrow

**ANIMATIONS:**
- Cards stagger-fade in from bottom on load (80ms delay between cards)
- Budget progress bar animates from 0 to current value on mount
- Status badge has a subtle pulse animation when active
- Filter chips slide in from left on filter change

**ICONS (Lucide):** `Megaphone`, `Star`, `Search`, `MapPin`, `Flame`, `Image`, `BarChart3`, `MoreHorizontal`, `PauseCircle`, `PlayCircle`, `Copy`, `Trash2`, `Plus`, `Filter`, `Search`

**DESIGN TOKENS:**
```
Background:      #0A0A0A (barzDark)
Card Surfaces:   #121212 (barzDarkLight), #1A1A1A (barzDarkCard)
Gold Accent:     #FFDE59 (barzGold)
Gold Grad:       #FFFFDF73 -> #FFFFC000
Active Green:    #00B37E (pixGreen)
Paused Yellow:   #FFD93D
Draft Purple:    #7C3AED
Error:           #FF4B4B
Text Primary:    #FFFFFF
Text Secondary:  #B0B0B0
Font:            Space Grotesk (headings), system (body)
Icons:           Lucide icon library