from pydantic import BaseModel, EmailStr

class BarBase(BaseModel):
    name: str
    address: str
    phone_number: str
    email: EmailStr
    owner_id: int

class BarCreate(BarBase):
    latitude: float
    longitude: float

class Bar(BarBase):
    id: int