from typing import Optional, Dict, Any, Literal
from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from enum import Enum


class CreditCard(BaseModel):
    number: str = Field(..., min_length=13, max_length=19)
    holder_name: str
    exp_month: int = Field(..., ge=1, le=12)
    exp_year: int = Field(..., ge=2024)
    cvv: str = Field(..., min_length=3, max_length=4)


class Customer(BaseModel):
    name: str
    email: EmailStr
    document: str = Field(..., min_length=11, max_length=14)


class PaymentMethod(BaseModel):
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
        return super().model_dump(*args, **kwargs, exclude_none=True)


class PaymentMethodType(str, Enum):
    CARD = "card"
    PIX = "pix"


class TokenProvider(str, Enum):
    APPLE_PAY = "apple_pay"
    GOOGLE_PAY = "google_pay"
    STRIPE = "stripe"
    SAVED = "saved"


class DPEPaymentMethod(BaseModel):
    type: PaymentMethodType
    token: Optional[str] = None
    provider: Optional[TokenProvider] = None
    pix_key: Optional[str] = None
    installments: int = Field(default=1, ge=1, le=24)


class CustomerInfo(BaseModel):
    name: str
    email: str
    document: str
    phone: Optional[str] = None


class DPEChargeRequest(BaseModel):
    order_id: int
    bar_id: int
    amount: float = Field(..., gt=0)
    currency: str = Field(default="BRL")
    country: str = Field(default="BR")
    payment_method: DPEPaymentMethod
    customer_info: Optional[CustomerInfo] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)
    description: Optional[str] = None


class DPEChargeResponse(BaseModel):
    payment_id: str
    status: str
    gateway: str
    gateway_id: str
    amount: float
    currency: str
    created_at: datetime
    pix_qr_code: Optional[str] = None
    pix_copia_e_cola: Optional[str] = None
    pix_expires_at: Optional[datetime] = None
    card_last_four: Optional[str] = None
    card_brand: Optional[str] = None


class DPERefundRequest(BaseModel):
    payment_id: str
    amount: Optional[float] = Field(None, gt=0)
    reason: Optional[str] = None


class DPERefundResponse(BaseModel):
    refund_id: str
    payment_id: str
    status: str
    amount: float
    created_at: datetime


class DPEPaymentStatusResponse(BaseModel):
    payment_id: str
    status: str
    amount: float
    currency: str
    gateway: str
    refunded_amount: float = 0.0
    created_at: datetime


class PixGenerateRequest(BaseModel):
    order_id: int
    bar_id: int
    amount: float = Field(..., gt=0)
    description: Optional[str] = None
    payer_name: Optional[str] = None
    payer_document: Optional[str] = None
    expires_in: int = Field(default=3600, ge=60, le=86400)


class PixGenerateResponse(BaseModel):
    pix_id: str
    brcode: str
    qr_code_base64: str
    expires_at: datetime
    status: str = "pending"

