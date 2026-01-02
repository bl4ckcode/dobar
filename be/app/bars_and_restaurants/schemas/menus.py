from pydantic import BaseModel
from typing import List, Optional

# Schema for menu items stored in MongoDB
class MenuItem(BaseModel):
    item_name: str
    price: float
    available: bool
    picture: Optional[str] = None

class MenuCreate(BaseModel):
    bar_id: int
    name: Optional[str] = "Menu Principal"
    description: Optional[str] = None
    is_active: Optional[bool] = True
    items: Optional[List[MenuItem]] = []  # Make items optional with default empty list

class Menu(BaseModel):
    id: int
    bar_id: int
    name: Optional[str] = None
    description: Optional[str] = None
    is_active: Optional[bool] = True
    
    class Config:
        from_attributes = True
