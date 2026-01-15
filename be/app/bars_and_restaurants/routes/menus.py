"""
Menu and Menu Items Routes

All menu data is now stored in PostgreSQL for referential integrity with orders.
MongoDB support is deprecated but kept for legacy data migration.
"""
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Query, UploadFile, File, Form, Depends
from sqlalchemy import and_
import httpx

from ..models.relational_models import Menu as MenuModel, MenuItem as MenuItemModel, Bar
from ..models.nosql_models import menus_collection  # Legacy - for migration only
from ..schemas.menus import (
    MenuCreate, MenuUpdate, Menu, MenuWithItems,
    MenuItemCreate, MenuItemCreateViaURL, MenuItemUpdate, MenuItem,
    LegacyMenuItem, MenuExtractionResponse, MenuExtractionURLRequest
)
from app.database import database
from app.errors import APIError
from app.auth.middleware import get_current_active_user
from app.auth.auth_models import User

menus_router = APIRouter(prefix="/menus", tags=["Menus"])


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

async def get_bar_by_id(bar_id: int):
    query = Bar.__table__.select().where(Bar.id == bar_id)
    return await database.fetch_one(query)


async def get_menu_by_id(menu_id: int):
    query = MenuModel.__table__.select().where(MenuModel.id == menu_id)
    return await database.fetch_one(query)


# =============================================================================
# MENU ROUTES
# =============================================================================

@menus_router.post("/", response_model=Menu)
async def create_menu(menu: MenuCreate):
    """Create a new menu for a bar."""
    # Check if the bar exists
    bar = await get_bar_by_id(menu.bar_id)
    if not bar:
        raise APIError.partner_not_found("Bar not found")
    
    # Create the menu in PostgreSQL
    now = datetime.utcnow()
    menu_data = {
        "bar_id": menu.bar_id,
        "name": menu.name,
        "description": menu.description,
        "is_active": menu.is_active,
        "created_at": now,
        "updated_at": now
    }
    query = MenuModel.__table__.insert().values(**menu_data)
    menu_id = await database.execute(query)
    
    return await database.fetch_one(MenuModel.__table__.select().where(MenuModel.id == menu_id))


@menus_router.get("/bar/{bar_id}", response_model=List[Menu])
async def get_menus_by_bar(bar_id: int):
    """Get all menus for a bar."""
    query = MenuModel.__table__.select().where(MenuModel.bar_id == bar_id)
    menus = await database.fetch_all(query)
    return menus if menus else []


@menus_router.get("/{menu_id}", response_model=Menu)
async def get_menu(menu_id: int):
    """Get a specific menu by ID."""
    menu = await get_menu_by_id(menu_id)
    if not menu:
        raise APIError.not_found("Menu not found")
    return menu


@menus_router.get("/{menu_id}/full", response_model=MenuWithItems)
async def get_menu_with_items(menu_id: int):
    """Get a menu with all its items included."""
    menu = await get_menu_by_id(menu_id)
    if not menu:
        raise APIError.not_found("Menu not found")
    
    # Get items for this menu
    items_query = MenuItemModel.__table__.select().where(
        MenuItemModel.menu_id == menu_id
    ).order_by(MenuItemModel.display_order, MenuItemModel.name)
    items = await database.fetch_all(items_query)
    
    # Combine menu and items
    result = dict(menu)
    result["items"] = items if items else []
    return result


@menus_router.put("/{menu_id}", response_model=Menu)
async def update_menu(menu_id: int, menu_update: MenuUpdate):
    """Update a menu's metadata."""
    menu = await get_menu_by_id(menu_id)
    if not menu:
        raise APIError.not_found("Menu not found")
    
    # Build update data (only non-None values)
    update_data = {k: v for k, v in menu_update.dict().items() if v is not None}
    update_data["updated_at"] = datetime.utcnow()
    
    query = MenuModel.__table__.update().where(MenuModel.id == menu_id).values(**update_data)
    await database.execute(query)
    
    return await get_menu_by_id(menu_id)


