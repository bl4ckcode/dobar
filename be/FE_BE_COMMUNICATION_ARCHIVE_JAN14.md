# 🍻 BARZ - Frontend ↔️ Backend Communication

> **⚠️ IMPORTANT:** This document contains ONLY the latest updates.  
> Previous changes are archived in git history.  
> Always update this file before committing new features.

> **Last Updated:** January 14, 2026  
> **Backend Status:** 🟢 Live on Fly.io  
> **API Base URL:** `https://barz-backend-bold-sun-5691.fly.dev`

---

## 📴 OFFLINE-FIRST ARCHITECTURE

> **Status:** ✅ FE IMPLEMENTED  
> **Priority:** HIGH - Critical for payments and orders  
> **Added:** January 14, 2026

### Overview

Barz implements an **offline-first architecture** to ensure reliable order and payment handling even with spotty network connectivity. The system uses local caching, background sync, and real-time WebSocket updates.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  OFFLINE-FIRST DATA FLOW                                                    │
│                                                                             │
│  ┌─────────────┐    ┌─────────────────┐    ┌─────────────────────────────┐  │
│  │   UI/BLoC   │◄──►│   Repository    │◄──►│  Network DataSource (API)  │  │
│  └─────────────┘    │   (Cache-First) │    └─────────────────────────────┘  │
│                     │                 │                                      │
│                     │    ┌────────────┴──────────────┐                      │
│                     │    ▼                           ▼                      │
│                     │ ┌──────────────┐    ┌──────────────────────────────┐  │
│                     │ │ Local Cache  │    │      Sync Queue             │  │
│                     │ │   (Hive)     │    │  (Pending Operations)       │  │
│                     │ └──────────────┘    └──────────────────────────────┘  │
│                     └────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ CONNECTIVITY SERVICE                                                    ││
│  │  • Monitors network state                                               ││
│  │  • Triggers sync on reconnect                                           ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ BACKGROUND WORKER (WorkManager)                                         ││
│  │  • Periodic sync every 1 hour                                           ││
│  │  • Immediate sync on critical operations                                ││
│  │  • Cache cleanup every 24 hours                                         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ WEBSOCKET SERVICE                                                       ││
│  │  • Real-time order status updates                                       ││
│  │  • Updates local cache immediately                                      ││
│  │  • Auto-reconnect with exponential backoff                              ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

### Core Services

| Service | File | Purpose |
|---------|------|---------|
| `ConnectivityService` | `lib/core/services/offline/connectivity_service.dart` | Network state monitoring |
| `HiveStorageService` | `lib/core/services/offline/hive_storage_service.dart` | Local NoSQL storage |
| `SyncService` | `lib/core/services/offline/sync_service.dart` | Sync queue orchestration |
| `BackgroundWorker` | `lib/core/services/offline/background_worker.dart` | WorkManager integration |

### Cache-First Repository Pattern

```dart
// OrderRepositoryImpl - Cache-first read pattern
Future<Either<Failure, PaginatedOrders>> getMyOrders(...) async {
  // 1. Always read from cache first (fast UI)
  final cachedOrders = localDataSource.getCachedOrders();

  // 2. If offline, return cached data
  if (!connectivityService.isOnline) {
    return Right(cachedOrders);
  }

  // 3. If online, fetch fresh data
  try {
    final result = await networkDataSource.getMyOrders(...);
    await localDataSource.cacheOrders(result.orders); // Update cache
    return Right(result);
  } catch (e) {
    // 4. On error, fallback to cache
    return Right(cachedOrders);
  }
}
```

### Sync Queue for Offline Writes

When user performs write operations offline:

```dart
// Example: Cancel order while offline
Future<Either<Failure, OrderModel>> cancelOrder(int orderId) async {
  if (!connectivityService.isOnline) {
    // 1. Update local state immediately
    await localDataSource.updateOrderStatus(orderId, 'pending_cancel');
    
    // 2. Queue for background sync
    await syncService.enqueueTask(
      type: SyncTaskType.cancelOrder,
      payload: {'order_id': orderId},
    );
    
    return Right(localDataSource.getOrder(orderId)!);
  }
  
  // If online, proceed normally...
}
```

### Sync Task Types

| Type | Description | Priority |
|------|-------------|----------|
| `createOrder` | New order creation | HIGH |
| `updateOrder` | Order modifications | MEDIUM |
| `cancelOrder` | Order cancellations | HIGH |
| `payment` | Payment processing | CRITICAL |

### Background Worker Schedule

| Task | Frequency | Constraints |
|------|-----------|-------------|
| `backgroundSync` | Every 1 hour | Network connected, battery not low |
| `immediateOrderSync` | On-demand | Network connected |
| `cleanupCache` | Every 24 hours | Battery not low, charging |

### WebSocket Real-Time Updates

```dart
// Order status updates via WebSocket
class OrderTrackingService {
  Stream<OrderStatusUpdate> get statusUpdates => ...;
  
  void _handleUpdate(OrderStatusUpdate update) {
    // Update local cache immediately
    localDataSource.updateOrderStatus(update.orderId, update.status);
    // Emit to UI
    _statusController.add(update);
  }
}
```

### Dependencies Added

```yaml
# pubspec.yaml
hive: ^2.2.3              # Local NoSQL database
hive_flutter: ^1.1.0      # Hive Flutter integration
connectivity_plus: ^6.1.4 # Network detection
workmanager: ^0.5.2       # Background tasks
```

### Platform Considerations

| Feature | Android | iOS | Web |
|---------|---------|-----|-----|
| Hive Storage | ✅ File | ✅ File | ✅ IndexedDB |
| Background Sync | ✅ WorkManager | ⚠️ Limited (30s) | ❌ Not supported |
| Connectivity | ✅ Full | ✅ Full | ✅ Full |
| WebSocket | ✅ Full | ✅ Full | ✅ Full |

### Backend WebSocket Endpoints (Needed)

```http
# Order status tracking (single order)
wss://barz-backend.fly.dev/ws/orders/{order_id}/status?token=<jwt>

# Bar orders stream (for business dashboard)
wss://barz-backend.fly.dev/ws/bars/{bar_id}/orders?token=<jwt>

# Messages:
{
  "type": "status_update",
  "order_id": 123,
  "status": "preparing",
  "message": "Your order is being prepared",
  "timestamp": "2026-01-14T12:00:00Z"
}
```

### Implementation Checklist

**Frontend (✅ Complete - Jan 14, 2026):**
- [x] `ConnectivityService` - Network state monitoring
- [x] `HiveStorageService` - Local storage with sync queue
- [x] `SyncService` - Foreground sync orchestration
- [x] `BackgroundWorker` - WorkManager integration
- [x] `OrderLocalDataSource` - Order caching layer
- [x] `OrderRepositoryImpl` - Cache-first pattern
- [x] Dependency injection setup
- [x] New failure types: `CacheFailure`, `NetworkFailure`, `SyncFailure`

**Backend (✅ COMPLETE - Jan 14, 2026):**
- [x] WebSocket endpoint for order status streaming (`/ws/orders/{order_id}/status`)
- [x] WebSocket endpoint for bar orders stream (`/ws/bar/{bar_id}/orders`)
- [ ] Conflict resolution strategy for offline sync
- [ ] Idempotency keys for payment operations

---

## 📱 PROGRESSIVE PROFILING: Email Collection Strategy

### Overview
Barz uses **phone-first authentication** with progressive email collection. This maximizes signup conversion while still enabling receipts and account recovery.

### User Journey Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SIGNUP                                                                  │
│  ┌──────────────┐                                                       │
│  │ Phone + OTP  │ ──────────────────────────────────────────────────►   │
│  └──────────────┘                                                       │
│        │                                                                 │
│        ▼                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────────┐   │
│  │  Onboarding  │───►│  Browse App  │───►│  First Order Complete ✓  │   │
│  │  (user_type) │    │  (no email)  │    └────────────┬─────────────┘   │
│  └──────────────┘    └──────────────┘                 │                  │
│                                                        ▼                  │
│                                           ┌──────────────────────────┐   │
│                                           │  📧 Email Prompt Modal   │   │
│                                           │  "Get your receipt?"     │   │
│                                           │  [Add Email] [Skip]      │   │
│                                           └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Backend Endpoints (Already Implemented ✅)

#### 1. Check if Email is Missing
```http
GET /me/profile
Authorization: Bearer <token>

Response:
{
  "display_name": "Carlos",
  "email": null,           // ← null means email not set
  "avatar_url": null,
  "terms_accepted": true,
  "privacy_accepted": true,
  "user_type": "client",
  "country_code": "BR"
}
```

#### 2. Add Email to Profile
```http
PUT /me/profile
Authorization: Bearer <token>
Content-Type: application/json

{
  "email": "user@example.com"
}

Response: 200 OK (updated profile)

Errors:
- 409 Conflict: "Email already in use"
- 422 Validation: Invalid email format
```

### When to Prompt for Email (UX Triggers)

| Trigger | Priority | Prompt Style | Skip Allowed? |
|---------|----------|--------------|---------------|
| First order completed | 🔴 High | Modal | ✅ Yes |
| View "Order History" | 🟡 Medium | Inline banner | ✅ Yes |
| Request receipt | 🔴 High | Modal | ❌ No (required) |
| Account recovery attempt | 🔴 High | Full screen | ✅ Yes |
| Profile settings | 🟢 Low | Inline field | ✅ Yes |
| 3rd login without email | 🟡 Medium | Soft prompt | ✅ Yes |

### UI Copy Suggestions

#### Modal: After First Order
```
┌────────────────────────────────────────┐
│  📧 Want your receipt?                 │
│                                        │
│  Add your email to get:                │
│  • Digital receipts                    │
│  • Order history access                │
│  • Account recovery if you lose phone  │
│                                        │
│  ┌────────────────────────────────┐    │
│  │ email@example.com              │    │
│  └────────────────────────────────┘    │
│                                        │
│  [Add Email]          [Maybe Later]    │
└────────────────────────────────────────┘
```

#### Banner: Order History Page
```
┌─────────────────────────────────────────────────────────────┐
│ 📧 Add your email for receipts and order history exports    │
│                                        [Add Email] [✕]      │
└─────────────────────────────────────────────────────────────┘
```

#### Inline: Profile Settings
```
Email (optional)
┌────────────────────────────────────────┐
│ Not set                          [Add] │
└────────────────────────────────────────┘
Used for receipts and account recovery
```

### FE Implementation Checklist

```markdown
- [ ] On app load, fetch `/me/profile` and cache `email` status
- [ ] Create `hasEmail` computed/state: `profile.email !== null`
- [ ] Create `EmailPromptModal` component
- [ ] Track `emailPromptDismissedAt` in local storage
- [ ] Show prompt only once per 24h if dismissed
- [ ] After first order: if (!hasEmail) showEmailPrompt()
- [ ] In Profile Settings: show email field with current value or "Add" button
- [ ] Handle 409 error: "This email is already linked to another account"
```

### State Machine (for complex FE state management)

```typescript
type EmailPromptState = 
  | 'idle'           // User has email OR recently dismissed
  | 'should_show'    // Trigger occurred, ready to show
  | 'showing'        // Modal is visible
  | 'submitting'     // API call in progress
  | 'success'        // Email added
  | 'error'          // API error
  | 'dismissed';     // User clicked "Skip"

// Persist dismissed state for 24h
const DISMISS_COOLDOWN_MS = 24 * 60 * 60 * 1000;
```

### Analytics Events (Suggested)

| Event | When | Properties |
|-------|------|------------|
| `email_prompt_shown` | Modal appears | `trigger: 'first_order' \| 'history' \| 'profile'` |
| `email_prompt_submitted` | User adds email | `trigger` |
| `email_prompt_dismissed` | User clicks skip | `trigger`, `dismiss_count` |
| `email_prompt_error` | API returns error | `error_code` |

---

## 🏪 BAR CREATION: Enhanced Registration Flow

> **New Feature:** Location-first bar registration with Google Places integration and country-specific validation.

