# dobar API Error Contract

This document defines the error contract between the dobar mobile app and backend API. All error responses must follow this specification to ensure consistent error handling and user messaging.

## Error Response Format

All error responses from the API must follow this JSON structure:

\`\`\`json
{
  "error_code": "ERROR_CODE_HERE",
  "message": "Human-readable error message",
  "details": {
    "field_name": ["Error message 1", "Error message 2"]
  },
  "gateway_code": "GATEWAY_SPECIFIC_CODE",
  "transaction_id": "txn_123456"
}
\`\`\`

### Required Fields
- \`error_code\`: (string) One of the defined error codes below
- \`message\`: (string) Human-readable message for display

### Optional Fields
- \`details\`: (object) Field-specific validation errors
- \`gateway_code\`: (string) Payment gateway specific error code (for payment errors)
- \`transaction_id\`: (string) Transaction ID for tracking (for payment errors)

---

## HTTP Status Code Mapping

| HTTP Status | Error Category | Description |
|-------------|----------------|-------------|
| 400 | BAD_REQUEST | Invalid request format or parameters |
| 401 | UNAUTHORIZED | Authentication required or invalid token |
| 403 | FORBIDDEN | Access denied to resource |
| 404 | NOT_FOUND | Resource not found |
| 409 | CONFLICT | Resource conflict (duplicate) |
| 422 | VALIDATION_ERROR | Validation failed |
| 429 | RATE_LIMITED | Too many requests |
| 500 | SERVER_UNAVAILABLE | Internal server error |
| 502 | SERVER_UNAVAILABLE | Bad gateway |
| 503 | MAINTENANCE_MODE | Service maintenance |
| 504 | NETWORK_TIMEOUT | Gateway timeout |

---

## Error Codes

### General Errors

| Code | HTTP | Description | User Message |
|------|------|-------------|--------------|
| \`UNKNOWN\` | 500 | Unexpected error | An unexpected error occurred |
| \`NETWORK_TIMEOUT\` | 504 | Connection timed out | Connection timed out |
| \`NETWORK_ERROR\` | - | Network connection failed | Network connection failed |
| \`NO_INTERNET\` | - | No internet connection | No internet connection |
| \`SERVER_UNAVAILABLE\` | 500/502/503 | Server temporarily unavailable | Server is temporarily unavailable |
| \`BAD_REQUEST\` | 400 | Invalid request | Invalid request |
| \`NOT_FOUND\` | 404 | Resource not found | Resource not found |
| \`CONFLICT\` | 409 | Resource already exists | Resource already exists |
| \`VALIDATION_ERROR\` | 422 | Invalid data provided | Invalid data provided |
| \`RATE_LIMITED\` | 429 | Too many requests | Too many requests, please try again later |
| \`MAINTENANCE_MODE\` | 503 | Service under maintenance | Service is under maintenance |

### Authentication Errors

| Code | HTTP | Description | User Message |
|------|------|-------------|--------------|
| \`UNAUTHORIZED\` | 401 | Authentication required | Authentication required |
| \`FORBIDDEN\` | 403 | Access denied | Access denied |
| \`SESSION_EXPIRED\` | 401 | Session has expired | Your session has expired |
| \`INVALID_TOKEN\` | 401 | Invalid JWT token | Invalid authentication token |

### Payment Errors

| Code | HTTP | Description | User Message |
|------|------|-------------|--------------|
| \`PAYMENT_DECLINED\` | 400 | Payment was declined by gateway | Payment was declined |
| \`PAYMENT_EXPIRED\` | 400 | Payment has expired | Payment has expired |
| \`INSUFFICIENT_FUNDS\` | 400 | Insufficient funds in account/card | Insufficient funds |
| \`INVALID_CARD\` | 400 | Invalid card details | Invalid card details |
| \`CARD_EXPIRED\` | 400 | Card has expired | Card has expired |
| \`PIX_EXPIRED\` | 400 | PIX payment has expired | PIX payment has expired |
| \`PAYMENT_PROCESSING\` | 202 | Payment is being processed | Payment is being processed |
| \`REFUND_FAILED\` | 400 | Refund could not be processed | Refund could not be processed |
| \`WALLET_LIMIT_EXCEEDED\` | 400 | Wallet limit exceeded | Wallet limit exceeded |
| \`MINIMUM_AMOUNT_NOT_MET\` | 400 | Minimum payment amount not met | Minimum amount not met |
| \`MAXIMUM_AMOUNT_EXCEEDED\` | 400 | Maximum payment amount exceeded | Maximum amount exceeded |

### Order Errors

| Code | HTTP | Description | User Message |
|------|------|-------------|--------------|
| \`ORDER_NOT_FOUND\` | 404 | Order not found | Order not found |
| \`ORDER_CANCELLED\` | 400 | Order has been cancelled | Order has been cancelled |
| \`ORDER_ALREADY_PAID\` | 409 | Order has already been paid | Order has already been paid |
| \`ORDER_EXPIRED\` | 400 | Order has expired | Order has expired |

### User Errors

| Code | HTTP | Description | User Message |
|------|------|-------------|--------------|
| \`USER_NOT_FOUND\` | 404 | User not found | User not found |
| \`EMAIL_IN_USE\` | 409 | Email already registered | Email is already registered |
| \`PHONE_IN_USE\` | 409 | Phone number already registered | Phone number is already registered |
| \`INVALID_CPF\` | 422 | Invalid CPF number | Invalid CPF number |
| \`INVALID_RG\` | 422 | Invalid RG number | Invalid RG number |
| \`DOCUMENT_IN_USE\` | 409 | Document already registered | Document is already registered |

### Partner Errors

| Code | HTTP | Description | User Message |
|------|------|-------------|--------------|
| \`PARTNER_NOT_FOUND\` | 404 | Partner not found | Partner not found |
| \`PARTNER_CLOSED\` | 400 | Partner is currently closed | Partner is currently closed |
| \`ITEM_UNAVAILABLE\` | 400 | Item is not available | Item is not available |

### Location Errors

| Code | HTTP | Description | User Message |
|------|------|-------------|--------------|
| \`LOCATION_PERMISSION_DENIED\` | - | Location permission denied | Location permission denied |
| \`LOCATION_SERVICE_DISABLED\` | - | Location service is disabled | Location service is disabled |

### Promotion Errors

| Code | HTTP | Description | User Message |
|------|------|-------------|--------------|
| \`PROMOTION_EXPIRED\` | 400 | Promotion has expired | Promotion has expired |
| \`PROMOTION_NOT_APPLICABLE\` | 400 | Promotion not applicable | Promotion is not applicable |
| \`OFFER_ALREADY_REDEEMED\` | 409 | Offer already redeemed | Offer has already been redeemed |

---

## Validation Error Response Format

For \`422 VALIDATION_ERROR\` responses, include field-specific errors:

\`\`\`json
{
  "error_code": "VALIDATION_ERROR",
  "message": "Validation failed",
  "details": {
    "email": ["Invalid email format"],
    "cpf": ["CPF is required", "CPF must have 11 digits"],
    "amount": ["Amount must be greater than 0"]
  }
}
\`\`\`

---

## Payment Gateway Error Mapping

### Pagar.me (Brazil)

| Gateway Code | dobar Error Code |
|--------------|------------------|
| \`refused\` | PAYMENT_DECLINED |
| \`insufficient_funds\` | INSUFFICIENT_FUNDS |
| \`invalid_card_number\` | INVALID_CARD |
| \`expired_card\` | CARD_EXPIRED |
| \`processing_error\` | PAYMENT_PROCESSING |

### Stripe (LATAM)

| Gateway Code | dobar Error Code |
|--------------|------------------|
| \`card_declined\` | PAYMENT_DECLINED |
| \`insufficient_funds\` | INSUFFICIENT_FUNDS |
| \`invalid_number\` | INVALID_CARD |
| \`expired_card\` | CARD_EXPIRED |
| \`processing_error\` | PAYMENT_PROCESSING |

### PayPal (ROW)

| Gateway Code | dobar Error Code |
|--------------|------------------|
| \`INSTRUMENT_DECLINED\` | PAYMENT_DECLINED |
| \`INSUFFICIENT_FUNDS\` | INSUFFICIENT_FUNDS |
| \`INVALID_ACCOUNT\` | INVALID_CARD |
| \`EXPIRED_CARD\` | CARD_EXPIRED |

---

## Regional Payment Methods

### Brazil (Pagar.me)
- Credit Card
- Debit Card
- **PIX** (Instant payment)
- dobar Wallet

### Latin America (Stripe)
- Credit Card
- Debit Card
- Apple Pay
- Google Pay
- dobar Wallet

### United States (Stripe)
- Credit Card
- Debit Card
- Apple Pay
- Google Pay
- dobar Wallet

### Rest of World (PayPal)
- PayPal
- Credit Card (via PayPal)
- dobar Wallet

---

## Example Error Responses

### Authentication Error
\`\`\`json
{
  "error_code": "SESSION_EXPIRED",
  "message": "Your session has expired. Please log in again."
}
\`\`\`

### Payment Error
\`\`\`json
{
  "error_code": "PAYMENT_DECLINED",
  "message": "Your payment was declined by the bank",
  "gateway_code": "insufficient_funds",
  "transaction_id": "txn_abc123"
}
\`\`\`

### Validation Error
\`\`\`json
{
  "error_code": "VALIDATION_ERROR",
  "message": "Please correct the following errors",
  "details": {
    "cpf": ["CPF is invalid"],
    "phone": ["Phone number must include country code"]
  }
}
\`\`\`

### PIX Expired
\`\`\`json
{
  "error_code": "PIX_EXPIRED",
  "message": "O código PIX expirou. Por favor, gere um novo.",
  "transaction_id": "pix_xyz789"
}
\`\`\`

---

## Implementation Notes

1. **Always include error_code**: Even for unexpected errors, use `UNKNOWN`
2. **Localize messages**: The `message` field should be localized based on `Accept-Language` header
3. **Don't expose internals**: Never include stack traces or internal error details
4. **Log everything**: Log the original error with full details server-side
5. **Transaction tracking**: Always include `transaction_id` for payment-related errors

---

## Backend Implementation Status ✅

**Implemented: December 30, 2025**

The dobar backend now fully implements this error contract. All error responses follow the standardized format:

### Modules Updated:
- ✅ `app/errors.py` - Core error classes (`APIError`, `ErrorCode`, `ErrorResponse`)
- ✅ `app/main.py` - Exception handlers for `APIError` and generic exceptions
- ✅ `app/auth/routes.py` - Authentication errors
- ✅ `app/auth/middleware.py` - JWT validation errors  
- ✅ `app/bars_and_restaurants/routes/bars.py` - Bar/partner errors
- ✅ `app/bars_and_restaurants/routes/menus.py` - Menu errors
- ✅ `app/bars_and_restaurants/routes/orders.py` - Order errors
- ✅ `app/bars_and_restaurants/routes/cart.py` - Cart/checkout errors
- ✅ `app/bars_and_restaurants/routes/wallet.py` - Wallet/cashback errors
- ✅ `app/bars_and_restaurants/routes/bar_owners.py` - Bar owner errors
- ✅ `app/payment/routes.py` - Payment gateway errors
- ✅ `app/bars_and_restaurants/services/wallet_service.py` - Wallet service errors
- ✅ `app/bars_and_restaurants/services/connection_manager.py` - WebSocket auth errors

### Additional Error Codes (Backend Only)
The following codes were added for backend-specific scenarios:

| Code | HTTP | Description |
|------|------|-------------|
| `CART_ITEM_NOT_FOUND` | 404 | Specific cart item not found |
| `CART_EMPTY` | 400 | Checkout attempted with empty cart |

### Gateway Error Mapping
The backend includes built-in mapping for:
- **Pagar.me** (Brazil)
- **Stripe** (LATAM/US)  
- **PayPal** (ROW)

Use `map_gateway_error(gateway, gateway_code, transaction_id)` to automatically convert gateway errors to standardized `APIError` responses.

---

## Frontend Implementation Notes

### Error Response Handling

```typescript
interface ApiError {
  error_code: string;
  message: string;
  details?: Record<string, string[]>;
  gateway_code?: string;
  transaction_id?: string;
}

// Example error handler
async function handleApiError(response: Response): Promise<never> {
  const error: ApiError = await response.json();
  
  // Handle by error_code
  switch (error.error_code) {
    case 'SESSION_EXPIRED':
    case 'INVALID_TOKEN':
      // Redirect to login
      await logout();
      navigate('/login');
      break;
    
    case 'VALIDATION_ERROR':
      // Show field-specific errors
      if (error.details) {
        showFieldErrors(error.details);
      }
      break;
    
    case 'PAYMENT_DECLINED':
    case 'INSUFFICIENT_FUNDS':
    case 'INVALID_CARD':
      // Show payment error with retry option
      showPaymentError(error.message, error.gateway_code);
      break;
    
    default:
      // Show generic error toast
      showToast(error.message);
  }
  
  throw new ApiError(error);
}
```

### Important Notes for Frontend

1. **Always check `error_code`** - Don't rely on HTTP status codes alone
2. **Display `message`** - This is user-friendly and potentially localized
3. **Handle `details`** - For validation errors, iterate through field errors
4. **Log `gateway_code` + `transaction_id`** - Useful for debugging payment issues
5. **Null checks** - `details`, `gateway_code`, `transaction_id` are optional

---

## Contact

For questions about this contract, contact the dobar backend team.
