"""
Pydantic schemas for wallet and cashback operations
"""
from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from datetime import datetime
from decimal import Decimal
from uuid import UUID

from app.bars_and_restaurants.models.wallet_models import (
    CashbackType, FundingSource, CashbackStatus
)


# ============== Request Schemas ==============

class EarnCashbackRequest(BaseModel):
    """Internal request to generate cashback after successful payment"""
    user_id: int
    order_id: int
    bar_id: int
    order_total: Decimal = Field(..., ge=0, description="Total order amount")
    cashback_percentage: Decimal = Field(default=Decimal("0.05"), ge=0, le=1, description="Cashback rate (e.g., 0.05 = 5%)")
    funded_by: FundingSource = Field(default=FundingSource.BARZ)
    expires_days: Optional[int] = Field(default=None, description="Days until expiry (None = never expires)")
    
    @field_validator('cashback_percentage')
    @classmethod
    def validate_percentage(cls, v):
        if v > 1:
            raise ValueError("Cashback percentage must be between 0 and 1 (e.g., 0.05 for 5%)")
        return v


class RedeemCashbackRequest(BaseModel):
    """Request to redeem cashback for current order"""
    amount: Decimal = Field(..., gt=0, description="Amount to redeem from wallet")
    
    @field_validator('amount')
    @classmethod
    def validate_amount(cls, v):
        if v <= 0:
            raise ValueError("Redeem amount must be positive")
        # Round to 2 decimal places
        return round(v, 2)


class ApplyCashbackRequest(BaseModel):
    """Apply cashback discount to checkout total"""
    bar_id: int
    amount: Optional[Decimal] = Field(None, gt=0, description="Specific amount to apply (None = use all available)")
    
    @field_validator('amount')
    @classmethod
    def validate_amount(cls, v):
        if v is not None and v <= 0:
            raise ValueError("Apply amount must be positive")
        if v is not None:
            return round(v, 2)
        return v


# ============== Response Schemas ==============

class WalletBalanceResponse(BaseModel):
    """User's current wallet balance"""
    user_id: int
    available_balance: Decimal = Field(..., description="Redeemable balance")
    pending_balance: Decimal = Field(..., description="Balance awaiting clearance")
    total_balance: Decimal = Field(..., description="Total balance (available + pending)")
    last_updated: datetime
    
    class Config:
        from_attributes = True


class CashbackTransactionResponse(BaseModel):
    """Single cashback transaction"""
    id: UUID
    user_id: int
    order_id: Optional[int]
    bar_id: int
    bar_name: Optional[str] = None  # Populated via join
    amount: Decimal
    type: CashbackType
    funded_by: FundingSource
    status: CashbackStatus
    created_at: datetime
    expires_at: Optional[datetime]
    
    class Config:
        from_attributes = True
        use_enum_values = True


class WalletHistoryResponse(BaseModel):
    """Paginated wallet transaction history"""
    transactions: List[CashbackTransactionResponse]
    total_count: int
    page: int
    page_size: int
    has_next: bool
    
    class Config:
        from_attributes = True


class CashbackEarnedResponse(BaseModel):
    """Response after earning cashback"""
    transaction_id: UUID
    amount_earned: Decimal
    new_balance: Decimal
    status: CashbackStatus
    expires_at: Optional[datetime]
    message: str
    
    class Config:
        from_attributes = True
        use_enum_values = True


class CashbackAppliedResponse(BaseModel):
    """Response after applying cashback to order"""
    amount_applied: Decimal
    remaining_balance: Decimal
    discount_code: Optional[str] = None  # For tracking in order
    message: str
    
    class Config:
        from_attributes = True


class InsufficientBalanceError(BaseModel):
    """Error response for insufficient balance"""
    error: str = "insufficient_balance"
    requested_amount: Decimal
    available_balance: Decimal
    shortfall: Decimal
    message: str
    
    class Config:
        from_attributes = True


# ============== Internal Schemas ==============

class CashbackCalculation(BaseModel):
    """Internal calculation result"""
    order_total: Decimal
    cashback_percentage: Decimal
    cashback_amount: Decimal
    funded_by: FundingSource
    expires_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True
