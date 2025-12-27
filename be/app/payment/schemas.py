from typing import Optional
from pydantic import BaseModel, EmailStr, constr, conint


class CreditCard(BaseModel):
    number: constr(min_length=13, max_length=19)  # type: ignore
    holder_name: str
    exp_month: conint(ge=1, le=12)  # type: ignore
    exp_year: conint(ge=2024)  # type: ignore
    cvv: constr(min_length=3, max_length=4)  # type: ignore


class Customer(BaseModel):
    name: str
    email: EmailStr
    document: constr(min_length=11, max_length=14)  # type: ignore


class PaymentMethod(BaseModel):
    """Represents how the user wants to pay.

    `payment_method` is intentionally a free string for now so we can support
    values like "credit_card", "pix", "paypal", "apple_pay", etc., without
    breaking existing clients. Pix is treated as a payment_method value and
    is implemented inside specific gateways (e.g. Stone/Pagar.me).
    """

    payment_method: str
    card: Optional[CreditCard] = None

class PaymentRequest(BaseModel):
    amount: int
    currency: str = "BRL"
    customer: Customer
    payment_method: PaymentMethod

class RefundRequest(BaseModel):
    charge_id: Optional[str] = None
    payment_intent_id: Optional[str] = None
    amount: Optional[float] = None

    def model_dump(self, *args, **kwargs):
        # Only include fields that are not None (to prevent issues in Stone)
        return super().model_dump(*args, **kwargs, exclude_none=True)
