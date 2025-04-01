from fastapi import APIRouter, HTTPException
from sqlalchemy import and_
from app.database import database  # Use the async database connection
from app.bars_and_restaurants.models.relational_models import BarOwner as BarOwnerModel
from ..schemas.bar_owners import BarOwnerCreate, BarOwner

bar_owners_router = APIRouter(prefix="/barowners", tags=["Bar Owners"])

async def create_new_bar_owner(owner_data: dict):
    query = (
        BarOwnerModel.__table__
        .insert()
        .values(**owner_data)
        .returning(BarOwnerModel.id)  # Ensure the query returns the id
    )
    owner_id = await database.execute(query)
    # Now fetch the newly created row
    return await database.fetch_one(
        BarOwnerModel.__table__.select().where(BarOwnerModel.id == owner_id)
    )

async def get_existing_bar_owner(owner_id: int):
    query = BarOwnerModel.__table__.select().where(
        and_(
            BarOwnerModel.id == owner_id
        )
    )
    return await database.fetch_one(query)

@bar_owners_router.post("/", response_model=BarOwner)
async def create_bar_owner(owner: BarOwnerCreate):
    owner_data = {
        "id": owner.id,
        "name": owner.name,
        "email": owner.email,
        "phone_number": owner.phone_number
    }
    # Check for duplicate bar entry by the same owner (e.g., same address)
    existing_bar_owner = await get_existing_bar_owner(owner_data["id"])
    
    if existing_bar_owner:
        raise HTTPException(status_code=400, detail="This owner already exists.")
    
    return await create_new_bar_owner(owner_data)