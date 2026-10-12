"""
dobar-payment-engine: Unified Data Models

Gateway-agnostic models for payment requests and responses.
These models abstract away provider-specific implementations.
"""

from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field, EmailStr, field_validator
from enum import Enum
from datetime import datetime
import uuid


# ============================================================================
# Enums
# ============================================================================

class PaymentStatus(str, Enum):
    """Standardized payment status across all gateways."""
    PENDING = "pending"
    PROCESSING = "processing"
    AUTHORIZED = "authorized"
    CAPTURED = "captured"
    PAID = "paid"
    FAILED = "failed"
    CANCELLED = "cancelled"
    REFUNDED = "refunded"
    PARTIALLY_REFUNDED = "partially_refunded"
    DISPUTED = "disputed"
    EXPIRED = "expired"


class PaymentMethodType(str, Enum):
    """Supported payment method types."""
    CREDIT_CARD = "credit_card"
    DEBIT_CARD = "debit_card"
    PIX = "pix"
    BOLETO = "boleto"
    BANK_TRANSFER = "bank_transfer"
    APPLE_PAY = "apple_pay"
    GOOGLE_PAY = "google_pay"
    PAYPAL = "paypal"


class Currency(str, Enum):
    """Supported currencies."""
    BRL = "BRL"
    USD = "USD"
    EUR = "EUR"
    MXN = "MXN"
    ARS = "ARS"
    CLP = "CLP"
    COP = "COP"
    PEN = "PEN"


# ============================================================================
# Address Models
# ============================================================================

class Address(BaseModel):
    """Standardized address model."""
    street: str
    number: str
    complement: Optional[str] = None
    neighborhood: Optional[str] = None
    city: str
    state: str
    zip_code: str
    country: str = "BR"
    
    def to_line(self) -> str:
        """Convert to single-line format."""
        parts = [self.number, self.street]
        if self.neighborhood:
            parts.append(self.neighborhood)
        return ", ".join(parts)


# ============================================================================
# Customer Models
# ============================================================================

class CustomerType(str, Enum):
    INDIVIDUAL = "individual"
    COMPANY = "company"


class Customer(BaseModel):
    """Gateway-agnostic customer model."""
    name: str
    email: EmailStr
    document: str = Field(..., min_length=11, max_length=14, description="CPF or CNPJ")
    type: CustomerType = CustomerType.INDIVIDUAL
    phone: Optional[str] = None
    address: Optional[Address] = None
    
    @field_validator("document")
    @classmethod
    def clean_document(cls, v: str) -> str:
        """Remove non-digit characters from document."""
        return "".join(c for c in v if c.isdigit())


# ============================================================================
# Card Models
# ============================================================================

class Card(BaseModel):
    """Card information for payment."""
    number: str = Field(..., min_length=13, max_length=19)
    holder_name: str
    exp_month: int = Field(..., ge=1, le=12)
    exp_year: int = Field(..., ge=2024)
    cvv: str = Field(..., min_length=3, max_length=4)
    brand: Optional[str] = None
    
    @property
    def last_four(self) -> str:
        return self.number[-4:]
    
    @property
    def masked_number(self) -> str:
        return f"****{self.last_four}"


class SavedCard(BaseModel):
    """Reference to a tokenized/saved card."""
    token: str
    brand: Optional[str] = None
    last_four: Optional[str] = None
    exp_month: Optional[int] = None
    exp_year: Optional[int] = None


# ============================================================================
# Payment Method Models
# ============================================================================

class CreditCardPayment(BaseModel):
    """Credit card payment details."""
    card: Optional[Card] = None
    saved_card: Optional[SavedCard] = None
    installments: int = Field(default=1, ge=1, le=24)
    capture: bool = True
    statement_descriptor: Optional[str] = Field(None, max_length=22)
    
    @field_validator("statement_descriptor")
    @classmethod
    def clean_descriptor(cls, v: Optional[str]) -> Optional[str]:
        """Remove special characters from statement descriptor."""
        if v:
            return "".join(c for c in v if c.isalnum() or c.isspace())
        return v


