# barz-backend

Backend API for the BarZ application. Enables users to browse restaurant and bar menus, place orders, and receive deliveries to their table.

## Architecture

- **Framework**: FastAPI
- **Databases**: PostgreSQL (static data), MongoDB (dynamic/geospatial data)
- **Storage**: AWS S3 for images
- **Authentication**: Firebase (phone, Google, Apple, Facebook) with JWT
- **Payments**: [dobar-payment-engine](https://github.com/bl4ckcode/dobar-payment-engine)
- **Real-time**: WebSocket connections via MongoDB change streams

## Setup

### Prerequisites

- Python 3.8+
- PostgreSQL
- MongoDB
- AWS S3 bucket
- Firebase project

### Installation

```bash
git clone https://github.com/bl4ckcode/barz-backend.git
cd barz-backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Environment Variables

Create a `.env` file:

```bash
# Application
SECRET_KEY=your-secret-key

# PostgreSQL
DATABASE_URL=postgresql://user:pass@host:port/dbname

# MongoDB
MONGO_HOST=localhost
MONGO_PORT=27017
MONGO_DB=barz_db

# Firebase
FIREBASE_CREDENTIALS_PATH=/path/to/credentials.json

# AWS S3
AWS_ACCESS_KEY=your-access-key
AWS_SECRET_KEY=your-secret-key
AWS_REGION=sa-east-1
AWS_S3_BUCKET=barz-images

# Payments
PAYMENT_GATEWAY=stripe
STRIPE_API_KEY=sk_...
```

### Run

```bash
uvicorn app.main:app --reload
```

API documentation available at `http://localhost:8000/docs`

## API Endpoints

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/phone` | Phone authentication |
| POST | `/auth/google` | Google Sign-In |
| POST | `/auth/apple` | Apple Sign-In |
| POST | `/auth/facebook` | Facebook Sign-In |

### Bars and Restaurants

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/bars/` | List bars near location |
| POST | `/bars/` | Create new bar |
| PUT | `/bars/{id}/image` | Update bar image |

### Payments

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/payments/charge` | Create charge |
| POST | `/payments/refund` | Refund payment |
| POST | `/payments/capture` | Capture authorized payment |
| POST | `/payments/setup` | Save card for future use |
| POST | `/payments/checkout` | Create hosted checkout |

### WebSocket

| Endpoint | Description |
|----------|-------------|
| `/ws` | General connection |
| `/ws/orders` | Order updates |
| `/ws/menus` | Menu updates |

## Authentication

All protected endpoints require a JWT token:

```
Authorization: Bearer <token>
```

## License

Proprietary License. See [LICENSE](LICENSE) for details.
