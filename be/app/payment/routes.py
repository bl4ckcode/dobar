from fastapi import APIRouter, Depends, Query, Header
from typing import Optional
from datetime import datetime, timedelta
import json
import uuid

from app.errors import APIError, map_gateway_error
from app.auth.dependencies import get_current_user
from app.auth.auth_models import User
from app.database import database
from .schemas import (
    PaymentRequest, RefundRequest,
    DPEChargeRequest, DPEChargeResponse,
    DPERefundRequest, DPERefundResponse,
    DPEPaymentStatusResponse,
    PixGenerateRequest, PixGenerateResponse,
)
from .models import IdempotencyKey
from . import get_payment_gateway, PaymentGateway, get_dpe_client, DPEClient

payment_router = APIRouter(prefix="/payments", tags=["Payments"])

IDEMPOTENCY_TTL_HOURS = 24


async def check_idempotency(key: str, user_id: int, request_path: str):
    if not key:
        return None
    
    query = IdempotencyKey.__table__.select().where(
        IdempotencyKey.key == key,
        IdempotencyKey.user_id == user_id
    )
    existing = await database.fetch_one(query)
    
    if existing:
        if existing["expires_at"] > datetime.utcnow():
            return existing["response_body"]
    return None


async def save_idempotency(key: str, user_id: int, request_path: str, response_status: int, response_body: dict):
    if not key:
        return
    
    expires_at = datetime.utcnow() + timedelta(hours=IDEMPOTENCY_TTL_HOURS)
    
    query = IdempotencyKey.__table__.insert().values(
        key=key,
        user_id=user_id,
        request_path=request_path,
        response_status=response_status,
        response_body=response_body,
        expires_at=expires_at
    )
    
    try:
        await database.execute(query)
    except Exception:
        pass


@payment_router.post("/charge")
async def create_charge(
    payment_request: PaymentRequest,
    current_user: User = Depends(get_current_user),
    gateway = Depends(get_payment_gateway),
    x_idempotency_key: Optional[str] = Header(None, alias="X-Idempotency-Key")
):
    if x_idempotency_key:
        cached = await check_idempotency(x_idempotency_key, current_user["id"], "/payments/charge")
        if cached:
            return cached
    
    response = gateway.create_charge(
        amount=payment_request.amount,
        currency=payment_request.currency,
        customer=payment_request.customer.model_dump(),
        payment_method=payment_request.payment_method.model_dump()
    )

    if response.get("status") == "error":
        gateway_code = response.get("code", "unknown")
        transaction_id = response.get("transaction_id")
        raise APIError.payment_declined(
            message=response.get("message", "Payment was declined"),
            gateway_code=gateway_code,
            transaction_id=transaction_id
        )
    
    if x_idempotency_key:
        await save_idempotency(x_idempotency_key, current_user["id"], "/payments/charge", 200, response)

    return response


@payment_router.post("/refund")
async def refund_charge(
    refund_request: RefundRequest,
    current_user: User = Depends(get_current_user),
    gateway: PaymentGateway = Depends(get_payment_gateway)
):
    data = refund_request.model_dump()
    
    # Compatibility fallback if neither ID is provided
    if not data.get("charge_id") and not data.get("payment_intent_id"):
        raise APIError.validation_error(
            message="You must provide either charge_id or payment_intent_id to refund",
            details={"charge_id": ["Either charge_id or payment_intent_id is required"]}
        )

    response = gateway.refund_charge(**data)
    
    if response.get("status") == "failure":
        raise APIError.refund_failed(
            message=response.get("error", "Refund could not be processed"),
            transaction_id=response.get("transaction_id")
        )
    return response


@payment_router.post("/capture")
async def capture_charge(
    payment_intent_id: str,
    amount: float | None = None,
    current_user: User = Depends(get_current_user),
    gateway: PaymentGateway = Depends(get_payment_gateway),
):
    response = gateway.capture_charge(payment_intent_id=payment_intent_id, amount=amount)

    if response.get("status") == "error":
        raise APIError.payment_declined(
            message=response.get("message", "Failed to capture payment"),
            gateway_code=response.get("code"),
            transaction_id=payment_intent_id
        )

    return response
   
@payment_router.post("/checkout")
async def create_checkout(
    success_url: str = Query(..., description="URL to redirect after successful payment"),
    cancel_url: str = Query(..., description="URL to redirect after cancellation"),
    current_user: User = Depends(get_current_user),
    gateway: PaymentGateway = Depends(get_payment_gateway)
):
    if not hasattr(gateway, "create_checkout_session"):
        raise APIError.bad_request(
            message="This gateway does not support hosted checkout"
        )

    response = gateway.create_checkout_session(success_url, cancel_url)
    if response.get("status") == "error":
        raise APIError.payment_declined(
            message=response.get("message", "Failed to create checkout session"),
            gateway_code=response.get("code")
        )
    return response

@payment_router.post("/setup")
async def setup_payment_method(
    customer_id: str,
    current_user: User = Depends(get_current_user),
    gateway: PaymentGateway = Depends(get_payment_gateway)
):
    response = gateway.create_setup_intent(customer_id)
    if response.get("status") == "error":
        raise APIError.payment_declined(
            message=response.get("message", "Failed to setup payment method"),
            gateway_code=response.get("code")
        )
    return response


