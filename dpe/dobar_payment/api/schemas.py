from typing import Optional, Dict, Any, Literal
from pydantic import BaseModel, Field
from datetime import datetime
from enum import Enum


class PaymentMethodTypeAPI(str, Enum):
    CARD = "card"
    PIX = "pix"
    BOLETO = "boleto"


class TokenProvider(str, Enum):
    APPLE_PAY = "apple_pay"
    GOOGLE_PAY = "google_pay"
    STRIPE = "stripe"
    SAVED = "saved"


class PaymentMethodAPI(BaseModel):
    type: PaymentMethodTypeAPI
    token: Optional[str] = None
    provider: Optional[TokenProvider] = None
    pix_key: Optional[str] = None
    installments: int = Field(default=1, ge=1, le=24)


class ChargeRequestAPI(BaseModel):
    order_id: int
    user_id: int
    bar_id: int
    amount: float = Field(..., gt=0)
    currency: str = Field(default="BRL", pattern="^[A-Z]{3}$")
    country: str = Field(default="BR", pattern="^[A-Z]{2}$")
    payment_method: PaymentMethodAPI
    idempotency_key: str
    metadata: Dict[str, Any] = Field(default_factory=dict)
    description: Optional[str] = None


class ChargeResponseAPI(BaseModel):
    payment_id: str
    status: str
    provider: str
    provider_id: str
    amount: float
    currency: str
    created_at: datetime
    pix_qr_code: Optional[str] = None
    pix_copia_e_cola: Optional[str] = None
    pix_expires_at: Optional[datetime] = None
    card_last_four: Optional[str] = None
    card_brand: Optional[str] = None


class RefundRequestAPI(BaseModel):
    payment_id: str
    amount: Optional[float] = Field(None, gt=0)
    reason: Optional[str] = None
    idempotency_key: str


class RefundResponseAPI(BaseModel):
    refund_id: str
    payment_id: str
    status: str
    amount: float
    created_at: datetime


class PaymentStatusResponse(BaseModel):
    payment_id: str
    status: str
    amount: float
    currency: str
    provider: str
    refunded_amount: float = 0.0
    created_at: datetime


class PixGenerateRequest(BaseModel):
    amount: float = Field(..., gt=0)
    currency: str = Field(default="BRL")
    merchant_name: str
    merchant_city: str
    pix_key: str
    description: Optional[str] = None
    reference_id: Optional[str] = None
    expires_in: int = Field(default=3600, ge=60, le=86400)


class PixGenerateResponse(BaseModel):
    qr_code: str
    copia_e_cola: str
    expires_at: datetime
    reference_id: str


class ErrorResponse(BaseModel):
    error_code: str
    message: str
    details: Optional[Dict[str, Any]] = None


class HealthResponse(BaseModel):
    status: Literal["healthy", "degraded", "unhealthy"]
    version: str
    gateways: Dict[str, bool]
    timestamp: datetime
