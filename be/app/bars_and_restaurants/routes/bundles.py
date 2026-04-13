from fastapi import APIRouter, Depends, status
from sqlalchemy import and_
from typing import List
from datetime import datetime

from app.auth.middleware import get_current_active_user
from app.auth.auth_models import User
from app.errors import APIError
from app.database import database
from ..models.relational_models import BundlePromotion as BundleModel, Bar as BarModel
from ..schemas.bundles import BundlePromotion, BundlePromotionCreate, BundlePromotionUpdate

bundles_router = APIRouter(prefix="/bundles", tags=["Bundle Promotions"])


async def verify_bar_ownership(bar_id: int, user_id: int) -> bool:
    from app.auth.rbac_models import BarStaff
    query = BarStaff.__table__.select().where(
        and_(
            BarStaff.bar_id == bar_id,
            BarStaff.user_id == user_id,
            BarStaff.role.in_(["owner", "manager"]),
            BarStaff.is_active == True
        )
    )
    staff = await database.fetch_one(query)
    return staff is not None


@bundles_router.post("/", response_model=BundlePromotion, status_code=status.HTTP_201_CREATED)
async def create_bundle(
    bundle: BundlePromotionCreate,
    current_user: User = Depends(get_current_active_user)
):
    if not await verify_bar_ownership(bundle.bar_id, current_user.id):
        raise APIError.forbidden("You don't have permission to create bundles for this bar")
    
    bundle_data = bundle.model_dump()
    bundle_data["created_at"] = datetime.utcnow()
    bundle_data["updated_at"] = datetime.utcnow()
    
    if bundle_data.get("recurring_days"):
        bundle_data["recurring_days"] = [d.value if hasattr(d, 'value') else d for d in bundle_data["recurring_days"]]
    if bundle_data.get("bundle_type") and hasattr(bundle_data["bundle_type"], 'value'):
        bundle_data["bundle_type"] = bundle_data["bundle_type"].value
    if bundle_data.get("discount_type") and hasattr(bundle_data["discount_type"], 'value'):
        bundle_data["discount_type"] = bundle_data["discount_type"].value
    
    bundle_id = await database.execute(BundleModel.__table__.insert().values(**bundle_data))
    return await database.fetch_one(BundleModel.__table__.select().where(BundleModel.id == bundle_id))


@bundles_router.get("/bar/{bar_id}", response_model=List[BundlePromotion])
async def get_bar_bundles(bar_id: int):
    query = BundleModel.__table__.select().where(
        BundleModel.bar_id == bar_id,
        BundleModel.is_active == True
    )
    return await database.fetch_all(query)


@bundles_router.get("/{bundle_id}", response_model=BundlePromotion)
async def get_bundle(bundle_id: int):
    bundle = await database.fetch_one(
        BundleModel.__table__.select().where(BundleModel.id == bundle_id)
    )
    if not bundle:
        raise APIError.not_found("Bundle not found")
    return bundle


@bundles_router.put("/{bundle_id}", response_model=BundlePromotion)
async def update_bundle(
    bundle_id: int,
    bundle_update: BundlePromotionUpdate,
    current_user: User = Depends(get_current_active_user)
):
    bundle = await database.fetch_one(
        BundleModel.__table__.select().where(BundleModel.id == bundle_id)
    )
    if not bundle:
        raise APIError.not_found("Bundle not found")
    
    if not await verify_bar_ownership(bundle["bar_id"], current_user.id):
        raise APIError.forbidden("You don't have permission to update this bundle")
    
    update_data = bundle_update.model_dump(exclude_unset=True)
    update_data["updated_at"] = datetime.utcnow()
    
    if update_data.get("recurring_days"):
        update_data["recurring_days"] = [d.value if hasattr(d, 'value') else d for d in update_data["recurring_days"]]
    if update_data.get("bundle_type") and hasattr(update_data["bundle_type"], 'value'):
        update_data["bundle_type"] = update_data["bundle_type"].value
    if update_data.get("discount_type") and hasattr(update_data["discount_type"], 'value'):
        update_data["discount_type"] = update_data["discount_type"].value
    
    await database.execute(
        BundleModel.__table__.update().where(BundleModel.id == bundle_id).values(**update_data)
    )
    return await database.fetch_one(BundleModel.__table__.select().where(BundleModel.id == bundle_id))


@bundles_router.delete("/{bundle_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_bundle(
    bundle_id: int,
    current_user: User = Depends(get_current_active_user)
):
    bundle = await database.fetch_one(
        BundleModel.__table__.select().where(BundleModel.id == bundle_id)
    )
    if not bundle:
        raise APIError.not_found("Bundle not found")
    
    if not await verify_bar_ownership(bundle["bar_id"], current_user.id):
        raise APIError.forbidden("You don't have permission to delete this bundle")
    
    await database.execute(
        BundleModel.__table__.delete().where(BundleModel.id == bundle_id)
    )
    return None
