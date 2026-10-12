from pydantic import BaseModel, EmailStr

class BarOwnerBase(BaseModel):
    id: int
    name: str
    phone_number: str
    email: EmailStr

class BarOwnerCreate(BarOwnerBase):
    pass

class BarOwner(BarOwnerBase):
    id: int