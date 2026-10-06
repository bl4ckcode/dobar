# BARZ - Frontend Backend Communication

Last Updated: September 25, 2026
Backend Status: Live on Fly.io
API Base URL: https://barz-backend-bold-sun-5691.fly.dev

---

## SUBSCRIPTION LIFECYCLE (SPRINT 8 - NEW)

Status: **✅ COMPLETE**
Priority: CRITICAL - Revenue & Subscription UX

### Overview

Full subscription lifecycle support for Dobar PRO plans. Covers free trial setup with card validation (Stripe SetupIntents), deferred payment capture after trial expiry, and prorated mid-cycle plan upgrades with automatic credit calculation.

### 1. Start Free Trial

Validates the owner's card via Stripe SetupIntent ($0 auth) and starts a 7-day trial. No charge is made until `trial_ends_at` expires.

```
POST /subscriptions/trial/setup
Auth: Required (Access Token)
Headers:
  X-Idempotency-Key: "uuid-v4-string" (Recommended)

Body:
{
  "bar_id": 123,
  "owner_id": 456,
  "plan": "VIP",
  "trial_days": 7,
  "payment_method_id": "pm_card_visa",
  "customer_email": "owner@bar.com",
  "customer_name": "Carlos Alves",
  "metadata": {}
}

Response 200:
{
  "setup_intent_id": "seti_abc123",
  "status": "succeeded",
  "client_secret": "seti_abc123_secret_xyz",
  "stripe_customer_id": "cus_abc123",
  "trial_ends_at": "2026-04-21T02:00:00Z",
  "payment_method_id": "pm_card_visa"
}

Errors:
402 Payment Required: {"error": {"code": "PAYMENT_DECLINED", "message": "Card validation failed"}}
400 Bad Request: {"error": {"code": "BAD_REQUEST", "message": "Trial setup failed"}}
```

### 2. Capture Payment After Trial

Called by the backend scheduler when `trial_ends_at` expires. Can also be triggered manually by the frontend for immediate billing.

```
POST /subscriptions/capture
Auth: Required (Access Token)
Headers:
  X-Idempotency-Key: "uuid-v4-string" (Recommended)

Body:
{
  "payment_id": "seti_abc123",
  "amount_cents": 2990
}

Response 200:
{
  "payment_id": "seti_abc123",
  "status": "captured",
  "amount_cents": 2990,
  "gateway": "stripe",
  "captured_at": "2026-04-21T02:00:00Z"
}

Errors:
402 Payment Required: {"error": {"code": "PAYMENT_DECLINED", "message": "Capture failed"}}
```

### 3. Prorated Plan Upgrade

When a bar upgrades mid-cycle (e.g., Master → VIP on Day 15), the frontend calculates the remaining credit for unused days and sends it as `proration_info`. DPE automatically deducts the credit from the charge.

```
POST /payments/v2/charge/upgrade
Auth: Required (Access Token)
Headers:
  X-Idempotency-Key: "uuid-v4-string" (Required)

Body:
{
  "order_id": 0,
  "bar_id": 123,
  "amount": 99.90,
  "currency": "BRL",
  "country": "BR",
  "payment_method": {
    "type": "card",
    "token": "tok_xxx",
    "provider": "saved"
  },
  "proration_info": {
    "previous_plan": "Master",
    "new_plan": "VIP",
    "credit_amount_cents": 3330,
    "cycle_start": "2026-04-01T00:00:00Z",
    "cycle_end": "2026-04-30T23:59:59Z",
    "upgrade_date": "2026-04-15T12:00:00Z"
  }
}

Response 200 (Partial credit applied):
{
  "payment_id": "pay_abc123",
  "status": "succeeded",
  "gateway": "stripe",
  "gateway_id": "pi_xxx",
  "amount": 99.90,
  "currency": "BRL",
  "created_at": "2026-04-15T12:00:00Z",
  "proration_credit_cents": 3330
}

Response 200 (Full credit, no gateway charge):
{
  "payment_id": "pay_abc123",
  "status": "credit_applied",
  "gateway": "internal",
  "gateway_id": "proration_credit",
  "amount": 0.0,
  "currency": "BRL",
  "created_at": "2026-04-15T12:00:00Z",
  "proration_credit_cents": 5000
}

Errors:
422 Validation Error: proration_info is required for upgrade charges
402 Payment Required: {"error": {"code": "PAYMENT_DECLINED", "message": "Upgrade payment declined"}}
```

### FE Implementation

```dart
class SubscriptionRepository {
  final Dio _dio;

  Future<TrialSetupResult> startFreeTrial({
    required int barId,
    required int ownerId,
    required String plan,
    required String paymentMethodId,
    required String email,
    required String name,
  }) async {
    final res = await _dio.post('/subscriptions/trial/setup', data: {
      'bar_id': barId,
      'owner_id': ownerId,
      'plan': plan,
      'trial_days': 7,
      'payment_method_id': paymentMethodId,
      'customer_email': email,
      'customer_name': name,
    });
    return TrialSetupResult.fromJson(res.data);
  }

  Future<CaptureResult> capturePayment({
    required String paymentId,
    required int amountCents,
  }) async {
    final res = await _dio.post('/subscriptions/capture', data: {
      'payment_id': paymentId,
      'amount_cents': amountCents,
    });
    return CaptureResult.fromJson(res.data);
  }

  Future<ChargeResult> upgradePlan({
    required int barId,
    required double amount,
    required String currency,
    required String country,
    required String cardToken,
    required ProrationInfo proration,
  }) async {
    final res = await _dio.post('/payments/v2/charge/upgrade',
      data: {
        'order_id': 0,
        'bar_id': barId,
        'amount': amount,
        'currency': currency,
        'country': country,
        'payment_method': {
          'type': 'card',
          'token': cardToken,
          'provider': 'saved',
        },
        'proration_info': proration.toJson(),
      },
      options: Options(headers: {
        'X-Idempotency-Key': const Uuid().v4(),
      }),
    );
    return ChargeResult.fromJson(res.data);
  }
}
```

### Proration Credit Calculation (FE Helper)

```dart
int calculateProrationCredit({
  required int planPriceCents,
  required DateTime cycleStart,
  required DateTime cycleEnd,
  required DateTime upgradeDate,
}) {
  final totalDays = cycleEnd.difference(cycleStart).inDays;
  final usedDays = upgradeDate.difference(cycleStart).inDays;
  final remainingDays = totalDays - usedDays;
  return ((planPriceCents / totalDays) * remainingDays).round();
}
```

---

## DOBAR PRO & PRO BUSINESS (SPRINT 8 - NEW)

Status: **✅ COMPLETE**
Priority: CRITICAL - Revenue & Core Business Logic

### Overview

Sprint 8 introduces backend capabilities for the Dobar PRO (consumer) and Dobar PRO Business subscription tiers, including priority order processing, business search ranking boosts, and segmented push notifications. Also includes a major RBAC stabilization migrating legacy user objects to the unified `AuthUser` dataclass.

### 1. Consumer PRO Features

**Priority Orders & Cashback:**
- Users with `subscription_tier = "pro"` automatically receive the `is_priority = true` flag on their orders during checkout.
- Pro users receive a 10% cashback boost compared to the standard 5%.
- App UI must handle the new priority flag to render UI feedback for Pro users.

### 2. PRO Business & Discovery

**Search Ranking Boost:**
Premium tiers (`master`, `vip`, `pro`) appear appropriately higher in search results, giving premium businesses maximum visibility regardless of strict distance sorting.

**Segmented Campaigns:**
New `PUSH_NOTIFICATION` campaign type gated exclusively for Business Master and VIP tiers. 

### 3. Auth & RBAC Stabilization

All middleware and protected routes now strictly implement the unified `AuthUser` dataclass. The backend is fully stable using dot-notation (`.id`) instead of legacy dictionary access.

---

## BAR CONTEXT HEADERS (BUSINESS / STAFF UI GATING - NEW)

Status: **✅ COMPLETE (Advertising + already-RBAC routes)**
Priority: MEDIUM - Lets the front-end decide what to show/hide for the active bar

### Overview

Every bar-scoped **business** endpoint (used by bar owners and their staff) that is protected with
`require_bar_role(...)` or `require_bar_permission(...)` now echoes three response headers on every
successful call. The front-end reads these once per request to gate UI elements for the currently
active bar — no extra API calls needed.

The headers are **purely additive** and the response body is unchanged, so this is fully backward
compatible.

### Header contract

| Header | Example | Meaning |
|---|---|---|
| `X-Bar-Id` | `42` | The bar the request operated on |
| `X-Bar-Role` | `owner` | User's role at that bar: `owner`, `admin`, `manager`, `cashier`, `staff` |
| `X-Bar-Permissions` | `ads:view,ads:manage,bar:view,...` | Comma-separated list of permission codes the user has at that bar |

### 1. On login / workspace entry

The front-end already fetches `GET /me/bars`, which returns each bar the user can access with its
`role` and `permissions`. Use this to build the global feature-flag map per bar.

### 2. On every bar-scoped business call

For the currently selected bar, the response also carries `X-Bar-Id`, `X-Bar-Role` and
`X-Bar-Permissions`. This lets the front-end switch a role or permission at runtime (e.g. if the
tab is stale) without a full re-login.

### FE implementation guide

```dart
final role = response.headers['x-bar-role'];          // 'owner', 'cashier', ...
final perms = (response.headers['x-bar-permissions'] ?? '').split(',');
final canManageAds = perms.contains('ads:manage');
final canViewAds = perms.contains('ads:view');

// Render contextual controls
if (canManageAds)  showAdsManager();
if (canViewAds)    showAdsDashboard();
```

### How to send `bar_id` on advertising routes

The advertising endpoints (`/advertising/*`) currently resolve the bar from the `?bar_id=...` query
parameter (kept for compatibility). They will also accept the `X-Bar-Id` request header as a
fallback, so new clients can standardize on the header:

```
GET /advertising/campaigns
X-Bar-Id: 42
X-Bar-Permissions: ads:view
```

### Permission split (Advertising)

Endpoints raised enforcement to the correct granularity:

- **View (read-only):** `GET /plans` (public), `GET /my-plan`, `GET /credits`, `GET /rates`,
  `GET /campaigns`, `GET /campaigns/{id}`, `GET /campaigns/summary`,
  `GET /campaigns/analytics-summary`, `GET /analytics`, `GET /analytics/{campaign_id}`,
  `GET /invoices` → require `ads:view`.
- **Manage (write):** `POST /subscribe`, `POST /campaigns`, `PUT /campaigns/{id}`,
  `POST /campaigns/{id}/publish`, `POST /campaigns/{id}/pause`,
  `POST /campaigns/{id}/resume`, `DELETE /campaigns/{id}` → require `ads:manage`.

Roles with these permissions today: **owner** and **admin** (manager and below are read-gated /
denied). If a manager should see ad analytics but not manage them, grant the `ads:view` custom
permission to that staff member.

---


## LEGAL DOCUMENTS (NEW)

Status: **✅ COMPLETE**
Priority: HIGH - Required for app store compliance

### Overview

Terms of Service and Privacy Policy are available in 3 languages for international support:
- **Portuguese (PT)** - Brazil
- **English (EN)** - North America
- **Spanish (ES)** - Latin America

### API Access

Static files served at `/legal/` endpoint:

```
GET /legal/TERMS_OF_SERVICE_PT.md
GET /legal/TERMS_OF_SERVICE_EN.md
GET /legal/TERMS_OF_SERVICE_ES.md

GET /legal/PRIVACY_POLICY_PT.md
GET /legal/PRIVACY_POLICY_EN.md
GET /legal/PRIVACY_POLICY_ES.md
```

### FE Implementation

```dart
Future<String> getLegalDocument(String type, String language) {
  // type: 'TERMS_OF_SERVICE' or 'PRIVACY_POLICY'
  // language: 'PT', 'EN', 'ES'
  final url = '$baseUrl/legal/${type}_$language.md';
  return dio.get(url).then((r) => r.data);
}

// Auto-detect device language
final deviceLocale = Platform.localeName; // e.g., 'pt_BR', 'en_US', 'es_MX'
final language = deviceLocale.startsWith('pt') ? 'PT' 
              : deviceLocale.startsWith('es') ? 'ES' 
              : 'EN';

final terms = await getLegalDocument('TERMS_OF_SERVICE', language);
```

### Content Coverage

**Terms of Service:**
- Service description (mobile ordering, payments, loyalty)
- Age requirements (18+ for alcohol)
- Payment methods (PIX, cards, wallets)
- Cashback program rules
- Liability disclaimers
- Governing law (Brazil)

**Privacy Policy:**
- Data collection (personal, payment, location, device)
- Data usage (orders, personalization, security)
- Data sharing (partners, payment processors)
- User rights (LGPD/GDPR compliance)
- Security measures (SSL/TLS encryption)

---

## SECURITY & AUTH (SPRINT 1 - NEW)

Status: **✅ COMPLETE**
Priority: CRITICAL - App Security & Compliance

### Multi-Factor Authentication (MFA)

**Overview:**
Users can enable MFA in their settings. Once enabled, login requires a second step (TOTP code).

**1. Setup MFA (Enable):**
```
POST /auth/mfa/setup
Auth: Required (Access Token)

Response 200:
{
  "secret": "JBSWY3DPEHPK3PXP",  // To display manual entry key
  "qr_code": "data:image/png;base64,..." // To display QR code
}
```

**2. Verify & Activate:**
User enters code from authenticator app to confirm setup.
```
POST /auth/mfa/verify
Auth: Required (Access Token)
Body: { "code": "123456" }

Response 200: { "message": "MFA verified and enabled", "recovery_codes": ["..."] }
```

