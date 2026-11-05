from typing import Optional
from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session
from app.auth.rbac_middleware import AuthUser, get_current_user
from app.database import get_db
from ..schemas.checkin import CheckinCreate, CheckinResponse
from ..services import checkin as service


checkin_router = APIRouter(prefix="/checkins", tags=["Check-in"])


@checkin_router.get("/active", response_model=Optional[CheckinResponse])
def active_checkin(user: AuthUser = Depends(get_current_user), db: Session = Depends(get_db)):
    return service.serialize(db, service.current(db, user.id))


@checkin_router.post("", response_model=CheckinResponse)
def create_checkin(data: CheckinCreate, user: AuthUser = Depends(get_current_user), db: Session = Depends(get_db)):
    return service.serialize(db, service.create(db, user.id, data))


@checkin_router.delete("/active", status_code=204)
def end_checkin(user: AuthUser = Depends(get_current_user), db: Session = Depends(get_db)):
    service.end(db, user.id)
    return Response(status_code=204)
