import json
import os
from dotenv import load_dotenv
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from app.bars_and_restaurants.models.nosql_models import create_geo_index
from app.errors import APIError, ErrorResponse, ErrorCode
from .database import engine, Base, database
from fastapi import FastAPI, Request
from .auth.routes import auth_router
from .bars_and_restaurants.routes.bars import bars_router
from .bars_and_restaurants.routes.menus import menus_router
from .bars_and_restaurants.routes.orders import orders_router
from .bars_and_restaurants.routes.cart import cart_router
from .bars_and_restaurants.routes.promotions import promotions_router
from .bars_and_restaurants.services.connection_manager import ws_router
from .bars_and_restaurants.routes.bar_owners import bar_owners_router
from .bars_and_restaurants.routes.wallet import wallet_router
from .bars_and_restaurants.routes.staff import staff_router, my_bars_router
from .bars_and_restaurants.routes.places import places_router
from .bars_and_restaurants.routes.bank_accounts import bank_accounts_router
from .bars_and_restaurants.routes.dashboard import dashboard_router
from .auth.profile import profile_router
from fastapi.openapi.utils import get_openapi
from contextlib import asynccontextmanager
from firebase_admin import initialize_app, credentials
from .payment.routes import payment_router
from .advertising.routes import advertising_router

IS_PRODUCTION = os.getenv("FLY_APP_NAME") is not None or os.getenv("ENVIRONMENT", "development") == "production"
ENABLE_DOCS = os.getenv("ENABLE_DOCS", "false").lower() == "true" if IS_PRODUCTION else True

def load_firebase_credentials():
    raw_json = os.getenv("FIREBASE_CREDENTIALS_JSON")

    if raw_json:
        try:
            return json.loads(raw_json)
        except json.JSONDecodeError as e:
            raise RuntimeError(f"Invalid FIREBASE_CREDENTIALS_JSON: {e}")
    else:
        with open("fb-barz-admin.json") as f:
            return json.load(f)

firebase_creds_dict = load_firebase_credentials()
cred = credentials.Certificate(firebase_creds_dict)
initialize_app(cred)

# Disabled: Using Alembic migrations instead
# Base.metadata.create_all(bind=engine)

@asynccontextmanager
async def lifespan(app: FastAPI):
    await database.connect()
    
    try:
        await create_geo_index()
        print("✅ MongoDB connected successfully")
    except Exception as e:
        print(f"⚠️  MongoDB connection failed (app will continue without MongoDB):")
        print(f"   Error: {type(e).__name__}: {str(e)}")
        print(f"   Hint: Check MongoDB Atlas network access whitelist for IP: Check Fly.io machine IPs")
    
    yield
    await database.disconnect()

app = FastAPI(
    lifespan=lifespan,
    docs_url="/docs" if ENABLE_DOCS else None,
    redoc_url="/redoc" if ENABLE_DOCS else None,
    openapi_url="/openapi.json" if ENABLE_DOCS else None,
)

# CORS middleware - allow all origins for now (Flutter web, mobile, etc.)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to specific domains
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods including OPTIONS
    allow_headers=["*"],  # Allow all headers including Authorization
)


# 🏥 Health check endpoint for Fly.io (responds fast, no database calls)
@app.get("/health", tags=["Health"])
async def health_check():
    """Simple health check endpoint for Fly.io proxy."""
    return {"status": "healthy", "app": "barz-backend"}


# Register the custom exception handler for APIError
@app.exception_handler(APIError)
async def api_error_handler(request: Request, exc: APIError):
    """Handle APIError exceptions with standardized error response."""
    return JSONResponse(
        status_code=exc.status_code,
        content=exc.to_response().model_dump(exclude_none=True)
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    details = {}
    for error in exc.errors():
        loc = error.get("loc", [])
        field = ".".join(str(part) for part in loc[1:]) if len(loc) > 1 else (loc[0] if loc else "unknown")
        if not field:
            field = "unknown"
        if field not in details:
            details[field] = []
        details[field].append(error.get("msg", "Invalid value"))
    
    return JSONResponse(
        status_code=422,
        content={
            "error_code": ErrorCode.VALIDATION_ERROR.value,
            "message": "Validation failed",
            "details": details
        }
    )


# Catch-all handler for unhandled exceptions
@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    """Handle unexpected exceptions with standardized error response."""
    # Log the actual error for debugging (in production, use proper logging)
    print(f"Unhandled exception: {type(exc).__name__}: {str(exc)}")
    
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error_code=ErrorCode.UNKNOWN.value,
            message="An unexpected error occurred"
        ).model_dump(exclude_none=True)
    )

app.include_router(auth_router)
app.include_router(bars_router)
app.include_router(menus_router)
app.include_router(orders_router)
app.include_router(cart_router)
app.include_router(promotions_router)
app.include_router(ws_router)
app.include_router(bar_owners_router)
app.include_router(payment_router)
app.include_router(wallet_router)
app.include_router(staff_router)
app.include_router(my_bars_router)
app.include_router(profile_router)
app.include_router(places_router)
app.include_router(bank_accounts_router)
app.include_router(dashboard_router)
app.include_router(advertising_router)

def custom_openapi():
    if not ENABLE_DOCS:
        return None
    if app.openapi_schema:
        return app.openapi_schema
    openapi_schema = get_openapi(
        title="BARZ-BACKEND API",
        version="1.2.0",
        description="All backend routes for the BARZ app, including authentication, bars, and menus. This API is used to authenticate, manage bar and restaurant data.",  
        routes=app.routes,
    )
    app.openapi_schema = openapi_schema
    return app.openapi_schema

if ENABLE_DOCS:
    app.openapi = custom_openapi