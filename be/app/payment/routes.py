from fastapi import APIRouter, Depends, Query, Header
from typing import Optional
from datetime import datetime, timedelta
import json

from app.errors import APIError, map_gateway_error
from app.auth.dependencies import get_current_user
from app.auth.auth_models import User
from app.database import database
from .schemas import PaymentRequest, RefundRequest
from .models import IdempotencyKey
from . import get_payment_gateway, PaymentGateway

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