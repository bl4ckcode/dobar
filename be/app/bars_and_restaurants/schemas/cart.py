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
    """Schema for cart item response."""
    id: int
    cart_id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class CartBase(BaseModel):
    """Base schema for cart."""
    pass


class Cart(CartBase):
    """Schema for cart response."""
    id: int
    user_id: int
    items: List[CartItem] = []
    created_at: datetime
    updated_at: datetime
    
    # Calculated fields
    total_items: int = 0
    subtotal: float = 0.0

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
    estimated_ready_time: Optional[datetime] = None
    message: str = "Order created successfully"
