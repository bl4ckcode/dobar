import os
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

WHITELIST_PATHS = {"/health", "/docs", "/redoc", "/openapi.json"}
WHITELIST_PREFIXES = ("/legal",)

API_KEYS = set(
    k.strip()
    for k in os.getenv("API_KEYS", "").split(",")
    if k.strip()
)

TESTING = os.getenv("TESTING", "false").lower() == "true"


class ApiKeyMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if TESTING:
            return await call_next(request)

        path = request.url.path

        if path in WHITELIST_PATHS:
            return await call_next(request)

        for prefix in WHITELIST_PREFIXES:
            if path.startswith(prefix):
                return await call_next(request)

        if not API_KEYS:
            return await call_next(request)

        api_key = request.headers.get("X-API-Key")
        if not api_key or api_key not in API_KEYS:
            return JSONResponse(
                status_code=401,
                content={
                    "error_code": "UNAUTHORIZED",
                    "message": "Invalid or missing API key",
                },
            )

        return await call_next(request)
