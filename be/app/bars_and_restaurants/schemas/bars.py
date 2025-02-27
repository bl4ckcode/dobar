from pydantic import BaseModel, EmailStr

class BarBase(BaseModel):
    name: str
    address: str
    latitude: float
    longitude: float
    phone_number: str
    email: EmailStr
    owner_id: int

class BarCreate(BarBase):
    pass

class Bar(BarBase):
    id: int