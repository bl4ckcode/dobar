from fastapi import APIRouter, HTTPException
from sqlalchemy import and_
from ..models.relational_models import Bar as BarModel, BarOwner, Menu
from ..models.nosql_models import menus_collection
from ..schemas.bars import BarCreate, Bar
from ..models.nosql_models import insert_bar_into_mongo  # Import from nosql models
from app.database import database  # Use the async database connection

bars_router = APIRouter()

# Helper functions
async def get_bar_owner_by_id(id: int):
    query = BarOwner.__table__.select().where(BarOwner.id == id)
    return await database.fetch_one(query)

async def create_new_bar_owner(owner_data: dict):
    query = BarOwner.__table__.insert().values(**owner_data)
    owner_id = await database.execute(query)
    return await database.fetch_one(BarOwner.__table__.select().where(BarOwner.id == owner_id))

async def get_menus_by_bar_id(bar_id: int):
    query = Menu.__table__.select().where(Menu.bar_id == bar_id)
    return await database.fetch_all(query)

async def get_menu_items_from_mongo(menu_id: int):
    menu = await menus_collection.find_one({"menu_id": menu_id})
    if menu:
        return menu["items"]
    return None

async def update_menu_item(menu_id: int, item_name: str, new_data: dict):
    await menus_collection.update_one(
        {"menu_id": menu_id, "items.item_name": item_name},
        {"$set": {"items.$": new_data}}  # Updates the specific item
    )

async def get_existing_bar(owner_id: int, address: str):
    query = BarModel.__table__.select().where(
        and_(
            BarModel.owner_id == owner_id,
            BarModel.address == address
        )
    )
    return await database.fetch_one(query)

async def create_new_bar(bar_data: dict):
    owner_id = bar_data["owner_id"]

    # Check for duplicate bar entry by the same owner (e.g., same address)
    existing_bar = await get_existing_bar(owner_id, bar_data["address"])
    
    if existing_bar:
        raise HTTPException(status_code=400, detail="A bar with this address already exists for this owner")

    # Check if the owner exists
    has_owner = await get_bar_owner_by_id(owner_id)
    # If the owner doesn't exist, create a new owner
    if not has_owner:
        owner_id = await create_new_bar_owner({"id": bar_data["owner_id"],
                              "name": bar_data["name"],
                              "email": bar_data["email"],
                              "phone_number": bar_data["phone_number"]
                              })
        
        if owner_id != bar_data["owner_id"]:
            raise HTTPException(status_code=400, detail="Error creating bar owner")
    
    # Create the bar in PostgreSQL
    bar_postgres_data = {key: value for key, value in bar_data.items() if key not in ["latitude", "longitude"]}
    query = BarModel.__table__.insert().values(**bar_postgres_data)
    bar_id = await database.execute(query)

    # Insert bar into MongoDB for geospatial and menu
    await insert_bar_into_mongo(bar_id, bar_data["latitude"], bar_data["longitude"])

    return await database.fetch_one(BarModel.__table__.select().where(BarModel.id == bar_id))

@bars_router.post("/", response_model=Bar)
async def create_bar(bar: BarCreate):
    bar_data = { 
        "name": bar.name,
        "address": bar.address,
        "latitude": bar.latitude,
        "longitude": bar.longitude,
        "phone_number": bar.phone_number,
        "email": bar.email,
        "owner_id": bar.owner_id,
    }
    return await create_new_bar(bar_data)

@bars_router.get("/{bar_id}", response_model=Bar)
async def read_bar(bar_id: int):
    # Fetch the bar by ID
    query = BarModel.__table__.select().where(BarModel.id == bar_id)
    db_bar = await database.fetch_one(query)
    
    if db_bar is None:
        raise HTTPException(status_code=404, detail="Bar not found")
    
    return db_bar