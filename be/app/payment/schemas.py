from pydantic import BaseModel, constr
from typing import Optional

CurrencyCode = constr(min_length=3, max_length=3)

class PaymentRequest(BaseModel):
    amount: float
    currency: CurrencyCode # type: ignore
    payment_method: str = "credit_card"
    installments: Optional[int] = 1
    card_number: Optional[str] = None
    card_expiration_date: Optional[str] = None  # Format MMYY
    card_cvv: Optional[str] = None

class RefundRequest(BaseModel):
    charge_id: str
    amount: Optional[float] = None