@menus_router.delete("/{menu_id}")
async def delete_menu(menu_id: int):
    """Delete a menu and all its items (CASCADE)."""
    menu = await get_menu_by_id(menu_id)
    if not menu:
        raise APIError.not_found("Menu not found")
    
    # Delete from PostgreSQL (items will cascade)
    delete_query = MenuModel.__table__.delete().where(MenuModel.id == menu_id)
    await database.execute(delete_query)
    
    # Also clean up legacy MongoDB data if exists
    try:
        await menus_collection.delete_one({"menu_id": menu_id})
    except:
        pass  # MongoDB might not be available
    
    return {"message": "Menu deleted successfully", "id": menu_id}


# =============================================================================
# MENU ITEM ROUTES
# =============================================================================

@menus_router.get("/{menu_id}/items", response_model=List[MenuItem])
async def get_menu_items(
    menu_id: int,
    category: Optional[str] = Query(None, description="Filter by category"),
    available_only: bool = Query(False, description="Only show available items")
):
    """Get all items for a menu with optional filtering."""
    # Verify menu exists
    menu = await get_menu_by_id(menu_id)
    if not menu:
        raise APIError.not_found("Menu not found")
    
    # Build query with filters
    query = MenuItemModel.__table__.select().where(MenuItemModel.menu_id == menu_id)
    
    if category:
        query = query.where(MenuItemModel.category == category)
    if available_only:
        query = query.where(MenuItemModel.available == True)
    
    query = query.order_by(MenuItemModel.display_order, MenuItemModel.name)
    items = await database.fetch_all(query)
    
    return items if items else []


@menus_router.post("/{menu_id}/items", response_model=MenuItem)
async def create_menu_item(menu_id: int, item: MenuItemCreateViaURL):
    """Add a new item to a menu."""
    # Verify menu exists
    menu = await get_menu_by_id(menu_id)
    if not menu:
        raise APIError.not_found("Menu not found")
    
    now = datetime.utcnow()
    item_data = item.dict()
    item_data["menu_id"] = menu_id  # Use URL parameter
    item_data["created_at"] = now
    item_data["updated_at"] = now
    
    query = MenuItemModel.__table__.insert().values(**item_data)
    item_id = await database.execute(query)
    
    return await database.fetch_one(
        MenuItemModel.__table__.select().where(MenuItemModel.id == item_id)
    )


@menus_router.get("/{menu_id}/items/{item_id}", response_model=MenuItem)
async def get_menu_item(menu_id: int, item_id: int):
    """Get a specific menu item by ID."""
    query = MenuItemModel.__table__.select().where(
        and_(MenuItemModel.id == item_id, MenuItemModel.menu_id == menu_id)
    )
    item = await database.fetch_one(query)
    
    if not item:
        raise APIError.not_found("Menu item not found")
    
    return item


@menus_router.put("/{menu_id}/items/{item_id}", response_model=MenuItem)
async def update_menu_item(menu_id: int, item_id: int, item_update: MenuItemUpdate):
    """Update a menu item."""
    # Verify item exists
    query = MenuItemModel.__table__.select().where(
        and_(MenuItemModel.id == item_id, MenuItemModel.menu_id == menu_id)
    )
    item = await database.fetch_one(query)
    
    if not item:
        raise APIError.not_found("Menu item not found")
    
    # Build update data (only non-None values)
    update_data = {k: v for k, v in item_update.dict().items() if v is not None}
    update_data["updated_at"] = datetime.utcnow()
    
    update_query = MenuItemModel.__table__.update().where(
        MenuItemModel.id == item_id
    ).values(**update_data)
    await database.execute(update_query)
    
    return await database.fetch_one(
        MenuItemModel.__table__.select().where(MenuItemModel.id == item_id)
    )


@menus_router.delete("/{menu_id}/items/{item_id}")
async def delete_menu_item(menu_id: int, item_id: int):
    """Delete a menu item."""
    # Verify item exists
    query = MenuItemModel.__table__.select().where(
        and_(MenuItemModel.id == item_id, MenuItemModel.menu_id == menu_id)
    )
    item = await database.fetch_one(query)
    
    if not item:
        raise APIError.not_found("Menu item not found")
    
    delete_query = MenuItemModel.__table__.delete().where(MenuItemModel.id == item_id)
    await database.execute(delete_query)
    
    return {"message": "Menu item deleted successfully", "id": item_id}