@payment_router.post("/v2/charge", response_model=DPEChargeResponse, tags=["Payments V2 (DPE)"])
async def create_charge_v2(
    request: DPEChargeRequest,
    current_user: User = Depends(get_current_user),
    x_idempotency_key: Optional[str] = Header(None, alias="X-Idempotency-Key"),
):
    dpe = get_dpe_client()
    idempotency_key = x_idempotency_key or str(uuid.uuid4())
    
    payment_method = {
        "type": request.payment_method.type.value,
        "installments": request.payment_method.installments,
    }
    if request.payment_method.token:
        payment_method["token"] = request.payment_method.token
    if request.payment_method.provider:
        payment_method["provider"] = request.payment_method.provider.value
    if request.payment_method.pix_key:
        payment_method["pix_key"] = request.payment_method.pix_key
    
    customer_info = None
    if request.customer_info:
        customer_info = {
            "name": request.customer_info.name,
            "email": request.customer_info.email,
            "document": request.customer_info.document,
        }
        if request.customer_info.phone:
            customer_info["phone"] = request.customer_info.phone
    
    result = await dpe.charge(
        order_id=request.order_id,
        user_id=current_user.id,
        bar_id=request.bar_id,
        amount=request.amount,
        currency=request.currency,
        country=request.country,
        payment_method=payment_method,
        idempotency_key=idempotency_key,
        metadata=request.metadata,
        description=request.description,
        customer_info=customer_info,
    )
    
    if result.get("status") == "error":
        error_code = result.get("error_code", "PAYMENT_DECLINED")
        http_status = result.get("http_status", 402)
        
        if http_status == 402:
            raise APIError.payment_declined(
                message=result.get("message", "Payment declined"),
                gateway_code=error_code,
            )
        elif http_status == 503:
            raise APIError.server_error(
                message=result.get("message", "Payment service unavailable")
            )
        else:
            raise APIError.payment_declined(
                message=result.get("message", "Payment failed"),
                gateway_code=error_code,
            )
    
    return DPEChargeResponse(
        payment_id=result["payment_id"],
        status=result["status"],
        gateway=result["gateway"],
        gateway_id=result["gateway_id"],
        amount=result["amount"],
        currency=result["currency"],
        created_at=result["created_at"],
        pix_qr_code=result.get("pix_qr_code"),
        pix_copia_e_cola=result.get("pix_copia_e_cola"),
        pix_expires_at=result.get("pix_expires_at"),
        card_last_four=result.get("card_last_four"),
        card_brand=result.get("card_brand"),
    )


@payment_router.post("/v2/refund", response_model=DPERefundResponse, tags=["Payments V2 (DPE)"])
async def create_refund_v2(
    request: DPERefundRequest,
    current_user: User = Depends(get_current_user),
    x_idempotency_key: Optional[str] = Header(None, alias="X-Idempotency-Key"),
):
    dpe = get_dpe_client()
    idempotency_key = x_idempotency_key or str(uuid.uuid4())
    
    result = await dpe.refund(
        payment_id=request.payment_id,
        amount=request.amount,
        reason=request.reason,
        idempotency_key=idempotency_key,
    )
    
    if result.get("status") == "error":
        if result.get("http_status") == 404:
            raise APIError.not_found(f"Payment {request.payment_id} not found")
        raise APIError.refund_failed(
            message=result.get("message", "Refund failed"),
        )
    
    return DPERefundResponse(
        refund_id=result["refund_id"],
        payment_id=result["payment_id"],
        status=result["status"],
        amount=result["amount"],
        created_at=result["created_at"],
    )


@payment_router.get("/v2/{payment_id}", response_model=DPEPaymentStatusResponse, tags=["Payments V2 (DPE)"])
async def get_payment_status(
    payment_id: str,
    current_user: User = Depends(get_current_user),
):
    dpe = get_dpe_client()
    
    result = await dpe.get_payment(payment_id)
    
    if result.get("status") == "error":
        raise APIError.not_found(f"Payment {payment_id} not found")
    
    return DPEPaymentStatusResponse(
        payment_id=result["payment_id"],
        status=result["payment_status"],
        amount=result["amount"],
        currency=result["currency"],
        gateway=result["gateway"],
        refunded_amount=result.get("refunded_amount", 0.0),
        created_at=result["created_at"],
    )


pix_router = APIRouter(prefix="/pix", tags=["PIX (Brazil)"])


@pix_router.post("/generate", response_model=PixGenerateResponse)
async def generate_pix_code(
    request: PixGenerateRequest,
    current_user: User = Depends(get_current_user),
):
    dpe = get_dpe_client()
    
    description = request.description or f"Pedido #{request.order_id}"
    
    result = await dpe.generate_pix(
        order_id=request.order_id,
        amount=request.amount,
        description=description,
        payer_name=request.payer_name,
        payer_document=request.payer_document,
        expires_in=request.expires_in,
    )
    
    if result.get("status") == "error":
        raise APIError.service_unavailable(
            message=result.get("message", "PIX generation failed")
        )
    
    return PixGenerateResponse(
        pix_id=result["pix_id"],
        brcode=result["brcode"],
        qr_code_base64=result["qr_code_base64"],
        expires_at=result["expires_at"],
        status=result.get("pix_status", "pending"),
    )
