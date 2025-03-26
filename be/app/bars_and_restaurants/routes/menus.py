from fastapi import APIRouter, HTTPException
from sqlalchemy import and_
from ..models.relational_models import Menu as MenuModel, Bar
from ..models.nosql_models import menus_collection
from ..schemas.menus import MenuCreate, Menu
from app.database import database  # Use the async database connection

menus_router = APIRouter(prefix="/menus", tags=["Menus"])

# Helper functions
async def get_bar_by_id(bar_id: int):
    query = Bar.__table__.select().where(Bar.id == bar_id)
    return await database.fetch_one(query)

async def get_menu_by_bar_id(bar_id: int):
    query = Menu.__table__.select().where(Menu.bar_id == bar_id)
    return await database.fetch_one(query)

async def create_new_menu_in_mongo(menu_data: dict):
    menu_id = menu_data["menu_id"]
    existing_menu = await menus_collection.find_one({"menu_id": menu_id})
    
    if existing_menu:
        raise HTTPException(status_code=400, detail="Menu with this ID already exists in MongoDB")
    
    await menus_collection.insert_one(menu_data)

async def update_menu_item_in_mongo(menu_id: int, item_name: str, new_data: dict):
    await menus_collection.update_one(
        {"menu_id": menu_id, "items.item_name": item_name},
        {"$set": {"items.$": new_data}}  # Updates the specific item
    )

async def get_menu_by_bar_id(bar_id: int):
    query = MenuModel.__table__.select().where(MenuModel.bar_id == bar_id)
    return await database.fetch_all(query)

async def get_menu_items_from_mongo(menu_id: int):
    menu = await menus_collection.find_one({"menu_id": menu_id})
    if menu:
        return menu["items"]
    return None

# Route to create a new menu
@menus_router.post("/", response_model=Menu)
async def create_menu(menu: MenuCreate):
    # Check if the bar exists in the relational DB
    bar = await get_bar_by_id(menu.bar_id)
    if not bar:
        raise HTTPException(status_code=404, detail="Bar not found")
    
    # Create the menu in PostgreSQL
    menu_postgres_data = {key: value for key, value in menu.dict().items() if key != "items"}
    query = MenuModel.__table__.insert().values(**menu_postgres_data)
    menu_id = await database.execute(query)
    
    # Insert the menu into MongoDB (for the items and other menu-related data)
    mongo_menu_data = {
        "menu_id": menu_id,
        "bar_id": menu.bar_id,
        "items": menu.items
    }
    await create_new_menu_in_mongo(mongo_menu_data)
    
    return await database.fetch_one(MenuModel.__table__.select().where(MenuModel.id == menu_id))

# Route to fetch a menu by bar ID
@menus_router.get("/{bar_id}", response_model=list[Menu])
async def read_menus_by_bar_id(bar_id: int):
    menu = await get_menu_by_bar_id(bar_id)
    if not menu:
        raise HTTPException(status_code=404, detail="Menu not found")
    items = await get_menu_items_from_mongo(menu.menu_id)
    if items is None:
        items = []
    return Menu(**menu.dict(), items=items)

# Route to fetch menu items from MongoDB
@menus_router.get("/items/{menu_id}")
async def read_menu_items(menu_id: int):
    items = await get_menu_items_from_mongo(menu_id)
    
    if items is None:
        raise HTTPException(status_code=404, detail="No items found for this menu")
    
    return {"items": items}

# Route to update a menu item in MongoDB
@menus_router.put("/{menu_id}/items/{item_name}")
async def update_menu_item(menu_id: int, item_name: str, new_data: dict):
    # Check if menu exists
    menu = await menus_collection.find_one({"menu_id": menu_id})
    if not menu:
        raise HTTPException(status_code=404, detail="Menu not found in MongoDB")
    
    # Update the specific menu item
    await update_menu_item_in_mongo(menu_id, item_name, new_data)
    return {"detail": "Menu item updated successfully"}
