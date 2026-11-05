from datetime import datetime
from enum import Enum
from typing import Any, Dict, Literal, Optional

from pydantic import BaseModel, Field


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
    card_id: Optional[str] = Field(default=None, min_length=1)
    provider: Optional[TokenProvider] = None
    pix_key: Optional[str] = None
    expires_in: Optional[int] = Field(default=None, ge=60, le=86400)
    installments: int = Field(default=1, ge=1, le=24)


class CustomerAddressAPI(BaseModel):
    line_1: str = Field(..., min_length=1)
    line_2: Optional[str] = None
    zip_code: str = Field(..., min_length=1)
    city: str = Field(..., min_length=1)
    state: str = Field(..., min_length=2, max_length=2)
    country: str = Field(default="BR", min_length=2, max_length=2)


class CustomerInfoAPI(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    email: str = Field(..., pattern=r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
    document: str = Field(..., min_length=11, max_length=14)
    type: Optional[str] = Field(default="individual")  # "individual" (CPF) or "company" (CNPJ)
    phone: Optional[str] = None
    address: Optional[CustomerAddressAPI] = None


class SaveCardRequestAPI(BaseModel):
    user_id: str = Field(..., min_length=1)
    token: str = Field(..., pattern=r"^token_[A-Za-z0-9]+$")
    customer_info: CustomerInfoAPI
    idempotency_key: str = Field(..., min_length=1)


class SaveCardResponseAPI(BaseModel):
    card_id: str
    customer_id: str
    brand: str
    last_four: str
    exp_month: int
    exp_year: int


class ProrationInfo(BaseModel):
    previous_plan: str = Field(..., min_length=1)
    new_plan: str = Field(..., min_length=1)
    credit_amount_cents: int = Field(..., ge=0)
    cycle_start: datetime
    cycle_end: datetime
    upgrade_date: datetime


class ChargeRequestAPI(BaseModel):
    order_id: str
    user_id: str
    bar_id: str
    amount_cents: int = Field(..., gt=0)
    currency: str = Field(default="BRL", pattern="^[A-Z]{3}$")
    country: str = Field(default="BR", pattern="^[A-Z]{2}$")
    payment_method: PaymentMethodAPI
    customer_info: Optional[CustomerInfoAPI] = None
    idempotency_key: str
    metadata: Dict[str, Any] = Field(default_factory=dict)
    description: Optional[str] = None
    proration_info: Optional[ProrationInfo] = None


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
    proration_credit_cents: Optional[int] = None


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


class DpeBackendWebhookPayload(BaseModel):
    event: str
    payment_id: str
    order_id: str
    status: str
    amount_cents: Optional[int] = None
    currency: Optional[str] = None
    gateway: Optional[str] = None
    created_at: Optional[datetime] = None


class TrialSetupRequestAPI(BaseModel):
    bar_id: str
    owner_id: str
    plan: str = Field(..., min_length=1)
    trial_days: int = Field(default=7, ge=1, le=30)
    payment_method_id: str
    customer_email: str = Field(..., pattern=r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
    customer_name: str = Field(..., min_length=1, max_length=255)
    idempotency_key: str
    metadata: Dict[str, Any] = Field(default_factory=dict)


class TrialSetupResponseAPI(BaseModel):
    setup_intent_id: str
    status: str
    client_secret: Optional[str] = None
    stripe_customer_id: str
    trial_ends_at: datetime
    payment_method_id: str


class CaptureRequestAPI(BaseModel):
    payment_id: str
    amount_cents: int = Field(..., gt=0)
    idempotency_key: str


class CaptureResponseAPI(BaseModel):
    payment_id: str
    status: str
    amount_cents: int
    gateway: str
    captured_at: datetime
