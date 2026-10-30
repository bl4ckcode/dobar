"""
Schemas for cart and checkout operations.
"""

from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class CartItemBase(BaseModel):
    """Base schema for cart item."""
    menu_item_id: int
    menu_item_name: str
    bar_id: int
    quantity: int = Field(gt=0, description="Quantity must be greater than 0")
    unit_price: float = Field(gt=0, description="Unit price must be greater than 0")


class CartItemCreate(CartItemBase):
    """Schema for creating a cart item."""
    pass


class CartItemUpdate(BaseModel):
    """Schema for updating a cart item."""
    quantity: int = Field(gt=0, description="Quantity must be greater than 0")


class CartItem(CartItemBase):
    id: int
    cart_id: int
    created_at: datetime
    updated_at: datetime
    total_price: float = 0.0

    class Config:
        from_attributes = True


class CartBase(BaseModel):
    pass


class AppliedBundleSummary(BaseModel):
    bundle_id: int
    bundle_name: str
    discount_amount: float
    message: str


class Cart(CartBase):
    id: int
    user_id: int
    items: List[CartItem] = []
    created_at: datetime
    updated_at: datetime
    
    total_items: int = 0
    subtotal: float = 0.0
    
    applied_bundles: List[AppliedBundleSummary] = []
    bundle_savings: float = 0.0
    subtotal_after_bundles: float = 0.0
    
    bundle_hint: Optional[str] = None

    class Config:
        from_attributes = True


class CheckoutRequest(BaseModel):
    """Schema for checkout request."""
    order_type: str = Field(..., description="Order type: delivery, pickup, or dine_in")
    payment_method: str = Field(..., description="Payment method: credit_card, debit_card, pix, etc.")
    
    # Optional fields
    tip: Optional[float] = Field(0.0, ge=0, description="Tip amount")
    coupon_code: Optional[str] = None
    delivery_address_id: Optional[int] = None
    delivery_address: Optional[str] = None
    notes: Optional[str] = None
    special_instructions: Optional[str] = None
    
    # Payment details (will be encrypted/tokenized in production)
    payment_details: Optional[dict] = None
    
    # 🆕 Place Location & Promotions
    location_identifier: Optional[str] = None
    active_promotion_ids: Optional[List[int]] = []


class CheckoutSummary(BaseModel):
    """Schema for checkout summary before finalizing."""
    subtotal: float
    tax: float
    tip: float
    delivery_fee: float
    discount: float
    total: float
    items_count: int


class CheckoutResponse(BaseModel):
    """Schema for checkout response."""
    order_id: int
    status: str
    payment_status: str
    payment_id: Optional[str] = None
    total: float
    discount: float = 0.0
    cashback_earned: float = 0.0
    estimated_ready_time: Optional[datetime] = None
    message: str = "Order created successfully"

    # PIX payment fields (for async payment confirmation)
    pix_qr_code: Optional[str] = None
    pix_copia_e_cola: Optional[str] = None
    pix_expires_at: Optional[datetime] = None


class PromotionApplied(BaseModel):
    id: int
    name: str
    amount: float


class CartCalculateRequest(BaseModel):
    active_promotion_ids: List[int] = []


class CartCalculateResponse(BaseModel):
    subtotal: float
    discount_total: float
    total: float
    promotions_applied: List[PromotionApplied] = []

class CartSyncItem(BaseModel):
    menu_item_id: int
    quantity: int = Field(gt=0)
    special_instructions: Optional[str] = None

class CartSyncRequest(BaseModel):
    items: List[CartSyncItem]
    location_identifier: Optional[str] = None
    active_promotion_ids: List[int] = []
    coupon_code: Optional[str] = None

class CartValidationIssue(BaseModel):
    severity: str  # "error", "warning"
    message: str
    related_field: Optional[str] = None

class LocationStatus(BaseModel):
    valid: bool
    message: Optional[str] = None

class CartItemView(BaseModel):
    menu_item_id: int
    name: str
    quantity: int
    unit_price: float
    total_price: float
    picture: Optional[str] = None
    special_instructions: Optional[str] = None

class ProCouponAllowance(BaseModel):
    is_pro: bool = False
    period_key: str = ""
    timezone: str = "America/Sao_Paulo"
    period_resets_at: str = ""
    monthly_limit: int = 0
    used_count: int = 0
    reserved_count: int = 0
    remaining_count: int = 0


class CartResponse(BaseModel):
    items: List[CartItemView]
    total_items: int
    subtotal: float
    discount: float
    tax: float
    tip: float
    delivery_fee: float
    total: float

    validation_issues: List[CartValidationIssue] = []
    location_status: Optional[LocationStatus] = None
    available_promotions: List[PromotionApplied] = []

    pro_coupon_allowance: Optional[ProCouponAllowance] = None
    cashback_earned: float = 0.0
    accepted_promotion_ids: List[int] = []

    class Config:
        from_attributes = True