@menus_router.patch("/{menu_id}/items/{item_id}/availability")
async def toggle_item_availability(menu_id: int, item_id: int, available: bool):
    """Quick toggle for item availability (86'd or back in stock)."""
    query = MenuItemModel.__table__.select().where(
        and_(MenuItemModel.id == item_id, MenuItemModel.menu_id == menu_id)
    )
    item = await database.fetch_one(query)
    
    if not item:
        raise APIError.not_found("Menu item not found")
    
    update_query = MenuItemModel.__table__.update().where(
        MenuItemModel.id == item_id
    ).values(available=available, updated_at=datetime.utcnow())
    await database.execute(update_query)
    
    return {"item_id": item_id, "available": available}


# =============================================================================
# POPULAR/TRENDING ITEMS ROUTES (for "Most Desired Drinks" FE feature)
# =============================================================================

@menus_router.get("/trending/drinks", response_model=List[MenuItem])
async def get_trending_drinks(
    limit: int = Query(default=20, le=50, description="Maximum items to return"),
    categories: Optional[str] = Query(
        default="drinks_trending,cachaça_cocktails,drinks_classicos",
        description="Comma-separated list of drink categories to include"
    )
):
    """
    Get trending/popular drinks across all bars.
    Used for "Most Desired Drinks" feature in FE.
    
    Categories available:
    - drinks_trending: Moscow Mule, Aperol Spritz, Espresso Martini, Negroni
    - cachaça_cocktails: Caipirinha, Rabo de Galo, Batidas
    - drinks_classicos: Mojito, Margarita, Piña Colada, Cuba Libre
    - batidas: Batida de Coco, Maracujá, Amendoim
    - cervejas: All beers (chopp, long necks, craft)
    - destilados: Shots and spirits
    """
    category_list = [c.strip() for c in categories.split(",") if c.strip()]
    
    # Get items from specified categories across all menus
    from sqlalchemy import or_
    
    conditions = [MenuItemModel.category == cat for cat in category_list]
    query = MenuItemModel.__table__.select().where(
        and_(
            MenuItemModel.available == True,
            or_(*conditions) if conditions else True
        )
    ).order_by(
        MenuItemModel.display_order, 
        MenuItemModel.name
    ).limit(limit)
    
    items = await database.fetch_all(query)
    return items if items else []


@menus_router.get("/trending/categories", response_model=dict)
async def get_drink_categories():
    """
    Get available drink categories with counts.
    Useful for building category filters in FE.
    """
    from sqlalchemy import func
    
    # Get category counts - using raw SQL for simplicity
    query = """
        SELECT category, COUNT(*) as count 
        FROM menu_items 
        WHERE available = true AND category IS NOT NULL
        GROUP BY category 
        ORDER BY count DESC
    """
    results = await database.fetch_all(query)
    
    categories = {
        "drink_categories": [
            {"category": "drinks_trending", "label": "🔥 Em Alta", "description": "Moscow Mule, Aperol Spritz, Espresso Martini"},
            {"category": "cachaça_cocktails", "label": "🇧🇷 Drinks Brasileiros", "description": "Caipirinha, Rabo de Galo, Batidas"},
            {"category": "drinks_classicos", "label": "🍸 Clássicos", "description": "Mojito, Margarita, Piña Colada"},
            {"category": "batidas", "label": "🥤 Batidas", "description": "Coco, Maracujá, Amendoim"},
            {"category": "cervejas", "label": "🍺 Cervejas", "description": "Chopp, Long Necks, Artesanais"},
            {"category": "destilados", "label": "🥃 Destilados", "description": "Shots, Cachaça, Rum, Tequila"},
        ],
        "food_categories": [
            {"category": "petiscos_fritos", "label": "🍟 Fritos", "description": "Batata, Bolinho, Coxinha"},
            {"category": "petiscos_grelhados", "label": "🔥 Grelhados", "description": "Calabresa, Espetinhos, Carnes"},
            {"category": "tabuas", "label": "🧀 Tábuas", "description": "Frios, Carnes, Mistas"},
            {"category": "porcoes", "label": "🍽️ Porções", "description": "Escondidinho, Feijão Tropeiro"},
            {"category": "especiais", "label": "⭐ Especiais", "description": "Caldinhos, Combos"},
        ],
        "category_counts": {r["category"]: r["count"] for r in results}
    }
    
    return categories


