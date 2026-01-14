from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

# =============================================================================
# MENU ITEM SCHEMAS (PostgreSQL-backed for referential integrity with orders)
# =============================================================================

class MenuItemBase(BaseModel):
    """Base schema for menu items - used for creation."""
    name: str = Field(..., min_length=1, max_length=200, description="Item name")
    price: float = Field(..., ge=0, description="Price in local currency")
    description: Optional[str] = Field(None, max_length=500, description="Item description")
    category: Optional[str] = Field(None, max_length=100, description="Category (drinks, food, etc.)")
    picture: Optional[str] = Field(None, description="Image URL")
    available: bool = Field(default=True, description="Whether item is currently available")
    display_order: Optional[int] = Field(default=0, description="Display order in menu")


class MenuItemCreate(MenuItemBase):
    """Schema for creating a menu item.
    menu_id is optional in body - can be provided via URL parameter.
    """
    menu_id: Optional[int] = Field(None, description="Menu this item belongs to (optional if in URL)")


class MenuItemCreateViaURL(MenuItemBase):
    """Schema for creating menu item via /menus/{menu_id}/items endpoint.
    menu_id is taken from URL, not body.
    """
    pass


class MenuItemUpdate(BaseModel):
    """Schema for updating a menu item (all fields optional)."""
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    price: Optional[float] = Field(None, ge=0)
    description: Optional[str] = Field(None, max_length=500)
    category: Optional[str] = Field(None, max_length=100)
    picture: Optional[str] = None
    available: Optional[bool] = None
    display_order: Optional[int] = None


class MenuItem(MenuItemBase):
    """Full menu item response with ID."""
    id: int
    menu_id: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


# =============================================================================
# MENU SCHEMAS
# =============================================================================

class MenuCreate(BaseModel):
    """Schema for creating a menu."""
    bar_id: int
    name: Optional[str] = Field(default="Menu Principal", max_length=200)
    description: Optional[str] = Field(None, max_length=500)
    is_active: Optional[bool] = True


class MenuUpdate(BaseModel):
    """Schema for updating a menu."""
    name: Optional[str] = Field(None, max_length=200)
    description: Optional[str] = Field(None, max_length=500)
    is_active: Optional[bool] = None


class Menu(BaseModel):
    """Menu response (without items)."""
    id: int
    bar_id: int
    name: Optional[str] = None
    description: Optional[str] = None
    is_active: Optional[bool] = True
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class MenuWithItems(Menu):
    """Menu response with all items included."""
    items: List[MenuItem] = []
    
    class Config:
        from_attributes = True


# =============================================================================
# LEGACY SUPPORT (for existing MongoDB data - will be deprecated)
# =============================================================================

class LegacyMenuItem(BaseModel):
    item_name: str
    price: float
    available: bool
    picture: Optional[str] = None


class ExtractedMenuItem(BaseModel):
    name: str
    price: float
    description: Optional[str] = None


class ExtractedCategory(BaseModel):
    name: str
    items: List[ExtractedMenuItem]


class MenuExtractionResponse(BaseModel):
    confidence: float
    categories: List[ExtractedCategory]
    raw_text: str
    currency_detected: str