class PixPayment(BaseModel):
    """PIX payment details."""
    expires_in: int = Field(default=3600, description="Expiration in seconds")
    additional_info: Optional[List[Dict[str, str]]] = None


class BoletoPayment(BaseModel):
    """Boleto payment details."""
    due_date: Optional[datetime] = None
    instructions: Optional[str] = None


class PaymentMethod(BaseModel):
    """Unified payment method container."""
    type: PaymentMethodType
    credit_card: Optional[CreditCardPayment] = None
    debit_card: Optional[CreditCardPayment] = None  # Same structure as credit
    pix: Optional[PixPayment] = None
    boleto: Optional[BoletoPayment] = None
    
    def get_details(self) -> Optional[BaseModel]:
        """Get the relevant payment details based on type."""
        mapping = {
            PaymentMethodType.CREDIT_CARD: self.credit_card,
            PaymentMethodType.DEBIT_CARD: self.debit_card,
            PaymentMethodType.PIX: self.pix,
            PaymentMethodType.BOLETO: self.boleto,
        }
        return mapping.get(self.type)


# ============================================================================
# Request Models
# ============================================================================

class ChargeRequest(BaseModel):
    """Standardized charge request."""
    amount: float = Field(..., gt=0, description="Amount in currency units (e.g., 100.50)")
    currency: Currency = Currency.BRL
    customer: Customer
    payment_method: PaymentMethod
    idempotency_key: Optional[str] = Field(
        default_factory=lambda: str(uuid.uuid4()),
        description="Unique key to prevent duplicate charges"
    )
    order_id: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)
    description: Optional[str] = None
    
    @property
    def amount_in_cents(self) -> int:
        """Convert amount to cents/centavos."""
        return int(self.amount * 100)


class RefundRequest(BaseModel):
    """Standardized refund request."""
    transaction_id: str
    amount: Optional[float] = Field(None, gt=0, description="Partial refund amount")
    idempotency_key: Optional[str] = Field(default_factory=lambda: str(uuid.uuid4()))
    reason: Optional[str] = None
    metadata: Dict[str, Any] = Field(default_factory=dict)


class CaptureRequest(BaseModel):
    """Standardized capture request."""
    transaction_id: str
    amount: Optional[float] = Field(None, gt=0, description="Partial capture amount")
    idempotency_key: Optional[str] = Field(default_factory=lambda: str(uuid.uuid4()))


# ============================================================================
# Response Models
# ============================================================================

class TransactionResponse(BaseModel):
    """Standardized transaction response."""
    success: bool
    transaction_id: Optional[str] = None
    status: PaymentStatus
    gateway: str
    gateway_transaction_id: Optional[str] = None
    amount: float
    currency: Currency
    request_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    idempotency_key: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    metadata: Dict[str, Any] = Field(default_factory=dict)
    
    # PIX-specific
    pix_qr_code: Optional[str] = None
    pix_qr_code_url: Optional[str] = None
    pix_copia_e_cola: Optional[str] = None
    pix_expires_at: Optional[datetime] = None
    
    # Card-specific
    card_last_four: Optional[str] = None
    card_brand: Optional[str] = None
    authorization_code: Optional[str] = None
    
    # Error info
    error_code: Optional[str] = None
    error_message: Optional[str] = None


class RefundResponse(BaseModel):
    """Standardized refund response."""
    success: bool
    refund_id: Optional[str] = None
    transaction_id: str
    status: PaymentStatus
    gateway: str
    amount_refunded: float
    request_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    created_at: datetime = Field(default_factory=datetime.utcnow)
    error_code: Optional[str] = None
    error_message: Optional[str] = None


class CaptureResponse(BaseModel):
    """Standardized capture response."""
    success: bool
    transaction_id: str
    status: PaymentStatus
    gateway: str
    amount_captured: float
    request_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    created_at: datetime = Field(default_factory=datetime.utcnow)
    error_code: Optional[str] = None
    error_message: Optional[str] = None


# ============================================================================
# Health Check Models
# ============================================================================

class GatewayHealth(BaseModel):
    """Gateway health status."""
    gateway: str
    healthy: bool
    latency_ms: Optional[float] = None
    last_check: datetime = Field(default_factory=datetime.utcnow)
    error: Optional[str] = None
