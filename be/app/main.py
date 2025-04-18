import json
import os
from dotenv import load_dotenv
from fastapi.responses import JSONResponse
from app.bars_and_restaurants.models.nosql_models import create_geo_index
from app.errors import CustomHTTPException, ErrorResponse
from .database import engine, Base, database
from fastapi import FastAPI, Request
from .auth.routes import auth_router
from .bars_and_restaurants.routes.bars import bars_router
from .bars_and_restaurants.routes.menus import menus_router
from .bars_and_restaurants.routes.orders import orders_router
from .bars_and_restaurants.services.connection_manager import ws_router
from .bars_and_restaurants.routes.bar_owners import bar_owners_router
from fastapi.openapi.utils import get_openapi
from contextlib import asynccontextmanager
from firebase_admin import initialize_app, credentials
from .payment.routes import payment_router

load_dotenv()

import json
import os
from dotenv import load_dotenv
from firebase_admin import credentials

load_dotenv()

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

Base.metadata.create_all(bind=engine)

@asynccontextmanager
async def lifespan(app: FastAPI):
    await database.connect()
    await create_geo_index()
    yield
    await database.disconnect()

app = FastAPI(lifespan=lifespan)

# Register the custom exception handler
@app.exception_handler(CustomHTTPException)
async def custom_http_exception_handler(request: Request, exc: CustomHTTPException):
    return JSONResponse(
        status_code=exc.code,
        content=ErrorResponse(
            code=exc.code,
            type=exc.error_type,
            message=exc.message,
            data=exc.data
        ).model_dump()
    )

# Include the authrouter
app.include_router(auth_router)

# Include the bars router
app.include_router(bars_router)

# Include the menus router
app.include_router(menus_router)

# Include the orders router
app.include_router(orders_router)

# Include sockets router
app.include_router(ws_router)

# Include bars owners router
app.include_router(bar_owners_router)

# Include the payment router
app.include_router(payment_router)

def custom_openapi():
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

app.openapi = custom_openapi