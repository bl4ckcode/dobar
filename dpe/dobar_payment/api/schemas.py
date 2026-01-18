from typing import Optional, Dict, Any, Literal
from pydantic import BaseModel, Field
from datetime import datetime
from enum import Enum


class PaymentMethodTypeAPI(str, Enum):
    CARD = "card"
    PIX = "pix"


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
    order_id: str
    user_id: str
    bar_id: str
    amount_cents: int = Field(..., gt=0)
    currency: str = Field(default="BRL", pattern="^[A-Z]{3}$")
    country: str = Field(default="BR", pattern="^[A-Z]{2}$")
    payment_method: PaymentMethodAPI
    idempotency_key: str
    metadata: Dict[str, Any] = Field(default_factory=dict)
    description: Optional[str] = None


class ChargeResponseAPI(BaseModel):
    payment_id: str
    status: str
    gateway: str
    gateway_id: str
    amount_cents: int
    currency: str
    created_at: datetime
    pix_qr_code: Optional[str] = None
    pix_copia_e_cola: Optional[str] = None
    pix_expires_at: Optional[datetime] = None
    card_last_four: Optional[str] = None
    card_brand: Optional[str] = None


class RefundRequestAPI(BaseModel):
    payment_id: str
    amount_cents: Optional[int] = Field(None, gt=0)
    reason: Optional[str] = None
    idempotency_key: str


class RefundResponseAPI(BaseModel):
    refund_id: str
    payment_id: str
    status: str
    amount_cents: int
    created_at: datetime


class PaymentStatusResponse(BaseModel):
    payment_id: str
    status: str
    amount_cents: int
    currency: str
    gateway: str
    refunded_amount_cents: int = 0
    created_at: datetime


class PayerInfo(BaseModel):
    name: str
    document: str


class PixGenerateRequest(BaseModel):
    order_id: str
    amount_cents: int = Field(..., gt=0)
    description: str
    expiration_seconds: int = Field(default=3600, ge=60, le=86400)
    payer_info: Optional[PayerInfo] = None


class PixGenerateResponse(BaseModel):
    pix_id: str
    brcode: str
    qr_code_base64: str
    expires_at: datetime
    status: Literal["pending", "paid", "expired"] = "pending"


class ErrorResponse(BaseModel):
    error_code: str
    message: str
    details: Optional[Dict[str, Any]] = None
    request_id: Optional[str] = None


class GatewayStatus(str, Enum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"


class HealthResponse(BaseModel):
    status: Literal["healthy", "degraded", "unhealthy"]
    version: str
    gateways: Dict[str, str]
    timestamp: Optional[datetime] = None