**3. Login with MFA:**
When logging in (`/auth/google-login`, etc.), if user has MFA enabled:
```
Response 200 (Partial Auth):
{
  "mfa_required": true,
  "mfa_token": "temporary_mfa_token_string" 
  // NO access_token returned yet!
}
```

**4. Submit MFA Challenge:**
Use the `mfa_token` from login response + user's code.
```
POST /auth/mfa/challenge
Body: 
{ 
  "mfa_token": "temporary_mfa_token_string",
  "code": "123456" 
}

Response 200 (Full Auth):
{
  "access_token": "...",
  "refresh_token": "...",
  "user": { ... }
}
```

### Account Recovery

**Overview:**
If user loses MFA device, they can recover account via `Recovery Token`.

**1. Initiate Recovery:**
```
POST /auth/recovery/initiate
Body: { "email": "user@example.com" }

Response 200: { "message": "Recovery token sent to email if account exists" }
```

**2. Verify Recovery:**
User clicks link or enters token from email.
```
POST /auth/recovery/verify
Body: { "token": "received_token_string" }

Response 200:
{
  "access_token": "...",
  "message": "Account recovered. MFA has been disabled."
}
```

### Data Exclusion (LGPD/GDPR)

**1. Delete Account Data:**
Irreversible action. Deletes all user data across all services.
```
DELETE /me/data
Auth: Required

Response 200:
{
  "message": "User data permanently deleted",
  "receipt_id": "del_123456789"
}
```

---

## USER PROFILE SETTINGS (SPRINT 2 - NEW)

Status: **✅ COMPLETE**
Priority: HIGH - User Preferences & Privacy

### Onboarding Flow (IMPORTANT)

**New user detection:**
The backend returns `"is_new_user": true` in the `/auth/phone-login`, `/auth/google-login`, and `/auth/apple-login` responses whenever a user logs in for the first time.

**What the frontend MUST do with `is_new_user: true`:**

1. After login, immediately navigate to the **Onboarding Screen** — do NOT go to the Home/Dashboard.
2. On the onboarding screen, collect:
   - **User Type**: `"client"` (bar-goer) or `"business"` (bar owner/staff)
   - **Country Code**: ISO 3166-1 alpha-2 (use `GET /me/available-countries` for the picker)
3. Call `POST /me/onboarding` with those two fields.
4. Onboarding implicitly accepts Terms of Service and Privacy Policy.
5. After onboarding, the user may still need to view legal documents (see `GET /legal/` endpoints).

**Why this matters:**
If the frontend calls `GET /me/profile` before onboarding, the response will have `"user_type": null` and `"country_code": null`. These are intentionally `null` until the user completes onboarding, so the frontend **cannot** skip the onboarding step by reading defaults from the profile. Always use the `is_new_user` flag from the login response to decide whether to show onboarding.

If the frontend ignores `is_new_user` and proceeds directly to the home screen:
- `GET /me/profile` will return `user_type: null` and `country_code: null`
- The `/home` endpoint may return unexpected or empty results
- Payment gateway routing will have no country to use
- The user will not have accepted Terms or Privacy Policy (legal/compliance issue)

**Recommended approach:**
```dart
// After login response:
if (loginResponse.isNewUser) {
  Navigator.pushReplacement(context, OnboardingScreen());
} else {
  Navigator.pushReplacement(context, HomeScreen());
}

// Onboarding screen:
Future<void> completeOnboarding(String userType, String countryCode) async {
  await dio.post('/me/onboarding', data: {
    'user_type': userType,
    'country_code': countryCode,
  });
  // Optionally show legal documents before proceeding
  Navigator.pushReplacement(context, HomeScreen());
}
```


### Update Profile Fields

Allows updating the user's phone number and avatar URL (previously only name and email).

```
PUT /me/profile
Auth: Required (Access Token)

Body:
{
  "display_name": "Carlos",
  "phone_number": "+5531999990000",
  "avatar_url": "https://..."
}

Response 200:
{
  "display_name": "Carlos",
  "email": "carlos@example.com",
  "phone_number": "+5531999990000",
  "avatar_url": "https://...",
  "terms_accepted": true,
  "privacy_accepted": true,
  "user_type": "client",
  "country_code": "BR",
  "subscription_tier": "regular",
  "is_pro": false,
  "location_mismatch": false
}

```
*Note: Editing a phone number to one that is already in use returns `409 Conflict` (`PHONE_IN_USE`).*

### Update User Country (CROSS-BORDER) [NEW]

Syncs the user's registered `country_code` with their current physical location.

```
POST /me/update-country
Auth: Required (Access Token)

Body:
{
  "latitude": -19.921,
  "longitude": -43.933
}

Response 200:
{
  "old_country": "US",
  "new_country": "BR",
  "status": "updated"
}
```

### Notification Preferences

Controls whether the user receives push notifications, order updates, or promotions.

```
GET /me/notification-preferences
Auth: Required

Response 200:
{
  "push_notifications_enabled": true,
  "order_updates_enabled": true,
  "promotions_enabled": true
}
```

```
PUT /me/notification-preferences
Auth: Required
Body is same as GET response.
```

### Privacy Settings

Controls data sharing and location tracking permissions.

```
GET /me/privacy-settings
Auth: Required

Response 200:
{
  "data_sharing_enabled": false,
  "location_enabled": false
}
```

```
PUT /me/privacy-settings
Auth: Required
Body is same as GET response.
```

---

## TRENDING DRINKS (UPDATED)

Status: **✅ COMPLETE**
Priority: MEDIUM - Home page drinks discovery

### Overview

Display trending drinks on home page with properly signed S3 image URLs.

### API Contract

```
GET /menus/trending/drinks?latitude=X&longitude=Y&type=most_wanted&limit=10

Query Params:
| Param | Type | Description |
|-------|------|-------------|
| latitude | float | User location (optional) |
| longitude | float | User location (optional) |
| type | string | `most_wanted` or `hottest` (default: most_wanted) |
| limit | int | Max results (default 10) |

Response 200:
{
  "drinks": [
    {
      "id": 1,
      "name": "Moscow Mule",
      "price_avg": 32.00,
      "bar_name": "Baxo Bar",
      "bar_id": 16,
      "image_url": "https://barz-images.s3.amazonaws.com/seed/moscowmule.jpeg?AWSAccessKeyId=...",
      "order_count": 150,
      "is_promoted": false
    }
  ]
}
```

### Hottest Algorithm (DOB-47)

The `hottest` list is no longer random. It is calculated by the **highest discount percentage** relative to the original price.

**SQL Logic:** `ORDER BY ((price - promotional_price) / price) DESC` 

Items must have a `promotional_price` and be `available` to appear in this list.

### Image Handling

**Backend:**
- Automatically generates presigned S3 URLs (1-hour expiration)
- Handles null images gracefully (returns null in response)
- Signs only S3 URLs (leaves external URLs unchanged)

**Frontend:**
- Use `image_url` directly from API response
- Handle null images with placeholder
- Refresh data periodically to get fresh signed URLs

```dart
class TrendingDrink {
  final int id;
  final String name;
  final double priceAvg;
  final String barName;
  final int barId;
  final String? imageUrl; // Can be null
  final int orderCount;
  final bool isPromoted;
}

// In UI
CachedNetworkImage(
  imageUrl: drink.imageUrl ?? '',
  placeholder: (context, url) => Icon(Icons.local_bar),
  errorWidget: (context, url, error) => Icon(Icons.broken_image),
)
```

---

## HOME DASHBOARD (NEW)

Status: **✅ COMPLETE**
Priority: HIGH - Performance & Scalability

### Overview

Aggregates all data required for the initial Home screen load to reduce multiple round-trips and waterfall requests.

### API Contract

```
GET /home?latitude=X&longitude=Y

Query Params:
| Param | Type | Description |
|-------|------|-------------|
| latitude | float | User latitude (optional) |
| longitude | float | User longitude (optional) |

Response 200:
{
  "user_status": {
    "active_cart": { ... },
    "unread_notifications": 5 // REAL COUNT: Based on DB notifications (is_read=false)
  },
  "nearby_bars": [
    {
      "id": 15,
      "name": "Bar do João",
      "image_url": "https://...",
      "distance_meters": 350.5,
      "rating": 4.5,
      "is_open": true
    }
  ],
  "trending_drinks": {
    "most_wanted": [
      {
        "id": 101,
        "name": "Caipirinha",
        "price": 12.00,
        "promotional_price": null,
        "image_url": "https://...",
        "is_promoted": false
      }
    ],
    "hottest": [
      {
        "id": 202,
        "name": "Gin Tônica",
        "price": 25.00,
        "promotional_price": 15.00,
        "image_url": "https://...",
        "is_promoted": true
      }
    ]
  },
  "active_promotions": [ ... ],
  "location_mismatch": true  // IMPORTANT: If true, FE must prompt user to update location via POST /me/update-country
}
```

### Nearby Bars (Filtering) & Location Mismatch

Both `/home` and `/bars` now strictly filter by the user's `country_code`. If a user is physically in a different country than their registered one, the `nearby_bars` list will be empty and `location_mismatch` will be `true`.

#### 📱 Frontend UI Flow (Cross-Border Prompt)
When `location_mismatch` is `true`, the frontend **MUST** display a prompt (e.g., a modal or banner) to the user:
1. **Detects Travel**: "We noticed you are in a different country."
2. **Action**: "Would you like to update your location to see local bars and restaurants?"
3. **Confirm**: If the user clicks "Yes/Update", the app calls `POST /me/update-country` with their current coordinates.
4. **Refresh**: After a successful `200 OK` from the update endpoint, the frontend should re-fetch the `/home` dashboard, which will now return bars for the new country.
If the user declines, they simply see an empty list of local bars until they choose to update.
---

## FINANCIAL OPERATIONS (SPRINT 9 - NEW)

Status: **✅ COMPLETE**
Priority: HIGH - Revenue & Payout Tracking

### Overview

Support for tracking Payouts and Disputes via DPE Webhooks.

### 1. Payout Tracking
Payouts are automatically recorded when DPE notifies the backend of successful transfers to the bar's bank account.

### 2. Dispute Management
Disputes (chargebacks) are recorded and linked to the original `order_id` for administrative review.

---

## NOTIFICATIONS (SPRINT 6 - NEW)

Status: **✅ COMPLETE**
Priority: HIGH - User Engagement & Operations

### Overview

Real-time notifications are now persistent and fetched from the database. This replaces the previous "dummy" notification count.

### 1. Fetch Recent Notifications

```
GET /notifications/?limit=50&offset=0
Auth: Required (Access Token)

Response 200:
[
  {
    "id": 1,
    "user_id": 5,
    "title": "🎉 Ready!",
    "message": "Your order #2005 is ready for pickup!",
    "notification_type": "order_update", // "order_update" | "promotion" | "system"
    "is_read": false,
    "reference_id": "2005", // ID of the related object (e.g., order_id)
    "created_at": "2026-03-31T20:05:00Z",
    "updated_at": "2026-03-31T20:05:00Z"
  }
]
```

### 2. Mark All as Read

```
PUT /notifications/read-all
Auth: Required

Response 200:
{
  "message": "All notifications marked as read.",
  "count": 5
}
```

### 3. Mark Specific as Read

```
PUT /notifications/{notification_id}/read
Auth: Required

Response 200:
{
  "id": 1,
  "is_read": true,
  ... (full object)
}
```

### Integration Notes

- **Polling/WebSocket**: Frontend should fetch notifications on app start and via WebSocket events (`new_notification`).
- **Badge Count**: The `/home` endpoint now returns the `unread_notifications` count based on this database. Use this for the home icon badge.
- **Click Action**: Use `notification_type` and `reference_id` to route the user within the app (e.g., `order_update` -> Navigate to Order Status screen for `order_id`).

---

## BUNDLE PROMOTIONS

Status: **✅ COMPLETE**
Priority: HIGH - Increases average ticket size 15-25%

### Cart Response (Enhanced)

```
GET /cart/
Auth: Required

Response 200:
{
  "id": 1,
  "user_id": 5,
  "items": [
    {
      "menu_item_id": 10,
      "menu_item_name": "Heineken 600ml",
      "bar_id": 8,
      "quantity": 3,
      "unit_price": 18.00,
      "total_price": 54.00
    }
  ],
  "total_items": 3,
  "subtotal": 54.00,
  "applied_bundles": [
    {
      "bundle_id": 1,
      "bundle_name": "Combo Cerveja",
      "discount_amount": 5.40,
      "message": "⚡ Combo Cerveja: -R$ 5.40"
    }
  ],
  "bundle_savings": 5.40,
  "subtotal_after_bundles": 48.60,
  "bundle_hint": null  // Upsell hint when close to bundle
}
```

### FE Implementation

```dart
// Display bundle savings
if (cart.bundleSavings > 0) {
  for (final bundle in cart.appliedBundles) {
    showSavingsBadge(bundle.message);
  }
}

// Display upsell hint
if (cart.bundleHint != null) {
  showUpsellBanner(cart.bundleHint!);
}
```

---

## ACTIVE PROMOTIONS & PLACE LOCATION

Status: **✅ COMPLETE**
Priority: MEDIUM - User engagement

### Get Bar Location Config

```
GET /bars/{bar_id}/location-config

Response 200:
{
  "bar_id": 16,
  "place_location": "spot_list",  // "spot_list" | "anywhere" | "geofence"
  "geofence_radius_meters": null
}
```

### Get Active Promotions

