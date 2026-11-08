import hashlib
import json
import math
import re
from datetime import datetime
from uuid import uuid4
from sqlalchemy.exc import IntegrityError
from pydantic import EmailStr, TypeAdapter, ValidationError
from app.errors import APIError
from app.auth.rbac_models import BarStaff
from ..models.relational_models import Bar, BarOwner
from ..models.bank_account import BarBankAccount
from ..models.onboarding import OnboardingDraft, OnboardingAsset, OnboardingProjection
from . import bank_account_service as bank
from .venue_location import geocode_address, valid_coordinates

STEPS = ("find", "details", "receiving", "photos", "hours", "review")
DAYS = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")
TEXT_LIMITS = {"name": 200, "address": 1000, "phone_number": 30, "email": 254, "business_id": 50}
PAYLOAD_KEYS = set(TEXT_LIMITS) | {"latitude", "longitude", "location_confirmed", "operating_hours", "menu_import_intent"}
BANK_KEYS = {"method", "pix_key", "pix_key_type", "bank_code", "branch_code", "account_number", "account_type", "account_holder_name", "holder_document"}


def check_owner(user):
    if not user.is_active or user.user_type != "business":
        raise APIError.forbidden("Business account required")


def owned(db, draft_id, user, lock=False):
    check_owner(user)
    query = db.query(OnboardingDraft).filter_by(id=draft_id, owner_id=user.id)
    if lock:
        query = query.with_for_update()
    draft = query.first()
    if draft is None:
        raise APIError.not_found("Draft not found")
    return draft


def editable(draft, version):
    if draft.bar_id is not None:
        raise APIError.conflict("Venue already created")
    if draft.version != version:
        raise APIError.conflict("Draft changed. Reload before saving")


def validate_partial(payload):
    if set(payload) - PAYLOAD_KEYS:
        raise APIError.validation_error("Unsupported draft fields")
    for key, limit in TEXT_LIMITS.items():
        value = payload.get(key)
        if value is not None and (not isinstance(value, str) or len(value) > limit):
            raise APIError.validation_error("Invalid draft field", details={key: [f"Maximum {limit} characters"]})
    for key in ("latitude", "longitude"):
        value = payload.get(key)
        if value is not None and (isinstance(value, bool) or not isinstance(value, (float, int)) or not math.isfinite(value)):
            raise APIError.validation_error("Invalid coordinate", details={key: ["Must be a finite number"]})
    for key in ("location_confirmed", "menu_import_intent"):
        if key in payload and payload[key] is not None and not isinstance(payload[key], bool):
            raise APIError.validation_error("Invalid flag")
    hours = payload.get("operating_hours")
    if hours is not None:
        if not isinstance(hours, dict) or set(hours) - set(DAYS):
            raise APIError.validation_error("Invalid operating hours")
        for day in hours.values():
            if not isinstance(day, dict) or set(day) - {"is_closed", "open", "close"}:
                raise APIError.validation_error("Invalid operating hours")
            if "is_closed" in day and not isinstance(day["is_closed"], bool):
                raise APIError.validation_error("Invalid operating hours")
            for key in ("open", "close"):
                if key in day and (not isinstance(day[key], str) or len(day[key]) > 5):
                    raise APIError.validation_error("Invalid operating hours")


def identity_errors(payload):
    errors = {}
    for key in ("name", "address"):
        if not (payload.get(key) or "").strip():
            errors[key] = ["Required"]
    lat, lng = payload.get("latitude"), payload.get("longitude")
    if not valid_coordinates(lat, lng) or (lat == 0 and lng == 0):
        errors["location_confirmed"] = ["Confirm a valid venue location"]
    if payload.get("email"):
        try:
            TypeAdapter(EmailStr).validate_python(payload["email"])
        except ValidationError:
            errors["email"] = ["Invalid email"]
    if payload.get("phone_number") and not re.fullmatch(r"(?:55)?[1-9]\d(?:9\d{8}|[2-8]\d{7})", re.sub(r"\D", "", payload["phone_number"])):
        errors["phone_number"] = ["Invalid Brazilian phone"]
    if payload.get("business_id"):
        from ..routes.bars import validate_cnpj
        if not validate_cnpj(payload["business_id"]):
            errors["business_id"] = ["Invalid CNPJ"]
    return errors


