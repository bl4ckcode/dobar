# BARZ Backend Security Implementation

## Summary
Security hardening implemented to protect API endpoints and disable public documentation in production.

## Changes Made

### 1. Documentation Protection (main.py)
- `/docs`, `/redoc`, and `/openapi.json` are **disabled in production**
- Controlled by environment variables:
  - `FLY_APP_NAME` (auto-set by Fly.io)
  - `ENVIRONMENT=production`
  - `ENABLE_DOCS=true/false` (override)
- Local development: docs enabled by default
- Production: docs disabled by default (enable with `ENABLE_DOCS=true`)

### 2. Admin Authentication System (app/auth/admin.py)
New admin module with:
- `get_admin_user()` - Verify user JWT and check against `ADMIN_EMAILS` list
- `verify_admin_api_key()` - Validate `X-Admin-Key` header
- `require_internal_or_admin()` - Allow access via API key or trusted IPs
- `get_rate_limiter()` - Simple in-memory rate limiting (60 req/min default)

### 3. Secured Endpoints

#### Wallet Admin Endpoints
- `POST /wallet/earn` - Now requires internal/admin key
- `POST /wallet/admin/make-available/{id}` - Now requires internal/admin key
- `POST /wallet/admin/expire/{id}` - Now requires internal/admin key
- `POST /wallet/admin/process-expirations` - Now requires internal/admin key
- `POST /wallet/admin/adjust` - Now requires **strict** admin API key

#### Payment Endpoints (ALL now require auth)
- `POST /payments/charge` - Now requires user auth
- `POST /payments/refund` - Now requires user auth
- `POST /payments/capture` - Now requires user auth
- `POST /payments/checkout` - Now requires user auth
- `POST /payments/setup` - Now requires user auth

#### Order Endpoints
- `POST /orders/` - Now requires internal/admin key (internal only)

#### Bar Owners Endpoints
- `POST /barowners/` - Now requires user auth

## New Environment Variables

```bash
# Admin access control
ADMIN_API_KEY=your-secure-32-char-api-key
INTERNAL_SERVICE_KEY=your-internal-service-key
ADMIN_EMAILS=admin1@example.com,admin2@example.com

# Production detection
ENVIRONMENT=production  # or development
ENABLE_DOCS=false       # override to enable docs in prod

# Trusted IPs (for internal services)
TRUSTED_IPS=127.0.0.1,::1
```

## Fly.io Secrets to Set

```bash
fly secrets set ADMIN_API_KEY="$(openssl rand -hex 32)"
fly secrets set INTERNAL_SERVICE_KEY="$(openssl rand -hex 32)"
fly secrets set ADMIN_EMAILS="carlos@dobar.io"
```

## How to Access Admin Endpoints

### Option 1: API Key Header
```bash
curl -X POST "https://api.barz.io/wallet/admin/process-expirations" \
  -H "X-Admin-Key: your-admin-api-key"
```

### Option 2: Internal Service Key
```bash
curl -X POST "https://api.barz.io/wallet/earn" \
  -H "X-Internal-Key: your-internal-service-key" \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "order_id": 123, ...}'
```

## Security Best Practices Applied
1. ✅ Disable docs in production (security through depth, not obscurity)
2. ✅ API key authentication for admin endpoints
3. ✅ Internal service key for service-to-service calls
4. ✅ Trusted IP whitelist option
5. ✅ Rate limiting (basic in-memory)
6. ✅ All payment endpoints require authentication
7. ✅ Admin wallet adjustment requires strict API key

## Not Implemented (Future Considerations)
- [ ] Redis-backed rate limiting for distributed deployments
- [ ] OAuth2 scopes for fine-grained permissions
- [ ] Audit logging for admin actions
- [ ] IP-based geo-blocking
- [ ] Request signing for webhooks
