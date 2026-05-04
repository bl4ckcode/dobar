from typing import Optional, Literal
from pydantic import BaseModel, EmailStr, Field, field_validator
from datetime import datetime


CityLiteral = Literal["São Paulo", "Rio de Janeiro", "Belo Horizonte", "Outra"]
SourceLiteral = Literal["organic", "email_outreach", "instagram", "whatsapp", "google_places"]
StatusLiteral = Literal["pending", "contacted", "qualified", "converted", "declined"]


class UTMParams(BaseModel):
    source: Optional[str] = None
    medium: Optional[str] = None
    campaign: Optional[str] = None


class WaitlistSignupCreate(BaseModel):
    bar_name: str = Field(..., min_length=2, max_length=255)
    contact_name: str = Field(..., min_length=2, max_length=255)
    email: EmailStr
    phone: Optional[str] = Field(None, max_length=20)
    city: CityLiteral
    source: SourceLiteral = "organic"
    utm_params: Optional[UTMParams] = None

    @field_validator('phone')
    @classmethod
    def validate_phone(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        # Remove common formatting characters
        cleaned = v.replace(' ', '').replace('-', '').replace('(', '').replace(')', '').replace('.', '')
        # Basic validation - should start with + or be digits
        if not (cleaned.startswith('+') or cleaned.isdigit()):
            raise ValueError('Phone number must start with + or contain only digits')
        return cleaned


class WaitlistSignupResponse(BaseModel):
    id: int
    bar_name: str
    contact_name: str
    email: str
    phone: Optional[str]
    city: str
    source: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


class WaitlistSignupSuccess(BaseModel):
    success: bool = True
    data: dict


class WaitlistSignupDuplicate(BaseModel):
    success: bool = False
    error: dict


class WaitlistUpdateRequest(BaseModel):
    status: Optional[StatusLiteral] = None
    notes: Optional[str] = None


class WaitlistStats(BaseModel):
    total: int
    by_city: dict[str, int]
    by_status: dict[str, int]


class WaitlistListResponse(BaseModel):
    success: bool = True
    data: dict


class WaitlistFilterParams(BaseModel):
    city: Optional[str] = None
    status: Optional[StatusLiteral] = None
    source: Optional[str] = None
    limit: int = Field(50, ge=1, le=100)
    offset: int = Field(0, ge=0)