### Flow Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  CREATE BAR WIZARD (5 Steps)                                                │
│                                                                             │
│  Step 1: FIND BAR                                                           │
│  ┌──────────────────┐                                                       │
│  │ 🔍 Google Places │ ──► Auto-fill: name, address, lat/lng, country       │
│  │    Autocomplete  │                                                       │
│  └──────────────────┘                                                       │
│         │                                                                   │
│         ▼ (or "Enter Manually")                                             │
│  Step 2: BAR DETAILS (Country-Aware Form)                                   │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ 🇧🇷 Brazil: CNPJ (##.###.###/####-##) + State Registration           │   │
│  │ 🇵🇹 Portugal: NIF (#########)                                         │   │
│  │ 🇺🇸 USA: EIN (##-#######)                                             │   │
│  │ 🇪🇸 Spain: CIF (A########)                                            │   │
│  │ 🇲🇽 Mexico: RFC (AAAA######AAA)                                       │   │
│  │ 🇦🇷 Argentina: CUIT (##-########-#)                                   │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│         │                                                                   │
│         ▼                                                                   │
│  Step 3: PHOTOS (Logo + Cover + Gallery)                                    │
│         │                                                                   │
│         ▼                                                                   │
│  Step 4: OPERATING HOURS                                                    │
│         │                                                                   │
│         ▼                                                                   │
│  Step 5: REVIEW & SUBMIT                                                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Frontend Implementation

**New Components Created:**
- `BarzPhoneField` - International phone input with country picker (uses `intl_phone_field`)
- `BarzAddressField` - Google Places autocomplete wrapper (uses `google_places_flutter`)
- `BarzMaskedField` - Masked input for CNPJ/CPF/CEP with validation (uses `mask_text_input_formatter`)
- `CountryFormConfig` - Country-specific form configuration

**Files:**
- `lib/core/design/components/barz_phone_field.dart`
- `lib/core/design/components/barz_address_field.dart`
- `lib/core/design/components/barz_masked_field.dart`
- `lib/core/design/config/country_form_config.dart`

### Backend Requirements (✅ IMPLEMENTED - Jan 10, 2026)

#### 1. Create Bar Endpoint Enhancement

Current endpoint: `POST /bars/`

**Required Updates:**

```http
POST /bars/
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Porcão BH",
  "address": "Av. Raja Gabaglia, 3200 - São Bento, Belo Horizonte - MG, 30350-540",
  "latitude": -19.9321,
  "longitude": -43.9478,
  "phone": "+5531999999999",
  "email": "contato@porcao.com.br",
  
  // 🆕 NEW FIELDS NEEDED
  "country_code": "BR",
  "business_id": "12.345.678/0001-90",  // CNPJ for Brazil
  "business_id_type": "CNPJ",           // Type label
  "state_registration": "123456789",     // Brazil-specific (optional)
  
  // Images (existing)
  "logo_url": "https://storage.../logo.png",
  "cover_url": "https://storage.../cover.png",
  "photo_urls": ["https://storage.../photo1.png", "..."],
  
  // Operating hours (existing)
  "operating_hours": {
    "monday": {"open": "18:00", "close": "02:00", "is_closed": false},
    "tuesday": {"open": "18:00", "close": "02:00", "is_closed": false},
    "wednesday": {"is_closed": true},
    "thursday": {"open": "18:00", "close": "02:00", "is_closed": false},
    "friday": {"open": "18:00", "close": "04:00", "is_closed": false},
    "saturday": {"open": "16:00", "close": "04:00", "is_closed": false},
    "sunday": {"open": "16:00", "close": "00:00", "is_closed": false}
  }
}
```

**Response:**
```json
{
  "id": 42,
  "name": "Porcão BH",
  "address": "Av. Raja Gabaglia, 3200...",
  "country_code": "BR",
  "business_id": "12.345.678/0001-90",
  "business_id_type": "CNPJ",
  "verification_status": "pending",
  "created_at": "2026-01-10T12:00:00Z"
}
```

#### 2. Country-Specific Validation (Backend)

| Country | business_id_type | Mask | Validation |
|---------|------------------|------|------------|
| BR | CNPJ | ##.###.###/####-## | Modulo 11 checksum |
| BR | CPF | ###.###.###-## | Modulo 11 checksum |
| PT | NIF | ######### | 9 digits |
| US | EIN | ##-####### | 9 digits |
| ES | CIF | A######## | Letter + 8 digits |
| MX | RFC | AAAA######AAA | 12-13 alphanumeric |
| AR | CUIT | ##-########-# | 11 digits |

#### 3. Database Schema Updates

```sql
-- Add to bars table
ALTER TABLE bars ADD COLUMN country_code VARCHAR(2) DEFAULT 'BR';
ALTER TABLE bars ADD COLUMN business_id VARCHAR(50);
ALTER TABLE bars ADD COLUMN business_id_type VARCHAR(20);
ALTER TABLE bars ADD COLUMN state_registration VARCHAR(50);
ALTER TABLE bars ADD COLUMN verification_status VARCHAR(20) DEFAULT 'pending';

-- Create index for business ID lookups (prevent duplicates)
CREATE UNIQUE INDEX idx_bars_business_id ON bars(country_code, business_id) 
  WHERE business_id IS NOT NULL;
```

#### 4. Verification Status Flow

```
pending → under_review → verified OR rejected

pending:      Just created, awaiting review
under_review: Admin is reviewing business documents
verified:     Business ID validated, bar is official
rejected:     Invalid business ID, needs correction
```

### Frontend Validation (Already Implemented ✅)

**CNPJ Validation (Brazil):**
```dart
// lib/core/design/components/barz_masked_field.dart
static bool validateCNPJ(String cnpj) {
  // Remove non-digits
  final digits = cnpj.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.length != 14) return false;
  
  // Check for all same digits
  if (RegExp(r'^(\d)\1+$').hasMatch(digits)) return false;
  
  // Modulo 11 checksum validation
  // ... (implemented in BrazilMasks class)
}
```

### Google Places Integration

**API Key:** Stored in app config (not committed)

**Countries Enabled:** `['br', 'pt', 'us', 'es', 'mx', 'ar']`

**Place Details Returned:**
- `description` - Full formatted address
- `latitude` / `longitude` - Coordinates
- `countryCode` - ISO 2-letter code (extracted from address_components)

### Implementation Checklist

**Frontend (✅ Complete):**
- [x] FindBarStep with Google Places autocomplete
- [x] BarzPhoneField with international picker
- [x] BarzMaskedField with CNPJ/CPF validation
- [x] CountryFormConfig for 6 countries
- [x] Dynamic form based on detected country
- [x] L10n strings in EN, PT, ES

**Backend (✅ Complete - Jan 10, 2026):**
- [x] Add `country_code` field to bars table
- [x] Add `business_id` + `business_id_type` fields
- [x] Add `state_registration` field (Brazil-specific)
- [x] Add `verification_status` field
- [x] Implement business ID validation per country (CNPJ, CPF, NIF, EIN, CIF, RFC, CUIT)
- [x] Create unique constraint on (country_code, business_id)
- [x] New endpoint: `POST /bars/wizard` accepts JSON body with all wizard fields
- [x] Update `GET /bars/{id}` to return new fields
- [x] Migration created: `bar_creation_wizard.py`

**New Wizard Endpoint:**
```http
POST /bars/wizard
Content-Type: application/json

{
  "name": "Porcão BH",
  "address": "Av. Raja Gabaglia, 3200...",
  "latitude": -19.9321,
  "longitude": -43.9478,
  "phone_number": "+5531999999999",
  "email": "contato@porcao.com.br",
  "owner_id": 1,
  "country_code": "BR",
  "business_id": "12.345.678/0001-90",
  "business_id_type": "CNPJ",
  "state_registration": "123456789",
  "logo_url": "https://...",
  "cover_url": "https://...",
  "photo_urls": ["https://..."],
  "operating_hours": {
    "monday": {"open": "18:00", "close": "02:00", "is_closed": false},
    ...
  }
}

Response:
{
  "id": 42,
  "name": "Porcão BH",
  "address": "Av. Raja Gabaglia, 3200...",
  "country_code": "BR",
  "business_id": "12.345.678/0001-90",
  "business_id_type": "CNPJ",
  "verification_status": "pending",
  "created_at": "2026-01-10T12:00:00Z"
}
```

---

## 🗺️ GOOGLE PLACES API PROXY ✅ BACKEND COMPLETE

> **✅ IMPLEMENTED (Jan 10, 2026):** Backend proxy endpoints are ready!

### Why This Is Needed

**Current Problem:**
- Flutter web app calls Google Places API directly from browser
- Browser CORS policy blocks cross-origin requests to `maps.googleapis.com`
- Currently using third-party CORS proxy (`corsproxy.io`) as workaround
- **Security Risk:** Google API key is exposed in frontend JavaScript code

**Solution:** Backend proxy endpoints that:
1. Keep the API key secure on the server
2. Add proper CORS headers for our frontend
3. Work identically on web, iOS, and Android
4. Allow caching to reduce API costs

### Required Endpoints

#### 1. Places Autocomplete

```http
GET /api/places/autocomplete?input=Baxo+Bar&countries=br,pt,us

Authorization: Bearer <token>

Response:
{
  "predictions": [
    {
      "place_id": "ChIJN1t_tDeuEmsRUsoyG83frY4",
      "description": "Baxo Bar, Rua Augusta, São Paulo - SP, Brazil",
      "structured_formatting": {
        "main_text": "Baxo Bar",
        "secondary_text": "Rua Augusta, São Paulo - SP, Brazil"
      }
    },
    ...
  ],
  "status": "OK"
}
```

**Query Parameters:**
| Parameter | Required | Description |
|-----------|----------|-------------|
| `input` | ✅ Yes | Search query string |
| `countries` | ❌ No | Comma-separated ISO country codes (e.g., `br,pt,us`) |
| `types` | ❌ No | Place types filter (default: `establishment`) |
| `sessiontoken` | ❌ No | Session token for billing optimization |

**Backend Implementation:**
```python
@router.get("/api/places/autocomplete")
async def places_autocomplete(
    input: str,
    countries: Optional[str] = None,
    types: str = "establishment",
    current_user: User = Depends(get_current_user)  # Require auth
):
    # Build Google API request
    params = {
        "input": input,
        "key": settings.GOOGLE_PLACES_API_KEY,  # Server-side secret
        "types": types,
    }
    if countries:
        # Format: "country:br|country:pt|country:us"
        params["components"] = "|".join(f"country:{c}" for c in countries.split(","))
    
    response = await httpx.get(
        "https://maps.googleapis.com/maps/api/place/autocomplete/json",
        params=params
    )
    return response.json()
```

#### 2. Place Details

```http
GET /api/places/details?place_id=ChIJN1t_tDeuEmsRUsoyG83frY4

Authorization: Bearer <token>

Response:
{
  "result": {
    "place_id": "ChIJN1t_tDeuEmsRUsoyG83frY4",
    "name": "Baxo Bar",
    "formatted_address": "Rua Augusta, 1234 - Consolação, São Paulo - SP, 01305-100, Brazil",
    "geometry": {
      "location": {
        "lat": -23.5505,
        "lng": -46.6333
      }
    },
    "address_components": [
      {"long_name": "1234", "short_name": "1234", "types": ["street_number"]},
      {"long_name": "Rua Augusta", "short_name": "R. Augusta", "types": ["route"]},
      {"long_name": "Consolação", "short_name": "Consolação", "types": ["sublocality"]},
      {"long_name": "São Paulo", "short_name": "São Paulo", "types": ["locality"]},
      {"long_name": "SP", "short_name": "SP", "types": ["administrative_area_level_1"]},
      {"long_name": "Brazil", "short_name": "BR", "types": ["country"]},
      {"long_name": "01305-100", "short_name": "01305-100", "types": ["postal_code"]}
    ]
  },
  "status": "OK"
}
```

**Query Parameters:**
| Parameter | Required | Description |
|-----------|----------|-------------|
| `place_id` | ✅ Yes | Google Place ID from autocomplete |
| `fields` | ❌ No | Comma-separated fields (default: basic + geometry + address) |
| `sessiontoken` | ❌ No | Session token for billing optimization |

**Backend Implementation:**
```python
@router.get("/api/places/details")
async def place_details(
    place_id: str,
    fields: str = "place_id,name,formatted_address,geometry,address_components",
    current_user: User = Depends(get_current_user)
):
    params = {
        "place_id": place_id,
        "key": settings.GOOGLE_PLACES_API_KEY,
        "fields": fields,
    }
    
    response = await httpx.get(
        "https://maps.googleapis.com/maps/api/place/details/json",
        params=params
    )
    return response.json()
```

### Environment Variable Required

```bash
# .env (backend)
GOOGLE_PLACES_API_KEY=AIzaSy...your-key-here
```

**⚠️ Important:** This key should be:
- Different from the frontend key (which will be deprecated)
- Restricted to server IP addresses only in Google Cloud Console
- Never committed to git

### Frontend Changes After Backend Is Ready

Once the backend endpoints exist, update `BarzAddressField` to use our API instead of the package:

```dart
// Current (INSECURE - uses exposed API key + third-party proxy):
PlaceSearchField(
  apiKey: 'AIzaSy...',  // ❌ Exposed in frontend
  webCorsProxyUrl: 'https://corsproxy.io',  // ❌ Third-party dependency
)

// Future (SECURE - uses our backend):
BarzAddressField(
  // No API key needed - backend handles it
  // No CORS proxy needed - same origin
)
```

### Implementation Checklist

**Backend:**
- [x] Add `GOOGLE_PLACES_API_KEY` to `.env` and Fly.io secrets *(key needed - see below)*
- [x] Create `/api/places/autocomplete` endpoint ✅
- [x] Create `/api/places/details` endpoint ✅
- [x] Create `/api/places/details/parsed` endpoint ✅ *(BONUS: Pre-parsed for bar creation)*
- [x] Add in-memory caching (30min autocomplete, 24h details)
- [ ] Optional: Migrate to Redis caching for multi-instance support

**Frontend (✅ COMPLETE - Jan 10, 2026):**
- [x] Remove `google_places_api_flutter` package dependency ✅
- [x] Update `BarzAddressField` to call our backend endpoints ✅
- [x] Remove exposed API key from frontend code ✅
- [x] Created `PlacesService` (`lib/core/services/places_service.dart`) ✅
- [ ] Test on web, iOS, and Android

### Ready-to-Use Endpoints

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/places/autocomplete` | GET | ✅ | Search for places |
| `/api/places/details` | GET | ✅ | Get full place details |
| `/api/places/details/parsed` | GET | ✅ | Get pre-parsed data for bar creation |

**Example Usage (from Flutter):**
```dart
// Autocomplete
final response = await http.get(
  Uri.parse('$baseUrl/api/places/autocomplete?input=Baxo+Bar&countries=br,pt,us'),
  headers: {'Authorization': 'Bearer $token'},
);

// Get parsed details for bar form
final details = await http.get(
  Uri.parse('$baseUrl/api/places/details/parsed?place_id=$placeId'),
  headers: {'Authorization': 'Bearer $token'},
);

// Response includes:
// {
//   "place_id": "ChIJ...",
//   "name": "Baxo Bar",
//   "address": "Rua Augusta, 1234",
//   "city": "São Paulo",
//   "state": "SP",
//   "postal_code": "01305-100",
//   "country_code": "BR",
//   "latitude": -23.5505,
//   "longitude": -46.6333
// }
```

### Billing Optimization (Optional)

Google charges per Autocomplete session + Details request. To minimize costs:

1. **Session Tokens:** Group autocomplete requests + 1 details request into a session
2. **Caching:** Cache popular searches (e.g., "bar" in São Paulo) for 24h
3. **Debouncing:** Already implemented (600ms) to reduce API calls
4. **Field Filtering:** Only request needed fields in details endpoint

---

## 📊 BUSINESS DASHBOARD: Analytics & Management Hub

> **Status:** ✅ FE + BE COMPLETE  
> **Priority:** HIGH - Core business experience  
> **Added:** January 12, 2026

### Overview

The Business Dashboard is the main hub for bar owners and staff after login. It displays analytics, quick actions, and navigation to all business features. The UI is **role-aware** - owners/admins see full analytics while cashiers see a simplified orders-focused view.

### Frontend Implementation Status ✅

**Files Created/Updated:**
- `lib/ui/business/business_dashboard_page.dart` - Main dashboard with role-aware components
- `lib/ui/business/business_shell.dart` - Responsive shell with side menu (web) / bottom nav (mobile)
- `lib/ui/business/widgets/business_side_menu.dart` - Web side navigation with bar switcher + "Add Bar"

### Dashboard Components by Role

| Component | Owner/Admin | Manager | Cashier |
|-----------|-------------|---------|---------|
| Welcome Header | ✅ | ✅ | ✅ |
| Today's Orders stat | ✅ | ✅ | ✅ |
| Pending Orders stat | ✅ | ✅ | ✅ |
| Revenue stat | ✅ | ✅ | ❌ |
| Avg. Ticket stat | ✅ | ❌ | ❌ |
| Campaign Promo Card | ✅ | ❌ | ❌ |
| Recent Orders list | ✅ | ✅ | ✅ |
| My Bars section | ✅ | ❌ | ❌ |
| Add Bar button | ✅ | ❌ | ❌ |
| Quick Actions | Full | Limited | Minimal |

### Backend Endpoints (✅ IMPLEMENTED)

#### 1. Dashboard Stats Endpoint

```http
GET /bars/{bar_id}/dashboard/stats?period=today

Authorization: Bearer <token>

Response:
{
  "period": "today",
  "orders": {
    "total": 47,
    "pending": 3,
    "completed": 42,
    "cancelled": 2,
    "trend_percent": 12.5  // vs yesterday/last week
  },
  "revenue": {
    "total": 4523.50,
    "currency": "BRL",
    "trend_percent": 8.3
  },
  "average_ticket": {
    "value": 96.24,
    "currency": "BRL",
    "trend_percent": -2.1
  },
  "top_items": [
    {"name": "Caipirinha", "quantity": 23, "revenue": 345.00},
    {"name": "Heineken 600ml", "quantity": 18, "revenue": 270.00}
  ]
}
```

**Query Parameters:**
| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `period` | `today`, `week`, `month` | `today` | Stats aggregation period |

#### 2. Recent Orders Endpoint

```http
GET /bars/{bar_id}/orders?limit=10&status=all

Authorization: Bearer <token>

Response:
{
  "orders": [
    {
      "id": 1234,
      "order_number": "A23",
      "status": "pending",
      "total": 156.00,
      "currency": "BRL",
      "items_count": 4,
      "table_number": "12",
      "customer_name": "Carlos A.",
      "created_at": "2026-01-12T20:45:00Z",
      "estimated_ready_at": "2026-01-12T21:00:00Z"
    },
    ...
  ],
  "pagination": {
    "total": 47,
    "page": 1,
    "per_page": 10,
    "has_more": true
  }
}
```

**Query Parameters:**
| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `limit` | 1-50 | 10 | Orders per page |
| `status` | `all`, `pending`, `preparing`, `ready`, `completed`, `cancelled` | `all` | Filter by status |
| `page` | 1+ | 1 | Pagination |

#### 3. Bar Status Endpoint

```http
GET /bars/{bar_id}/status

Authorization: Bearer <token>

Response:
{
  "bar_id": 16,
  "is_open": true,
  "current_schedule": {
    "day": "sunday",
    "open": "18:00",
    "close": "00:00"
  },
  "next_open": null,  // or "Monday 18:00" if closed
  "active_orders_count": 3,
  "active_tables_count": 8
}
```

#### 4. Toggle Bar Open/Closed

```http
POST /bars/{bar_id}/status/toggle

Authorization: Bearer <token>

Request:
{
  "is_open": false,
  "reason": "closing_early"  // optional: closing_early, emergency, maintenance
}

Response:
{
  "bar_id": 16,
  "is_open": false,
  "toggled_at": "2026-01-12T23:30:00Z",
  "reason": "closing_early"
}
```

### Dashboard UI Structure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  BUSINESS DASHBOARD                                                         │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ 🌙 Good evening                                              ● Open    ││
│  │ Baxo Bar                                                               ││
│  │ ┌─────────┐                                                            ││
│  │ │ Owner   │                                                            ││
│  │ └─────────┘                                                            ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │ 📋 47        │ │ ⏳ 3         │ │ 📈 R$ 4,523  │ │ 🎫 R$ 96     │       │
│  │ Today Orders │ │ Pending      │ │ Revenue      │ │ Avg. Ticket  │       │
│  │    +12%      │ │    ●         │ │    +8%       │ │              │       │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       │
│  (Cashier sees only first 2)                                               │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ 🎯 Boost Your Sales                                                    ││
│  │ Create a campaign and reach more customers in your area!               ││
│  │ [Create Campaign]                                          📈         ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│  (Owner/Admin only)                                                         │
│                                                                             │
│  Recent Orders                                          [View All →]        │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ 📋 No orders yet                                                       ││
│  │ Orders will appear here when customers place them                      ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
│  My Bars                                                [+ Add Bar]         │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐                              │
│  │ 🍺 Baxo   │ │ 🍺 Bar 2   │ │ ➕ Add Bar │                              │
│  │   Owner   │ │   Admin    │ │            │                              │
│  └────────────┘ └────────────┘ └────────────┘                              │
│  (Owner/Admin only, shows all user's bars)                                  │
│                                                                             │
│  Quick Actions                                                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────────┐    │
│  │ 💳       │ │ 📝       │ │ 🏷️       │ │ 📱       │ │ 👥 Invite     │    │
│  │ Cashier  │ │ Edit Menu│ │ New Promo│ │ Table QR │ │    Staff      │    │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └────────────────┘    │
│  (Shown based on permissions)                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Permission-Based Feature Access

Frontend uses `BarAccess` model with these permission flags:

```dart
class BarAccess {
  final int barId;
  final String barName;
  final BarRole role;  // owner, admin, manager, cashier, staff
  
  // Permission flags (from /me/bars response)
  final bool canManageOrders;
  final bool canEditMenu;
  final bool canManageStaff;
  final bool canManageAds;
  final bool canViewBilling;
}
```

**Expected `/me/bars` Response:**
```json
[
  {
    "bar_id": 16,
    "bar_name": "Baxo Bar",
    "role": "owner",
    "permissions": {
      "can_manage_orders": true,
      "can_edit_menu": true,
      "can_manage_staff": true,
      "can_manage_ads": true,
      "can_view_billing": true
    },
    "joined_at": "2026-01-12T19:50:31Z"
  }
]
```

### Quick Actions Navigation

| Action | Route | Permission Required |
|--------|-------|---------------------|
| Cashier | `/business/cashier` | `canManageOrders` |
| Edit Menu | `/business/menu` | `canEditMenu` |
| New Promo | `/business/promotions/new` | `canManageAds` |
| Table QR | `/business/tables/qr` | `canEditMenu` |
| Invite Staff | `/business/staff/invite` | `canManageStaff` |

### Add Bar Flow

1. User clicks "Add Bar" button (dashboard or side menu)
2. Navigate to `/create-bar` (same wizard as first-time creation)
3. On wizard completion with `pop(true)`:
4. FE triggers `SessionEvent.refreshBarAccess()`
5. Session BLoC calls `GET /me/bars` to fetch updated bar list
6. New bar appears in dashboard and bar switcher

### Implementation Checklist

**Frontend (✅ Complete):**
- [x] `BusinessDashboardPage` with role-aware components
- [x] `_WelcomeHeader` with greeting, bar name, role badge, open status
- [x] `_QuickStatsGrid` with conditional stats (2 for cashier, 4 for owner)
- [x] `_PromoteCampaignCard` for owners/admins only
- [x] `_RecentOrdersSection` with empty state
- [x] `_BarsOverviewSection` with horizontal scroll + Add Bar card
- [x] `_QuickActionsSection` with permission-based action chips
- [x] Add Bar button in side menu bar selector
- [x] Session refresh after bar creation

**Backend (✅ Complete - Jan 12, 2026):**
- [x] `GET /bars/{bar_id}/dashboard/stats` - Dashboard analytics
- [x] `GET /bars/{bar_id}/orders` - Recent orders list
- [x] `GET /bars/{bar_id}/status` - Bar open/closed status
- [x] `POST /bars/{bar_id}/status/toggle` - Toggle open/closed
- [x] `GET /me/bars` already includes `permissions` array

**Frontend (✅ Complete - Jan 12, 2026):**
- [x] `DashboardBloc` with LoadDashboard, RefreshDashboard, ToggleBarOpen events
- [x] `DashboardStats`, `BarStatus`, `RecentOrder` models
- [x] Dashboard API endpoints in `ApiEndpoints`
- [x] Dashboard methods in `BarNetworkDataSource`
- [x] `BusinessDashboardPage` updated to use real data from API
- [x] Real-time stats display with loading states
- [x] Order cards with status colors and formatting
- [x] Open/Closed toggle in header

---

## 🏪 BUSINESS APP QUICK REFERENCE

> **For FE team building the Business UI** - All bar owner features consolidated here.

### Business User Flow

```
1. Login → GET /me/bars → Check if user has bar roles
2. If no bars → Show "Create Bar" or "Accept Invitation" 
3. If has bars → Show BusinessShell with bar selector
4. Bar owner sees: Dashboard, Orders, Menu, Staff, Ads, Settings
```

### Key Endpoints by Feature

#### 📊 Dashboard & My Bars
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/me/bars` | GET | Get all bars user has access to (with roles/permissions) |
| `/me/bars/accept-invitation` | POST | Accept staff invitation |
| `/bars/{bar_id}` | GET | Get bar details |
| `/bars/{bar_id}` | PUT | Update bar info |

#### 🍔 Menu Management
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/menus/bar/{bar_id}` | GET | Get all menus for a bar |
| `/menus/` | POST | Create menu `{bar_id, name, description, is_active}` |
| `/menus/{menu_id}` | PUT | Update menu |
| `/menus/{menu_id}` | DELETE | Delete menu + all items (CASCADE) |
| `/menus/{menu_id}/items` | GET | Get all menu items |
| `/menus/{menu_id}/items` | POST | Add item `{name, price, description, category, available}` |
| `/menus/{menu_id}/items/{item_id}` | PUT | Update item |
| `/menus/{menu_id}/items/{item_id}` | DELETE | Delete item |
| `/menus/{menu_id}/items/{item_id}/availability` | PATCH | Quick toggle `{available: bool}` |

#### 👥 Staff Management
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/bars/{bar_id}/staff` | GET | List all staff members |
| `/bars/{bar_id}/staff/invite` | POST | Invite `{email/phone, role}` |
| `/bars/{bar_id}/staff/{staff_id}` | DELETE | Remove staff member |

**Roles (Hierarchy):** `owner` > `admin` > `manager` > `cashier` > `staff`

#### 💳 Subscription Plans
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/advertising/plans` | GET | Get available plans with pricing |
| `/advertising/subscriptions` | POST | Create subscription `{bar_id, tier, region_code}` |
| `/advertising/subscriptions/{bar_id}` | GET | Get current subscription status |
| `/advertising/subscriptions/{subscription_id}` | PUT | Update subscription |
| `/advertising/subscriptions/{subscription_id}/cancel` | POST | Cancel subscription |

**Tiers:** `regular` (Free), `master` (R$299/mo), `vip` (R$699/mo)

---

## 🏦 BANK ACCOUNT & PAYOUT COLLECTION ✅ BACKEND COMPLETE

> **Status:** ✅ IMPLEMENTED (Jan 11, 2026)  
> **Priority:** HIGH - Required for bar owner payouts

### Overview

To pay bar owners for their sales, we need to collect bank account information. Requirements vary by country based on local banking systems and Stripe Connect capabilities.

### Why This Is Needed

- Bar owners receive payouts from customer orders
- Stripe Connect requires bank account details for payouts
- Different countries use different banking identifiers (IBAN, CLABE, CBU, etc.)
- Business IDs (CNPJ, RFC, CUIT) required for compliance

### Country-Specific Requirements

| Country | Currency | Bank Identifier | Format | Business ID |
|---------|----------|-----------------|--------|-------------|
| 🇧🇷 Brazil | BRL | Bank Code + Branch + Account | 3 + 4 + varies | CNPJ (14 digits) |
| 🇲🇽 Mexico | MXN | CLABE | 18 digits | RFC (12-13 chars) |
| 🇦🇷 Argentina | ARS | CBU | 22 digits | CUIT (11 digits) |
| 🇨🇴 Colombia | COP | Account Number | varies | NIT (9-10 digits) |
| 🇺🇸 USA | USD | Routing + Account | 9 + varies | EIN (9 digits) |

### Bank Account Field Details

#### 🇧🇷 Brazil (PIX-enabled)
```json
{
  "country_code": "BR",
  "bank_code": "001",           // 3 digits (e.g., 001 = Banco do Brasil)
  "branch_code": "1234",        // 4 digits (agência)
  "account_number": "12345678", // varies by bank
  "account_type": "checking",   // checking | savings
  "pix_key": "12345678901",     // CPF/CNPJ/email/phone (optional alternative)
  "pix_key_type": "cpf"         // cpf | cnpj | email | phone | random
}
```

#### 🇲🇽 Mexico
```json
{
  "country_code": "MX",
  "clabe": "012180001234567890", // 18 digits - Clave Bancaria Estandarizada
  "account_holder_name": "Restaurant Name S.A. de C.V."
}
```

#### 🇦🇷 Argentina
```json
{
  "country_code": "AR",
  "cbu": "0140000012345678901234", // 22 digits - Clave Bancaria Uniforme
  "account_holder_name": "Restaurant Name S.R.L."
}
```

#### 🇨🇴 Colombia
```json
{
  "country_code": "CO",
  "bank_code": "001",           // Bank identifier
  "account_number": "1234567890",
  "account_type": "checking"    // checking | savings
}
```

#### 🇺🇸 USA
```json
{
  "country_code": "US",
  "routing_number": "110000000", // 9 digits (ABA routing)
  "account_number": "000123456789",
  "account_type": "checking"
}
```

### Proposed Wizard Flow Change

Current 5-step wizard:
1. Find Bar (Google Places)
2. Bar Details (name, address, phone, email, **CNPJ**)  ← Move CNPJ out
3. Photos
4. Hours
5. Review

**Proposed 6-step wizard:**
1. Find Bar (Google Places)
2. Bar Details (name, address, phone, email)  ← Basic info only
3. Photos
4. Hours
5. **🆕 Bank Account & Business ID** ← New step
6. Review

### New Step 5: Bank Account Form

```
┌─────────────────────────────────────────────────────────────────┐
│  Step 5: Payment Setup                                          │
│                                                                 │
│  🏦 Business Information                                        │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ CNPJ                                                        ││
│  │ ┌───────────────────────────────────────────────────────┐   ││
│  │ │ 12.345.678/0001-90                                    │   ││
│  │ └───────────────────────────────────────────────────────┘   ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  🏦 Bank Account for Payouts                                    │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Bank Code          Branch                                   ││
│  │ ┌─────────┐        ┌─────────┐                              ││
│  │ │ 001     │        │ 1234    │                              ││
│  │ └─────────┘        └─────────┘                              ││
│  │                                                             ││
│  │ Account Number                    Type                      ││
│  │ ┌─────────────────────────┐      ┌──────────────┐           ││
│  │ │ 12345678-9              │      │ Checking  ▼  │           ││
│  │ └─────────────────────────┘      └──────────────┘           ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ─── OR use PIX ───                                             │
│                                                                 │
│  PIX Key                             Type                       │
│  ┌─────────────────────────────┐    ┌──────────────┐            │
│  │ 12.345.678/0001-90          │    │ CNPJ      ▼  │            │
│  │ (same as CNPJ)              │    └──────────────┘            │
│  └─────────────────────────────┘                                │
│                                                                 │
│  [Back]                                      [Continue ✓]       │
└─────────────────────────────────────────────────────────────────┘
```

### Backend Requirements (✅ IMPLEMENTED - Jan 11, 2026)

#### New Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/bars/{bar_id}/bank-account` | GET | Get bar's bank account (masked) |
| `/bars/{bar_id}/bank-account` | POST | Create bank account |
| `/bars/{bar_id}/bank-account` | PUT | Update bank account |
| `/bars/{bar_id}/bank-account` | DELETE | Delete bank account |

#### Integration with Bar Wizard

`POST /bars/wizard` now accepts `bank_account` field:

```json
{
  "name": "Baxo Bar",
  "address": "...",
  "latitude": -23.55,
  "longitude": -46.63,
  "phone_number": "+5511999999999",
  "email": "bar@example.com",
  "owner_id": 1,
  "country_code": "BR",
  "business_id": "12.345.678/0001-90",
  "business_id_type": "CNPJ",
  
  "bank_account": {
    "country_code": "BR",
    "bank_code": "341",
    "branch_code": "1234",
    "account_number": "12345678-9",
    "account_type": "checking",
    "pix_key": "12345678000190",
    "pix_key_type": "cnpj"
  }
}
```

#### 1. Update Bar Creation Endpoint

```http
POST /bars/
Authorization: Bearer <token>

{
  // ... existing fields ...
  
  // Business ID (moved from step 2)
  "business_id": "12345678000190",
  "business_id_type": "CNPJ",
  
  // 🆕 Bank Account
  "bank_account": {
    "bank_code": "001",
    "branch_code": "1234",
    "account_number": "123456789",
    "account_type": "checking",
    "pix_key": "12345678000190",
    "pix_key_type": "cnpj"
  }
}
```

#### 2. Database Schema

```sql
-- Bank accounts table (separate for security)
CREATE TABLE bar_bank_accounts (
  id SERIAL PRIMARY KEY,
  bar_id INTEGER REFERENCES bars(id) ON DELETE CASCADE,
  country_code VARCHAR(2) NOT NULL,
  
  -- Brazil-specific
  bank_code VARCHAR(5),
  branch_code VARCHAR(10),
  account_number_encrypted TEXT,  -- Encrypted!
  account_type VARCHAR(20),
  pix_key_encrypted TEXT,
  pix_key_type VARCHAR(20),
  
  -- Mexico
  clabe_encrypted TEXT,
  
  -- Argentina
  cbu_encrypted TEXT,
  
  -- USA
  routing_number VARCHAR(9),
  
  -- Common
  account_holder_name VARCHAR(255),
  is_verified BOOLEAN DEFAULT FALSE,
  stripe_external_account_id VARCHAR(255),
  
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Encryption: Use Postgres pgcrypto or application-level encryption
-- Never store raw bank numbers in logs or error messages
```

#### 3. Stripe Connect Integration

```python
# When bar is approved for payouts
stripe.Account.create_external_account(
    connected_account_id,
    external_account={
        "object": "bank_account",
        "country": "BR",
        "currency": "brl",
        "account_holder_name": "Restaurant Name LTDA",
        "account_holder_type": "company",
        "routing_number": "001-1234",  # bank_code-branch_code
        "account_number": "123456789"
    }
)
```

### Frontend Implementation Checklist

```markdown
- [ ] Create `BankAccountStep` widget in steps folder
- [ ] Create `BarzBankCodeField` component (dropdown with Brazilian banks)
- [ ] Create `BarzClabeField` for Mexico (18 digit validation)
- [ ] Create `BarzCbuField` for Argentina (22 digit validation)
- [ ] Add PIX key type selector for Brazil
- [ ] Move CNPJ from BasicInfoStep to BankAccountStep
- [ ] Update CreateBarFormData with bank account fields
- [ ] Update wizard step count from 5 to 6
- [ ] Add country-aware field rendering
```

### Security Considerations

1. **Never log** bank account numbers in plain text
2. **Encrypt at rest** using AES-256 or Postgres pgcrypto
3. **Mask display** - show only last 4 digits (e.g., ****6789)
4. **Rate limit** bank account updates (max 3/day)
5. **Require re-auth** for bank account changes
6. **Audit trail** - log all bank account modifications

### Stripe PIX Support (Brazil)

Stripe Connect supports PIX for connected accounts in Brazil:
- Real-time payments between bank accounts
- Lower fees than card payments (~1% vs 2.99%)
- Requires `pix_payments` capability on connected account
- IOF tax (3.5%) applies to international transactions

```python
# Enable PIX for connected account
stripe.Account.modify(
    connected_account_id,
    capabilities={"pix_payments": {"requested": True}}
)
```

---

#### 📢 Ad Campaigns
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/advertising/campaigns` | GET | List campaigns `?bar_id=X` |
| `/advertising/campaigns` | POST | Create campaign (see schema below) |
| `/advertising/campaigns/{id}` | GET | Get campaign details |
| `/advertising/campaigns/{id}` | PUT | Update campaign |
| `/advertising/campaigns/{id}/pause` | POST | Pause campaign |
| `/advertising/campaigns/{id}/resume` | POST | Resume campaign |
| `/advertising/analytics/{campaign_id}` | GET | Get campaign analytics |

**Campaign Types:** `featured`, `search`, `map`, `promo_boost`, `banner`

#### 📦 Orders (Real-time)
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/orders/?bar_id=X` | GET | Get orders for bar |
| `/orders/{order_id}` | GET | Get order details |
| `/orders/{order_id}/status` | PUT | Update status `{status}` |
| `ws://host/ws/bar/{bar_id}/orders?token=JWT` | WS | Real-time order stream |

**Order Statuses:** `pending` → `confirmed` → `preparing` → `ready` → `completed`

#### 🎁 Promotions
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/promotions/bar/{bar_id}` | GET | Get bar's promotions |
| `/promotions/` | POST | Create promotion |
| `/promotions/{id}` | PUT | Update promotion |
| `/promotions/{id}` | DELETE | Delete promotion |
| `/promotions/{id}/toggle-active` | PUT | Toggle active status |

---

### Business UI Screens → API Mapping

| Screen | Primary Endpoints |
|--------|-------------------|
| **Dashboard** | `GET /me/bars`, `GET /orders/?bar_id=X&status=pending` |
| **Orders (Cashier)** | `WS /ws/bar/{bar_id}/orders`, `PUT /orders/{id}/status` |
| **Menu Management** | `GET /menus/bar/{bar_id}`, CRUD on `/menus/` and `/menus/{id}/items` |
| **Staff Management** | `GET /bars/{bar_id}/staff`, `POST invite`, `DELETE remove` |
| **Advertising** | `GET /advertising/plans`, `GET/POST /advertising/campaigns` |
| **Analytics** | `GET /advertising/analytics/{campaign_id}` |
| **Settings** | `PUT /bars/{bar_id}`, `GET/PUT /advertising/subscriptions` |

---

## 📊 Latest Changes (January 8, 2026)

### 📢 NEW: Advertising & Monetization System

We now have a complete **advertising/monetization system** for bar owners! This allows bars to boost visibility through paid campaigns and premium subscriptions.

#### Overview

**Subscription Tiers:**
| Tier | Price (BR) | Price (US) | Commission | Benefits |
|------|------------|------------|------------|----------|
| Regular | Free | Free | 15-18% | Basic listing, standard support |
| Master | R$299/month | $49/month | 12-15% | Featured placement, priority support, analytics |
| VIP | R$699/month | $149/month | 8-12% | Premium placement, dedicated manager, all features |

**Ad Products:**
| Product | Description | Use Case |
|---------|-------------|----------|
| `featured` | Featured Home Carousel | Main screen visibility |
| `search` | Sponsored Search Results | Appear at top of search |
| `map` | Map Spotlight | Highlighted on map view |
| `promo_boost` | Promotion Boost | Boost specific promotions |
| `banner` | Banner Ads | Display banners in app |

---

#### 🎯 Ad Serving Endpoints (For Client App)

These endpoints return ads to display in the client app. **No authentication required**.

##### GET `/advertising/serve/featured`

Returns featured ads for home screen carousel.

**Request:**
```
GET /advertising/serve/featured?latitude=-23.5505&longitude=-46.6333&limit=5
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `latitude` | float | ✅ Yes | - | User's latitude |
| `longitude` | float | ✅ Yes | - | User's longitude |
| `limit` | int | No | 10 | Max ads to return (1-20) |

**Response:**
```json
[
  {
    "bar_id": 8,
    "bar_name": "Porcão BH",
    "logo_url": "https://example.com/porcao-logo.png",
    "tagline": "O melhor churrasco de BH! 🥩🔥",
    "distance_km": 2.3,
    "campaign_id": 1
  },
  {
    "bar_id": 9,
    "bar_name": "Mascate",
    "logo_url": "https://example.com/mascate-logo.png",
    "tagline": "Drinks de Rum e Cervejas Artesanais 🍹",
    "distance_km": 5.1,
    "campaign_id": 2
  }
]
```

**Flutter Implementation:**
```dart
// In HomeScreen - Featured Carousel
Future<List<FeaturedAd>> getFeaturedAds() async {
  final position = await _locationService.getCurrentPosition();
  final response = await _dio.get('/advertising/serve/featured', queryParameters: {
    'latitude': position.latitude,
    'longitude': position.longitude,
    'limit': 5,
  });
  return (response.data as List).map((e) => FeaturedAd.fromJson(e)).toList();
}

// Widget
CarouselSlider(
  items: featuredAds.map((ad) => FeaturedAdCard(
    ad: ad,
    onTap: () {
      // Track click then navigate
      _trackClick(ad.campaignId);
      Navigator.pushNamed(context, '/bar/${ad.barId}');
    },
    onVisible: () => _trackImpression(ad.campaignId),
  )).toList(),
)
```

##### GET `/advertising/serve/search`

Returns sponsored search results to show at top of search.

**Request:**
```
GET /advertising/serve/search?latitude=-23.5505&longitude=-46.6333&query=cerveja&limit=3
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `latitude` | float | ✅ Yes | - | User's latitude |
| `longitude` | float | ✅ Yes | - | User's longitude |
| `query` | string | No | - | Search query (for relevance) |
| `category` | string | No | - | Category filter |
| `limit` | int | No | 3 | Max ads (1-5) |

**Response:**
```json
[
  {
    "bar_id": 9,
    "bar_name": "Mascate",
    "logo_url": "https://example.com/mascate-logo.png",
    "tagline": "Especialistas em Rum desde 2018",
    "position": 0,
    "campaign_id": 4
  }
]
```

**Flutter Implementation:**
```dart
// In SearchResults - Show sponsored at top
Widget build(BuildContext context) {
  return Column(children: [
    // Sponsored results (from /advertising/serve/search)
    if (sponsoredResults.isNotEmpty) ...[
      const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('Patrocinado', style: TextStyle(color: Colors.grey)),
      ),
      ...sponsoredResults.map((ad) => BarCard(
        bar: ad,
        isSponsored: true,
        onTap: () => _trackClick(ad.campaignId),
      )),
      const Divider(),
    ],
    // Organic results (from /bars/search)
    ...organicResults.map((bar) => BarCard(bar: bar)),
  ]);
}
```

##### GET `/advertising/serve/map`

Returns map spotlight ads for highlighted pins on map.

**Request:**
```
GET /advertising/serve/map?latitude=-23.5505&longitude=-46.6333&zoom_level=15&limit=5
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `latitude` | float | Yes | - | Map center latitude |
| `longitude` | float | Yes | - | Map center longitude |
| `zoom_level` | int | No | 15 | Current zoom level |
| `limit` | int | No | 5 | Max ads to return |

**Response:**
```json
[
  {
    "bar_id": 8,
    "bar_name": "Porcão BH",
    "latitude": -23.5495,
    "longitude": -46.6323,
    "logo_url": "https://example.com/porcao-logo.png",
    "campaign_id": 3
  }
]
```

**Flutter Implementation:**
```dart
// In MapScreen - Highlighted markers
Set<Marker> _buildMarkers() {
  final markers = <Marker>{};
  
  // Sponsored markers (highlighted/animated)
  for (final ad in sponsoredBars) {
    markers.add(Marker(
      markerId: MarkerId('sponsored_${ad.barId}'),
      position: LatLng(ad.latitude, ad.longitude),
      icon: _sponsoredIcon, // Custom highlighted icon
      onTap: () {
        _trackClick(ad.campaignId);
        _showBarDetails(ad.barId);
      },
    ));
  }
  
  // Regular markers
  for (final bar in regularBars) {
    markers.add(Marker(
      markerId: MarkerId('bar_${bar.id}'),
      position: LatLng(bar.latitude, bar.longitude),
      icon: _regularIcon,
    ));
  }
  
  return markers;
}
```

---

#### 📈 Impression & Click Tracking

**IMPORTANT:** Track impressions and clicks to measure ad performance and charge advertisers correctly.

##### POST `/advertising/track`

Track when ads are viewed or clicked. **No authentication required**.

**Request:**
```json
POST /advertising/track
{
  "campaign_id": 1,
  "action": "impression",      // "impression", "click", or "conversion"
  "placement": "home",         // Optional: "home", "search", "map", "promo"
  "latitude": -23.5505,        // Optional
  "longitude": -46.6333        // Optional
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `campaign_id` | int | ✅ Yes | - | Campaign ID from ad response |
| `action` | string | ✅ Yes | - | `impression`, `click`, or `conversion` |
| `placement` | string | No | `unknown` | Where ad was shown: `home`, `search`, `map`, `promo` |
| `session_id` | string | No | - | Client-side session ID for deduplication |
| `latitude` | float | No | - | User location for analytics |
| `longitude` | float | No | - | User location for analytics |

**Response:**
```json
{
  "status": "tracked"
}
```

**Flutter Implementation:**
```dart
class AdTrackingService {
  final Dio _dio;
  
  Future<void> trackImpression(int campaignId, String placement, {LatLng? location}) async {
    await _track(campaignId, 'impression', placement, location);
  }
  
  Future<void> trackClick(int campaignId, String placement, {LatLng? location}) async {
    await _track(campaignId, 'click', placement, location);
  }
  
  Future<void> trackConversion(int campaignId, String placement, {LatLng? location}) async {
    await _track(campaignId, 'conversion', placement, location);
  }
  
  Future<void> _track(int campaignId, String action, String placement, LatLng? location) async {
    try {
      await _dio.post('/advertising/track', data: {
        'campaign_id': campaignId,
        'action': action,
        'placement': placement,
        if (location != null) ...{
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
      });
    } catch (e) {
      // Silent fail - don't block UX for tracking
      debugPrint('Ad tracking failed: $e');
    }
  }
}
```

**Best Practices:**
- Track impressions when ad becomes visible (use `VisibilityDetector`)
- Track clicks before navigation (don't wait for response)
- Fire tracking calls in background, don't block UX
- Deduplicate: track impression once per session per ad

---

#### 🏪 Business App Endpoints (For Bar Owners)

These endpoints require authentication and are for bar owners to manage their advertising.

##### GET `/advertising/plans`

Get available subscription plans with regional pricing.

**Request:**
```
GET /advertising/plans?region_code=BR
```

**Response:**
```json
{
  "region_code": "BR",
  "currency": "BRL",
  "plans": [
    {
      "tier": "regular",
      "name": "Regular",
      "price": 0.0,
      "commission_rate": 0.15,
      "features": ["Basic listing", "Standard support"]
    },
    {
      "tier": "master",
      "name": "Master",
      "price": 299.0,
      "commission_rate": 0.12,
      "features": ["Featured placement", "Priority support", "Analytics dashboard"]
    },
    {
      "tier": "vip",
      "name": "VIP",
      "price": 699.0,
      "commission_rate": 0.08,
      "features": ["Premium placement", "Dedicated manager", "All features"]
    }
  ]
}
```

##### POST `/advertising/subscriptions`

Create a new subscription for a bar.

**Request:**
```json
POST /advertising/subscriptions
Authorization: Bearer {token}

{
  "bar_id": 8,
  "tier": "master",
  "region_code": "BR"
}
```

**Response:**
```json
{
  "id": 1,
  "bar_id": 8,
  "tier": "master",
  "status": "active",
  "current_period_start": "2026-01-08T00:00:00Z",
  "current_period_end": "2026-02-08T00:00:00Z",
  "created_at": "2026-01-08T12:00:00Z"
}
```

##### GET `/advertising/subscriptions/{bar_id}`

Get subscription status for a bar.

**Response:**
```json
{
  "id": 1,
  "bar_id": 8,
  "tier": "master",
  "status": "active",
  "current_period_start": "2026-01-08T00:00:00Z",
  "current_period_end": "2026-02-08T00:00:00Z",
  "auto_renew": true,
  "created_at": "2026-01-08T12:00:00Z"
}
```

##### POST `/advertising/campaigns`

Create a new ad campaign.

**Request:**
```json
POST /advertising/campaigns
Authorization: Bearer {token}

{
  "bar_id": 8,
  "name": "Weekend Promotion",
  "campaign_type": "featured",
  "budget_type": "credits",
  "budget_amount": 1000.0,
  "start_date": "2026-01-10T00:00:00Z",
  "end_date": "2026-01-17T00:00:00Z",
  "targeting": {
    "radius_km": 10,
    "target_audience": ["young_adults"]
  },
  "creative": {
    "tagline": "Happy Hour 50% OFF!",
    "image_url": "https://cdn.barz.app/campaigns/weekend.jpg"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `bar_id` | int | ✅ Yes | Bar running the campaign |
| `name` | string | ✅ Yes | Campaign name (internal) |
| `campaign_type` | string | ✅ Yes | `featured`, `search`, `map`, `promo_boost`, `banner` |
| `budget_type` | string | ✅ Yes | `credits`, `cash`, or `mixed` |
| `budget_amount` | float | ✅ Yes | Total budget |
| `start_date` | datetime | ✅ Yes | Campaign start |
| `end_date` | datetime | No | Campaign end (null = indefinite) |
| `targeting` | object | No | Targeting options |
| `creative` | object | No | Creative assets (tagline, images) |

**Response:**
```json
{
  "id": 5,
  "bar_id": 8,
  "name": "Weekend Promotion",
  "campaign_type": "featured",
  "status": "pending",
  "budget_type": "credits",
  "budget_amount": 1000.0,
  "budget_spent": 0.0,
  "impressions": 0,
  "clicks": 0,
  "conversions": 0,
  "start_date": "2026-01-10T00:00:00Z",
  "end_date": "2026-01-17T00:00:00Z",
  "created_at": "2026-01-08T12:00:00Z"
}
```

##### GET `/advertising/campaigns`

List campaigns for a bar.

**Request:**
```
GET /advertising/campaigns?bar_id=8
Authorization: Bearer {token}
```

**Response:**
```json
[
  {
    "id": 1,
    "bar_id": 8,
    "name": "Porcão BH - Featured Home",
    "campaign_type": "featured",
    "status": "active",
    "budget_spent": 150.0,
    "budget_amount": 1000.0,
    "impressions": 5420,
    "clicks": 312,
    "conversions": 45,
    "ctr": 5.76,
    "start_date": "2026-01-01T00:00:00Z",
    "end_date": "2026-01-31T00:00:00Z"
  }
]
```

##### GET `/advertising/analytics/{campaign_id}`

Get detailed campaign analytics.

**Response:**
```json
{
  "campaign_id": 1,
  "campaign_name": "Porcão BH - Featured Home",
  "campaign_type": "featured",
  "status": "active",
  "date_range": {
    "start": "2026-01-01T00:00:00Z",
    "end": "2026-01-08T00:00:00Z"
  },
  "metrics": {
    "impressions": 5420,
    "clicks": 312,
    "conversions": 45,
    "ctr": 5.76,
    "conversion_rate": 14.42,
    "cost_per_click": 0.48,
    "cost_per_conversion": 3.33
  },
  "budget": {
    "total": 1000.0,
    "spent": 150.0,
    "remaining": 850.0,
    "daily_average": 18.75
  },
  "daily_breakdown": [
    {"date": "2026-01-01", "impressions": 680, "clicks": 39, "conversions": 6},
    {"date": "2026-01-02", "impressions": 712, "clicks": 41, "conversions": 5}
  ]
}
```

---

#### 💳 All Advertising Endpoints Reference

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/advertising/plans` | GET | ❌ | Get subscription plans with pricing |
| `/advertising/subscriptions` | POST | ✅ | Create subscription |
| `/advertising/subscriptions/{bar_id}` | GET | ✅ | Get bar's subscription |
| `/advertising/subscriptions/{subscription_id}` | PUT | ✅ | Update subscription |
| `/advertising/subscriptions/{subscription_id}/cancel` | POST | ✅ | Cancel subscription |
| `/advertising/campaigns` | POST | ✅ | Create campaign |
| `/advertising/campaigns` | GET | ✅ | List campaigns |
| `/advertising/campaigns/{campaign_id}` | GET | ✅ | Get campaign details |
| `/advertising/campaigns/{campaign_id}` | PUT | ✅ | Update campaign |
| `/advertising/campaigns/{campaign_id}/pause` | POST | ✅ | Pause campaign |
| `/advertising/campaigns/{campaign_id}/resume` | POST | ✅ | Resume campaign |
| `/advertising/serve/featured` | GET | ❌ | Get featured ads |
| `/advertising/serve/search` | GET | ❌ | Get search ads |
| `/advertising/serve/map` | GET | ❌ | Get map ads |
| `/advertising/track` | POST | ❌ | Track impression/click |
| `/advertising/analytics/{campaign_id}` | GET | ✅ | Get campaign analytics |

---

### 🍔 REFACTOR: Menu Items Now in PostgreSQL (Breaking Change)

Menu items are now stored in **PostgreSQL** instead of MongoDB for proper referential integrity with orders, carts, and payments. This means:

1. ✅ **Menu items now have proper integer `id`** - can be referenced by cart/order items
2. ✅ **New fields added**: `id`, `description`, `category` 
3. ✅ **Better filtering**: filter by category, available items only
4. 🔴 **Field rename**: `item_name` → `name` (legacy endpoint still returns both)

#### Data Flow Fixed

```
MenuItem (id: 1) → CartItem (menu_item_id: 1) → OrderItem (menu_item_id: 1) → Payment
       ↓                     ↓                           ↓
   PostgreSQL FK ───────────────────────────────────────────→ Referential Integrity ✅
```

#### New Menu Item Schema

```json
{
  "id": 1,                                    // ✅ NEW: Integer ID for FK references
  "menu_id": 1,                               // Parent menu
  "name": "Caipirinha Clássica",              // ✅ Renamed from item_name
  "price": 22.90,
  "description": "Cachaça artesanal, limão e açúcar",  // ✅ NEW
  "category": "drinks",                       // ✅ NEW: for filtering
  "picture": "https://cdn.barz.app/...",
  "available": true,
  "display_order": 0,                         // ✅ NEW: for sorting
  "created_at": "2026-01-07T22:15:14.758444",
  "updated_at": "2026-01-07T22:15:14.758444"
}
```

#### Menu Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/menus/` | POST | Create a menu |
| `/menus/bar/{bar_id}` | GET | Get all menus for a bar |
| `/menus/{menu_id}` | GET | Get menu by ID |
| `/menus/{menu_id}/full` | GET | Get menu with all items |
| `/menus/{menu_id}` | PUT | Update menu |
| `/menus/{menu_id}` | DELETE | Delete menu + items (CASCADE) |

#### Menu Item Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/menus/{menu_id}/items` | GET | Get all items for menu |
| `/menus/{menu_id}/items?category=drinks` | GET | Filter by category |
| `/menus/{menu_id}/items?available_only=true` | GET | Only available items |
| `/menus/{menu_id}/items` | POST | Add item to menu |
| `/menus/{menu_id}/items/{item_id}` | GET | Get specific item |
| `/menus/{menu_id}/items/{item_id}` | PUT | Update item |
| `/menus/{menu_id}/items/{item_id}` | DELETE | Delete item |
| `/menus/{menu_id}/items/{item_id}/availability` | PATCH | Quick toggle availability |

#### Legacy Endpoint (Backward Compatible)

```
GET /menus/items/{menu_id}  ⚠️ DEPRECATED - use GET /menus/{menu_id}/items
```

Returns items in old format with both `item_name` (legacy) and `name` (new):
```json
{
  "items": [
    {
      "id": 1,          // ✅ NEW: Now includes ID!
      "item_name": "Caipirinha",  // Legacy field
      "name": "Caipirinha",       // New field
      "price": 22.90,
      "description": "...",
      "category": "drinks",
      "available": true,
      "picture": null
    }
  ]
}
```

#### Flutter FE Action Required

Update your MenuItem model to include the new fields:

```dart
class MenuItem {
  final int id;           // ✅ NEW - use this for cart/order references
  final int menuId;
  final String name;      // ✅ Use 'name' instead of 'item_name'
  final double price;
  final String? description;  // ✅ NEW
  final String? category;     // ✅ NEW
  final String? picture;
  final bool available;
  final int displayOrder;     // ✅ NEW
  
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      menuId: json['menu_id'],
      name: json['name'] ?? json['item_name'],  // Fallback for legacy
      price: (json['price'] as num).toDouble(),
      description: json['description'],
      category: json['category'],
      picture: json['picture'],
      available: json['available'] ?? true,
      displayOrder: json['display_order'] ?? 0,
    );
  }
}
```

Update cart/order to use `menu_item_id`:
```dart
class CartItem {
  final int menuItemId;      // Reference to MenuItem.id
  final String menuItemName; // Denormalized for display
  final int quantity;
  final double unitPrice;
}
```

---

### 🔥 NEW: "Most Desired Drinks" Feature (Trending & Categories)

New endpoints to power the "Most Desired Drinks" carousel and category filters in the FE! This aggregates drink data across all bars for discovery features.

#### Available Categories

| Category | Emoji | Label | Examples |
|----------|-------|-------|----------|
| `drinks_trending` | 🔥 | Em Alta | Moscow Mule, Aperol Spritz, Espresso Martini, Negroni |
| `cachaça_cocktails` | 🇧🇷 | Drinks Brasileiros | Caipirinha, Rabo de Galo, Caju Amigo, Leite de Onça |
| `drinks_classicos` | 🍸 | Clássicos | Mojito, Margarita, Piña Colada, Cuba Libre, Daiquiri |
| `batidas` | 🥤 | Batidas | Batida de Coco, Maracujá, Amendoim |
| `cervejas` | 🍺 | Cervejas | Chopp, Heineken, Corona, IPAs, Weiss |
| `destilados` | 🥃 | Destilados | Shots de Cachaça, Rum, Tequila, Jägermeister |
| `petiscos_fritos` | 🍟 | Fritos | Batata Frita, Bolinho, Coxinha, Onion Rings |
| `petiscos_grelhados` | 🔥 | Grelhados | Calabresa, Espetinhos, Picanha na Chapa |
| `tabuas` | 🧀 | Tábuas | Frios, Carnes, Mistas |
| `especiais` | ⭐ | Especiais | Combos, Caldinhos (Mocotó, Feijão) |

#### GET `/menus/trending/drinks`

Returns trending/popular drinks across all bars. Perfect for home screen carousels.

**Request:**
```
GET /menus/trending/drinks?limit=10&categories=drinks_trending,cachaça_cocktails
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | int | 20 | Max items (1-50) |
| `categories` | string | `drinks_trending,cachaça_cocktails,drinks_classicos` | Comma-separated categories |

**Response:**
```json
[
  {
    "id": 10,
    "name": "Moscow Mule",
    "price": 32.90,
    "description": "Vodka, ginger beer, limão, servido na caneca de cobre",
    "category": "drinks_trending",
    "available": true,
    "menu_id": 3
  },
  {
    "id": 11,
    "name": "Aperol Spritz",
    "price": 34.90,
    "description": "Aperol, prosecco, água com gás, fatia de laranja",
    "category": "drinks_trending",
    "available": true,
    "menu_id": 3
  }
]
```

#### GET `/menus/trending/categories`

Returns all available categories with labels and counts. Use for building category filter UI.

**Request:**
```
GET /menus/trending/categories
```

**Response:**
```json
{
  "drink_categories": [
    {"category": "drinks_trending", "label": "🔥 Em Alta", "description": "Moscow Mule, Aperol Spritz, Espresso Martini"},
    {"category": "cachaça_cocktails", "label": "🇧🇷 Drinks Brasileiros", "description": "Caipirinha, Rabo de Galo, Batidas"},
    {"category": "drinks_classicos", "label": "🍸 Clássicos", "description": "Mojito, Margarita, Piña Colada"},
    {"category": "batidas", "label": "🥤 Batidas", "description": "Coco, Maracujá, Amendoim"},
    {"category": "cervejas", "label": "🍺 Cervejas", "description": "Chopp, Long Necks, Artesanais"},
    {"category": "destilados", "label": "🥃 Destilados", "description": "Shots, Cachaça, Rum, Tequila"}
  ],
  "food_categories": [
    {"category": "petiscos_fritos", "label": "🍟 Fritos", "description": "Batata, Bolinho, Coxinha"},
    {"category": "petiscos_grelhados", "label": "🔥 Grelhados", "description": "Calabresa, Espetinhos, Carnes"},
    {"category": "tabuas", "label": "🧀 Tábuas", "description": "Frios, Carnes, Mistas"}
  ],
  "category_counts": {
    "cervejas": 40,
    "petiscos_fritos": 26,
    "drinks_classicos": 18,
    "petiscos_grelhados": 17,
    "sem_alcool": 16,
    "cachaça_cocktails": 13,
    "drinks_trending": 11
  }
}
```

#### Flutter Implementation

```dart
// TrendingDrinksService
class TrendingDrinksService {
  final Dio _dio;
  
  /// Get trending drinks for home carousel
  Future<List<MenuItem>> getTrendingDrinks({int limit = 10}) async {
    final response = await _dio.get('/menus/trending/drinks', queryParameters: {
      'limit': limit,
      'categories': 'drinks_trending,cachaça_cocktails',
    });
    return (response.data as List).map((e) => MenuItem.fromJson(e)).toList();
  }
  
  /// Get category filters for UI
  Future<DrinkCategories> getCategories() async {
    final response = await _dio.get('/menus/trending/categories');
    return DrinkCategories.fromJson(response.data);
  }
}

// Category model
class DrinkCategory {
  final String category;
  final String label;      // "🔥 Em Alta"
  final String description;
  
  factory DrinkCategory.fromJson(Map<String, dynamic> json) => DrinkCategory(
    category: json['category'],
    label: json['label'],
    description: json['description'],
  );
}
```

#### UI Design Suggestion

```
┌────────────────────────────────────────────────────┐
│ 🔥 Drinks em Alta                      [Ver todos] │
├────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐    │
│ │Moscow   │ │Aperol   │ │Espresso │ │Negroni  │    │
│ │Mule     │ │Spritz   │ │Martini  │ │         │ →  │
│ │R$ 32,90 │ │R$ 34,90 │ │R$ 36,90 │ │R$ 34,90 │    │
│ └─────────┘ └─────────┘ └─────────┘ └─────────┘    │
├────────────────────────────────────────────────────┤
│ 🇧🇷 Drinks Brasileiros                [Ver todos] │
├────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐    │
│ │Caipirinh│ │Rabo de  │ │Batida de│ │Caju     │    │
│ │a Limão  │ │Galo     │ │Coco     │ │Amigo    │ →  │
│ │R$ 19,90 │ │R$ 28,90 │ │R$ 22,90 │ │R$ 18,90 │    │
│ └─────────┘ └─────────┘ └─────────┘ └─────────┘    │
└────────────────────────────────────────────────────┘
```

---

## 📊 Previous Changes (January 7, 2026)

### 🔴 BREAKING: Promotions Endpoint Now Requires Location

The `/promotions/` endpoint now requires location parameters to be consistent with `/bars/`. Promotions are only returned for bars within the user's search radius.

**Old Call (deprecated):**
```
GET /promotions/?active_only=true
```

**New Call (required):**
```
GET /promotions/?latitude=-22.67&longitude=-48.69&max_distance=5000&active_only=true
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `latitude` | float | ✅ Yes | - | User's latitude |
| `longitude` | float | ✅ Yes | - | User's longitude |
| `max_distance` | float | No | 5000 | Search radius in meters |
| `active_only` | bool | No | true | Only active promotions |
| `limit` | int | No | 50 | Max results (1-100) |

**Flutter FE Action Required:**
```dart
// Update PromotionsRepository to pass location
Future<List<Promotion>> getNearbyPromotions() async {
  final position = await _locationService.getCurrentPosition();
  final response = await _dio.get('/promotions/', queryParameters: {
    'latitude': position.latitude,
    'longitude': position.longitude,
    'max_distance': 5000.0,  // 5km default, or use user preference
    'active_only': true,
  });
  return (response.data as List).map((e) => Promotion.fromJson(e)).toList();
}
```

---

## 📊 Previous Changes (January 6, 2026)

### 🌎 Country-Guided Onboarding Workflow - NEW!

We now support **multi-country operations** with a **gateway-driven approach**. Countries are enabled based on available payment gateways, with regulatory compliance verified per country before launch.

#### Payment Gateways & Coverage

| Gateway | Coverage | Payment Methods | Currencies |
|---------|----------|-----------------|------------|
| **Stone/Pagar.me** | Brazil | Pix, Credit Card, Debit Card, Boleto | BRL |
| **Stripe** | US, Canada, Europe, APAC, 40+ countries | Credit Card, Debit Card, Apple Pay, Google Pay | USD, EUR, GBP, CAD, AUD, JPY, MXN, BRL |
| **MercadoPago** | Latin America | Credit Card, Debit Card, MP Wallet, Pix | ARS, MXN, CLP, COP, PEN, UYU, BRL |
| **PayPal** | Global (200+ countries) | PayPal, Credit Card, Debit Card | USD, EUR, GBP, CAD, AUD, BRL, MXN |

#### Currently Enabled Countries (Phase 1-3)

| Phase | Countries | Gateway |
|-------|-----------|---------|
| **Phase 1** | 🇧🇷 Brazil (BR) | Stone |
| **Phase 2** | 🇦🇷 Argentina (AR), 🇲🇽 Mexico (MX), 🇨🇱 Chile (CL), 🇨🇴 Colombia (CO), 🇵🇪 Peru (PE) | MercadoPago |
| **Phase 3** | 🇺🇸 USA (US), 🇨🇦 Canada (CA) | Stripe |

> **Note:** Countries can be enabled dynamically. The backend has gateway mappings for 25+ countries. New countries are added as regulatory compliance is verified.

#### New Endpoints

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/me/onboarding` | POST | ✅ Bearer | Complete onboarding (set user_type + country) |
| `/me/payment-gateway` | GET | ✅ Bearer | Get payment gateway for user's country |
| `/me/available-countries` | GET | ❌ Public | Get list of enabled countries (for UI) |

#### GET `/me/available-countries` (Public - No Auth)

Use this to populate country selector in onboarding UI:

**Response:**
```json
{
  "enabled_countries": ["AR", "BR", "CA", "CL", "CO", "MX", "PE", "US"],
  "countries": [
    {
      "code": "BR",
      "gateway": "stone",
      "gateway_name": "Stone/Pagar.me",
      "payment_methods": ["pix", "credit_card", "debit_card", "boleto"]
    },
    {
      "code": "US",
      "gateway": "stripe",
      "gateway_name": "Stripe",
      "payment_methods": ["credit_card", "debit_card", "apple_pay", "google_pay"]
    }
  ],
  "total": 8
}
```

#### POST `/me/onboarding`

**Request:**
```json
{
  "user_type": "client",      // "client" or "business"
  "country_code": "BR"        // Must be in enabled_countries
}
```

**Response:** (ProfileResponse)
```json
{
  "display_name": "Carlos",
  "email": "carlos@gmail.com",
  "avatar_url": null,
  "terms_accepted": false,
  "privacy_accepted": false,
  "user_type": "client",
  "country_code": "BR"
}
```

**Validation:**
- `country_code` must be in the enabled countries list
- Returns 422 with message listing available countries if not enabled

#### GET `/me/payment-gateway`

**Response:**
```json
{
  "gateway": "stone",
  "gateway_name": "Stone/Pagar.me",
  "country_code": "BR",
  "payment_methods": ["pix", "credit_card", "debit_card", "boleto"],
  "currencies": ["BRL"]
}
```

#### Updated Profile Response

The profile endpoint now includes `country_code`:

```json
GET /me/profile

{
  "display_name": "Carlos",
  "email": "carlos@gmail.com",
  "avatar_url": null,
  "terms_accepted": true,
  "privacy_accepted": true,
  "user_type": "business",
  "country_code": "AR"
}
```

#### Frontend Onboarding Flow

```
1. User signs in → POST /auth/phone-login (or google/apple)
   
2. If response has is_new_user: true → Start onboarding flow

3. Fetch available countries (cache this):
   GET /me/available-countries
   → Shows which countries are enabled + their payment methods

4. Show role selection screen:
   ┌─────────────────────────────┐
   │  Welcome to BARZ! 🍻        │
   │                             │
   │  I am a...                  │
   │                             │
   │  [🍺 Bar Customer]          │
   │  [🏪 Bar Owner/Staff]       │
   └─────────────────────────────┘

5. Detect country from phone number OR show country picker:
   - Auto-detect: +55 → BR, +54 → AR, +1 → US
   - If country not in enabled list → show picker with enabled countries
   - Show payment methods available for selected country

6. POST /me/onboarding
   {
     "user_type": "client",  // or "business"
     "country_code": "BR"
   }

7. Show terms/privacy acceptance screens:
   - POST /me/accept-terms
   - POST /me/accept-privacy

8. If business: Show business profile completion
   - PUT /me/profile with business details

9. Done! Navigate to main app
   - Clients → Browse bars, order drinks
   - Business → Dashboard to create/manage bar
```

#### Phone Number → Country Detection (FE Helper)

```dart
String? detectCountryFromPhone(String phone, List<String> enabledCountries) {
  final prefixMap = {
    '+55': 'BR',  // Brazil
    '+54': 'AR',  // Argentina
    '+1': 'US',   // USA/Canada (check if US or CA enabled)
    '+52': 'MX',  // Mexico
    '+56': 'CL',  // Chile
    '+57': 'CO',  // Colombia
    '+51': 'PE',  // Peru
    '+598': 'UY', // Uruguay
    '+58': 'VE',  // Venezuela
    '+44': 'GB',  // UK
    '+49': 'DE',  // Germany
    '+33': 'FR',  // France
    '+34': 'ES',  // Spain
    '+39': 'IT',  // Italy
    '+351': 'PT', // Portugal
    '+61': 'AU',  // Australia
    '+64': 'NZ',  // New Zealand
    '+81': 'JP',  // Japan
    '+65': 'SG',  // Singapore
  };
  
  for (final entry in prefixMap.entries) {
    if (phone.startsWith(entry.key)) {
      final country = entry.value;
      // Only return if country is enabled
      if (enabledCountries.contains(country)) {
        return country;
      }
    }
  }
  return null; // Country not detected or not enabled → show picker
}
```

#### Country Picker Widget Example

```dart
class CountryPicker extends StatelessWidget {
  final List<CountryInfo> countries; // From /me/available-countries
  final Function(String) onSelected;
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: countries.length,
      itemBuilder: (context, index) {
        final country = countries[index];
        return ListTile(
          leading: Text(countryFlag(country.code)), // 🇧🇷 🇦🇷 🇺🇸
          title: Text(countryName(country.code)),
          subtitle: Text('${country.gatewayName} • ${country.paymentMethods.join(", ")}'),
          onTap: () => onSelected(country.code),
        );
      },
    );
  }
}
```

---

### 🔒 Security Update: aiohttp Vulnerability Fixes

Updated `aiohttp` from `3.10.5` → `3.13.3` to fix **10 security vulnerabilities**:

| Severity | CVE | Issue |
|----------|-----|-------|
| High | CVE-2025-69228 | DoS through large payloads |
| High | CVE-2025-XXXXX | HTTP Parser zip bomb |
| Moderate | CVE-2024-52304 | Request smuggling (chunk extensions) |
| Moderate | Multiple | DoS through chunked messages, bypassing asserts |
| Low | Multiple | Unicode parsing, cookie warnings, path leaks |

**No action required from FE** - this is a backend dependency update.

---

### 🐛 Bug Fix: DateTime Timezone Handling

Fixed `PUT /me/profile` returning 500 error due to timezone-aware vs timezone-naive datetime mismatch.

**Before:** `TypeError: can't subtract offset-naive and offset-aware datetimes`  
**After:** ✅ Works correctly

---

## 📊 Previous Changes (January 5, 2026)

### 🔐 Token Refresh System - IMPLEMENTED

#### Overview
We now use a **dual-token system** for better session management:
- **Access Token**: Short-lived JWT (1 hour default), used for API authentication
- **Refresh Token**: Long-lived opaque token (30 days or matches provider), used to get new access tokens

#### Benefits
- ✅ Users stay logged in for up to 30 days (or until Google/Apple token expires)
- ✅ Automatic token refresh without re-login
- ✅ Secure: short-lived access tokens minimize exposure
- ✅ Multi-device support: each device gets its own refresh token

#### New Response Format
All login endpoints now return:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "a1b2c3d4e5f6...",
  "token_type": "bearer",
  "expires_in": 3600,
  "is_new_user": false
}
```

| Field | Description |
|-------|-------------|
| `access_token` | JWT for API calls (1 hour) |
| `refresh_token` | Long-lived token to get new access tokens (30 days) |
| `token_type` | Always "bearer" |
| `expires_in` | Seconds until access token expires |
| `is_new_user` | Whether user was just created |

#### Updated Login Requests
FE can now optionally send the OAuth provider's token expiration:

**Google Login:**
```json
POST /auth/google-login
{
  "id_token": "eyJhbGciOiJSUzI1NiIs...",
  "email": "user@gmail.com",
  "display_name": "John Doe",
  "token_expiration": 1767900000  // Optional: Unix timestamp of Google token expiry
}
```

**Apple Login:**
```json
POST /auth/apple-login
{
  "id_token": "eyJhbGciOiJSUzI1NiIs...",
  "email": "user@privaterelay.appleid.com",
  "display_name": "John Doe",
  "token_expiration": 1767900000  // Optional: Unix timestamp of Apple token expiry
}
```

If `token_expiration` is provided, the refresh token will match that expiration (capped at 90 days).

#### New Endpoints

| Endpoint | Method | Request Body | Response |
|----------|--------|--------------|----------|
| `/auth/refresh` | POST | `{refresh_token: string}` | Same as login response |
| `/auth/logout` | POST | `{refresh_token?: string}` | `{message: "Logged out successfully"}` |

**Refresh Token:**
```json
POST /auth/refresh
{
  "refresh_token": "a1b2c3d4e5f6..."
}
```
Response: Same format as login (new access_token, same refresh_token)

**Logout:**
```json
POST /auth/logout
{
  "refresh_token": "a1b2c3d4e5f6..."  // Optional: revokes specific token
}
```

#### Frontend Implementation Guide

1. **Store both tokens** securely (use secure storage, not plain SharedPreferences)

2. **On API 401 response**, try to refresh:
```dart
// In your Dio interceptor
onError: (error) async {
  if (error.response?.statusCode == 401) {
    // Try to refresh the token
    try {
      final newTokens = await authRepository.refreshToken(storedRefreshToken);
      await tokenStorage.saveTokens(newTokens);
      
      // Retry the original request with new token
      error.requestOptions.headers['Authorization'] = 'Bearer ${newTokens.accessToken}';
      return dio.fetch(error.requestOptions);
    } catch (e) {
      // Refresh failed - force logout
      await authRepository.logout();
      navigateToLogin();
    }
  }
  throw error;
}
```

3. **On logout**, revoke the refresh token:
```dart
await authRepository.logout(refreshToken: storedRefreshToken);
await tokenStorage.clearAllTokens();
```

4. **Optional: Send provider token expiration** for longer sessions:
```dart
// For Google Sign-In
final googleUser = await GoogleSignIn().signIn();
final googleAuth = await googleUser.authentication;

// Get expiration from the ID token claims
final claims = JwtDecoder.decode(googleAuth.idToken!);
final expiration = claims['exp'] as int?;

await authRepository.googleLogin(
  idToken: googleAuth.idToken!,
  email: googleUser.email,
  displayName: googleUser.displayName,
  tokenExpiration: expiration,  // Send to backend
);
```

#### Error Codes
| Error Code | HTTP Status | When |
|------------|-------------|------|
| `INVALID_TOKEN` | 401 | Refresh token not found or malformed |
| `SESSION_EXPIRED` | 401 | Refresh token has expired (needs re-login) |
| `FORBIDDEN` | 403 | User account is inactive |
| `USER_NOT_FOUND` | 404 | User was deleted |

---

## 📊 Latest Changes (January 4, 2026)

### ✅ Authentication & Profile Endpoints - IMPLEMENTED

#### Auth Endpoints (Server-Side Token Verification)
All OAuth tokens are now verified server-side before creating/returning users.

| Endpoint | Method | Request Body | Response |
|----------|--------|--------------|----------|
| `/auth/phone-login` | POST | Firebase ID token in header | `{access_token, token_type, is_new_user}` |
| `/auth/google-login` | POST | `{id_token, email?, display_name?}` | `{access_token, token_type, is_new_user}` |
| `/auth/apple-login` | POST | `{id_token, email?, display_name?}` | `{access_token, token_type, is_new_user}` |

**Note:** `is_new_user` flag indicates if user was just created (FE should show registration completion).

#### Profile Endpoints (Authenticated)
| Endpoint | Method | Request Body | Response |
|----------|--------|--------------|----------|
| `/me/profile` | GET | - | `{display_name, email, avatar_url, terms_accepted, privacy_accepted, user_type, country_code}` |
| `/me/profile` | PUT | `{display_name?, email?}` | Updated profile |
| `/me/accept-terms` | POST | `{}` | `{message, terms_accepted: true}` |
| `/me/accept-privacy` | POST | `{}` | `{message, privacy_accepted: true}` |
| `/me/onboarding` | POST | `{user_type, country_code}` | Updated profile |
| `/me/payment-gateway` | GET | - | `{gateway, country_code, payment_methods}` |

#### Registration Flow (Updated with Country)
1. User logs in via Phone/Google/Apple
2. Backend returns `is_new_user: true` if new
3. FE shows onboarding: role selection + country detection
4. FE calls `POST /me/onboarding` with `{user_type, country_code}`
5. FE calls `GET /me/profile` to check completeness
6. If `terms_accepted` or `privacy_accepted` is false, show acceptance screens
7. FE calls `POST /me/accept-terms` and `POST /me/accept-privacy`
8. FE calls `GET /me/payment-gateway` to know which payment methods to show
9. User can now access main app

#### Token Verification
- **Phone:** Firebase Admin SDK verifies ID token
- **Google:** Firebase first → fallback Google tokeninfo API
- **Apple:** Firebase first → fallback JWT decode

---

## 🔧 Platform Configuration Required

### 1. Firebase Console (✅ Already Configured)
Your `fb-barz-admin.json` is already set up. Just ensure these auth providers are enabled:

**Firebase Console → Authentication → Sign-in method:**
- [x] Phone (SMS) - Already enabled
- [x] Google - Enable if not already
- [x] Apple - Enable if not already

### 2. Google Cloud Console (For Google Sign-In)
**Required for web and native Google Sign-In:**

1. Go to: https://console.cloud.google.com/apis/credentials
2. Select your Firebase project
3. Create OAuth 2.0 Client IDs:

| Platform | Type | What you'll get |
|----------|------|-----------------|
| iOS | iOS | `CLIENT_ID` (for GoogleSignIn) |
| Android | Android | `CLIENT_ID` + SHA-1 fingerprint |
| Web | Web application | `CLIENT_ID` + `CLIENT_SECRET` |

4. Configure OAuth consent screen:
   - Add app name, support email
   - Add scopes: `email`, `profile`, `openid`

**What FE needs from you:**
- iOS OAuth Client ID
- Android OAuth Client ID  
- Web OAuth Client ID

### 3. Apple Developer Console (For Apple Sign-In)
**Required for Apple Sign-In on iOS and Web:**

1. Go to: https://developer.apple.com/account/resources/identifiers
2. Create/configure:

| Item | Where | What to do |
|------|-------|------------|
| **App ID** | Identifiers → App IDs | Enable "Sign in with Apple" capability |
| **Service ID** | Identifiers → Service IDs | For web login (add domains + return URLs) |
| **Key** | Keys | Create key with "Sign in with Apple" enabled |

3. For **Service ID** (web):
   - Domains: `barz-backend-bold-sun-5691.fly.dev`, `your-frontend-domain.com`
   - Return URLs: `https://your-frontend-domain.com/auth/callback`

**What FE needs from you:**
- Service ID (for web)
- Team ID
- Key ID + `.p8` key file (for web callback verification)

### 4. Backend Environment Variables
Ensure these are set in Fly.io:

```bash
# Already set
FIREBASE_CREDENTIALS_JSON="{...}"  # ✅ Already configured
SECRET_KEY="your-jwt-secret"       # ✅ Already configured

# Optional (only if using direct Apple verification, not Firebase)
APPLE_TEAM_ID="your-team-id"
APPLE_KEY_ID="your-key-id"
APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

---

### ✅ Role-Based Access Control (RBAC) - DUAL APP ARCHITECTURE

The app now supports **two user experiences in ONE app** based on user roles:

#### User Types
| Type | Description |
|------|-------------|
| `client` | Regular bar-goer (browse, order, track, earn cashback) |
| `business` | Bar owner/staff (manage bar, orders, staff) |

#### Bar-Specific Roles (Hierarchy: OWNER > ADMIN > MANAGER > CASHIER > STAFF)
| Role | Description | Key Permissions |
|------|-------------|-----------------|
| `owner` | Full control, can delete bar | All permissions |
| `admin` | Full control except ownership | Menu, Orders, Staff, Billing, Ads |
| `manager` | Day-to-day operations | Menu edit, Order process, Analytics |
| `cashier` | Process orders (cashier view) | Order view/process, Menu view |
| `staff` | View-only, receive notifications | View only |

#### New Tables (Alembic migration: `rbac001`)
- `user_profiles` - Extended user info, FCM tokens, user type
- `bar_staff` - User roles per bar (user can have different roles at different bars)
- `staff_invitations` - Pending staff invitations

#### New Endpoints

**Staff Management (`/bars/{bar_id}/staff`)**
```
GET    /bars/{bar_id}/staff          - List staff (requires STAFF_VIEW)
POST   /bars/{bar_id}/staff/invite   - Invite staff (requires STAFF_MANAGE)
DELETE /bars/{bar_id}/staff/{id}     - Remove staff (requires STAFF_MANAGE)
```

**My Bars (`/me/bars`)**
```
GET    /me/bars                      - Get all bars user has access to
POST   /me/bars/accept-invitation    - Accept staff invitation
```

#### Example: Staff Invite Request
```json
POST /bars/12/staff/invite
{
  "email": "cashier@example.com",  // or "phone": "+5511999999999"
  "role": "cashier"
}
```

Response:
```json
{
  "id": 1,
  "bar_id": 12,
  "email": "cashier@example.com",
  "role": "cashier",
  "status": "pending",  // or "accepted" if user exists
  "invitation_code": "abc123xyz",
  "expires_at": "2026-01-10T12:00:00Z"
}
```

#### Example: My Bars Response
```json
GET /me/bars
[
  {
    "bar_id": 12,
    "bar_name": "Bar do Zé",
    "role": "owner",
    "permissions": ["bar:view", "bar:edit", "bar:delete", "menu:view", "menu:edit", ...]
  },
  {
    "bar_id": 45,
    "bar_name": "Boteco da Esquina",
    "role": "cashier",
    "permissions": ["bar:view", "menu:view", "order:view", "order:process"]
  }
]
```

---

## 📊 Previous Changes (January 2, 2026)

### ✅ Real-Time Architecture Implemented

#### 1. Bar Owner WebSocket Dashboard
**Endpoint:** `ws://host/ws/bar/{bar_id}/orders?token={jwt_token}`

Bar owners connect to receive real-time order notifications:

```json
// Connection established
{
  "type": "connected",
  "bar_id": 12,
  "bar_name": "Bar do Zé",
  "pending_orders_count": 3,
  "timestamp": "2026-01-02T12:00:00Z"
}

// New order received
{
  "type": "new_order",
  "order_id": 456,
  "status": "pending",
  "total_price": 45.90,
  "timestamp": "2026-01-02T12:05:00Z",
  "message": "🔔 New order received!"
}

// Order status update
{
  "type": "order_update",
  "order_id": 456,
  "status": "preparing",
  "timestamp": "2026-01-02T12:10:00Z"
}
```

**Bar Owner Commands (send via WebSocket):**
```json
{"action": "confirm", "order_id": 456}
{"action": "prepare", "order_id": 456}
{"action": "ready", "order_id": 456}
{"action": "complete", "order_id": 456}
{"action": "cancel", "order_id": 456, "reason": "Out of stock"}
```

#### 2. User Order Tracking WebSocket
**Endpoint:** `ws://host/ws/orders/{order_id}/status?token={jwt_token}`

Users connect to track their order in real-time:

```json
// Connection established
{
  "type": "connected",
  "order_id": 123,
  "status": "pending",
  "timestamp": "2026-01-02T12:00:00Z"
}

// Status update (automatic when bar owner changes status)
{
  "type": "status_update",
  "order_id": 123,
  "status": "preparing",
  "message": "Your order is being prepared",
  "timestamp": "2026-01-02T12:10:00Z"
}
```

#### 3. Firebase Cloud Messaging (Push Notifications)
Backend now supports FCM push notifications as backup to WebSockets.

**Topics for subscription:**
- `bar_{bar_id}_orders` - Bar owners subscribe for order alerts
- `bar_{bar_id}_promotions` - Users subscribe for promo alerts

**Notification Types:**
| Event | Title | Target |
|-------|-------|--------|
| New Order | "🔔 New Order!" | Bar owner |
| Order Confirmed | "✅ Order Confirmed" | User |
| Order Ready | "🎉 Order Ready!" | User |
| Payment Success | "💳 Payment Confirmed" | User |
| New Promotion | "🎁 {bar_name}" | Users near bar |

### ✅ Menu Schema Update
**POST /menus/** now accepts:
```json
{
  "bar_id": 12,
  "name": "Menu Principal",
  "description": "Our main menu",
  "is_active": true,
  "items": []
}
```

### ✅ Image Upload Validation
- Minimum size: 1KB (rejects empty/corrupted files)
- Maximum size: 10MB
- Allowed types: PNG, JPEG, WebP, GIF

---

## 📡 API Quick Reference

### WebSocket Endpoints
```
/ws/bar/{bar_id}/orders?token=JWT     # Bar owner dashboard (real-time orders)
/ws/orders/{order_id}/status?token=JWT # User order tracking
```

### REST Endpoints
```
HEALTH
└── GET  /health                # {"status": "healthy"}

AUTH
├── POST /auth/phone-login          # Firebase ID token in header → {access_token, refresh_token, expires_in, is_new_user}
├── POST /auth/google-login         # {id_token, email?, display_name?, token_expiration?} → same
├── POST /auth/apple-login          # {id_token, email?, display_name?, token_expiration?} → same
├── POST /auth/refresh              # {refresh_token} → new access_token
└── POST /auth/logout               # {refresh_token?} → revokes token

PROFILE (Authenticated)
├── GET  /me/profile                # Get profile + completion status
├── PUT  /me/profile                # Update display_name, email
├── POST /me/accept-terms           # Accept terms of service
└── POST /me/accept-privacy         # Accept privacy policy

BARS
├── GET  /bars/?lat&long&distance   # Returns [] if none
├── GET  /bars/{bar_id}
├── POST /bars/
└── GET  /bars/{bar_id}/refresh-image

MENUS
├── GET  /menus/bar/{bar_id}        # Get all menus for a bar (returns [])
├── GET  /menus/{menu_id}           # Get menu by ID
├── GET  /menus/{menu_id}/full      # Get menu with all items included
├── POST /menus/                    # Create menu
├── PUT  /menus/{menu_id}           # Update menu
└── DELETE /menus/{menu_id}         # Deletes menu + items (CASCADE)

MENU ITEMS (🆕 PostgreSQL-backed with proper IDs)
├── GET  /menus/{menu_id}/items              # Get all items (with category/available filters)
├── GET  /menus/{menu_id}/items/{item_id}    # Get specific item
├── POST /menus/{menu_id}/items              # Add item to menu
├── PUT  /menus/{menu_id}/items/{item_id}    # Update item
├── DELETE /menus/{menu_id}/items/{item_id}  # Delete item
├── PATCH /menus/{menu_id}/items/{item_id}/availability  # Quick toggle
└── GET  /menus/items/{menu_id}              # ⚠️ LEGACY (deprecated)

PROMOTIONS
├── GET  /promotions/?lat&long&max_distance  # 🔴 UPDATED: Now requires location (returns [] if none nearby)
├── GET  /promotions/{id}
├── GET  /promotions/bar/{bar_id}
├── GET  /promotions/nearby?lat&long    # Deprecated - use main endpoint
├── POST /promotions/
├── PUT  /promotions/{id}
├── DELETE /promotions/{id}
└── PUT  /promotions/{id}/toggle-active

ORDERS
├── GET  /orders/
├── GET  /orders/{order_id}
├── POST /orders/
└── PUT  /orders/{order_id}/status

CART
├── GET  /cart/
├── POST /cart/add
├── POST /cart/remove
└── POST /cart/clear

PAYMENTS
├── POST /payments/create
├── POST /payments/confirm
└── GET  /payments/{payment_id}

WALLET
├── GET  /wallet/
├── POST /wallet/topup
└── POST /wallet/withdraw

STAFF MANAGEMENT
├── GET    /bars/{bar_id}/staff          # List staff
├── POST   /bars/{bar_id}/staff/invite   # Invite staff
└── DELETE /bars/{bar_id}/staff/{id}     # Remove staff

MY BARS
├── GET  /me/bars                        # Get all bars I have access to
└── POST /me/bars/accept-invitation      # Accept staff invitation
```

---

## 🎯 Current Implementation Status

| Feature | Backend | Frontend | Notes |
|---------|---------|----------|-------|
| Bar Discovery (Phase 1) | ✅ Complete | ✅ Complete | Geo-search working |
| Promotions (Phase 2) | ✅ Complete | ✅ Complete | All CRUD + nearby |
| **🆕 Bar Creation Wizard** | ✅ Complete | ✅ Complete | POST /bars/wizard, CNPJ validation |
| **🆕 Google Places Proxy** | ✅ Complete | ✅ Complete | Secure backend proxy, no CORS issues |
| **🆕 Dashboard Stats** | ✅ Complete | ✅ Complete | GET /bars/{id}/dashboard/stats |
| **🆕 Bar Orders** | ✅ Complete | ✅ Complete | GET /bars/{id}/orders with pagination |
| **🆕 Bar Status** | ✅ Complete | ✅ Complete | GET + POST toggle open/closed |
| Bar Owner WebSocket | ✅ Complete | ⏳ TODO | Real-time orders |
| User Order Tracking WS | ✅ Complete | ⏳ TODO | Status updates |
| FCM Push Notifications | ✅ Complete | ⏳ TODO | Service ready |
| Image Upload Validation | ✅ Complete | ✅ Complete | 1KB-10MB limit |
| Menu Schema Update | ✅ Complete | ✅ Complete | name/description/is_active |
| **Menu Delete** | ✅ Complete | ⏳ TODO | DELETE /menus/{id} |
| **RBAC System** | ✅ Complete | ✅ Complete | Dual-app architecture |
| **Staff Management** | ✅ Complete | ⏳ UI Only | Invite, remove, roles |
| **Auth Flow** | ✅ Complete | ✅ Complete | Phone, Google, Apple |
| **Profile Endpoints** | ✅ Complete | ⏳ TODO | GET/PUT profile, terms, privacy |
| **Token Verification** | ✅ Complete | ✅ Complete | Server-side OAuth verification |
| **🆕 Refresh Tokens** | ✅ Complete | ⏳ TODO | Long-lived sessions, auto-refresh |
| Drinks Discovery (Phase 3) | ⏳ TODO | ⏳ TODO | Next priority |

---

## 🔧 Frontend Integration Checklist

### Authentication Flow (NEEDS UPDATE 🔄)
- [x] Phone login via Firebase + backend token exchange
- [x] Google Sign-In with backend token verification
- [x] Apple Sign-In with backend token verification
- [x] Token persistence via TokenStorageService
- [x] Auto token loading on app start (DioNetwork interceptor)
- [x] Logout clears all tokens
- [x] Profile page shows login/logout based on auth state
- [x] `is_new_user` flag handling for registration flow
- [ ] **🆕 Store refresh_token alongside access_token**
- [ ] **🆕 Implement 401 interceptor to auto-refresh tokens**
- [ ] **🆕 Call /auth/logout with refresh_token on logout**
- [ ] **🆕 Send token_expiration from Google/Apple on login**

**Frontend Implementation Details:**
- `lib/core/services/token_storage_service.dart` - Secure token storage (update for refresh_token)
- `lib/core/network/dio_network.dart` - Auth interceptor with token injection (add refresh logic)
- `lib/features/authentication/` - Login BLoC, pages, and repository
- `lib/ui/screens/profile_wireframe.dart` - Login prompt and logout button
- Route `/login` added to GoRouter

### RBAC / Dual-App Architecture (IMPLEMENTED ✅)
- [x] Check `GET /me/bars` on login to determine user type
- [x] If user has bar roles → show business view (BusinessShell)
- [x] If user has no bar roles → show client view (WireframeShell)
- [x] Store user's `permissions` per bar for UI controls (BarAccess model)
- [x] Implement staff invitation flow (`accept-invitation`)

**Frontend Implementation Details:**
- `lib/core/rbac/` - RBAC core module with UserType, BarRole (5-level hierarchy), Permission enums
- `lib/features/session/` - SessionBloc manages session state, bar access, active bar selection
- `lib/ui/shell/app_shell.dart` - Root widget that switches between client/business views
- `lib/ui/business/` - BusinessShell with CashierPage, DashboardPage, MenuManagementPage, StaffManagementPage
- `lib/shared/presentation/widget/role_guard.dart` - Permission-based conditional rendering widget

### WebSocket Integration
- [ ] Connect to `/ws/bar/{bar_id}/orders` for bar owner app
- [ ] Connect to `/ws/orders/{order_id}/status` for user order tracking
- [ ] Handle heartbeat messages (every 30s)
- [ ] Implement reconnection logic on disconnect

### Push Notifications
- [ ] Integrate Firebase Cloud Messaging SDK
- [ ] Subscribe to `bar_{bar_id}_orders` topic (bar owners)
- [ ] Subscribe to `bar_{bar_id}_promotions` topic (users near bar)
- [ ] Handle notification tap actions (`click_action` in payload)

### Error Handling
All errors follow this format:
```json
{
  "error_code": "PARTNER_NOT_FOUND",
  "message": "Bar not found"
}
```

---

## � SECURITY UPDATE (January 11, 2026)

### What Changed

1. **API Documentation Disabled in Production**
   - `/docs`, `/redoc`, `/openapi.json` now return 404 in production
   - Still available in local development
   - No impact on FE - documentation was for dev reference only

2. **Payment Endpoints Now Require Authentication**
   - All `/payments/*` endpoints now require Bearer token
   - FE should already be sending auth headers (no changes needed)

### FE Impact: ✅ NONE

- All user-facing endpoints work exactly the same
- Auth headers you're already sending are sufficient
- No API contract changes for client/business flows

### Internal Endpoints (FE Does Not Use)

These endpoints are now admin-only (require API key header):
- `POST /wallet/earn` - internal cashback generation
- `POST /wallet/admin/*` - admin wallet operations
- `POST /orders/` - internal order creation (checkout uses `/cart/checkout`)

---

## �📞 Quick Reference

- **Fly.io Dashboard:** Check logs with `fly logs`
- **Health Check:** `GET /health` returns `{"status": "healthy"}`
- **WebSocket Test:** Use browser dev tools or wscat

---

*This document is the single source of truth for FE-BE coordination.*  
*Always update before committing. Previous versions in git history.* 🚀

---

## ✅ VALIDATION ERROR FORMAT (January 11, 2026)

### Improved 422 Errors

Validation errors now follow the API contract format with field-level details:

**Before (unhelpful):**
```json
{
  "message": "Field required"
}
```

**After (developer-friendly):**
```json
{
  "error_code": "VALIDATION_ERROR",
  "message": "Validation failed",
  "details": {
    "email": ["value is not a valid email address"],
    "phone_number": ["Field required"]
  }
}
```

### FE Usage

```dart
if (response.statusCode == 422) {
  final body = jsonDecode(response.body);
  final details = body['details'] as Map<String, dynamic>?;
  
  if (details != null) {
    details.forEach((field, errors) {
      print('$field: ${(errors as List).join(", ")}');
    });
  }
}
```

---

## 🏪 BAR WIZARD UPDATE (January 11, 2026)

### Breaking Change: Authentication Required

`POST /bars/wizard` now requires authentication:

**Before:**
```json
{
  "name": "My Bar",
  "owner_id": 123,  // ← Had to send this
  ...
}
```

**After:**
```json
{
  "name": "My Bar",
  // owner_id is derived from JWT token
  ...
}
```

### FE Changes Required:

1. **Include Authorization header** (you probably already do)
2. **Remove `owner_id` from payload** (now automatic)

### Request Example

```http
POST /bars/wizard
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Baxo Bar",
  "address": "R. Fernandes Tourinho, 241",
  "latitude": -19.9392586,
  "longitude": -43.936965,
  "phone_number": "+5531988918273",
  "email": "bar@example.com",
  "country_code": "BR",
  "business_id": "51154827000190",
  "business_id_type": "CNPJ",
  "operating_hours": {...},
  "bank_account": {
    "country_code": "BR",
    "pix_key": "12345678901",
    "pix_key_type": "cpf"
  }
}
```


### Auto-Create BarOwner (January 11, 2026)

The wizard now **automatically creates a BarOwner record** from the authenticated user if one doesn't exist. FE doesn't need to call `/barowners/` before creating a bar.

**Flow:**
1. User authenticates → gets JWT token
2. User calls `POST /bars/wizard` with bar data
3. Backend auto-creates BarOwner from user info (if needed)
4. Bar is created with owner_id = user.id

**This means:**
- ✅ No need to create BarOwner separately
- ✅ Wizard is fully self-contained
- ✅ Just send bar data with auth header


---

## 🇧🇷 PIX VALIDATION UPDATE (January 12, 2026)

### Brazil Bank Account: PIX Key OR Full Bank Details

For Brazil, you can now provide **either**:

1. **PIX Key only** (recommended for most cases):
```json
{
  "bank_account": {
    "country_code": "BR",
    "pix_key": "12345678901",
    "pix_key_type": "cpf"
  }
}
```

2. **Full bank account** (for traditional transfers):
```json
{
  "bank_account": {
    "country_code": "BR",
    "bank_code": "001",
    "branch_code": "1234",
    "account_number": "123456-7"
  }
}
```

### Valid PIX Key Types

| Type | Description | Example |
|------|-------------|---------|
| `cpf` | Brazilian CPF | 12345678901 |
| `cnpj` | Brazilian CNPJ | 12345678000199 |
| `email` | Email address | bar@example.com |
| `phone` | Phone number | +5531999999999 |
| `random` | Random key (EVP) | abc123-def456-... |
| `evp` | Same as random | abc123-def456-... |

### Why This Change?

PIX keys are self-sufficient - the payment processor (via DICT) automatically looks up the bank info. No need to ask users for bank_code/branch_code when they have a PIX key!

