from typing import Optional
import asyncio
from fastapi import APIRouter, Depends, Response
from pymongo.errors import PyMongoError
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool
from app.auth.rbac_middleware import AuthUser, get_current_user
from app.database import get_db
from ..schemas.checkin import CheckinCreate, CheckinResponse
from ..services import checkin as service
from ..services.venue_location import coordinates_from_geojson, valid_coordinates
from ..models.relational_models import Bar
from ..models.nosql_models import bars_collection


checkin_router = APIRouter(prefix="/checkins", tags=["Check-in"])


@checkin_router.get("/active", response_model=Optional[CheckinResponse])
def active_checkin(user: AuthUser = Depends(get_current_user), db: Session = Depends(get_db)):
    return service.serialize(db, service.current(db, user.id))


@checkin_router.post("", response_model=CheckinResponse)
async def create_checkin(data: CheckinCreate, user: AuthUser = Depends(get_current_user), db: Session = Depends(get_db)):
    location = await run_in_threadpool(stored_location, db, data.bar_id)
    coordinates = None
    if location is not None and not valid_coordinates(*location):
        try:
            document = await asyncio.wait_for(
                bars_collection.find_one({"bar_id": data.bar_id}, {"location": 1, "_id": 0}), timeout=2.0,
            )
            coordinates = coordinates_from_geojson(document)
        except (PyMongoError, TimeoutError):
            pass
    return await run_in_threadpool(confirm_checkin, db, user.id, data, coordinates)


def stored_location(db, bar_id):
    return db.query(Bar.latitude, Bar.longitude).filter(Bar.id == bar_id).first()


def confirm_checkin(db, user_id, data, coordinates):
    return service.serialize(db, service.create(db, user_id, data, mongodb_coordinates=coordinates))


@checkin_router.delete("/active", status_code=204)
def end_checkin(user: AuthUser = Depends(get_current_user), db: Session = Depends(get_db)):
    service.end(db, user.id)
    return Response(status_code=204)
