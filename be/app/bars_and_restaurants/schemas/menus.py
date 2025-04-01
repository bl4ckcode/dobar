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
    items: List[MenuItem]

class Menu(BaseModel):
    menu_id: int
    bar_id: int