```
GET /bars/{bar_id}/promotions

Response 200:
[
  {
    "id": 1,
    "name": "VIP Cashback 5%",
    "description": "Ganhe 5% de volta em créditos",
    "promotion_type": "cashback",
    "discount_value": 5.0,
    "is_active": true,
    "start_date": "2026-02-01T00:00:00Z",
    "end_date": "2026-12-31T23:59:59Z"
  }
]
```

### Calculate Cart with Promotions (REQUIRED)

To support dynamic promotions (cashback, percentages) affecting the total in real-time.

```
POST /cart/calculate
Body:
{
  "active_promotion_ids": [1, 2]
}

Response 200:
{
  "subtotal": 100.00,
  "discount_total": 5.00,
  "total": 95.00,
  "promotions_applied": [
    {
      "id": 1,
      "name": "Cashback 5%",
      "amount": 5.00
    }
  ]
}
```

## LOCATION CHECK (NEW & REQUIRED)

### Check Spot Availability

To ensure a selected spot is still available before checkout.

```
GET /bars/{bar_id}/spots/{spot_id}/availability

Response 200:
{
  "is_available": true,
  "message": null // or "Spot occupied"
}
```

---

---

## CART SYNC (NEW & REQUIRED)

Status: **✅ COMPLETE**
Priority: HIGH - Performance & Reliability

### Overview

We have introduced a server-driven cart architecture. Instead of manually adding/removing items and calculating totals, the frontend synchronizes its state with the backend via a single endpoint.

### Sync Endpoint

```
POST /cart/sync
Auth: Required

Request Body:
{
  "items": [
    {
      "menu_item_id": 123,
      "quantity": 2,
      "special_instructions": "No ice"
    }
  ],
  "location_identifier": "table_5",
  "active_promotion_ids": [10, 25],
  "coupon_code": "WELCOME10"
}

Response 200:
{
  "items": [
    {
      "menu_item_id": 123,
      "name": "Classic Mojito",
      "quantity": 2,
      "unit_price": 25.0,
      "total_price": 50.0,
      "picture": "https://...",
      "special_instructions": "No ice"
    }
  ],
  "total_items": 2,
  "subtotal": 50.0,
  "discount": 5.0,
  "tax": 0.0,
  "tip": 0.0,
  "delivery_fee": 0.0,
  "total": 45.0,
  "validation_issues": [
    {
      "severity": "warning",
      "message": "Promo 'Student Discount' expired",
      "related_field": "active_promotion_ids"
    }
  ],
  "location_status": {
    "valid": true,
    "message": null
  },
  "available_promotions": []
}
```

### Integration Logic

1.  **Optimistic UI**: Update UI immediately on user action.
2.  **Debounce**: Wait 500ms before calling `/cart/sync`.
3.  **Replace State**: Always replace local state with the backend response.
4.  **Validations**: Display `validation_issues` and block checkout if needed.

---

## STAFF MANAGEMENT (REQUIRED)

Status: **✅ COMPLETE**
Priority: HIGH - Required for Business Owner Controls

### Overview

Allows Bar Owners and Admins to manage their team members, assign privileges (roles), and invite new staff.

### List Staff Members

```
GET /bars/{bar_id}/staff
Auth: Required (Owner/Admin)

Response 200:
[
  {
    "id": "uuid_string",
    "name": "Marcus Rivera",
    "email": "marcus@thebar.com",
    "phone": "+1 555-0101",
    "role": "owner",
    "avatar_url": null 
  },
  {
    "id": "uuid_string2",
    "name": "Lena Whitfield",
    "email": "lena@thebar.com",
    "phone": "+1 555-0104",
    "role": "cashier",
    "avatar_url": "https://..."
  }
]
```

### Invite Staff Member

Send an email or SMS invitation to join a specific bar with a designated role. The system automatically detects if the contact is an email or a phone number.

```
POST /bars/{bar_id}/staff/invite
Auth: Required (Owner/Admin)

Body:
{
  "contact": "name@email.com", // can be email or E.164 phone number (+55...)
  "role": "manager" // "admin" | "manager" | "cashier" | "staff"
}

Response 200:
{
  "id": 123,
  "bar_id": 16,
  "email": "name@email.com",
  "phone": null,
  "role": "manager",
  "status": "pending",
  "invitation_code": "ABC123XYZ",
  "expires_at": "2026-03-30T10:00:00Z"
}
```

### Change Staff Role

```
PUT /bars/{bar_id}/staff/{staff_id}/role
Auth: Required (Owner/Admin)

Body:
{
  "role": "manager"
}

Response 200:
{
  "message": "Role updated successfully",
  "staff_id": "uuid_string",
  "new_role": "manager"
}
```

### Remove Staff Member

Revoke access for a specific staff member.

```
DELETE /bars/{bar_id}/staff/{staff_id}
Auth: Required (Owner)

Response 200:
{
  "message": "Staff member removed from bar"
}
```

---

## CASHIER OPERATIONS (REQUIRED)

Status: **✅ COMPLETE**
Priority: HIGH - Core Operational Loop for Bar Staff

### Overview

Cashiers need to view incoming orders in real-time, get alerted with sound for new/urgent orders, and update the status of an order as it moves through the pipeline. 

### 1. Fetch Active Pipeline

Fetch all orders that are not `completed` (or fetched by specific date if needed).

```
GET /bars/{bar_id}/orders/live
Auth: Required (Cashier/Manager)

Response 200:
[
  {
    "id": "ORD-2005",
    "customer_name": "Sarah M.",
    "status": "pending", // "pending" | "preparing" | "ready" | "completed"
    "total": 45.00,
    "created_at": "2026-03-02T18:05:00Z",
    "items": [
      {
        "name": "Double Smash Burger",
        "quantity": 2,
        "price": 14.50
      }
    ]
  }
]
```

### 2. Update Order Status

Updates an order through the pipeline: `confirmed` → `preparing` → `ready` → `completed`

```
PUT /bars/{bar_id}/orders/{order_id}/status
Auth: Required (Cashier/Manager — requires ORDER_PROCESS permission)

Body:
{
  "status": "preparing",
  "notes": null
}

Valid status transitions:
  confirmed  → ["preparing", "cancelled"]
  preparing  → ["ready", "cancelled"]
  ready      → ["completed"]
  completed  → []
  cancelled  → []

Response 200:
{
  "id": 1367,
  "user_id": 8,
  "bar_id": 16,
  "status": "preparing",
  "total_price": 88.0,
  "subtotal": 80.0,
  "tax": 8.0,
  "tip": 0.0,
  "delivery_fee": 0.0,
  "discount": 0.0,
  "order_type": "dine_in",
  "payment_method": "1",
  "payment_status": "completed",
  "created_at": "2026-05-03T14:28:22.018342",
  "updated_at": "2026-05-03T14:30:00.000000",
  "estimated_ready_time": null,
  "completed_at": null,
  "items": [
    {
      "id": 1437,
      "order_id": 1367,
      "menu_item_id": 4,
      "menu_item_name": "DA CASA",
      "quantity": 1,
      "unit_price": 20.0,
      "total_price": 20.0,
      "created_at": null
    }
  ]
}

Errors:
500 Internal Server Error: {"detail": "Failed to update order status: ..."}
400 Bad Request: {"detail": "Invalid status transition from confirmed to ..."}
```

**Frontend Implementation:**
```dart
Future<void> updateOrderStatus({
  required int barId,
  required String orderId,
  required String newStatus,
}) async {
  await dio.put(
    '/bars/$barId/orders/$orderId/status',
    data: {'status': newStatus},
  );
}
```

### 3. Real-Time WebSocket Alerts (REQUIRED FOR SOUND / URGENCY)

The frontend relies on WebSocket events to trigger notification sounds (`new_order`, `status_changed`) without constant polling.

**Endpoint existing in reference:**
`wss://.../ws/bar/{bar_id}/orders?token=jwt`

**Expected Event JSON:**
```json
{
  "event": "new_order",
  "order": { ...order_object }
}
```

---

## QUICK API REFERENCE

### Auth
- POST /auth/phone-login
- POST /auth/google-login
- POST /auth/apple-login
- POST /auth/refresh
- POST /auth/logout

### Profile (User Settings)
- GET /me/profile
- PUT /me/profile (Now accepts `phone_number` and `avatar_url`)

### Subscriptions
- POST /subscriptions/trial/setup (Free trial with card validation)
- POST /subscriptions/capture (Capture after trial ends)
- POST /payments/v2/charge/upgrade (Prorated mid-cycle upgrade)

## ADVERTISING & SUBSCRIPTIONS (SPRING 5 - NEW)

Status: **✅ COMPLETE**
Priority: HIGH - Monetization & Growth

### Overview

Allows bar owners to subscribe to Pro plans (MASTER/VIP) and create/manage advertising campaigns with detailed performance analytics.

> [!IMPORTANT]
> All advertising endpoints require the `bar_id` for RBAC verification — as a **Query Parameter**
> (`?bar_id=123`) or via the `X-Bar-Id` request header.
> Read endpoints require `ads:view`; write endpoints require `ads:manage`. Owner and Admin hold both
> today; Manager and below are read-gated / denied unless granted a custom permission.

### 1. Subscription Management

**List Available Plans:**
`GET /advertising/plans?bar_id={bar_id}`
Returns pricing and feature list for the bar's region.

**Current Subscription:**
`GET /advertising/my-plan?bar_id={bar_id}`
Returns active tier, status, and remaining credits.

**Rate Card & Credit Balances:**
`GET /advertising/rates?bar_id={bar_id}`
Returns the region rate card per placement (pricing model, rate, rate range, minimum daily budget,
allowed `budget_type` values, credit bucket) plus the bar's current tier and available credits.
This is the canonical source for the campaign wizard — see the full schema section later in this file.
Requires `ads:view` (read), not `ads:manage`.

**Subscribe to Plan:**
```
POST /advertising/subscribe?bar_id={bar_id}
Body:
{
  "tier": "master", // "master" | "vip"
  "payment_method_id": "pm_123...", // Token from gateway
  "billing_cycle": "monthly" // "monthly" | "annual"
}
```

### 2. Campaign Creation

**Create Campaign:**
`POST /advertising/campaigns?bar_id={bar_id}`
Auth: Required (ADS_MANAGE)

*Note on Campaign Types:* Standard tiers support `featured`, `search_boost`, etc. The new `push_notification` type (which triggers advanced background Geofencing & Cohort targeting) is **strictly gated** to `master` and `vip` subscriptions.

```json
Body:
{
  "name": "Happy Hour Push",
  "campaign_type": "push_notification", 
  "budget_type": "fixed",
  "budget_amount": 50.00,
  "start_time": "2026-04-10T18:00:00Z",
  "end_time": "2026-04-15T22:00:00Z",
  "creative": {
    "title": "50% off all Drafts!",
    "tagline": "Come join us for Happy Hour"
  }
}
```

### 3. Campaign Analytics

**Dashboard Overview:**
`GET /advertising/dashboard/analytics?bar_id={bar_id}`
Aggregated stats for all campaigns.

**Campaign Detailed Stats:**
```
GET /advertising/analytics/{campaign_id}?bar_id={bar_id}&start_date=2026-03-01&end_date=2026-03-23

Response 200:
{
  "campaign_id": 10,
  "campaign_name": "Happy Hour Boost",
  "impressions": 1500,
  "clicks": 45,
  "ctr": 3.0,
  "spend": 15.50,
  "daily_stats": [
    {
      "date": "2026-03-22",
      "impressions": 200,
      "clicks": 5,
      "conversions": 1,
      "spend": 2.00
    }
  ]
}
```

### 3. Billing & Invoices

**Invoices List:**
`GET /advertising/invoices?bar_id={bar_id}`
Returns history of subscription payments and ad spend invoices.
- GET/PUT /me/notification-preferences (Push, Order Updates, Promotions)
- GET/PUT /me/privacy-settings (Data Sharing, Location)
- POST /me/onboarding
- GET /me/bars

### Bars
- GET /bars/
- GET /bars/{bar_id}
- POST /bars/wizard
- GET /bars/{bar_id}/location-config
- GET /bars/{bar_id}/promotions

### Menus
- GET /menus/bar/{bar_id}
- GET/POST /menus/{menu_id}/items
- POST /menus/{menu_id}/items/bulk
- GET /menus/trending/drinks
- POST /menus/extract

### Orders
- GET/POST /orders/
- GET /orders/{order_id}
- GET /orders/{order_id}/timeline
- POST /orders/{order_id}/cancel
- PUT /orders/{order_id}/status

### Cart
- GET /cart/
- POST /cart/items
- PUT /cart/items/{item_id}
- DELETE /cart/items/{item_id}
- DELETE /cart/
- POST /cart/checkout

### Bundles
- GET /bundles/bar/{bar_id}
- POST /bundles/ (bar owner)
- PUT /bundles/{id} (bar owner)
- DELETE /bundles/{id} (bar owner)

### Legal
- GET /legal/TERMS_OF_SERVICE_{PT|EN|ES}.md
- GET /legal/PRIVACY_POLICY_{PT|EN|ES}.md

### Staff Management
- GET /bars/{bar_id}/staff
- POST /bars/{bar_id}/staff/invite
- PUT /bars/{bar_id}/staff/{staff_id}/role
- DELETE /bars/{bar_id}/staff/{staff_id}

### WebSocket
- wss://.../ws/orders/{order_id}/status?token=jwt (Optional - See Note)
- wss://.../ws/bar/{bar_id}/orders?token=jwt (Required for Cashier/Live Dashboard)

