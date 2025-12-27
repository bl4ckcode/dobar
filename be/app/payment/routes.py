from fastapi import APIRouter, Depends, Query

from app.errors import CustomHTTPException
from .schemas import PaymentRequest, RefundRequest
from .core.factory import get_payment_gateway
from .core.interfaces import PaymentGateway

payment_router = APIRouter(prefix="/payments", tags=["Payments"])

@payment_router.post("/charge")
async def create_charge(
    payment_request: PaymentRequest,
    gateway = Depends(get_payment_gateway)
):
    response = gateway.create_charge(
        amount=payment_request.amount,
        currency=payment_request.currency,
        customer=payment_request.customer.model_dump(),
        payment_method=payment_request.payment_method.model_dump()
    )

    if response.get("status") == "error":
        raise CustomHTTPException(
            code=400,
            error_type="payment_error",
            message=response.get("message", "Unknown payment error"),
            data=response
        )

    return response


@payment_router.post("/refund")
async def refund_charge(
    refund_request: RefundRequest,
    gateway: PaymentGateway = Depends(get_payment_gateway)
):
    data = refund_request.model_dump()
    
    # Compatibility fallback if neither ID is provided
    if not data.get("charge_id") and not data.get("payment_intent_id"):
        raise CustomHTTPException(
            code=422,
            error_type="validation_error",
            message="You must provide either charge_id or payment_intent_id to refund"
        )

    response = gateway.refund_charge(**data)
    
    if response.get("status") == "failure":
        raise CustomHTTPException(
            code=400,
            error_type="payment_error",
            message=response.get("error", "Unknown error"),
            data=response
        )
    return response


@payment_router.post("/capture")
async def capture_charge(
    payment_intent_id: str,
    amount: float | None = None,
    gateway: PaymentGateway = Depends(get_payment_gateway),
):
    response = gateway.capture_charge(payment_intent_id=payment_intent_id, amount=amount)

    if response.get("status") == "error":
        raise CustomHTTPException(
            code=400,
            error_type="payment_error",
            message=response.get("message", "Failed to capture payment"),
            data=response,
        )

    return response
   
@payment_router.post("/checkout")
async def create_checkout(
    success_url: str = Query(..., description="URL to redirect after successful payment"),
    cancel_url: str = Query(..., description="URL to redirect after cancellation"),
    gateway: PaymentGateway = Depends(get_payment_gateway)
):
    if not hasattr(gateway, "create_checkout_session"):
        raise CustomHTTPException(
            code=400,
            error_type="unsupported_gateway",
            message="This gateway does not support hosted checkout"
        )

    response = gateway.create_checkout_session(success_url, cancel_url)
    if response.get("status") == "error":
        raise CustomHTTPException(
            code=400,
            error_type="stripe_error",
            message=response.get("message", "Failed to create checkout session")
        )
    return response

@payment_router.post("/setup")
async def setup_payment_method(customer_id: str, gateway: PaymentGateway = Depends(get_payment_gateway)):
    response = gateway.create_setup_intent(customer_id)
    if response.get("status") == "error":
        raise CustomHTTPException(
            code=400,
            error_type="stripe_error",
            message=response.get("message"),
            data=response
        )
    return response