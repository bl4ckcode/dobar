from typing import Callable, Optional
from datetime import datetime, timezone
import uuid
import os
import logging
from functools import wraps
import json
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger("dobar.payment.api")

DPE_API_VERSION = "2026-01-16"
DPE_VERSION = "2.0.0"


class RequestContext:
    _current: Optional["RequestContext"] = None
    
    def __init__(
        self,
        request_id: str,
        api_version: str,
        authenticated: bool = False,
        service_name: Optional[str] = None,
    ):
        self.request_id = request_id
        self.api_version = api_version
        self.authenticated = authenticated
        self.service_name = service_name
        self.timestamp = datetime.now(timezone.utc)
    
    @classmethod
    def get_current(cls) -> Optional["RequestContext"]:
        return cls._current
    
    @classmethod
    def set_current(cls, ctx: "RequestContext") -> None:
        cls._current = ctx
    
    @classmethod
    def clear(cls) -> None:
        cls._current = None


def get_request_id(headers: dict) -> str:
    return headers.get("x-request-id", str(uuid.uuid4()))


def get_api_version(headers: dict) -> str:
    return headers.get("x-dpe-version", DPE_API_VERSION)


def verify_service_auth(headers: dict) -> tuple[bool, Optional[str]]:
    auth_header = headers.get("x-service-auth")
    if not auth_header:
        return False, None
    
    expected_secret = os.environ.get("DPE_SERVICE_SECRET")
    if not expected_secret:
        return False, None
    
    if auth_header == expected_secret:
        return True, "barz-backend"
    
    return False, None


def create_response_headers(ctx: RequestContext) -> dict:
    return {
        "X-Request-ID": ctx.request_id,
        "X-DPE-Version": ctx.api_version,
        "X-DPE-Engine-Version": DPE_VERSION,
    }


ERROR_CODE_TO_HTTP = {
    "PAYMENT_DECLINED": 402,
    "INSUFFICIENT_FUNDS": 402,
    "INVALID_CARD": 400,
    "INVALID_AMOUNT": 400,
    "INVALID_CURRENCY": 400,
    "INVALID_PAYMENT_METHOD": 400,
    "MISSING_REQUIRED_FIELD": 400,
    "PROVIDER_ERROR": 502,
    "GATEWAY_UNAVAILABLE": 503,
    "GATEWAY_TIMEOUT": 504,
    "DUPLICATE_PAYMENT": 409,
    "IDEMPOTENCY_CONFLICT": 409,
    "WALLET_LOCKED": 409,
    "RATE_LIMITED": 429,
    "UNAUTHORIZED": 401,
    "FORBIDDEN": 403,
    "NOT_FOUND": 404,
    "UNKNOWN_ERROR": 500,
}


def error_code_to_http_status(error_code: str) -> int:
    return ERROR_CODE_TO_HTTP.get(error_code, 500)


class LogMaskingMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, masked_fields: Optional[list] = None):
        super().__init__(app)
        self.masked_fields = set(masked_fields or ["token", "cvv", "number", "card", "password"])

    def _mask_sensitive_data(self, data: Any) -> Any:
        if isinstance(data, dict):
            return {
                k: "***MASKED***" if k.lower() in self.masked_fields else self._mask_sensitive_data(v)
                for k, v in data.items()
            }
        elif isinstance(data, list):
            return [self._mask_sensitive_data(item) for item in data]
        return data

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        try:
            body = await request.body()
            if body:
                try:
                    json_body = json.loads(body)
                    masked_body = self._mask_sensitive_data(json_body)
                    logger.debug(f"Request body: {json.dumps(masked_body)}")
                except json.JSONDecodeError:
                    pass
        except Exception:
            pass

        async def receive():
            return {"type": "http.request", "body": body}
        
        request._receive = receive
        return await call_next(request)