> [!NOTE]
> **Order Tracking Strategy**: For users tracking their own orders, it is recommended to use **Periodic Polling** (e.g., every 30s) of `GET /orders/{order_id}/timeline` as the primary synchronization method. The timeline route returns the full history of status changes needed for the UI tracking view. WebSockets are preferred for Cashier/Kitchen dashboards where real-time latency is critical. User-side WebSockets are subject to aggressive timeouts and should be considered "best-effort" fallback.

---

## CREDIT CARDS (SPRINT 3 - NEW)

Status: **✅ COMPLETE**
Priority: HIGH - Secure Payment Methods

### Overview

Allows users to manage their saved credit cards via secure tokenization. The backend does not store raw CD (Credit Card) data, only the token returned from the Payment Gateway (e.g. DPE / Stripe / Stone) + basic metadata for display.

### API Contract

**1. List Saved Cards**
```
GET /me/cards
Auth: Required (Access Token)

Response 200:
[
  {
    "id": 1,
    "user_id": 12,
    "card_token": "tok_123456789abc",
    "last_four": "4242",
    "brand": "Visa",
    "exp_month": 12,
    "exp_year": 2029,
    "is_default": true,
    "created_at": "2026-03-04T12:00:00Z",
    "updated_at": "2026-03-04T12:00:00Z" // Can be null
  }
]
```

**2. Add New Card**
```
POST /me/cards
Auth: Required (Access Token)

Body:
{
  "card_token": "tok_12345...",
  "last_four": "4242",
  "brand": "Visa",
  "exp_month": 12,
  "exp_year": 2029,
  "is_default": true
}

Response 201:
{
  "id": 2,
  "user_id": 12,
  "card_token": "tok_12345...",
  "last_four": "4242",
  "brand": "Visa",
  "exp_month": 12,
  "exp_year": 2029,
  "is_default": true,
  "created_at": "2026-03-04T12:05:00Z",
  "updated_at": "2026-03-04T12:05:00Z"
}

Errors:
409 Conflict: {"error": {"code": "CONFLICT", "message": "Card token already added"}}
```
*Note: If `is_default` is set to `true`, all other cards for this user will automatically become non-default.*

**3. Delete Saved Card**
```
DELETE /me/cards/{card_id}
Auth: Required (Access Token)

Response 204 No Content
```

---

## PAYMENTS PROCESSING / CHECKOUT (SPRINT 3 - NEW)

Status: **✅ COMPLETE**
Priority: CRITICAL - Main checkout flow

### API Contract

**1. Create Charge (Checkout)**
This endpoint hits the Dobar Payment Engine (DPE) synchronously for immediate payment feedback, or returns a Pix QR code.

```
POST /payments/v2/charge
Auth: Required (Access Token)
Headers:
  X-Idempotency-Key: "uuid-v4-string" (Required for double-charge prevention)

Body:
{
  "order_id": 1234,
  "bar_id": 12,
  "amount": 150.50,
  "currency": "BRL",
  "country": "BR",
  "payment_method": {
    "type": "card", // "card" or "pix"
    "token": "tok_12345...", // Optional if PIX. Required if card.
    "provider": "apple_pay", // "apple_pay", "google_pay", "stripe", or "saved"
    "installments": 1
  },
  "customer_info": { // Strongly recommended/required by PagarMe Anti-fraud
    "name": "Carlos Alves",
    "email": "carlos@example.com",
    "document": "12345678909", // CPF or CNPJ
    "phone": "+5511999999999" // Optional
  },
  "description": "Payment for Order 1234 at Bar 12" // Optional
}

Response 200 (Success - Credit Card):
{
  "payment_id": "ch_123abc...",
  "status": "succeeded",
  "gateway": "pagarme",
  "gateway_id": "pgm_987xyz",
  "amount": 150.50,
  "currency": "BRL",
  "created_at": "2026-03-05T12:00:00Z",
  "card_last_four": "4242",
  "card_brand": "Visa"
}

Response 200 (Success - PIX generated):
{
  "payment_id": "ch_pix_123...",
  "status": "pending",
  "gateway": "pagarme",
  "gateway_id": "pgm_pix_987",
  "amount": 150.50,
  "currency": "BRL",
  "created_at": "2026-03-05T12:00:00Z",
  "pix_qr_code": "00020101021243650016BR.GOV.BCB.PIX...",
  "pix_copia_e_cola": "0002010102124365...",
  "pix_expires_at": "2026-03-05T12:30:00Z"
}

Errors:
402 Payment Required: {"error": {"code": "PAYMENT_DECLINED", "message": "Card declined"}}
```

---

### 2. Generate Standalone Pix QR Code (Alternative)

For scenarios where you want to generate a Pix QR code separately from the checkout flow (e.g., "Pay with Pix" button before order confirmation).

```
POST /pix/generate
Auth: Required (Access Token)

Body:
{
  "order_id": 1234,
  "bar_id": 12,
  "amount": 150.50,
  "description": "Pedido #1234 - Bar do Zé",
  "payer_name": "Carlos Alves",
  "payer_document": "12345678909",
  "expires_in": 3600
}

Response 200:
{
  "pix_id": "pix_abc123",
  "brcode": "00020101021243650016BR.GOV.BCB.PIX...",
  "qr_code_base64": "data:image/png;base64,iVBORw0KGgo...",
  "expires_at": "2026-03-05T12:30:00Z",
  "status": "pending"
}
```

**Frontend Implementation:**

```dart
class PixPaymentRepository {
  final Dio _dio;

  Future<PixCode> generatePix({
    required int orderId,
    required int barId,
    required double amount,
    String? description,
    String? payerName,
    String? payerDocument,
    int expiresIn = 3600,
  }) async {
    final res = await _dio.post('/pix/generate', data: {
      'order_id': orderId,
      'bar_id': barId,
      'amount': amount,
      'description': description ?? 'Pedido #$orderId',
      'payer_name': payerName,
      'payer_document': payerDocument,
      'expires_in': expiresIn,
    });
    return PixCode.fromJson(res.data);
  }
}

class PixCode {
  final String pixId;
  final String brcode;           // Copia e Cola
  final String qrCodeBase64;     // Base64 QR image
  final DateTime expiresAt;
  final String status;

  // Convert base64 to Image widget
  Image get qrCodeImage {
    final bytes = base64Decode(qrCodeBase64.split(',')[1]);
    return Image.memory(bytes);
  }
}
```

---

## IMPLEMENTATION STATUS

| Feature | Backend | Frontend |
|---------|---------|----------|
| Auth | ✅ | ✅ |
| Profile | ✅ | ✅ |
| Bar Discovery | ✅ | ✅ |
| Menus | ✅ | ✅ |
| Orders | ✅ | ✅ |
| WebSocket | ✅ | ✅ |
| Bundle Promotions | ✅ | ✅ |
| Active Promotions | ✅ | ✅ |
| Place Location | ✅ | ✅ |
| Trending Drinks | ✅ | ✅ |
| Legal Documents | ✅ | ✅ |
| Staff Management | ✅ | ✅ |
| Order History (Cursor) | ✅ | ✅ |
| Push Notifications (FCM) | ✅ | ✅ |
| Subscription Trial Setup | ✅ | 🔲 |
| Subscription Capture | ✅ | 🔲 |
| Prorated Plan Upgrade | ✅ | 🔲 |
| Pix Payment (QR + Copia e Cola) | ✅ | 🔲 |

---

## ORDER HISTORY — CURSOR PAGINATION (DOB-37)

Status: **✅ COMPLETE**

`GET /orders/user/me` now uses cursor-based pagination.

**Query params:**
- `limit` — number of results (default: 20)
- `cursor` — opaque cursor returned by previous response (omit for first page)
- `status` — optional filter (pending, confirmed, preparing, ready, completed, cancelled)

**Response:**
```json
{
  "orders": [...],
  "next_cursor": "<string|null>",
  "has_more": true
}
```

**FE pattern:**
```dart
Future<List<Order>> loadNextPage(String? cursor) async {
  final res = await dio.get('/orders/user/me', queryParameters: {
    'limit': 20,
    if (cursor != null) 'cursor': cursor,
  });
  nextCursor = res.data['next_cursor'];
  hasMore = res.data['has_more'];
  return (res.data['orders'] as List).map(Order.fromJson).toList();
}
```

---

## PUSH NOTIFICATIONS — FCM TOKEN (DOB-38)

Status: **✅ COMPLETE**

### Register / Update FCM Token

`PUT /me/fcm-token` — call on app start after Firebase init.

Requires Bearer JWT.

**Request body:**
```json
{
  "token": "<FCM device token>",
  "platform": "ios" // or "android"
}
```

**Response:** `200 { "message": "FCM token updated" }`

**FE pattern:**
```dart
Future<void> registerFcmToken() async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) return;
  await dio.put('/me/fcm-token', data: {
    'token': token,
    'platform': Platform.isIOS ? 'ios' : 'android',
  });
  // Also call on token refresh:
  FirebaseMessaging.instance.onTokenRefresh.listen((t) {
    dio.put('/me/fcm-token', data: {'token': t, 'platform': Platform.isIOS ? 'ios' : 'android'});
  });
}
```

### Push Notification Events

Push notifications are sent automatically by the backend for:
- **Order status change** → customer receives push + DB notification record
- **Order cancellation** → customer receives push + DB notification record
- **Payment Success** → customer receives push + DB notification record

---

## NOTIFICATIONS (DOB-47 - NEW)

Status: **✅ COMPLETE**
Priority: HIGH - User Engagement & History

### Overview

Notifications are persisted in the database. When a push notification is sent to a user, a corresponding record is created in the `notifications` table.

### API Contract

**1. List Notifications**
```
GET /notifications?limit=20&offset=0
Auth: Required
```

**2. Mark as Read**
```
PUT /notifications/{notification_id}/read
Auth: Required
```

**3. Mark All as Read**
```
PUT /notifications/read-all
Auth: Required
```

### Notification Object Schema

```json
{
  "id": 10,
  "user_id": 5,
  "title": "🎉 Order Ready!",
  "message": "Your order #123 at Baxi Bar is ready for pickup!",
  "notification_type": "order_update", // "order_update", "system", "promotion"
  "is_read": false,
  "reference_id": "123", // e.g., order_id
  "created_at": "2026-04-03T14:30:00Z"
}
```

---

Previous versions archived in git history.

---

## PLAN FEATURES & INTERNATIONALIZATION (i18n) [MAY 25, 2026 - NEW]

Status: **✅ COMPLETE**
Priority: MEDIUM - Multi-language support

### Overview

Plan feature strings (e.g., "Premium Support", "Reduced Commission") are no longer hardcoded in the backend. They are stored as **string keys** in the `region_pricing` database table's JSON columns. The frontend receives these keys via `GET /advertising/plans` and translates them into the user's selected language.

### i18n Feature Keys

Each plan uses keys from the DB. Fallback keys are embedded in the code but will be replaced once the migration adds the columns to production. The keys follow the pattern `feature_<short_description>`:

| Key | Meaning (English) |
|-----|-------------------|
| `feature_basic_listing` | Basic listing in app |
| `feature_order_management` | Order management |
| `feature_basic_analytics` | Basic analytics |
| `feature_everything_regular` | Everything in Regular |
| `feature_reduced_commission` | Reduced commission rate |
| `feature_monthly_credits` | Monthly advertising credits |
| `feature_featured_home` | Featured Home placement |
| `feature_sponsored_search` | Sponsored Search |
| `feature_priority_support` | Priority support |
| `feature_everything_master` | Everything in Master |
| `feature_lowest_commission` | Lowest commission rate |
| `feature_max_credits` | Maximum advertising credits |
| `feature_map_spotlight` | Map Spotlight |
| `feature_promotion_boost` | Promotion Boost |
| `feature_rich_media_banners` | Rich Media Banners |
| `feature_verified_badge` | Verified Badge |
| `feature_dedicated_manager` | Dedicated account manager |

### Frontend Implementation

