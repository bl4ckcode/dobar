from typing import Callable, Any
from datetime import datetime, timezone
import logging
import os

logger = logging.getLogger("dobar.payment.api")

from .schemas import (
    ChargeRequestAPI,
    ChargeResponseAPI,
    RefundRequestAPI,
    RefundResponseAPI,
    PaymentStatusResponse,
    PixGenerateRequest,
    PixGenerateResponse,
    ErrorResponse,
    HealthResponse,
)
from .middleware import (
    RequestContext,
    get_request_id,
    get_api_version,
    verify_service_auth,
    create_response_headers,
    DPE_VERSION,
)
from .routes import PaymentRoutes, PixRoutes, HealthRoutes
from .dependencies import gateway_registry


def create_app(
    enable_auth: bool = True,
    gateways: dict | None = None,
):
    try:
        from fastapi import FastAPI, Request, Response, HTTPException, Depends
        from fastapi.responses import JSONResponse
        from fastapi.middleware.cors import CORSMiddleware
    except ImportError:
        raise ImportError(
            "FastAPI is required for the API layer. "
            "Install it with: pip install fastapi uvicorn"
        )
    
    app = FastAPI(
        title="Dobar Payment Engine",
        description="Enterprise-grade payment processing API",
        version=DPE_VERSION,
        docs_url="/docs",
        redoc_url="/redoc",
    )
    
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    if gateways:
        for name, gateway in gateways.items():
            gateway_registry.register(name, gateway)
    
    @app.middleware("http")
    async def request_middleware(request: Request, call_next: Callable) -> Response:
        headers = {k.lower(): v for k, v in request.headers.items()}
        
        request_id = get_request_id(headers)
        api_version = get_api_version(headers)
        
        authenticated = True
        service_name = None
        
        if enable_auth and request.url.path not in ["/health", "/docs", "/redoc", "/openapi.json"]:
            authenticated, service_name = verify_service_auth(headers)
            if not authenticated:
                return JSONResponse(
                    status_code=401,
                    content={
                        "error_code": "UNAUTHORIZED",
                        "message": "Invalid or missing X-Service-Auth header",
                    },
                    headers={"X-Request-ID": request_id},
                )
        
        ctx = RequestContext(
            request_id=request_id,
            api_version=api_version,
            authenticated=authenticated,
            service_name=service_name,
        )
        RequestContext.set_current(ctx)
        
        try:
            response = await call_next(request)
            
            for key, value in create_response_headers(ctx).items():
                response.headers[key] = value
            
            return response
        finally:
            RequestContext.clear()
    
    @app.post(
        "/payments/charge",
        response_model=ChargeResponseAPI,
        responses={402: {"model": ErrorResponse}, 503: {"model": ErrorResponse}},
    )
    async def charge(request: ChargeRequestAPI):
        response, status_code = await PaymentRoutes.create_charge(request)
        if status_code != 200:
            raise HTTPException(status_code=status_code, detail=response.model_dump())
        return response
    
    @app.post(
        "/payments/refund",
        response_model=RefundResponseAPI,
        responses={404: {"model": ErrorResponse}, 502: {"model": ErrorResponse}},
    )
    async def refund(request: RefundRequestAPI):
        response, status_code = await PaymentRoutes.create_refund(request)
        if status_code != 200:
            raise HTTPException(status_code=status_code, detail=response.model_dump())
        return response
    
    @app.get(
        "/payments/{payment_id}",
        response_model=PaymentStatusResponse,
        responses={404: {"model": ErrorResponse}},
    )
    async def get_payment(payment_id: str):
        response, status_code = await PaymentRoutes.get_payment(payment_id)
        if status_code != 200:
            raise HTTPException(status_code=status_code, detail=response.model_dump())
        return response
    
    @app.post(
        "/pix/generate",
        response_model=PixGenerateResponse,
        responses={500: {"model": ErrorResponse}},
    )
    async def generate_pix(request: PixGenerateRequest):
        response, status_code = await PixRoutes.generate_brcode(request)
        if status_code != 200:
            raise HTTPException(status_code=status_code, detail=response.model_dump())
        return response
    
    @app.get("/health", response_model=HealthResponse)
    async def health():
        response, _ = await HealthRoutes.health_check()
        return response
    
    @app.exception_handler(HTTPException)
    async def http_exception_handler(request: Request, exc: HTTPException):
        ctx = RequestContext.get_current()
        headers = {"X-Request-ID": ctx.request_id} if ctx else {}
        
        if isinstance(exc.detail, dict):
            return JSONResponse(
                status_code=exc.status_code,
                content=exc.detail,
                headers=headers,
            )
        
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error_code": "UNKNOWN_ERROR",
                "message": str(exc.detail),
            },
            headers=headers,
        )
    
    @app.exception_handler(Exception)
    async def general_exception_handler(request: Request, exc: Exception):
        ctx = RequestContext.get_current()
        request_id = ctx.request_id if ctx else "unknown"
        
        logger.exception(f"[{request_id}] Unhandled exception: {exc}")
        
        return JSONResponse(
            status_code=500,
            content={
                "error_code": "UNKNOWN_ERROR",
                "message": "Internal server error",
            },
            headers={"X-Request-ID": request_id},
        )
    
    return app


def run_server(host: str = "0.0.0.0", port: int = 8000, **kwargs):
    try:
        import uvicorn
    except ImportError:
        raise ImportError("uvicorn is required to run the server")
    
    app = create_app(**kwargs)
    uvicorn.run(app, host=host, port=port)
