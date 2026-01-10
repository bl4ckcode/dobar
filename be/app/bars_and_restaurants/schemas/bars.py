from typing import Optional, Literal
from pydantic import BaseModel, EmailStr
from datetime import datetime


class OperatingHoursDay(BaseModel):
    """Operating hours for a single day."""
    open: Optional[str] = None  # HH:MM format
    close: Optional[str] = None  # HH:MM format
    is_closed: bool = False


class OperatingHours(BaseModel):
    """Weekly operating hours."""
    monday: Optional[OperatingHoursDay] = None
    tuesday: Optional[OperatingHoursDay] = None
    wednesday: Optional[OperatingHoursDay] = None
    thursday: Optional[OperatingHoursDay] = None
    friday: Optional[OperatingHoursDay] = None
    saturday: Optional[OperatingHoursDay] = None
    sunday: Optional[OperatingHoursDay] = None


class BarCreate(BaseModel):
    """Schema for creating a new bar (Create Bar Wizard)."""
    name: str
    address: str
    phone_number: str
    email: EmailStr
    owner_id: int
    latitude: float
    longitude: float
    
    # Country & Business ID
    country_code: str = "BR"  # ISO 3166-1 alpha-2
    business_id: Optional[str] = None  # CNPJ, NIF, EIN, etc.
    business_id_type: Optional[str] = None  # "CNPJ", "NIF", "EIN", etc.
    state_registration: Optional[str] = None  # Brazil-specific
    
    # Media
    logo_url: Optional[str] = None
    cover_url: Optional[str] = None
    photo_urls: Optional[list[str]] = None
    
    # Legacy field (for backwards compatibility with image upload)
    image_url: Optional[str] = None
    
    # Operating hours
    operating_hours: Optional[OperatingHours] = None


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
    
    # Timestamps
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    
    # Computed fields (from MongoDB)
    approximateLocation: Optional[float] = None
    image_url_expiration: Optional[int] = None


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