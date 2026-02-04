from typing import Optional, Literal
from pydantic import BaseModel, EmailStr
from datetime import datetime
from .bank_account import BankAccountCreate


class OperatingHoursDay(BaseModel):
    open: Optional[str] = None
    close: Optional[str] = None
    is_closed: bool = False


class OperatingHours(BaseModel):
    monday: Optional[OperatingHoursDay] = None
    tuesday: Optional[OperatingHoursDay] = None
    wednesday: Optional[OperatingHoursDay] = None
    thursday: Optional[OperatingHoursDay] = None
    friday: Optional[OperatingHoursDay] = None
    saturday: Optional[OperatingHoursDay] = None
    sunday: Optional[OperatingHoursDay] = None


class BarCreate(BaseModel):
    name: str
    address: str
    phone_number: str
    email: EmailStr
    owner_id: Optional[int] = None
    latitude: float
    longitude: float
    
    country_code: str = "BR"
    business_id: Optional[str] = None
    business_id_type: Optional[str] = None
    state_registration: Optional[str] = None
    
    logo_url: Optional[str] = None
    cover_url: Optional[str] = None
    photo_urls: Optional[list[str]] = None
    
    image_url: Optional[str] = None
    
    operating_hours: Optional[OperatingHours] = None
    
    bank_account: Optional[BankAccountCreate] = None


class BarBase(BaseModel):
    name: str
    address: str
    phone_number: str
    email: EmailStr
    owner_id: int


class Bar(BarBase):
    id: int
    image_url: Optional[str] = None
    
    # Country & Business ID
    country_code: Optional[str] = "BR"
    business_id: Optional[str] = None
    business_id_type: Optional[str] = None
    state_registration: Optional[str] = None
    verification_status: Optional[str] = "pending"
    
    # Media
    logo_url: Optional[str] = None
    cover_url: Optional[str] = None
    photo_urls: Optional[list[str]] = None
    
    # Operating hours
    operating_hours: Optional[dict] = None
    
    category: Optional[str] = None
    
    # Timestamps
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    
    # Computed fields (from MongoDB)
    approximateLocation: Optional[float] = None
    image_url_expiration: Optional[int] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class BarResponse(BaseModel):
    """Response after creating a bar."""
    id: int
    name: str
    address: str
    country_code: str
    business_id: Optional[str] = None
    business_id_type: Optional[str] = None
    verification_status: str
    created_at: datetime