# =============================================================================
# LEGACY ROUTES (for backward compatibility - DEPRECATED)
# =============================================================================

@menus_router.get("/items/{menu_id}", response_model=dict, deprecated=True)
async def read_menu_items_legacy(menu_id: int):
    """
    DEPRECATED: Use GET /{menu_id}/items instead.
    Returns items in old format for backward compatibility.
    """
    # First try PostgreSQL
    items = await database.fetch_all(
        MenuItemModel.__table__.select().where(MenuItemModel.menu_id == menu_id)
    )
    
    if items:
        # Convert to legacy format
        legacy_items = [
            {
                "id": item["id"],  # NEW: now includes ID!
                "item_name": item["name"],  # Legacy field name
                "name": item["name"],
                "price": item["price"],
                "description": item["description"],
                "category": item["category"],
                "available": item["available"],
                "picture": item["picture"]
            }
            for item in items
        ]
        return {"items": legacy_items}
    
    # Fallback to MongoDB for legacy data
    try:
        menu = await menus_collection.find_one({"menu_id": menu_id})
        if menu and "items" in menu:
            return {"items": menu["items"]}
    except:
        pass
    
    return {"items": []}


@menus_router.post("/extract", response_model=MenuExtractionResponse)
async def extract_menu_from_image(
    image: UploadFile = File(...),
    bar_id: int = Form(...),
    language_hint: Optional[str] = Form(None),
    current_user: User = Depends(get_current_active_user)
):
    if image.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
        raise APIError.validation_error(
            message="Invalid image format. Only JPEG and PNG are supported.",
            details={"image": ["Must be JPEG or PNG"]}
        )
    
    content = await image.read()
    
    if len(content) > 10 * 1024 * 1024:
        raise APIError.validation_error(
            message="Image too large. Maximum size is 10MB.",
            details={"image": ["Max size 10MB"]}
        )
    
    bar = await get_bar_by_id(bar_id)
    if not bar:
        raise APIError.partner_not_found("Bar not found")
    
    from ..services.menu_extraction import menu_extraction_service
    
    try:
        result = await menu_extraction_service.extract_menu(content, language_hint)
        return MenuExtractionResponse(**result)
    except ValueError as e:
        error_msg = str(e)
        if "quality" in error_msg.lower():
            raise APIError.bad_request(error_msg)
        elif "No menu items" in error_msg:
            raise APIError.validation_error(message=error_msg, details={})
        raise APIError.server_error(f"Menu extraction failed: {error_msg}")


@menus_router.post("/extract-url", response_model=MenuExtractionResponse)
async def extract_menu_from_url(
    request: MenuExtractionURLRequest,
    current_user: User = Depends(get_current_active_user)
):
    bar = await get_bar_by_id(request.bar_id)
    if not bar:
        raise APIError.partner_not_found("Bar not found")
    
    from ..services.menu_extraction import menu_extraction_service
    
    try:
        result = await menu_extraction_service.extract_menu_from_url(
            request.menu_url, 
            request.language_hint
        )
        return MenuExtractionResponse(**result)
    except httpx.HTTPStatusError as e:
        raise APIError.bad_request(f"Could not fetch URL: {e.response.status_code}")
    except ValueError as e:
        error_msg = str(e)
        if "quality" in error_msg.lower() or "Could not extract" in error_msg:
            raise APIError.bad_request(error_msg)
        elif "No menu items" in error_msg:
            raise APIError.validation_error(message=error_msg, details={})
        raise APIError.server_error(f"Menu extraction failed: {error_msg}")
