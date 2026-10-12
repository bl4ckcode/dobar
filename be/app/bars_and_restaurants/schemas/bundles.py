from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


class BundleType(str, Enum):
    QUANTITY = "quantity"
    CATEGORY = "category"
    COMBO = "combo"


class BundleDiscountType(str, Enum):
    PERCENTAGE = "percentage"
    FIXED = "fixed"
    FREE_ITEM = "free_item"


class DayOfWeek(str, Enum):
    MONDAY = "monday"
    TUESDAY = "tuesday"
    WEDNESDAY = "wednesday"
    THURSDAY = "thursday"
    FRIDAY = "friday"
    SATURDAY = "saturday"
    SUNDAY = "sunday"


class BundlePromotionBase(BaseModel):
    bar_id: int
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    bundle_type: BundleType = BundleType.QUANTITY
    min_quantity: Optional[int] = Field(2, ge=2, description="Minimum items to trigger bundle")
    target_items: Optional[List[int]] = Field(None, description="Menu item IDs for combo type")
    target_category: Optional[str] = Field(None, max_length=100, description="Category for category type")
    discount_type: BundleDiscountType = BundleDiscountType.PERCENTAGE
    discount_value: float = Field(..., ge=0, description="Discount amount")
    start_time: Optional[str] = Field(None, description="Daily start time HH:MM")
    end_time: Optional[str] = Field(None, description="Daily end time HH:MM")
    recurring_days: Optional[List[DayOfWeek]] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    max_uses_per_user: Optional[int] = Field(None, ge=1)
    is_active: bool = True


class BundlePromotionCreate(BundlePromotionBase):
    pass


class BundlePromotionUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    bundle_type: Optional[BundleType] = None
    min_quantity: Optional[int] = Field(None, ge=2)
    target_items: Optional[List[int]] = None
    target_category: Optional[str] = None
    discount_type: Optional[BundleDiscountType] = None
    discount_value: Optional[float] = Field(None, ge=0)
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    recurring_days: Optional[List[DayOfWeek]] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    max_uses_per_user: Optional[int] = None
    is_active: Optional[bool] = None


class BundlePromotion(BundlePromotionBase):
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class AppliedBundle(BaseModel):
    bundle_id: int
    bundle_name: str
    discount_amount: float
    message: str
