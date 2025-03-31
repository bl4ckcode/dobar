from typing import Optional
from pydantic import BaseModel, EmailStr

class BarBase(BaseModel):
    name: str
    address: str
    phone_number: str
    email: EmailStr
    owner_id: int

class Bar(BarBase):
    id: int
    image_url: Optional[str]