```dart
// Plan response now includes `features` as a list of string keys:
// "features": ["feature_basic_listing", "feature_order_management", ...]

class PlanFeatureKeys {
  static const Map<String, Map<String, String>> translations = {
    'en': {
      'feature_basic_listing': 'Basic listing in app',
      'feature_order_management': 'Order management',
      'feature_basic_analytics': 'Basic analytics',
      'feature_everything_regular': 'Everything in Regular',
      'feature_reduced_commission': 'Reduced commission rate',
      'feature_monthly_credits': 'Monthly advertising credits',
      'feature_featured_home': 'Featured Home placement',
      'feature_sponsored_search': 'Sponsored Search',
      'feature_priority_support': 'Priority support',
      'feature_everything_master': 'Everything in Master',
      'feature_lowest_commission': 'Lowest commission rate',
      'feature_max_credits': 'Maximum advertising credits',
      'feature_map_spotlight': 'Map Spotlight',
      'feature_promotion_boost': 'Promotion Boost',
      'feature_rich_media_banners': 'Rich Media Banners',
      'feature_verified_badge': 'Verified Badge',
      'feature_dedicated_manager': 'Dedicated account manager',
    },
    'pt': {
      'feature_basic_listing': 'Listagem básica no app',
      'feature_order_management': 'Gerenciamento de pedidos',
      'feature_basic_analytics': 'Analytics básicos',
      'feature_everything_regular': 'Tudo do Regular',
      'feature_reduced_commission': 'Taxa de comissão reduzida',
      'feature_monthly_credits': 'Créditos de publicidade mensais',
      'feature_featured_home': 'Destaque na página inicial',
      'feature_sponsored_search': 'Pesquisa patrocinada',
      'feature_priority_support': 'Suporte prioritário',
      'feature_everything_master': 'Tudo do Master',
      'feature_lowest_commission': 'Menor taxa de comissão',
      'feature_max_credits': 'Máximo de créditos publicitários',
      'feature_map_spotlight': 'Destaque no mapa',
      'feature_promotion_boost': 'Impulso de promoções',
      'feature_rich_media_banners': 'Banners de mídia avançada',
      'feature_verified_badge': 'Selo verificado',
      'feature_dedicated_manager': 'Gerente de conta dedicado',
    },
    'es': {
      'feature_basic_listing': 'Listado básico en la app',
      'feature_order_management': 'Gestión de pedidos',
      'feature_basic_analytics': 'Analíticas básicas',
      'feature_everything_regular': 'Todo lo de Regular',
      'feature_reduced_commission': 'Tasa de comisión reducida',
      'feature_monthly_credits': 'Créditos publicitarios mensuales',
      'feature_featured_home': 'Destacado en inicio',
      'feature_sponsored_search': 'Búsqueda patrocinada',
      'feature_priority_support': 'Soporte prioritario',
      'feature_everything_master': 'Todo lo de Master',
      'feature_lowest_commission': 'Tasa de comisión más baja',
      'feature_max_credits': 'Máximos créditos publicitarios',
      'feature_map_spotlight': 'Destacado en mapa',
      'feature_promotion_boost': 'Impulso de promociones',
      'feature_rich_media_banners': 'Banners multimedia',
      'feature_verified_badge': 'Insignia verificada',
      'feature_dedicated_manager': 'Gerente de cuenta dedicado',
    },
  };

  static String translate(String key, String locale) {
    final lang = locale.startsWith('pt')
        ? 'pt'
        : locale.startsWith('es')
            ? 'es'
            : 'en';
    return translations[lang]?[key] ?? key;
  }

  static List<String> translateList(List<String> keys, String locale) {
    return keys.map((k) => translate(k, locale)).toList();
  }
}

// Usage:
final plans = response.data['plans'];
final myLocale = Platform.localeName; // e.g., 'pt_BR'
for (final plan in plans.values) {
  final features = PlanFeatureKeys.translateList(
    List<String>.from(plan['features']),
    myLocale,
  );
  // Display `features` in the UI
}
```

---

## ADVERTISING FRONTEND STATUS UPDATE (SEP 2026)

Status: **✅ FRONTEND WIRED**
Priority: MEDIUM - Campaigns polish & subscription flow

### Overview

## Q4 2026 PROMO REACH LADDER — PROMO CPM ALIGNMENT (A/B HANDOFF)

Status: **✅ COMPLETE** · 2026-12-06 · Priority: P0 — pricing & billing integrity

### Decisions

- **Tier gating (A2):** `master` may create `featured`, `search`, `push_notification`, `promo_boost`; `vip` may create all six. `banner`/`map_pin` remain VIP-only. 400 fail-closed when `campaign_type` cannot resolve.
- **Rate-card budget-type validation (A3):** `allowed_budget_types` tokens are `credits`, `fixed`, or the API-legal pricing token (`cpc` / `cpm` / `hourly`). `cph` is a pricing *model* only — never a budget_type.
- **Per-placement billing (B1/B5/B3):** `search` = region-averaged CPC; `promo`/`banner`/`push` = regional `boost_cpm` (CPM); `featured`/`map_pin` = per-hour `hourly`. Missing rate raises `ValueError` (no silent 15.00).
- **Legacy credit-key folding (B6):** `banner`/`promo_boost` → `boost_impressions` additively at read time; response uses canonical keys only.
- **Canonicalization (B2):** `normalize_placement` → `placement_for_campaign_type`; canonical keys; legacy `"click"` key never written.

### Verification

- `tests/test_advertising_contract.py` — **50** cases.
- `tests/test_budget_management.py` — **23** cases.
- `scripts/verify_rate_card_live.py --self-test` — **122** checks, **10** mutations detected.


Frontend implementation status for the Advertising feature. Backend action **not required** for any item below except where noted.

### 1. ✅ Plan Feature Descriptions (i18n keys) — Implemented

The frontend now translates the `features` string keys returned by `GET /advertising/plans`
(e.g. `feature_reduced_commission`) into localized labels (PT/EN/ES) using the key table from the
"PLAN FEATURES & INTERNATIONALIZATION" section, and renders them per plan card in
`SubscriptionPlansSheet`. Credits (`featured_hours`, `search_clicks`, `map_hours`,
`boost_impressions`) are also rendered per tier. Unknown keys fall back to the raw key string.

### 2. ✅ CORS on `/advertising/subscribe` — Verified Fixed (no backend request needed)

The earlier `XMLHttpRequest onError` / CORS preflight failure from `http://localhost:8888` was
re-tested against the live backend:

- `OPTIONS` preflight to `POST /advertising/subscribe?bar_id=16` with
  `Origin: http://localhost:8888`, `Access-Control-Request-Method: POST` and
  `Access-Control-Request-Headers: content-type, authorization` returns
  `access-control-allow-origin: http://localhost:8888` and
  `access-control-allow-headers: content-type, authorization`.
- The actual `POST` (non-preflighted) response also carries the CORS headers.

The CORS middleware now reflects arbitrary localhost ports, so **no removal request is needed**.
The previous failures were caused by the two frontend bugs already documented in
"KNOWN ISSUES & BUG REPORTS" item 0 (wrong URL + missing `payment_method`), both now fixed.

### 3. ✅ Subscribe Request Body — Fixed

`POST /advertising/subscribe?bar_id={bar_id}` now sends the required fields:

```json
{
  "tier": "master",
  "billing_cycle": "monthly",
  "payment_method": { "type": "pix" }
}
```

Both response shapes are handled gracefully: full `AdSubscription` (card, `active`) and
`waiting_payment` with PIX QR code (mapped to `pending`).

### 4. ✅ Multi-Step Campaign Sheet — Fires Real Create Request

`MultiStepCampaignSheet` now dispatches a real `POST /advertising/campaigns?bar_id={bar_id}`
via `CreateCampaign` flow on "Launch" instead of only updating local UI. The success celebration
dialog only shows after the backend responds; backend errors surface as a snackbar in the sheet.

### 5. ✅ Delete Campaign — Wired

`DELETE /advertising/campaigns/{id}?bar_id={bar_id}` is now wired end-to-end
(datasource → repository → usecase → bloc). The campaigns page shows a confirmation dialog,
dispatches `DeleteCampaign`, and removes the campaign from the list on success. Errors surface
as a snackbar.

### 6. ✅ Campaign Creation Contract Alignment & Budget/Credits (SEP 2026)

Status: **✅ BACKEND COMPLETE — FRONTEND INTEGRATION & DEPLOYMENT VERIFICATION PENDING**
Priority: HIGH - Production Launch Readiness

#### Resolution

The reported campaign-creation and subscription-plan issues were addressed backend-side:

1. **Campaign budget contract aligned**
   - `"daily"` is no longer used. The accepted values are `credits`, `fixed`, `cpc`, `cpm`, and `hourly`.
   - Credit campaigns use `budget_amount`; placement percentages may be supplied as a map through
     `placement_distribution` and are normalized to the backend's stored distribution format.
   - Placement aliases such as `mapPin`, `map`, `promo_boost`, and `featured_home` are accepted.
   - Cash campaigns are validated against placement-specific minimum daily budgets.

2. **`GET /advertising/my-plan` resilience fixed**
   - A bar with no paid advertising subscription now receives a default `regular` plan with zero
     advertising credits and HTTP `200 OK`, rather than an HTTP `500`.
   - Sparse/legacy subscription rows and legacy status values are handled defensively.

3. **Rate card and credit balances exposed**
   - New endpoint: `GET /advertising/rates`
   - Requires `ads:view` and resolves the bar through the standard query parameter/header contract.
   - The response includes the region currency, current tier, current available credits, tier credit
     allowances, per-placement pricing model/rate/rate range, minimum daily budget, supported budget
     types, and the credit bucket consumed by that placement.
   - The frontend should use this endpoint instead of client-side rate constants or reach heuristics.
   - **Full canonical schema, field reference, examples, error contract and Dart parsing helpers:
     see the section `GET /advertising/rates` (CANONICAL SCHEMA) below.**

#### Confirmed placement and credit mappings

| Frontend placement / alias | Canonical placement | Pricing model | Credit bucket |
|---|---|---|---|
| `featured`, `featured_home`, `home` | `featured` | `cph` | `featured_hours` |
| `search`, `sponsored_search` | `search` | `cpc` | `search_clicks` |
| `map`, `mapPin`, `map_spotlight` | `map_pin` | `cph` | `map_hours` |
| `promo`, `promo_boost` | `promo` | `cpm` | `boost_impressions` |
| `banner` | `banner` | `cpm` | `boost_impressions` |
| `push`, `push_notification` | `push_notification` | `cpm` | none |

Banner campaigns are credit-backed and use `boost_impressions`; they are not restricted to a fixed
cash budget. Every placement also supports `fixed` when its regional rate is configured.

#### Valid `POST /advertising/campaigns` payload

```json
{
  "name": "Campanha Destaque",
  "campaign_type": "featured",
  "budget_type": "credits",
  "budget_amount": 100.0,
  "start_time": "2026-09-24T19:30:27.008Z",
  "end_time": "2026-10-24T19:30:27.008Z",
  "targeting": {
    "radius_km": 10,
    "age_min": 18,
    "age_max": 65,
    "peak_hours_only": true,
    "budget_optimizer_enabled": true
  },
  "creative": {
    "title": "Campanha Destaque",
    "cta": "visit_now",
    "tagline": "Venha nos visitar!"
  },
  "placement_distribution": {
    "featured": 50.0,
    "search": 50.0
  }
}
```

For cash campaigns, use one of the supported values returned by `/advertising/rates` for the selected
placement: `fixed`, `cpc`, `cpm`, or `hourly`. `daily` is not a valid request value.

#### Frontend follow-up

- Update the campaign sheet to send the payload above and never send `budget_type: "daily"`.
- Fetch `/advertising/rates` when opening campaign creation; derive budget choices, minimum budgets,
  credit balances, and estimate labels from that response.
- Confirm the regular-plan response no longer requires a client-side error fallback.
- Validate this contract against the deployed Fly.io backend after the current changes pass CI/CD.

---

## ADVERTISING RATE CARD — `GET /advertising/rates` (CANONICAL SCHEMA)

Status: **✅ BACKEND COMPLETE** (live on Fly.io after the next CI/CD deploy)
Priority: HIGH - Required before wiring campaign creation end-to-end
Last verified: Sep 25, 2026 — captured from the running app (`app/advertising/routes.py::get_rate_card`,
Pydantic 2.8.2 / FastAPI 0.112.0) and pinned by `tests/test_advertising_contract.py::TestRateCard`.

### Overview

`GET /advertising/rates` is the **single source of truth for the campaign wizard**. It returns, for
the active bar:

