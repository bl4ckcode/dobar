from fastapi import APIRouter, Depends

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
    return gateway.create_charge(
        amount=payment_request.amount,
        currency=payment_request.currency,
        customer=payment_request.customer.model_dump(),
        payment_method=payment_request.payment_method.model_dump()
    )

@payment_router.post("/refund")
async def refund_charge(
    refund_request: RefundRequest,
    gateway: PaymentGateway = Depends(get_payment_gateway)
):
    response = gateway.refund_charge(**refund_request.model_dump())
    if response.get("status") == "failure":
        raise CustomHTTPException(
            code=400,
            error_type="payment_error",
            message=response.get("error", "Unknown error"),
            data=response
        )
    return response    