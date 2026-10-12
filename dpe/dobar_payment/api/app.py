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
    TrialSetupRequestAPI,
    TrialSetupResponseAPI,
    CaptureRequestAPI,
    CaptureResponseAPI,
)
from .middleware import (
    RequestContext,
    get_request_id,
    get_api_version,
    verify_service_auth,
    create_response_headers,
    DPE_VERSION,
    LogMaskingMiddleware,
)
from .routes import PaymentRoutes, PixRoutes, HealthRoutes, SubscriptionRoutes
from .dependencies import gateway_registry


def _load_gateways_from_env() -> dict:
    gateways = {}
    
    if os.getenv("PAGARME_USERNAME") or os.getenv("PAGARME_API_KEY"):
        try:
            from dobar_payment.gateways.stone import StonePaymentGateway
            config = {
                "PAGARME_USERNAME": os.getenv("PAGARME_USERNAME") or os.getenv("PAGARME_API_KEY"),
                "PAGARME_PASSWORD": os.getenv("PAGARME_PASSWORD", ""),
                "SETTLEMENT_DELAY_DAYS": int(os.getenv("STONE_SETTLEMENT_DELAY_DAYS", "1")),
            }
            gateway = StonePaymentGateway(config)
            if gateway.is_configured:
                gateways["stone"] = gateway
                logger.info("Stone gateway loaded from environment")
        except Exception as e:
            logger.warning(f"Failed to load Stone gateway: {e}")
    
    if os.getenv("STRIPE_API_KEY"):
        try:
            from dobar_payment.gateways.stripe import StripePaymentGateway
            config = {
                "STRIPE_API_KEY": os.getenv("STRIPE_API_KEY"),
                "SETTLEMENT_DELAY_DAYS": int(os.getenv("STRIPE_SETTLEMENT_DELAY_DAYS", "7")),
            }
            gateway = StripePaymentGateway(config)
            if gateway.is_configured:
                gateways["stripe"] = gateway
                logger.info("Stripe gateway loaded from environment")
        except Exception as e:
            logger.warning(f"Failed to load Stripe gateway: {e}")
    
    if os.getenv("PAYPAL_CLIENT_ID") and os.getenv("PAYPAL_CLIENT_SECRET"):
        try:
            from dobar_payment.gateways.paypal import PaypalPaymentGateway
            config = {
                "PAYPAL_CLIENT_ID": os.getenv("PAYPAL_CLIENT_ID"),
                "PAYPAL_CLIENT_SECRET": os.getenv("PAYPAL_CLIENT_SECRET"),
                "PAYPAL_ENV": os.getenv("PAYPAL_ENV", "sandbox"),
            }
            gateway = PaypalPaymentGateway(config)
            if gateway.is_configured:
                gateways["paypal"] = gateway
                logger.info("PayPal gateway loaded from environment")
        except Exception as e:
            logger.warning(f"Failed to load PayPal gateway: {e}")
    
    return gateways


def create_app(
    enable_auth: bool = True,
    gateways: dict | None = None,
):
    try:
        from fastapi import FastAPI, Request, Response, HTTPException, Depends
        from fastapi.responses import JSONResponse
        from fastapi.middleware.cors import CORSMiddleware
        from fastapi.exceptions import RequestValidationError
    except ImportError:
        raise ImportError(
            "FastAPI is required for the API layer. "
            "Install it with: pip install fastapi uvicorn"
        )
    
    app = FastAPI(
        title="Dobar Payment Engine",
        description="Enterprise-grade payment processing API",
        version=DPE_VERSION,
        docs_url=None,
        redoc_url=None,
        openapi_url=None,
    )
    
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(LogMaskingMiddleware)
    
    if gateways is None:
        gateways = _load_gateways_from_env()
    
    if gateways:
        for name, gateway in gateways.items():
            gateway_registry.register(name, gateway)
            logger.info(f"Registered gateway: {name}")
    
    @app.middleware("http")
    async def request_middleware(request: Request, call_next: Callable) -> Response:
        headers = {k.lower(): v for k, v in request.headers.items()}
        
        request_id = get_request_id(headers)
        api_version = get_api_version(headers)
        
        authenticated = True
        service_name = None
        
        bypass_paths = ["/health", "/docs", "/redoc", "/openapi.json"]
        is_webhook = request.url.path.startswith("/webhooks/")
        
        if enable_auth and request.url.path not in bypass_paths and not is_webhook:
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
    
    @app.post(
        "/webhooks/{gateway}",
        responses={401: {"model": ErrorResponse}, 500: {"model": ErrorResponse}},
    )
    async def handle_webhook(gateway: str, request: Request):
        from .routes import WebhookRoutes
        payload = await request.body()
        headers = dict(request.headers)
        
        response, status_code = await WebhookRoutes.process_gateway_webhook(gateway, payload, headers)
        if status_code != 200:
            if isinstance(response, ErrorResponse):
                raise HTTPException(status_code=status_code, detail=response.model_dump())
            else:
                raise HTTPException(status_code=status_code, detail=response)
        return response
    
    @app.post(
        "/subscriptions/trial/setup",
        response_model=TrialSetupResponseAPI,
        responses={502: {"model": ErrorResponse}, 503: {"model": ErrorResponse}},
    )
    async def setup_trial(request: TrialSetupRequestAPI):
        response, status_code = await SubscriptionRoutes.setup_trial(request)
        if status_code != 200:
            raise HTTPException(status_code=status_code, detail=response.model_dump())
        return response

    @app.post(
        "/payments/capture",
        response_model=CaptureResponseAPI,
        responses={404: {"model": ErrorResponse}, 400: {"model": ErrorResponse}},
    )
    async def capture_payment(request: CaptureRequestAPI):
        response, status_code = await PaymentRoutes.capture_payment(request)
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
    
    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request: Request, exc: RequestValidationError):
        ctx = RequestContext.get_current()
        headers = {"X-Request-ID": ctx.request_id} if ctx else {}
        body = await request.body()
        
        logger.error(
            f"Validation error for {request.method} {request.url.path}\n"
            f"Errors: {exc.errors()}\n"
            f"Body: {body.decode('utf-8') if body else ''}"
        )
        
        return JSONResponse(
            status_code=422,
            content={
                "error_code": "VALIDATION_ERROR",
                "message": "Request validation failed",
                "details": exc.errors(),
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
