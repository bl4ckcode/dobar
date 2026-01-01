from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


class DiscountType(str, Enum):
    PERCENTAGE = "percentage"
    FIXED = "fixed"
    BOGO = "bogo"  # Buy One Get One


class DayOfWeek(str, Enum):
    MONDAY = "monday"
    TUESDAY = "tuesday"
    WEDNESDAY = "wednesday"
    THURSDAY = "thursday"
    FRIDAY = "friday"
    SATURDAY = "saturday"
    SUNDAY = "sunday"


class PromotionBase(BaseModel):
    bar_id: int
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    discount_type: DiscountType = DiscountType.PERCENTAGE
    discount_value: float = Field(..., ge=0, description="Discount amount (percentage or fixed value)")
    start_time: Optional[str] = Field(None, description="Daily start time (HH:MM format)")
    end_time: Optional[str] = Field(None, description="Daily end time (HH:MM format)")
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    recurring: bool = False
    recurring_days: Optional[List[DayOfWeek]] = None
    terms: Optional[str] = Field(None, max_length=500)
    is_active: bool = True


class PromotionCreate(PromotionBase):
    pass


class PromotionUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    discount_type: Optional[DiscountType] = None
    discount_value: Optional[float] = Field(None, ge=0)
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    recurring: Optional[bool] = None
    recurring_days: Optional[List[DayOfWeek]] = None
    terms: Optional[str] = Field(None, max_length=500)
    is_active: Optional[bool] = None


class Promotion(PromotionBase):
    id: int
    created_at: datetime
    updated_at: datetime
    image_url: Optional[str] = None
    image_url_expiration: Optional[int] = None

    class Config:
        from_attributes = True


class PromotionWithBar(Promotion):
    bar_name: Optional[str] = None
    bar_address: Optional[str] = None
    approximate_location: Optional[float] = None  # Distance in meters