def hours_invalid(hours):
    if hours is None:
        return False
    return any(
        not day.get("is_closed") and (
            any(not re.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d", day.get(t, "")) for t in ("open", "close"))
            or day.get("open") == day.get("close")
        ) for day in hours.values()
    )


def next_step(draft):
    errors = identity_errors(draft.payload)
    if "address" in errors or "location_confirmed" in errors:
        return "find"
    if errors:
        return "details"
    for step in STEPS[2:-1]:
        if step == "receiving" and draft.bank_summary and not draft.bank_summary.get("complete"):
            return step
        if step == "hours" and hours_invalid(draft.payload.get("operating_hours")):
            return step
        if draft.steps.get(step) not in ("complete", "skipped"):
            return step
    return "review"



def bank_plain(draft):
    if not draft.bank_encrypted:
        return None
    require_bank_key()
    return json.loads(bank.decrypt_value(draft.bank_encrypted))


def require_bank_key():
    if not bank.ENCRYPTION_KEY:
        raise APIError.server_error("Receiving account storage is unavailable")


def validate_bank(data):
    valid, error = bank.validate_bank_account_for_country("BR", data)
    if not valid:
        return error
    if data.get("method") == "pix":
        key, kind = data.get("pix_key", ""), data.get("pix_key_type")
        from ..routes.bars import validate_cnpj, validate_cpf
        if kind in ("cpf", "cnpj") and not (validate_cpf(key) if kind == "cpf" else validate_cnpj(key)):
            return "Invalid Pix document"
        if kind == "email":
            try:
                TypeAdapter(EmailStr).validate_python(key)
            except ValidationError:
                return "Invalid Pix email"
        if kind == "phone" and not re.fullmatch(r"\+?55[1-9]\d9?\d{8}", re.sub(r"[\s()-]", "", key)):
            return "Invalid Pix phone"
        if kind == "random" and not re.fullmatch(r"[a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}", key):
            return "Invalid Pix key"
    else:
        if data.get("account_type", "checking") not in ("checking", "savings"):
            return "Invalid account type"
        if not re.fullmatch(r"\d{3}", data.get("bank_code", "")) or not re.fullmatch(r"\d{4}", data.get("branch_code", "")) or not re.fullmatch(r"\d{3,12}-?[\dXx]", data.get("account_number", "")):
            return "Invalid bank, branch or account"
        from ..routes.bars import validate_cnpj, validate_cpf
        document = data.get("holder_document", "")
        if len(data.get("account_holder_name", "").strip()) < 3 or not (validate_cpf(document) or validate_cnpj(document)):
            return "Invalid account holder"
    return None


def serialize(db, draft):
    from .image_upload import generate_presigned_url
    assets = db.query(OnboardingAsset).filter_by(draft_id=draft.id, removed=0).all()
    projection = db.get(OnboardingProjection, draft.bar_id) if draft.bar_id else None
    return {
        "id": draft.id, "version": draft.version, "payload": draft.payload,
        "steps": draft.steps, "next_step": "photos" if any(a.status != "saved" for a in assets) and STEPS.index(next_step(draft)) > 3 else next_step(draft),
        "bank_summary": draft.bank_summary, "updated_at": draft.updated_at.isoformat() + "Z",
        "bar_id": draft.bar_id, "status": "created" if draft.bar_id else "draft",
        "projection_status": "ready" if projection and projection.completed_at else "pending",
        "assets": [{"id": a.id, "client_key": a.client_key, "slot": a.slot, "filename": a.filename, "status": a.status, "preview_url": generate_presigned_url(a.object_key) if a.status == "saved" else None} for a in assets],
    }


def create(db, user, key):
    check_owner(user)
    draft = db.query(OnboardingDraft).filter_by(owner_id=user.id, creation_key=key).first()
    if draft:
        return draft
    draft = OnboardingDraft(id=str(uuid4()), owner_id=user.id, creation_key=key, payload={}, steps={})
    db.add(draft)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        draft = db.query(OnboardingDraft).filter_by(owner_id=user.id, creation_key=key).one()
    return draft


def patch(db, user, draft_id, request):
    draft = owned(db, draft_id, user, lock=True)
    editable(draft, request.version)
    validate_partial(request.payload)
    if set(request.steps) - set(STEPS) or any(s in ("find", "details", "review") and v == "skipped" for s, v in request.steps.items()):
        raise APIError.validation_error("Invalid step")
    payload = {**draft.payload, **request.payload}
    if "address" in request.payload:
        address_changed = payload.get("address") != draft.payload.get("address")
        supplied_coordinates = valid_coordinates(request.payload.get("latitude"), request.payload.get("longitude"))
        if address_changed and not supplied_coordinates:
            payload.update(latitude=None, longitude=None, location_confirmed=False)
        if not valid_coordinates(payload.get("latitude"), payload.get("longitude")):
            coordinates = geocode_address(payload.get("address"))
            if coordinates:
                payload.update(latitude=coordinates[0], longitude=coordinates[1], location_confirmed=True)
    draft.payload = payload
    draft.steps = {**draft.steps, **request.steps}
    if "bank_account" in request.model_fields_set:
        data = request.bank_account
        if data is not None:
            require_bank_key()
            if set(data) - BANK_KEYS or any(not isinstance(v, str) or len(v) > 255 for v in data.values()) or data.get("method") not in ("pix", "bank"):
                raise APIError.validation_error("Invalid receiving account fields")
            data = {k: v for k, v in data.items() if k not in ("pix_key", "pix_key_type")} if data["method"] == "bank" else {k: v for k, v in data.items() if k in ("method", "pix_key", "pix_key_type")}
            draft.bank_encrypted = bank.encrypt_value(json.dumps(data))
            source = data.get("pix_key") or data.get("account_number") or ""
            draft.bank_summary = {"method": data["method"], "masked": "••••" + re.sub(r"[^\dA-Za-z]", "", source)[-4:], "complete": validate_bank(data) is None, "verified": False}
        else:
            draft.bank_encrypted = None
            draft.bank_summary = None
    draft.version += 1
    draft.updated_at = datetime.utcnow()
    db.commit()
    return draft


def finalize(db, user, draft_id, request):
    draft = owned(db, draft_id, user, lock=True)
    if draft.bar_id:
        if draft.finalize_key != request.operation_key or draft.finalized_version != request.version:
            raise APIError.conflict("Finalization operation differs from the created venue")
        return draft
    editable(draft, request.version)
    p = dict(draft.payload)
    if not valid_coordinates(p.get("latitude"), p.get("longitude")):
        coordinates = geocode_address(p.get("address"))
        if coordinates:
            p.update(latitude=coordinates[0], longitude=coordinates[1], location_confirmed=True)
            draft.payload = p
    errors = identity_errors(p)
    account = bank_plain(draft)
    if account and validate_bank(account):
        errors["bank_account"] = [validate_bank(account)]
    hours = p.get("operating_hours")
    if hours is not None:
        for key, day in hours.items():
            if not day.get("is_closed"):
                if any(not re.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d", day.get(t, "")) for t in ("open", "close")) or day.get("open") == day.get("close"):
                    errors["operating_hours"] = ["Invalid hours"]
    if errors:
        raise APIError.validation_error("Review venue fields", details=errors)
    from app.auth.auth_models import User
    db.query(User).filter_by(id=user.id).with_for_update().one()
    if not db.get(BarOwner, user.id):
        db.add(BarOwner(id=user.id, name=user.display_name or p["name"], email=user.email, phone_number=user.phone_number))
        try:
            db.flush()
        except IntegrityError as exc:
            db.rollback()
            raise APIError.conflict("Owner profile conflicts with an existing account") from exc
    if db.query(Bar).filter(Bar.address == p["address"].strip()).first():
        raise APIError.conflict("A venue with this address already exists")
    if p.get("business_id") and db.query(Bar).filter_by(country_code="BR", business_id=p["business_id"]).first():
        raise APIError.conflict("A venue with this CNPJ already exists")
    assets = db.query(OnboardingAsset).filter_by(draft_id=draft.id, removed=0).all()
    if any(a.status != "saved" for a in assets):
        raise APIError.validation_error("Remove or retry unfinished image uploads", details={"assets": ["Unfinished uploads"]})
    media = {slot: [a.object_key for a in assets if a.slot == slot] for slot in ("logo", "cover", "gallery")}
    bar = Bar(owner_id=user.id, name=p["name"].strip(), address=p["address"].strip(), phone_number=(p.get("phone_number") or "").strip() or None, email=(p.get("email") or "").strip() or None, country_code="BR", business_id=p.get("business_id") or None, business_id_type="CNPJ" if p.get("business_id") else None, latitude=p["latitude"], longitude=p["longitude"], logo_url=media["logo"][0] if media["logo"] else None, cover_url=media["cover"][0] if media["cover"] else None, photo_urls=media["gallery"], operating_hours=hours)
    db.add(bar)
    try:
        db.flush()
    except IntegrityError as exc:
        db.rollback()
        raise APIError.conflict("Venue conflicts with an existing record") from exc
    db.add(BarStaff(user_id=user.id, bar_id=bar.id, role="owner", is_active=True, accepted_at=datetime.utcnow()))
    if account:
        db.add(BarBankAccount(bar_id=bar.id, country_code="BR", bank_code=account.get("bank_code"), branch_code=account.get("branch_code"), account_number_encrypted=bank.encrypt_value(account.get("account_number")), account_type=account.get("account_type"), pix_key_encrypted=bank.encrypt_value(account.get("pix_key")), pix_key_type=account.get("pix_key_type"), account_holder_name=account.get("account_holder_name"), is_verified=False))
    draft.bar_id = bar.id
    draft.finalize_key = request.operation_key
    draft.finalized_version = request.version
    draft.bank_encrypted = None
    draft.updated_at = datetime.utcnow()
    db.add(OnboardingProjection(bar_id=bar.id, payload={"bar_id": bar.id, "location": {"type": "Point", "coordinates": [p["longitude"], p["latitude"]]}, "image_url": bar.logo_url}))
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise APIError.conflict("Venue creation conflicted; reload the draft") from exc
    return draft


def store_asset(db, user, draft_id, file, key, slot):
    from .image_upload import s3_client
    import os
    draft = owned(db, draft_id, user, lock=True)
    if draft.bar_id:
        raise APIError.conflict("Venue already created")
    content = file.file.read(10 * 1024 * 1024 + 1)
    is_png = content.startswith(b"\x89PNG\r\n\x1a\n")
    is_jpeg = content.startswith(b"\xff\xd8\xff")
    is_webp = content.startswith(b"RIFF") and content[8:12] == b"WEBP"
    mime = "image/png" if is_png else "image/jpeg" if is_jpeg else "image/webp" if is_webp else None
    if not mime or len(content) > 10 * 1024 * 1024 or len(content) < 12 or file.content_type != mime:
        raise APIError.validation_error("Use PNG, JPEG or WebP up to 10MB")
    digest = hashlib.sha256(content).hexdigest()
    existing = db.query(OnboardingAsset).filter_by(draft_id=draft.id, client_key=key).first()
    if existing:
        if existing.digest != digest or existing.slot != slot or existing.removed:
            raise APIError.conflict("Upload key already used")
        if existing.status == "saved":
            return draft
    else:
        active = db.query(OnboardingAsset).filter_by(draft_id=draft.id, slot=slot, removed=0).count()
        if active >= (6 if slot == "gallery" else 1):
            raise APIError.validation_error("Remove an existing image before adding another")
        existing = OnboardingAsset(id=str(uuid4()), draft_id=draft.id, client_key=key, slot=slot, filename=(file.filename or "image")[:255], digest=digest, object_key=f"onboarding/{draft.id}/{key}", status="pending")
        db.add(existing)
        draft.version += 1
        draft.updated_at = datetime.utcnow()
        db.commit()
    draft = owned(db, draft_id, user, lock=True)
    existing = db.query(OnboardingAsset).filter_by(draft_id=draft.id, client_key=key).one()
    if draft.bar_id or existing.removed:
        raise APIError.conflict("Upload no longer editable")
    try:
        s3_client.put_object(Bucket=os.environ["AWS_S3_BUCKET"], Key=existing.object_key, Body=content, ContentType=mime)
    except Exception as exc:
        existing.status = "failed"
        db.commit()
        raise APIError.server_error("Image upload failed; retry the same upload") from exc
    existing.status = "saved"
    draft.version += 1
    draft.updated_at = datetime.utcnow()
    db.commit()
    return draft
