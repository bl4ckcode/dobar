from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class OrderItemBase(BaseModel):
    """Base schema for order item."""
    menu_item_id: int
    menu_item_name: str
    quantity: int
    unit_price: float


class OrderItem(OrderItemBase):
    """Schema for order item response."""
    id: int
    order_id: int
    total_price: float
    created_at: datetime

    class Config:
        from_attributes = True


class OrderStatusUpdate(BaseModel):
    """Schema for updating order status."""
    status: str = Field(..., description="New status: pending, confirmed, preparing, ready, completed, cancelled")
    notes: Optional[str] = None
    estimated_ready_time: Optional[datetime] = None


class OrderBase(BaseModel):
    """Base schema for order."""
    user_id: int
    bar_id: int
    status: str
    total_price: Optional[float] = None


class OrderCreate(BaseModel):
    """Schema for creating an order (used internally by checkout)."""
    user_id: int
    bar_id: int
    order_type: str
    payment_method: str
    subtotal: float
    tax: float = 0.0
    tip: float = 0.0
    delivery_fee: float = 0.0
    discount: float = 0.0
    total_price: Optional[float] = None


class Order(BaseModel):
    """Schema for order response."""
    id: int
    user_id: int
    bar_id: int
    status: str
    total_price: Optional[float] = None
    subtotal: Optional[float] = None
    tax: Optional[float] = None
    tip: Optional[float] = None
    delivery_fee: Optional[float] = None
    discount: Optional[float] = None
    
    payment_id: Optional[str] = None
    payment_status: Optional[str] = None
    payment_method: Optional[str] = None
    
    order_type: Optional[str] = None
    
    created_at: datetime
    updated_at: datetime
    estimated_ready_time: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    
    items: List[OrderItem] = []

    class Config:
        from_attributes = True


class OrderWithHistory(Order):
    """Schema for order with status history."""
    status_history: List[dict] = []


class OrderHistoryResponse(BaseModel):
    orders: List[Order]
    next_cursor: Optional[str] = None
    has_more: bool = False


class SyncOperation(BaseModel):
    type: str
    order_id: Optional[int] = None
    bar_id: Optional[int] = None
    client_timestamp: str


class SyncRequest(BaseModel):
    operations: List[SyncOperation]


class SyncConflict(BaseModel):
    operation: dict
    conflict_type: str
    server_state: Optional[dict] = None
    resolution: str


class SyncResponse(BaseModel):
    synced: List[dict]
    conflicts: List[SyncConflict]