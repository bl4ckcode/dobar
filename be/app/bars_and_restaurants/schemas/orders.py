from pydantic import BaseModel

class OrderBase(BaseModel):
    user_id: int
    bar_id: int
    status: str
    total_price: float

class OrderCreate(OrderBase):
    pass

class Order(OrderBase):
    id: int

    class Config:
        from_attributes = True