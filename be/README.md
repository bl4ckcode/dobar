# barz-backend

Backend API for BARZ - a platform connecting users with bars, restaurants, and nightlife venues. Users can browse partners, view menus, place orders, and have items delivered to their table.

## Overview

barz-backend is built with FastAPI using a hybrid database architecture. It supports real-time order tracking via WebSockets, role-based access control for bar owners and staff, and integrates with multiple payment gateways.

## Architecture

```
app/
├── auth/                    # Authentication & RBAC
│   ├── auth_models.py       # User and Token models
│   ├── routes.py            # Auth endpoints (phone, Google, Apple, Facebook)
│   ├── rbac_models.py       # Roles, permissions, staff models
│   └── rbac_middleware.py   # Role-based route protection
├── bars_and_restaurants/    # Core business logic
│   ├── models/              # SQLAlchemy + MongoDB models
│   ├── routes/              # API endpoints
│   │   ├── bars.py          # Bar CRUD + geo-search
│   │   ├── menus.py         # Menu management
│   │   ├── orders.py        # Order processing
│   │   ├── promotions.py    # Promotions + nearby
│   │   ├── cart.py          # Shopping cart
│   │   ├── wallet.py        # User wallet + cashback
│   │   └── staff.py         # Staff management
│   ├── schemas/             # Pydantic schemas
│   └── services/            # Business services
│       ├── connection_manager.py  # WebSocket manager
│       ├── push_notifications.py  # FCM integration
│       └── image_upload.py        # S3 upload service
├── payment/                 # Payment processing
│   ├── routes.py            # Payment endpoints
│   └── schemas.py           # Payment schemas
├── database.py              # Database connections
├── errors.py                # Standardized error handling
└── main.py                  # FastAPI app entry point
```

## Tech Stack

| Category | Technology |
|----------|------------|
| Framework | FastAPI |
| Databases | PostgreSQL (relational), MongoDB (geo/dynamic) |
| ORM | SQLAlchemy + Databases (async) |
| Auth | Firebase Auth + JWT |
| Storage | AWS S3 |
| Real-time | WebSockets + FCM Push Notifications |
| Payments | [dobar-payment-engine](https://github.com/bl4ckcode/dobar-payment-engine) |
| Hosting | Fly.io |

## Dual-App Architecture

The backend supports ONE app with TWO experiences based on user roles:

| User Type | Experience |
|-----------|------------|
| `client` | Browse bars, order drinks, track orders, earn cashback |
| `business` | Manage orders (cashier), menus, staff, billing, promotions |

### Role Hierarchy (per bar)

| Role | Access Level |
|------|--------------|
| `owner` | Full control, can delete bar |
| `admin` | Full control except ownership transfer |
| `manager` | Orders, menus, analytics |
| `cashier` | Process orders (cashier view) |
| `staff` | View-only |

## Setup

### Prerequisites

- Python 3.11+
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

### Configuration

Create a `.env` file:

```bash
# Application
SECRET_KEY=your-secret-key

# PostgreSQL
DATABASE_URL=postgresql://user:pass@host:port/dbname

# MongoDB
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/barz_db

# Firebase
FIREBASE_CREDENTIALS_JSON={"type": "service_account", ...}

# AWS S3
AWS_ACCESS_KEY=your-access-key
AWS_SECRET_KEY=your-secret-key
AWS_REGION=sa-east-1
AWS_S3_BUCKET=barz-images
```

### Running

```bash
uvicorn app.main:app --reload
```

### API Documentation

- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`
- **Health Check**: `GET /health`

## Testing

```bash
# Run all tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=app --cov-report=html
```

## Deployment

The app is hosted on **Fly.io** with automatic deploys via GitHub Actions:

```bash
# Manual deploy
fly deploy

# Run migrations after deploy
fly ssh console -a barz-backend-bold-sun-5691 -C "sh -c 'cd /app && alembic upgrade head'"

# Check logs
fly logs -a barz-backend-bold-sun-5691
```

## WebSocket Endpoints

| Endpoint | Description |
|----------|-------------|
| `/ws/bar/{bar_id}/orders` | Bar owner real-time order dashboard |
| `/ws/orders/{order_id}/status` | User order tracking |

## Error Handling

The API implements a standardized error contract:

```json
{
  "error_code": "PARTNER_NOT_FOUND",
  "message": "Bar not found"
}
```

See `app/errors.py` for all error codes.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/name`)
3. Run tests (`pytest tests/`)
4. Commit changes (`git commit -m 'Add feature'`)
5. Push to branch (`git push origin feature/name`)
6. Open a pull request

## License

Proprietary License. See [LICENSE](LICENSE) for details.
