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
from firebase_admin import auth, initialize_app, credentials

# Initialize Firebase Admin SDK
cred = credentials.Certificate("/Users/carlosalves/Documents/PDev/barz777-firebase-adminsdk-1daez-49a9bc4a0e.json")
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

def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    openapi_schema = get_openapi(
        title="BARZ-BACKEND API",
        version="1.1.0",
        description="All backend routes for the BARZ app, including authentication, bars, and menus. This API is used to authenticate, manage bar and restaurant data.",  
        routes=app.routes,
    )
    app.openapi_schema = openapi_schema
    return app.openapi_schema

app.openapi = custom_openapi