import re
from typing import Literal
from fastapi import APIRouter, Depends, File, Form, UploadFile
from sqlalchemy.orm import Session
from app.database import get_db
from app.auth.middleware import get_current_active_user
from app.auth.rbac_middleware import AuthUser
from app.errors import APIError
from ..schemas.onboarding import DraftCreate, DraftPatch, DraftFinalize
from ..models.onboarding import OnboardingDraft, OnboardingAsset
from ..models.relational_models import Bar
from ..services import onboarding as service

onboarding_router = APIRouter(prefix="/bars/onboarding-drafts", tags=["Venue onboarding"])


@onboarding_router.post("")
def create_draft(request: DraftCreate, db: Session = Depends(get_db), user: AuthUser = Depends(get_current_active_user)):
    return service.serialize(db, service.create(db, user, request.creation_key))


@onboarding_router.get("")
def list_drafts(db: Session = Depends(get_db), user: AuthUser = Depends(get_current_active_user)):
    service.check_owner(user)
    drafts = db.query(OnboardingDraft).filter_by(owner_id=user.id).order_by(OnboardingDraft.updated_at.desc()).all()
    return [service.serialize(db, d) for d in drafts]


@onboarding_router.get("/{draft_id}")
def read_draft(draft_id: str, db: Session = Depends(get_db), user: AuthUser = Depends(get_current_active_user)):
    return service.serialize(db, service.owned(db, draft_id, user))


@onboarding_router.patch("/{draft_id}")
def save_draft(draft_id: str, request: DraftPatch, db: Session = Depends(get_db), user: AuthUser = Depends(get_current_active_user)):
    return service.serialize(db, service.patch(db, user, draft_id, request))


@onboarding_router.get("/{draft_id}/venue")
def read_created_venue(draft_id: str, db: Session = Depends(get_db), user: AuthUser = Depends(get_current_active_user)):
    draft = service.owned(db, draft_id, user)
    if not draft.bar_id:
        raise APIError.not_found("Venue has not been created")
    bar = db.get(Bar, draft.bar_id)
    return {"schema_version": 1, "id": bar.id, "name": bar.name, "address": bar.address, "contact": {"phone_number": bar.phone_number, "email": bar.email}}


@onboarding_router.post("/{draft_id}/finalize")
def finalize_draft(draft_id: str, request: DraftFinalize, db: Session = Depends(get_db), user: AuthUser = Depends(get_current_active_user)):
    return service.serialize(db, service.finalize(db, user, draft_id, request))


@onboarding_router.post("/{draft_id}/assets")
def upload_asset(draft_id: str, client_key: str = Form(...), slot: Literal["logo", "cover", "gallery"] = Form(...), image: UploadFile = File(...), db: Session = Depends(get_db), user: AuthUser = Depends(get_current_active_user)):
    if not re.fullmatch(r"[A-Za-z0-9_-]{8,80}", client_key):
        raise APIError.validation_error("Invalid upload key")
    return service.serialize(db, service.store_asset(db, user, draft_id, image, client_key, slot))


@onboarding_router.delete("/{draft_id}/assets/{asset_id}")
def remove_asset(draft_id: str, asset_id: str, db: Session = Depends(get_db), user: AuthUser = Depends(get_current_active_user)):
    draft = service.owned(db, draft_id, user, lock=True)
    if draft.bar_id:
        raise APIError.conflict("Venue already created")
    asset = db.query(OnboardingAsset).filter_by(id=asset_id, draft_id=draft_id).first()
    if not asset:
        raise APIError.not_found("Image not found")
    if not asset.removed:
        asset.removed = 1
        draft.version += 1
    db.commit()
    return service.serialize(db, draft)
