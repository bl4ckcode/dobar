# Waitlist API Integration Guide

> **For Frontend Team**: How to connect the landing page form to the backend API.

## API Base URL

```
Production: https://barz-backend-bold-sun-5691.fly.dev
```

## Endpoints

### 1. Submit Waitlist Signup (Public)

**POST** `/api/v1/waitlist/signup`

Rate limited to **5 requests per IP per hour**.

#### Request Body

```json
{
  "bar_name": "Astor",
  "contact_name": "João Silva",
  "email": "contato@barastor.com.br",
  "phone": "+55 11 94364-3170",
  "city": "São Paulo",
  "source": "organic",
  "utm_params": {
    "source": "email",
    "medium": "outreach",
    "campaign": "mvp_waitlist_may2025"
  }
}
```

**Field Details:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `bar_name` | string | ✅ | Name of the bar/restaurant |
| `contact_name` | string | ✅ | Name of the contact person |
| `email` | string (email) | ✅ | Contact email (must be unique) |
| `phone` | string | ❌ | Phone number (E.164 format recommended) |
| `city` | enum | ✅ | One of: `São Paulo`, `Rio de Janeiro`, `Belo Horizonte`, `Outra` |
| `source` | enum | ❌ | One of: `organic`, `email_outreach`, `instagram`, `whatsapp`, `google_places`. Default: `organic` |
| `utm_params` | object | ❌ | UTM tracking parameters |

#### Success Response (201 Created)

```json
{
  "success": true,
  "data": {
    "id": 123,
    "message": "Você está na lista! Entraremos em contato em breve."
  }
}
```

#### Duplicate Email Response (409 Conflict)

```json
{
  "success": false,
  "error": {
    "code": "DUPLICATE_EMAIL",
    "message": "Este email já está na nossa lista de espera!"
  }
}
```

#### Validation Error Response (422)

```json
{
  "error_code": "VALIDATION_ERROR",
  "message": "Validation failed",
  "details": {
    "city": ["Invalid city"]
  }
}
```

#### Rate Limit Response (429)

```json
{
  "error": "Rate limit exceeded: 5 per 1 hour"
}
```

---

### 2. List Waitlist Signups (Admin Only)

**GET** `/api/v1/admin/waitlist`

Requires admin authentication (Bearer token).

#### Query Parameters

| Param | Type | Description |
|-------|------|-------------|
| `city` | string | Filter by city |
| `status` | string | Filter by status |
| `source` | string | Filter by source |
| `limit` | int | Results per page (default: 50, max: 100) |
| `offset` | int | Pagination offset (default: 0) |

#### Response (200)

```json
{
  "success": true,
  "data": {
    "signups": [
      {
        "id": 123,
        "bar_name": "Astor",
        "contact_name": "João Silva",
        "email": "contato@barastor.com.br",
        "phone": "+5511943643170",
        "city": "São Paulo",
        "source": "email_outreach",
        "status": "pending",
        "created_at": "2026-05-03T22:00:00Z"
      }
    ],
    "total": 150,
    "by_city": {
      "São Paulo": 60,
      "Rio de Janeiro": 45,
      "Belo Horizonte": 35,
      "Outra": 10
    },
    "by_status": {
      "pending": 120,
      "contacted": 20,
      "qualified": 8,
      "converted": 2
    }
  }
}
```

---

### 3. Update Waitlist Signup (Admin Only)

**PATCH** `/api/v1/admin/waitlist/{id}`

Requires admin authentication.

#### Request Body

```json
{
  "status": "contacted",
  "notes": "Called on May 4, interested in VIP plan"
}
```

**Status Options:** `pending`, `contacted`, `qualified`, `converted`, `declined`

#### Response (200)

```json
{
  "success": true,
  "data": {
    "id": 123,
    "status": "contacted",
    "notes": "Called on May 4, interested in VIP plan",
    "updated_at": "2026-05-04T10:30:00Z"
  }
}
```

---

### 4. Get Statistics (Admin Only)

**GET** `/api/v1/admin/waitlist/stats`

Requires admin authentication.

#### Response (200)

```json
{
  "success": true,
  "data": {
    "total": 150,
    "by_city": {
      "São Paulo": 60,
      "Rio de Janeiro": 45,
      "Belo Horizonte": 35,
      "Outra": 10
    },
    "by_status": {
      "pending": 120,
      "contacted": 20,
      "qualified": 8,
      "converted": 2
    },
    "by_source": {
      "organic": 50,
      "email_outreach": 70,
      "instagram": 20,
      "whatsapp": 10
    }
  }
}
```

---

## Frontend Implementation Example

### JavaScript/TypeScript