- the region rate card (currency + per-placement pricing model, rate, rate range, minimum daily budget),
- the placements the bar may buy and the `budget_type` values each placement accepts,
- the credit bucket each placement consumes when the campaign is credit-backed,
- the bar's **current tier** and **current available credits**,
- the regional credit allowances for `master` and `vip` (used for upsell copy, not for the bar's balance).

The front-end must derive budget choices, minimum budgets, credit balances and estimate labels from
this response instead of client-side rate constants or reach heuristics.

### 1. Request

```
GET /advertising/rates?bar_id={bar_id}
Auth: Required (Access Token - Bearer JWT)
Permission: ads:view            (owner / admin by default; manager needs the custom ads:view grant)
```

`bar_id` is resolved in this order (implemented by `require_bar_permission`):

| # | Source | Notes |
|---|---|---|
| 1 | path parameter | not applicable to this route |
| 2 | `?bar_id=` query parameter | current clients — keep sending it |
| 3 | `X-Bar-Id` request header | supported fallback for new clients |

There is **no** `region_code` request parameter and none is accepted: the region comes from the
bar's advertising subscription row (falling back to `BR` when the bar has no subscription yet).

### 2. Response headers (bar context)

Every successful call also echoes the standard bar-context headers, so the FE can gate UI in the
same round-trip (see "BAR CONTEXT HEADERS"):

| Header | Example |
|---|---|
| `X-Bar-Id` | `16` |
| `X-Bar-Role` | `owner` |
| `X-Bar-Permissions` | `ads:manage,ads:view,analytics:export,...` |

### 3. Response — canonical shape

> [!IMPORTANT]
> **Monetary fields are JSON strings, not numbers.** `Decimal` fields (`rate`, `rate_max`,
> `min_daily_budget`) are serialized as strings: `"25.00"`, `"0.80"`, `"40.00"`. Do **not** cast
> them with `as double` / `as num` in Dart — they will throw. Parse with `double.parse(value)`
> (see the Dart section below). Integers in `credits*` objects are real numbers.

Example: a **Master** bar in region `BR` (rates as seeded by the contract test), after consuming
part of its monthly credits:

```json
{
  "region_code": "BR",
  "currency": "BRL",
  "tier": "master",
  "placements": {
    "featured": {
      "placement": "featured",
      "campaign_type": "featured",
      "pricing_model": "cph",
      "rate": "25.00",
      "rate_max": null,
      "rate_unit": "per_hour",
      "credit_bucket": "featured_hours",
      "credit_unit": "hours",
      "credit_backed": true,
      "min_daily_budget": "40.00",
      "allowed_budget_types": ["credits", "cph", "fixed"]
    },
    "search": {
      "placement": "search",
      "campaign_type": "search",
      "pricing_model": "cpc",
      "rate": "0.80",
      "rate_max": "2.50",
      "rate_unit": "per_click",
      "credit_bucket": "search_clicks",
      "credit_unit": "clicks",
      "credit_backed": true,
      "min_daily_budget": "20.00",
      "allowed_budget_types": ["credits", "cpc", "fixed"]
    },
    "map_pin": {
      "placement": "map_pin",
      "campaign_type": "map",
      "pricing_model": "cph",
      "rate": "35.00",
      "rate_max": null,
      "rate_unit": "per_hour",
      "credit_bucket": "map_hours",
      "credit_unit": "hours",
      "credit_backed": true,
      "min_daily_budget": "25.00",
      "allowed_budget_types": ["credits", "cph", "fixed"]
    },
    "promo": {
      "placement": "promo",
      "campaign_type": "promo_boost",
      "pricing_model": "cpm",
      "rate": "8.00",
      "rate_max": null,
      "rate_unit": "per_1000_impressions",
      "credit_bucket": "boost_impressions",
      "credit_unit": "impressions",
      "credit_backed": true,
      "min_daily_budget": "15.00",
      "allowed_budget_types": ["credits", "cpm", "fixed"]
    },
    "banner": {
      "placement": "banner",
      "campaign_type": "banner",
      "pricing_model": "cpm",
      "rate": "8.00",
      "rate_max": null,
      "rate_unit": "per_1000_impressions",
      "credit_bucket": "boost_impressions",
      "credit_unit": "impressions",
      "credit_backed": true,
      "min_daily_budget": "30.00",
      "allowed_budget_types": ["credits", "cpm", "fixed"]
    },
    "push_notification": {
      "placement": "push_notification",
      "campaign_type": "push_notification",
      "pricing_model": "cpm",
      "rate": "8.00",
      "rate_max": null,
      "rate_unit": "per_1000_impressions",
      "credit_bucket": null,
      "credit_unit": null,
      "credit_backed": false,
      "min_daily_budget": "25.00",
      "allowed_budget_types": ["cpm", "fixed"]
    }
  },
  "credit_buckets": ["featured_hours", "search_clicks", "map_hours", "boost_impressions"],
  "credits_by_tier": {
    "master": {"featured_hours": 4, "search_clicks": 200, "map_hours": 2, "boost_impressions": 5000},
    "vip": {"featured_hours": 12, "search_clicks": 1000, "map_hours": 8, "boost_impressions": 25000}
  },
  "credits_available": {"featured_hours": 2, "search_clicks": 40, "map_hours": 1, "boost_impressions": 0},
  "generated_at": "2026-09-25T12:00:00Z"
}
```

### 4. Field reference

**Root object**

| Field | Type | Description |
|---|---|---|
| `region_code` | string | Region used to price the bar (`BR`, `US`, `MX`, ...), uppercased |
| `currency` | string | ISO currency for all monetary fields; defaults to `BRL` when the region row is missing |
| `tier` | `"regular"` \| `"master"` \| `"vip"` | The bar's **current** advertising tier. A bar with no subscription row is auto-provisioned as `regular` |
| `placements` | object (map) | Keyed by canonical placement — always **all six keys** are present, whether or not the bar can afford them |
| `credit_buckets` | string[] | Fixed order: `featured_hours`, `search_clicks`, `map_hours`, `boost_impressions` |
| `credits_by_tier` | object | Regional monthly **allowance** per tier (`master`, `vip`). This is plan marketing data, **not** the bar's balance |
| `credits_available` | object | The bar's **current remaining** credits — the value to show in the wizard and to spend |
| `generated_at` | ISO-8601 UTC | Server timestamp of the response |

**Each entry in `placements`**

| Field | Type | Description |
|---|---|---|
| `placement` | string | Canonical key, mirrors the map key (echoed for convenience) |
| `campaign_type` | string | Value to send as `campaign_type` when a single-placement campaign is created. Note `map_pin` → `"map"` and `promo` → `"promo_boost"` |
| `pricing_model` | `"cph"` \| `"cpc"` \| `"cpm"` | Metered model used for this placement |
| `rate` | decimal **string** | Region rate for the model above. `"0"` means the region has no configured rate for this placement |
| `rate_max` | decimal **string** or `null` | Upper bound only for placements with a range (currently only `search`, from `search_cpc_max`). `null` = single fixed rate |
| `rate_unit` | string | Human label for `rate`: `per_hour`, `per_click`, `per_1000_impressions` |
| `credit_bucket` | string or `null` | Credit bucket consumed when `budget_type: "credits"`. `null` = placement cannot be paid with credits |
| `credit_unit` | string or `null` | Unit of the bucket: `hours`, `clicks`, `impressions` |
| `credit_backed` | boolean | Convenience flag = `credit_bucket != null` |
| `min_daily_budget` | decimal **string** | Minimum **daily** cash budget for this placement, used to validate cash campaigns |
| `allowed_budget_types` | string[] | Exactly the `budget_type` values accepted by `POST /advertising/campaigns` for this placement |

**How `allowed_budget_types` is composed** (backend algorithm, in this order):

1. `"fixed"` is always present.
2. If `rate > 0`, the placement's `pricing_model` (`cph` / `cpc` / `cpm`) is prepended.
3. If the placement is credit-backed, `"credits"` is prepended.

So a healthy `BR` region yields `["credits", "cph", "fixed"]` for `featured`, and a region with no
pricing row yields just `["credits", "fixed"]` (or `["fixed"]` for `push_notification`, which is never
credit-backed). `hourly` is **not** emitted by the rate card — `POST /advertising/campaigns` still
accepts it, but `fixed` is the value the FE should send for cash campaigns.

### 5. Example — Regular bar (upsell view)

Rates are **region-level**, so a `regular` bar receives the same rate card as a paying bar but with
`credits_available` zeroed out. This is exactly what the FE should render to upsell Master/VIP:
show the real cash rates plus the `credits_by_tier` allowances as the "included credits" of the paid plans.

```json
{
  "region_code": "BR",
  "currency": "BRL",
  "tier": "regular",
  "placements": {
    "featured": {
      "placement": "featured",
      "campaign_type": "featured",
      "pricing_model": "cph",
      "rate": "25.00",
      "rate_max": null,
      "rate_unit": "per_hour",
      "credit_bucket": "featured_hours",
      "credit_unit": "hours",
      "credit_backed": true,
      "min_daily_budget": "40.00",
      "allowed_budget_types": ["credits", "cph", "fixed"]
    }
  },
  "credit_buckets": ["featured_hours", "search_clicks", "map_hours", "boost_impressions"],
  "credits_by_tier": {
    "master": {"featured_hours": 4, "search_clicks": 200, "map_hours": 2, "boost_impressions": 5000},
    "vip": {"featured_hours": 12, "search_clicks": 1000, "map_hours": 8, "boost_impressions": 25000}
  },
  "credits_available": {"featured_hours": 0, "search_clicks": 0, "map_hours": 0, "boost_impressions": 0},
  "generated_at": "2026-09-25T12:00:00Z"
}
```

> [!NOTE]
> A `regular` bar has **no credits**, so `"credits"` still appears in `allowed_budget_types` (it is a
> property of the placement, not of the bar). The FE must disable the "pay with credits" option when
> the matching `credits_available` bucket is `0`, rather than relying on the array alone.

(Only one placement is shown above for brevity; the full response always contains all six
placements with the same field set as section 3.)

### 6. Errors

| Status | Body | Cause |
|---|---|---|
| `401` | `{"error_code":"UNAUTHORIZED","message":"Authentication required"}` | Missing / invalid Bearer token |
| `400` | `{"detail":"bar_id is required in path, query, or X-Bar-Id header"}` | No `bar_id` in path, query or header |
| `400` | `{"detail":"Invalid bar_id format"}` | Non-integer `bar_id` |
| `403` | `{"detail":"You don't have access to this bar"}` | Caller is not an active member of that bar |
| `403` | `{"detail":"Missing permission: ads:view"}` | Member, but lacks `ads:view` (e.g. cashier / staff) |

The endpoint never returns `500` for a bar without a subscription: the bar is auto-provisioned as
`regular` with zeroed credits, and a region without a `region_pricing` row degrades to `rate: "0"`
and `currency: "BRL"`.

### 7. Canonical placements, aliases and rate sources

`placements` is **always** keyed by these six canonical names. The FE may keep using aliases when
sending `placement_distribution`, but must read the response with the canonical keys.

| Canonical key | Accepted `placement_distribution` aliases | `campaign_type` to send | `pricing_model` | `rate` source column (`region_pricing`) | `credit_bucket` | `min_daily_budget` |
|---|---|---|---|---|---|---|
| `featured` | `featured`, `featured_home`, `featuredhome`, `home` | `featured` | `cph` | `featured_cph` | `featured_hours` | `"40.00"` |
| `search` | `search`, `sponsored_search`, `sponsoredsearch` | `search` | `cpc` | `search_cpc_min` (`rate_max` ← `search_cpc_max`) | `search_clicks` | `"20.00"` |
| `map_pin` | `map`, `map_pin`, `mapPin`, `mappin`, `map_spotlight`, `mapspotlight` | `map` | `cph` | `map_cph` | `map_hours` | `"25.00"` |
| `promo` | `promo`, `promo_boost`, `promoboost` | `promo_boost` | `cpm` | `boost_cpm` | `boost_impressions` | `"15.00"` |
| `banner` | `banner`, `banners` | `banner` | `cpm` | `boost_cpm` | `boost_impressions` | `"30.00"` |
| `push_notification` | `push`, `push_notification` | `push_notification` | `cpm` | `boost_cpm` | — (`null`) | `"25.00"` |

Aliases are matched case-insensitively with `-` / spaces normalized to `_` (`mapPin` → `map_pin`).
Unknown names are rejected with `422` at create time.

`push_notification` is additionally **tier-gated**: it is not credit-backed and requires a `master`
or `vip` subscription, otherwise `POST /advertising/campaigns` returns `403`.

> [!NOTE]
> **Ground truth for the `promo` model.** `.docs/q4_2026/Dobar_Market_Analysis_Brazil_2026.pdf`
> (August 2026, the most recent pricing document) prices Promotion Boost **per 1,000 impressions** —
> §5.2 "Product 4: Promotion Boost (CPM)": R$12/1k (Local 1–2km, min R$25) · R$10/1k (District, min
> R$50) · R$8/1k (City wide, min R$100) · R$6/1k (Metro/event, min R$200), with 5,000 impressions/month
> included for VIP. That is why `promo` reports `pricing_model: "cpm"` and shares the `boost_cpm`
> column with `banner` / `push_notification` — the three rates are identical by construction.
>
> **Not modelled yet (roadmap — do not look for these fields in the response):** the PDF's reach-tier
> ladder above, and its **Master + VIP tier gating** of promo. The rate card exposes a single `rate`
> per placement today, and `POST /advertising/campaigns` does not reject `promo` for a `regular` bar.
> Treat the ladder and the tier restriction as product guidance, not as response data.

### 8. Wiring the wizard

1. On opening campaign creation, call `GET /advertising/rates?bar_id={bar_id}` (cache per bar + tier).
2. Render one card per `placements` key, localizing `placement` / `campaign_type` labels client-side.
3. Budget selector = `allowed_budget_types` of the selected placement, minus `"credits"` when the
   corresponding `credits_available[bucket]` is `0` (or the placement is not `credit_backed`).
4. Show `rate` + `rate_unit` (+ `rate_max` as "up to" for `search`) using the response `currency`.
5. Enforce `min_daily_budget` in the UI **before** submitting — the backend enforces it server-side as:

```
daily_placement_budget = placement.budget / campaign_duration_days
campaign_duration_days = max((end_time - start_time).days, 1)   # default 7 when dates are missing
reject if daily_placement_budget < min_daily_budget             # cash budget types only
```

So for a 30-day campaign you must allocate at least `30 × min_daily_budget` to the placement
(e.g. `featured` → ≥ `1200.00` BRL over 30 days). Credit campaigns skip this check entirely.

6. Build and send the create payload:

```json
{
  "name": "Campanha Destaque",
  "campaign_type": "featured",
  "budget_type": "credits",
  "budget_amount": 12.0,
  "start_time": "2026-09-25T19:30:27.008Z",
  "end_time": "2026-10-25T19:30:27.008Z",
  "targeting": {"radius_km": 10, "age_min": 18, "age_max": 65, "budget_optimizer_enabled": true},
  "creative": {"title": "Campanha Destaque", "cta": "visit_now", "tagline": "Venha nos visitar!"},
  "placement_distribution": {"featured": 50.0, "search": 50.0}
}
```

- `placement_distribution` accepts the **map form** (`{"featured": 50.0}`) or the list form
  (`[{"placement": "featured", "percentage": 50}]`). Percentages are normalized server-side and each
  placement's `budget` is derived from `budget_amount × percentage / 100`.
- For `budget_type: "credits"`, `budget_amount` is expressed in the placement's `credit_unit`
  (hours / clicks / impressions) and is **not** currency. It is validated against
  `credits_available[credit_bucket]`.
- Never send `budget_type: "daily"` — it is rejected. Use `credits`, `fixed`, `cpc`, `cpm` or `hourly`
  (`fixed` recommended for cash).

Failure to meet a minimum returns `400`:

```json
{
  "error_code": "BAD_REQUEST",
  "message": "Placement 'featured' requires minimum daily budget of R$ 40.00. Current allocation: R$ 10.00/day"
}
```

### 9. Dart implementation

```dart
class PlacementRate {
  final String placement;
  final String campaignType;
  final String pricingModel;
  final double rate;
  final double? rateMax;
  final String rateUnit;
  final String? creditBucket;
  final String? creditUnit;
  final bool creditBacked;
  final double minDailyBudget;
  final List<String> allowedBudgetTypes;

  PlacementRate.fromJson(String key, Map<String, dynamic> json)
      : placement = json['placement'] as String? ?? key,
        campaignType = json['campaign_type'] as String,
        pricingModel = json['pricing_model'] as String,
        // Decimals arrive as JSON *strings* -> never use `as double` / `as num`.
        rate = _money(json['rate']),
        rateMax = json['rate_max'] == null ? null : _money(json['rate_max']),
        rateUnit = json['rate_unit'] as String,
        creditBucket = json['credit_bucket'] as String?,
        creditUnit = json['credit_unit'] as String?,
        creditBacked = json['credit_backed'] as bool,
        minDailyBudget = _money(json['min_daily_budget']),
        allowedBudgetTypes =
            (json['allowed_budget_types'] as List).cast<String>().toList();

  static double _money(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class RateCard {
  final String regionCode;
  final String currency;
  final String tier;
  final Map<String, PlacementRate> placements;
  final List<String> creditBuckets;
  final Map<String, Map<String, int>> creditsByTier;
  final Map<String, int> creditsAvailable;

  RateCard.fromJson(Map<String, dynamic> json)
      : regionCode = json['region_code'] as String,
        currency = json['currency'] as String,
        tier = json['tier'] as String,
        placements = {
          for (final e in (json['placements'] as Map).entries)
            e.key as String
                : PlacementRate.fromJson(e.key as String, e.value as Map<String, dynamic>),
        },
        creditBuckets = (json['credit_buckets'] as List).cast<String>(),
        creditsByTier = (json['credits_by_tier'] as Map).map(
          (k, v) => MapEntry(k as String, Map<String, int>.from(v as Map)),
        ),
        creditsAvailable = Map<String, int>.from(json['credits_available'] as Map);

  /// Credits the bar may actually spend for a given placement.
  int spendableCredits(String placement) {
    final bucket = placements[placement]?.creditBucket;
    if (bucket == null) return 0;
    return creditsAvailable[bucket] ?? 0;
  }

  /// Budget types to offer in the UI (drops `credits` when the balance is 0).
  List<String> usableBudgetTypes(String placement) {
    final card = placements[placement];
    if (card == null) return const [];
    if (!card.creditBacked || spendableCredits(placement) == 0) {
      return card.allowedBudgetTypes.where((t) => t != 'credits').toList();
    }
    return card.allowedBudgetTypes;
  }

  /// Minimum total budget for a placement over `days`, in the response currency.
  double minTotalBudget(String placement, int days) =>
      (placements[placement]?.minDailyBudget ?? 0) * (days < 1 ? 1 : days);
}

class AdvertisingRepository {
  final Dio _dio;

  Future<RateCard> getRateCard(int barId) async {
    final res = await _dio.get(
      '/advertising/rates',
      queryParameters: {'bar_id': barId},
    );
    return RateCard.fromJson(res.data as Map<String, dynamic>);
  }
}
```

### 10. Known quirks & caveats (read before wiring)

1. **`promo` is CPM (it reported `cpc` until Sep 25, 2026).** `promo` takes its `rate` from the
   regional `boost_cpm` column, but it used to report `pricing_model: "cpc"` / `rate_unit: "per_click"`.
   It now reports `cpm` / `per_1000_impressions` with `allowed_budget_types: ["credits","cpm","fixed"]`,
   aligned with `.docs/q4_2026/Dobar_Market_Analysis_Brazil_2026.pdf` §5.2 ("Product 4: Promotion Boost
   (CPM)") and with the `boost_impressions` credit bucket. `promo`, `banner` and `push_notification` all
   read the same `boost_cpm` column, so their `rate` values are equal by construction — never treat that
   as three independent price points.
2. **`rate_max` semantics.** Only `search` has a range today (`"0.80"` – `"2.50"`); every other
   placement returns `null`. When the region has no `region_pricing` row, `search.rate_max` comes
   back as the string `"0"` instead of `null` — always compare numerically, never by null-ness.
3. **Decimal formatting is not uniform.** A configured rate is `"25.00"`; a missing region rate is
   `"0"` (no decimals). Parse numerically; do not pattern-match on the string.
4. **`credits_by_tier` is marketing data, `credits_available` is the balance.** Both keys are always
   present — even for a `regular` bar, which sees the Master/VIP allowances so the FE can upsell.
5. **`hourly` is accepted but never advertised.** The create endpoint accepts `hourly`, yet no
   placement lists it in `allowed_budget_types`. Stick to the returned values.
6. **All six placements are always returned,** even those the bar's tier cannot use (e.g.
   `push_notification` on a `regular` plan). Gate by `tier` + balance, not by key presence.
7. **`tier` reflects the advertising subscription,** not the consumer subscription of the user:
   a bar on a free/absent plan reports `regular` and is auto-provisioned on first call.
8. **Cash budget accrual is not live yet.** No scheduler invokes the campaign billing paths and the ad
   server's impression/click handlers are not called anywhere in the current code base, so
   `budget_spent` stays at `0` and a running campaign will **not** auto-complete on budget exhaustion.
   Do not build progress bars or "spend so far" copy that assumes per-impression/per-click/per-hour
   accrual yet — drive status from the campaign endpoints instead.

### 11. Verification status

| Check | Result |
|---|---|
| `tests/test_advertising_contract.py::TestRateCard` (2 tests) | ✅ passing locally |
| `X-Bar-Id` header resolution without `?bar_id=` | ✅ `200` |
| `region_pricing` row missing → zeroed rates, `200` | ✅ verified |
| Bar without subscription → auto-provisioned `regular`, `200` | ✅ verified |
| `Decimal` wire format is string-typed | ✅ verified on the ASGI test client |
| `bar_id` missing → `400`, non-member → `403`, no token → `401` | ✅ verified |
| `promo.pricing_model == "cpm"` (was `cpc`), `rate_unit == "per_1000_impressions"` | ✅ asserted in `tests/test_advertising_contract.py::TestRateCard` |
| `promo`/`banner`/`push_notification` share the `boost_cpm` rate | ✅ asserted in `tests/test_advertising_contract.py::TestRateCard` |
| Live re-check on Fly.io (`scripts/verify_rate_card_live.py`) | ✅ 2026-09-25, run from inside the production container (`flyctl ssh console`) and against the public URL with principal `user_id=6` / `bar_id=16`: **116/116 checks in both the `?bar_id=` and the `X-Bar-Id`-only forms**, `promo.pricing_model == "cpm"`, `rate == "8.00"`, `rate_unit == "per_1000_impressions"`, `credit_bucket == "boost_impressions"`. CI job: `.github/workflows/rate-card-live.yml` (manual `workflow_dispatch` or post-deploy `workflow_call`; verifies **from inside the app container** via the existing `FLY_API_TOKEN` — no app secret is stored in GitHub) |

---

## ADVERTISING SUBSCRIPTION (SPRINT 5 - NEW)

## ADVERTISING SUBSCRIPTION (SPRINT 5 - NEW)

---

## KNOWN ISSUES & DATA INCONSISTENCIES (NEW)

Status: **⚠️ BUG REPORTED**
Priority: MEDIUM - Map Visual Accuracy

### 🛰️ Geocoordinate Clustering (Bar Pins)
**Issue:** Multiple bars are returning identical latitude and longitude coordinates in the mock/real dataset, regardless of their displayed physical address.
- **Observed Behavior:** All bars plot at the exact same location (São Paulo center) in `FindConnected` and `HomeConnected`.
- **Backend Action Required:** Ensure `latitude` and `longitude` fields in the `bars` table represent unique, accurate physical locations in the seed data/database.
- **Impact:** Map pins cluster on top of each other, making the "Find Nearby Bars" feature visually broken despite correct descriptive addresses.

flutter: [DIO]
flutter: Bar do Zé -23.5505 -46.6333
flutter: Boteco da Esquina -23.5505 -46.6333
flutter: Cervejaria Artesanal -23.5505 -46.6333
flutter: Porcão BH -23.5505 -46.6333

### 🖼️ Mock Image 404 Errors
**Issue:** Presigned URLs for bar images (specifically mock items 12, 13, 14, 16) are returning 404 Not Found even after a manual refresh.
- **Observed Behavior:** The application correctly identifies an expired or broken URL and calls `/bars/{id}/refresh-image`, but the new URL provided by the secondary call also returns a 404.
- **Backend Action Required:** 
    1. Verify if mock image assets (e.g., `mock-12.png`) actually exist in the S3 bucket.
    2. Check the `refresh-image` logic to ensure it doesn't return stale or incorrect paths.
- **Impact:** UI displays broken image icons or placeholders for most bars/promotions in the feed.

---

## USER DOCUMENTS (SPRINT 9 - NEW)

Status: **✅ COMPLETE**
Priority: HIGH - Required for payment flow (CPF)

### Overview

Allows users to store and manage identity documents (CPF, RG, CNH, passport) required for payment processing in Brazil. The frontend must collect the user's CPF before initiating a payment if no CPF document exists.

### 1. Create/Update Document

Upserts a document by type — if a document of the same type already exists for the user, it updates it instead of creating a duplicate.

```
POST /users/me/documents
Auth: Required (Access Token)

Body:
{
  "type": "cpf",          // cpf | rg | cnh | passport
  "number": "93095135270",
  "issuing_authority": "SSP-SP",   // optional
  "issue_date": null,              // optional, ISO-8601
  "expiry_date": null,             // optional, ISO-8601
  "verified": false                // optional, default false
}

Response 201:
{
  "id": 1,
  "user_id": 42,
  "type": "cpf",
  "number": "93095135270",
  "issuing_authority": null,
  "issue_date": null,
  "expiry_date": null,
  "verified": false,
  "created_at": "2026-04-22T09:30:00Z",
  "updated_at": "2026-04-22T09:30:00Z"
}

Errors:
- 401 UNAUTHORIZED → Not authenticated
- 422 INVALID_CPF → CPF number failed modulo-11 validation
- 422 VALIDATION_ERROR → Invalid type or missing required fields
```

### 2. List Documents

Returns all documents for the currently authenticated user.

```
GET /users/me/documents
Auth: Required (Access Token)

Response 200:
[
  {
    "id": 1,
    "user_id": 42,
    "type": "cpf",
    "number": "93095135270",
    "issuing_authority": null,
    "issue_date": null,
    "expiry_date": null,
    "verified": false,
    "created_at": "2026-04-22T09:30:00Z",
    "updated_at": "2026-04-22T09:30:00Z"
  }
]

Errors:
- 401 UNAUTHORIZED → Not authenticated
```

### Frontend Integration Notes

- Before payment, check `GET /users/me/documents` for a CPF document
- If none exists, prompt the user to enter their CPF and call `POST /users/me/documents`
- CPF is validated server-side using the modulo-11 algorithm
- The endpoint is idempotent per type — calling POST with the same type updates the existing document

---

## NOTIFICATIONS FIX (SPRINT 9)

Status: **✅ FIXED**

### Issue

`GET /notifications?limit=50&offset=0` was returning 307 → 401 due to FastAPI's trailing slash redirect stripping the Authorization header on the client side.

### Fix

The backend notifications route no longer uses a trailing slash, so `GET /notifications?limit=50&offset=0` is served directly with no redirect.

### Frontend Action Required

**None** — the fix is backend-only. The frontend should continue calling `GET /notifications?limit=50&offset=0` as before.

---

## KNOWN ISSUES & BUG REPORTS (SPRINT 6)

### 0. 🚨 Advertising Subscription POST Returns 404/422 (Wrong Endpoint + Missing Required Fields) [SPRINT 9 - NEW]
**Issue:** The frontend calls `POST /advertising/subscriptions` to subscribe/upgrade a plan, but the backend expects `POST /advertising/subscribe?bar_id={bar_id}`. Even after fixing the URL, the request body is **missing the required `payment_method` field**, causing a **422 Validation Error**.

**Root Cause — Two Separate Frontend Bugs:**

**Bug 1 — Wrong URL:** In `lib/core/api/api_endpoints.dart`, line 128:
```dart
static const String subscriptions = '/advertising/subscriptions';
```
This constant is used for the POST request, but the backend route is registered as `/advertising/subscribe` (see `app/advertising/routes.py` line 120).

Additionally, two other derived endpoints also point to non-existent routes:
- `subscription(int barId)` → `/advertising/subscriptions/$barId` (no GET route exists; the correct one is `GET /advertising/my-plan?bar_id={bar_id}`)
- `cancelSubscription(int subscriptionId)` → `/advertising/subscriptions/$subscriptionId/cancel` (no DELETE route exists)

**Bug 2 — Missing `payment_method` in request body:** The backend's `SubscribeRequest` schema (see `app/advertising/schemas.py` lines 118-122) requires:
```python
class SubscribeRequest(BaseModel):
    tier: SubscriptionTierEnum                                   # Required
    payment_method: PaymentMethodSchema                          # Required! Contains {type, token?}
    billing_cycle: str = Field(default="monthly")                # Optional (defaults to "monthly")
```

But the frontend is sending only:
```json
{tier: master, billing_cycle: monthly}
```
The `payment_method` field is **completely missing**, so the backend rejects it with `422: Validation failed: Field required`.

**Fix Required (Frontend):**
1. Change the base constant from:
   ```dart
   static const String subscriptions = '/advertising/subscriptions';
   ```
   to:
   ```dart
   static const String subscriptions = '/advertising/subscribe';
   ```
2. The POST call must pass `bar_id` as a **query parameter** (`?bar_id=16`), not in the request body.
3. **Add the required `payment_method` object to the request body.** The minimum valid request body is:
   ```json
   {
     "tier": "master",
     "billing_cycle": "monthly",
     "payment_method": {
       "type": "pix"
     }
   }
   ```
   For card payments, include the card token:
   ```json
   {
     "tier": "master",
     "billing_cycle": "monthly",
     "payment_method": {
       "type": "card",
       "token": "pm_12345..."
     }
   }
   ```
4. Remove `region_code` and `bar_id` from the request body — they are not accepted fields.
5. If the "my plan" GET endpoint is needed, use `/advertising/my-plan?bar_id={bar_id}` instead of the non-existent `/advertising/subscriptions/{bar_id}`.

**Log Evidence (appbusiness.log lines 410-476 + new attempt logs):**

*First attempt (Bug 1 — 404 Wrong URL):*
```
[DIO] uri: https://barz-backend-bold-sun-5691.fly.dev/advertising/plans    ← ✅ Works
[DIO] uri: https://barz-backend-bold-sun-5691.fly.dev/advertising/subscriptions  ← ❌ Wrong
[DIO] data: {bar_id: 16, tier: master, region_code: BR}
[DIO] *** Error Response ***
[DIO] status: 404
[DIO] message: Not Found
```

*Second attempt (Bug 2 — 422 Missing `payment_method`):*
```
[DIO] uri: https://barz-backend-bold-sun-5691.fly.dev/advertising/subscribe?bar_id=16  ← ✅ URL fixed
[DIO] data: {tier: master, billing_cycle: monthly}                                      ← ❌ Missing payment_method
[DIO] *** Error Response ***
[DIO] status: 422
[DIO] message: Validation failed: Field required
```

The user tested with `tier: master` (multiple times) and `tier: vip` — all failed.

**Impact:** Business users cannot subscribe to any paid plan (Master or VIP) through the app.

### 1. Identical Bar Coordinates
- **Issue:** Multiple bars (e.g. 'Bar do Zé', 'Boteco da Esquina', 'Bar da Vila') are returning exactly the same coordinates: 'latitude: -23.5505', 'longitude: -46.6333'.
- **Impact:** Map pins overlap completely, making them indistinguishable without custom clustering.
- **Request:** Update seed data or backend logic to provide unique coordinates for each bar.

### 2. Mock Image 404s
- **Issue:** Several mock images (e.g., 'mock-12.png', 'mock-13.png', 'mock-14.png', 'mock-16.png') return '404 Not Found' from S3.
- **Impact:** Frontend displays placeholders instead of bar branding.
- **Request:** Verify S3 bucket contents and presigned URL generation for mock bars.

### 3. APNS Token Not Set
- **Issue:** FCM registration fails on initial launch because APNS token is not yet available.
- **Impact:** Temporary delay in push notification registration.
- **Recommendation:** Implement a retry mechanism or wait for 'iOS' APNS token callback.

### 4. /home Endpoint Limited Results
- **Issue:** The `/home` endpoint currently returns only ONE bar in the `nearby_bars` list, even when many more bars are available within proximity (as seen in `/bars` endpoint).
- **Impact:** The "Meet our partners" section (horizontal carousel) only shows the single closest bar, making the Home screen feel empty.
- **Request:** Investigate if there's a hard limit (limit=1) or a filtering bug on the backend for the `/home` result set.

---

## 5. 🚨 Plan Descriptions Returning Wrong/Misleading Content (FIXED - JUL 2026)

**⚠️ STATUS: ✅ RESOLVED** — Backend migration applied + route hardened.

**Issue:** The `GET /advertising/plans?bar_id={bar_id}` endpoint returned incorrect or misleading descriptions for PRO subscription tiers (Master, VIP). The `plan.name`, `plan.commission_rate`, and `plan.features` arrays were returning wrong data per tier.

**Root Cause (Confirmed):**
- The `region_pricing` database table had **Master and VIP column data swapped** for commission rates, annual prices, and features JSON arrays
- The seed data population during the i18n migration (MAY 25, 2026) inserted Master data into VIP columns and vice versa
- The `/advertising/plans` route lacked defensive handling for edge cases (null annual_price, string JSON columns, non-list features)

**Fix Applied (Backend):**
1. **Migration `20250720_fix_pricing_swap`** — Detects and corrects swapped Master/VIP tier data in `region_pricing` table:
   - Compares `master_commission` vs `vip_commission` to detect the swap (Master should have lower commission than Regular but higher than VIP)
   - Swaps `master_monthly ↔ vip_monthly`, `master_annual ↔ vip_annual`, `master_commission ↔ vip_commission`, `master_credits ↔ vip_credits`, `master_features ↔ vip_features` where swap is detected
   - Restores correct feature arrays for all tiers using the i18n key patterns from `routes.py` defaults
2. **Route hardening** in `GET /advertising/plans` (`app/advertising/routes.py`):
   - Added defensive type checks for `features` and `credits` JSON columns (handles string DB representations, None values, non-list edge cases)
   - Ensured `annual_price` defaults to `Decimal("0.00")` instead of null
   - Plans always ordered by tier priority: Regular → Master → VIP

**Runbook (Deploy):**
```bash
# Apply the migration on each environment
alembic upgrade head
# After migration, verify data:
# SELECT region_code, master_commission, vip_commission, master_features, vip_features FROM region_pricing;
```

**Verification (Expected after fix):**

| Field | Regular | Master | VIP |
|-------|---------|--------|-----|
| name | "Regular" | "Master" | "VIP" |
| commission_rate | 15% (0.1500) | 5% (0.05) | 3% (0.03) |
| features count | 3 | 6 | 8 |
| annual_price | R$ 0,00 | R$ 479,40 | R$ 719,40 |

**See Also:** Migration file: `migrations/versions/20250720_fix_region_pricing_tier_swap.py`

---

## BUSINESS SETTINGS (SPRINT 10 - NEW)

Status: **✅ COMPLETE** — Backend implemented
Priority: HIGH - Business User Configuration

### Overview

Allows bar owners and admins to manage their business profile, contact information, delete business data, and deactivate/reactivate their account from the Business Settings page.

### 1. Get Business Details

Returns the bar's full profile information for display in the Business Details form.

```
GET /bars/{bar_id}/details
Auth: Required (Owner/Admin)

Response 200:
{
  "bar_id": 16,
  "bar_name": "Baxi Bar",
  "description": "The best craft beer in town",
  "category": "bar", // "bar" | "restaurant" | "club" | "lounge"
  "address": "Rua Augusta, 1500",
  "city": "São Paulo",
  "state": "SP",
  "country": "BR",
  "latitude": -23.5505,
  "longitude": -46.6333,
  "cover_image_url": "https://...",
  "logo_url": "https://...",
  "timezone": "America/Sao_Paulo",
  "created_at": "2026-01-15T10:00:00Z",
  "updated_at": "2026-05-20T14:30:00Z"
}

Errors:
403 Forbidden: {"error": {"code": "FORBIDDEN", "message": "Insufficient permissions"}}
```

### 2. Update Business Details

Updates the bar's profile information. Only provided fields are updated (partial update).

```
PUT /bars/{bar_id}/details
Auth: Required (Owner/Admin)

Body:
{
  "bar_name": "Baxi Bar Premium",
  "description": "Now serving premium cocktails",
  "category": "lounge",
  "address": "Rua Augusta, 1520",
  "city": "São Paulo",
  "state": "SP",
  "latitude": -23.5505,
  "longitude": -46.6333,
  "cover_image_url": "https://...",
  "logo_url": "https://..."
}

Response 200:
{
  "bar_id": 16,
  "bar_name": "Baxi Bar Premium",
  "description": "Now serving premium cocktails",
  "category": "lounge",
  "address": "Rua Augusta, 1520",
  "city": "São Paulo",
  "state": "SP",
  "country": "BR",
  "latitude": -23.5505,
  "longitude": -46.6333,
  "cover_image_url": "https://...",
  "logo_url": "https://...",
  "updated_at": "2026-05-23T20:00:00Z"
}

Errors:
400 Bad Request: {"error": {"code": "VALIDATION_ERROR", "message": "Invalid address format"}}
409 Conflict: {"error": {"code": "BAR_NAME_TAKEN", "message": "Bar name already in use"}}
```

### 3. Get Contact Settings

Returns the bar's contact information for customer-facing display.

```
GET /bars/{bar_id}/contact
Auth: Required (Owner/Admin)

Response 200:
{
  "bar_id": 16,
  "phone": "+5511999990000",
  "email": "contato@baxibar.com",
  "website": "https://baxibar.com.br",
  "instagram": "@baxibar",
  "facebook": "baxibaroficial",
  "whatsapp": "+5511999990000",
  "whatsapp_enabled": true,
  "updated_at": "2026-05-20T14:30:00Z"
}
```

### 4. Update Contact Settings

Updates the bar's contact information.

```
PUT /bars/{bar_id}/contact
Auth: Required (Owner/Admin)

Body:
{
  "phone": "+5511999991111",
  "email": "novo@baxibar.com",
  "website": "https://baxibar.com.br",
  "instagram": "@baxibar_oficial",
  "facebook": "baxibaroficial",
  "whatsapp": "+5511999991111",
  "whatsapp_enabled": true
}

Response 200:
{
  "bar_id": 16,
  "phone": "+5511999991111",
  "email": "novo@baxibar.com",
  "website": "https://baxibar.com.br",
  "instagram": "@baxibar_oficial",
  "facebook": "baxibaroficial",
  "whatsapp": "+5511999991111",
  "whatsapp_enabled": true,
  "updated_at": "2026-05-23T20:05:00Z"
}

Errors:
400 Bad Request: {"error": {"code": "VALIDATION_ERROR", "message": "Invalid phone number format"}}
```

### 5. Delete Business Data

Permanently removes all business data including campaign history, menu items, order records, and analytics. This action is **irreversible**.

```
DELETE /bars/{bar_id}/data
Auth: Required (Owner)

Headers:
  X-Idempotency-Key: "uuid-v4-string" (Recommended)

Response 200:
{
  "message": "Business data permanently deleted",
  "deleted_records": {
    "campaigns": 5,
    "menu_items": 42,
    "orders": 187,
    "analytics": 365
  },
  "receipt_id": "del_biz_123456789"
}

Errors:
403 Forbidden: {"error": {"code": "FORBIDDEN", "message": "Only the bar owner can delete business data"}}
```

### 6. Deactivate Account

Temporarily disables the business profile. The bar will not appear in search results and will not accept new orders. Data is preserved for reactivation.

```
POST /bars/{bar_id}/deactivate
Auth: Required (Owner)

Body:
{
  "reason": "temporary_closure", // "temporary_closure" | "vacation" | "maintenance" | "other"
  "estimated_return_date": "2026-06-15" // Optional, ISO-8601 date
}

Response 200:
{
  "bar_id": 16,
  "status": "deactivated",
  "deactivated_at": "2026-05-23T20:10:00Z",
  "estimated_return_date": "2026-06-15",
  "message": "Business account deactivated successfully. Data preserved."
}
```

### 7. Reactivate Account

Reactivates a previously deactivated business profile.

```
POST /bars/{bar_id}/reactivate
Auth: Required (Owner)

Response 200:
{
  "bar_id": 16,
  "status": "active",
  "reactivated_at": "2026-06-14T10:00:00Z",
  "message": "Business account reactivated successfully."
}

Errors:
400 Bad Request: {"error": {"code": "NOT_DEACTIVATED", "message": "Account is not currently deactivated"}}
```

### FE Implementation Plan

```dart
class BusinessSettingsRepository {
  final Dio _dio;

  Future<BarDetails> getBarDetails(int barId) async {
    final res = await _dio.get('/bars/$barId/details');
    return BarDetails.fromJson(res.data);
  }

  Future<BarDetails> updateBarDetails(int barId, Map<String, dynamic> data) async {
    final res = await _dio.put('/bars/$barId/details', data: data);
    return BarDetails.fromJson(res.data);
  }

  Future<ContactSettings> getContactSettings(int barId) async {
    final res = await _dio.get('/bars/$barId/contact');
    return ContactSettings.fromJson(res.data);
  }

  Future<ContactSettings> updateContactSettings(int barId, Map<String, dynamic> data) async {
    final res = await _dio.put('/bars/$barId/contact', data: data);
    return ContactSettings.fromJson(res.data);
  }

  Future<DeleteResult> deleteBusinessData(int barId) async {
    final res = await _dio.delete('/bars/$barId/data');
    return DeleteResult.fromJson(res.data);
  }

  Future<DeactivateResult> deactivateAccount(int barId, {String? reason, String? estimatedReturnDate}) async {
    final res = await _dio.post('/bars/$barId/deactivate', data: {
      if (reason != null) 'reason': reason,
      if (estimatedReturnDate != null) 'estimated_return_date': estimatedReturnDate,
    });
    return DeactivateResult.fromJson(res.data);
  }

  Future<ReactivateResult> reactivateAccount(int barId) async {
    final res = await _dio.post('/bars/$barId/reactivate');
    return ReactivateResult.fromJson(res.data);
  }
}
```

### Implementation Status Update

| Feature | Backend | Frontend |
|---------|---------|----------|
| Bar Details (GET/PUT) | ✅ | 🔲 |
| Contact Settings (GET/PUT) | ✅ | 🔲 |
| Delete Business Data | ✅ | 🔲 |
| Deactivate/Reactivate Account | ✅ | 🔲 |