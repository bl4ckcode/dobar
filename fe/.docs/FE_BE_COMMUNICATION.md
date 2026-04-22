# BARZ - Frontend Backend Communication

Last Updated: April 14, 2026
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
  "is_pro": false
}

```
*Note: Editing a phone number to one that is already in use returns `409 Conflict` (`PHONE_IN_USE`).*

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
  "active_promotions": [
    {
      "id": 5,
      "title": "Happy Hour",
      "description": "50% off on drafts",
      "discount_type": "percentage",
      "discount_value": 50.0,
      "start_time": "17:00",
      "end_time": "20:00",
      "image_url": "https://..."
    }
  ]
}
```

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

```
PUT /bars/{bar_id}/orders/{order_id}/status
Auth: Required (Cashier/Manager)

Body:
{
  "status": "preparing"
}

Response 200:
{
  "message": "Status updated successfully",
  "order_id": "ORD-2005",
  "new_status": "preparing"
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
> All advertising endpoints require the `bar_id` as a **Query Parameter** for RBAC verification (e.g., `?bar_id=123`).
> Users must have `ADS_MANAGE` permission (Owner, Admin, or Manager roles).

### 1. Subscription Management

**List Available Plans:**
`GET /advertising/plans?bar_id={bar_id}`
Returns pricing and feature list for the bar's region.

**Current Subscription:**
`GET /advertising/my-plan?bar_id={bar_id}`
Returns active tier, status, and remaining credits.

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
  "budget": 50.00,
  "budget_type": "daily",
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
- wss://.../ws/orders/{order_id}/status?token=jwt
- wss://.../ws/bar/{bar_id}/orders?token=jwt

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

## ADVERTISING SUBSCRIPTION (SPRINT 5 - NEW)

Status: **✅ COMPLETE**
Priority: HIGH - Monetization & Business Tiering

### 1. Subscribe to Plan
Subscribe or upgrade the current bar to a higher tier.

```
POST /api/advertising/subscribe?bar_id={bar_id}
Auth: Required (ADS_MANAGE permission)

Body:
{
  "tier": "master", // "regular" | "master" | "vip"
  "billing_cycle": "monthly", // "monthly" | "annual"
  "payment_method": {
    "type": "pix" // "pix" | "card"
  }
}

Response 200 (Credit Card - Immediate):
{
  "id": 12,
  "bar_id": 16,
  "tier": "master",
  "status": "active",
  "monthly_fee": 100.0,
  "credits": {
      "featured_hours": 10,
      "search_clicks": 100,
      "map_hours": 5,
      "boost_impressions": 1000
  },
  "billing_cycle_start": "2026-03-24T10:00:00Z",
  "next_billing_date": "2026-04-24T10:00:00Z"
}

Response 200 (PIX - Waiting Payment):
{
  "status": "waiting_payment",
  "pix_qr_code": "000201...",
  "pix_copia_e_cola": "000201...",
  "pix_qr_code_url": "https://gateway.stone.com.br/qr/...",
  "pix_expires_at": "2026-03-24T12:00:00Z",
  "invoice_id": 45
}
```

### 2. Check Credits
Check remaining advertising credits for the bar.

```
GET /api/advertising/credits?bar_id={bar_id}
Auth: Required (ADS_MANAGE)

Response 200:
{
  "featured_hours": 8,
  "search_clicks": 45,
  "map_hours": 2,
  "boost_impressions": 850
}
```

### 3. Payment Webhook (DPE Internal)
The Dobar Payment Engine (DPE) notifies the backend when a PIX payment is confirmed.

```
POST /api/payment/webhook/dpe
Body:
{
  "event": "payment.succeeded",
  "data": {
    "payment_id": "pay_123",
    "status": "succeeded",
    "metadata": {
      "type": "subscription",
      "bar_id": 16,
      "tier": "master",
      "invoice_id": 45
    }
  }
}
```
*Note: Upon successful webhook, the backend automatically activates the subscription and updates the bar's tier and credits.*

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

## KNOWN ISSUES & BUG REPORTS (SPRINT 6)

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