```typescript
// Form submission handler
async function submitWaitlist(formData: WaitlistFormData) {
  const payload = {
    bar_name: formData.barName,
    contact_name: formData.contactName,
    email: formData.email,
    phone: formData.phone,
    city: formData.city,
    source: 'organic',
    utm_params: extractUTMParams() // Parse from URL
  };

  try {
    const response = await fetch('https://barz-backend-bold-sun-5691.fly.dev/api/v1/waitlist/signup', {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(payload)
    });
    
    const data = await response.json();
    
    if (response.status === 201) {
      showSuccessState(data.data.message);
      fireConfetti();
      return { success: true };
    } else if (response.status === 409) {
      showMessage('Este email já está na nossa lista de espera!', 'info');
      return { success: false, alreadyRegistered: true };
    } else if (response.status === 429) {
      showMessage('Muitas tentativas. Tente novamente mais tarde.', 'error');
      return { success: false, rateLimited: true };
    } else {
      showMessage('Ocorreu um erro. Tente novamente.', 'error');
      return { success: false };
    }
  } catch (error) {
    console.error('Error submitting waitlist:', error);
    showMessage('Erro de conexão. Tente novamente.', 'error');
    return { success: false };
  }
}

// UTM params extraction
function extractUTMParams() {
  const urlParams = new URLSearchParams(window.location.search);
  return {
    source: urlParams.get('utm_source') || undefined,
    medium: urlParams.get('utm_medium') || undefined,
    campaign: urlParams.get('utm_campaign') || undefined
  };
}
```

### React Hook Example

```typescript
import { useState } from 'react';

const API_BASE_URL = 'https://barz-backend-bold-sun-5691.fly.dev';

interface WaitlistData {
  barName: string;
  contactName: string;
  email: string;
  phone?: string;
  city: 'São Paulo' | 'Rio de Janeiro' | 'Belo Horizonte' | 'Outra';
}

interface SubmitResult {
  success: boolean;
  message?: string;
  alreadyRegistered?: boolean;
}

export function useWaitlist() {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (data: WaitlistData): Promise<SubmitResult> => {
    setIsLoading(true);
    setError(null);

    try {
      const urlParams = new URLSearchParams(window.location.search);
      
      const payload = {
        bar_name: data.barName,
        contact_name: data.contactName,
        email: data.email,
        phone: data.phone,
        city: data.city,
        source: 'organic',
        utm_params: {
          source: urlParams.get('utm_source') || undefined,
          medium: urlParams.get('utm_medium') || undefined,
          campaign: urlParams.get('utm_campaign') || undefined
        }
      };

      const response = await fetch(`${API_BASE_URL}/api/v1/waitlist/signup`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      const result = await response.json();

      if (response.status === 201) {
        return { success: true, message: result.data.message };
      } else if (response.status === 409) {
        return { 
          success: false, 
          alreadyRegistered: true,
          message: 'Este email já está na nossa lista de espera!'
        };
      } else {
        setError('Ocorreu um erro ao processar sua inscrição.');
        return { success: false };
      }
    } catch (err) {
      setError('Erro de conexão. Tente novamente.');
      return { success: false };
    } finally {
      setIsLoading(false);
    }
  };

  return { submit, isLoading, error };
}
```

---

## Environment Variables

The backend uses these environment variables for email notifications:

```bash
# Email Provider (sendgrid or mailjet)
EMAIL_PROVIDER=sendgrid

# SendGrid
SENDGRID_API_KEY=SG.xxx

# Mailjet (alternative)
MAILJET_API_KEY=xxx
MAILJET_SECRET=xxx

# Sender and admin notification
FROM_EMAIL=contato@dobar.com.br
FROM_NAME=Dobar
ADMIN_EMAIL=contato@dobar.com.br
```

---

## CORS Configuration

The backend is configured to accept requests from:
- `https://dobar-landing.fly.dev` (production landing page)
- `https://www.dobar-landing.fly.dev`
- `https://dobar.app`
- `https://www.dobar.app`
- Local development (`localhost`, `127.0.0.1`)

---

## Testing

Run the waitlist tests:

```bash
cd /Users/carlosalves/Documents/PDev/barz-backend
pytest tests/test_waitlist.py -v
```

---

## Migration

To apply the waitlist database migration:

```bash
alembic upgrade 20250503_add_waitlist
```

Or run all pending migrations:

```bash
alembic upgrade head
```

---

## Notes

- Email confirmations are sent asynchronously and failures don't block the signup
- Admin notifications are sent when new signups are created
- Phone numbers are normalized to E.164 format (+55...)
- All emails are stored in lowercase
- UTM parameters are captured for marketing attribution
