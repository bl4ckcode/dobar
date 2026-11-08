import json
import math
import os
from datetime import datetime, timedelta, timezone
from sqlalchemy import and_
from app.database import database
from app.auth.auth_models import User
from app.errors import APIError
from .venue_location import geocode_address, valid_coordinates
from ..models.checkin import Checkin
from ..models.relational_models import Bar, Order


def utc_naive(value):
    if value.tzinfo is not None:
        return value.astimezone(timezone.utc).replace(tzinfo=None)
    return value


def distance_meters(latitude, longitude, bar_latitude, bar_longitude):
    lat1, lat2 = math.radians(latitude), math.radians(bar_latitude)
    dlat = lat2 - lat1
    dlng = math.radians(bar_longitude - longitude)
    a = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng / 2) ** 2
    return 6371000 * 2 * math.asin(min(1, math.sqrt(a)))


def validate_location(bar, table_number):
    value = (table_number or "").strip()
    if not value:
        return None
    method = bar.location_method or "table_number"
    if method == "table_number" and (not value.isdigit() or int(value) <= 0):
        raise APIError.validation_error("Informe uma mesa válida", details={"table_number": ["invalid"]})
    if method == "spot_list":
        spots = bar.location_spots or []
        if isinstance(spots, str):
            try:
                spots = json.loads(spots)
            except (ValueError, TypeError):
                spots = []
        if not any(str(spot.get("id")) == value for spot in spots if isinstance(spot, dict)):
            raise APIError.validation_error("Local indisponível", details={"table_number": ["invalid"]})
    return value


def current(db, user_id, now=None):
    now = now or datetime.utcnow()
    return db.query(Checkin).filter(
        Checkin.user_id == user_id, Checkin.status == "active", Checkin.expires_at > now
    ).first()


def serialize(db, checkin):
    if checkin is None:
        return None
    bar = db.get(Bar, checkin.bar_id)
    if bar is None:
        return None
    return {
        "id": checkin.id, "user_id": checkin.user_id, "bar_id": checkin.bar_id,
        "bar_name": bar.name or "", "bar_image_url": bar.logo_url or bar.cover_url,
        "table_number": checkin.table_number, "status": checkin.status,
        "checked_in_at": checkin.checked_in_at.replace(tzinfo=timezone.utc),
        "expires_at": checkin.expires_at.replace(tzinfo=timezone.utc),
        "checked_out_at": checkin.checked_out_at.replace(tzinfo=timezone.utc) if checkin.checked_out_at else None,
        "distance_meters": checkin.distance_meters,
    }


def create(db, user_id, data, now=None, mongodb_coordinates=None):
    now = now or datetime.utcnow()
    measured_at = utc_naive(data.measured_at)
    age = (now - measured_at).total_seconds()
    if age < -15 or age > 120:
        raise APIError.validation_error("Atualize sua localização para fazer check-in", details={"measured_at": ["stale"]})
    db.query(User).filter(User.id == user_id).with_for_update().one()
    bar = db.query(Bar).filter(Bar.id == data.bar_id).with_for_update().first()
    if bar is None:
        raise APIError.partner_not_found("Bar não encontrado")
    if not valid_coordinates(bar.latitude, bar.longitude):
        coordinates = mongodb_coordinates or geocode_address(bar.address, bar.country_code)
        if coordinates is None:
            raise APIError.validation_error("Não foi possível localizar o endereço do bar. Tente novamente mais tarde", details={"bar_id": ["location_unavailable"]})
        bar.latitude, bar.longitude = coordinates
    distance = distance_meters(data.latitude, data.longitude, bar.latitude, bar.longitude)
    if distance >= 10:
        raise APIError.validation_error("Aproxime-se do bar para fazer check-in", details={"location": ["outside_checkin_radius"]})
    table = validate_location(bar, data.table_number)
    if table and (bar.location_method or "table_number") == "spot_list":
        occupied = db.query(Order.id).filter(
            Order.bar_id == bar.id, Order.location_identifier == table,
            Order.status.in_(["pending", "confirmed", "preparing", "ready"]),
            Order.user_id != user_id,
        ).first()
        occupied_checkin = db.query(Checkin.id).filter(
            Checkin.bar_id == bar.id, Checkin.table_number == table,
            Checkin.status == "active", Checkin.expires_at > now, Checkin.user_id != user_id,
        ).first()
        if occupied or occupied_checkin:
            raise APIError.conflict("Este local está ocupado. Selecione outro local")
    checkin = db.query(Checkin).filter(Checkin.user_id == user_id).first()
    if checkin is None:
        checkin = Checkin(user_id=user_id)
        db.add(checkin)
    checkin.bar_id = bar.id
    checkin.table_number = table
    checkin.status = "active"
    checkin.latitude = data.latitude
    checkin.longitude = data.longitude
    checkin.distance_meters = distance
    checkin.measured_at = measured_at
    checkin.checked_in_at = now
    checkin.expires_at = now + timedelta(hours=max(1, int(os.getenv("CHECKIN_TTL_HOURS", "12"))))
    checkin.checked_out_at = None
    db.commit()
    db.refresh(checkin)
    return checkin


def end(db, user_id):
    db.query(User).filter(User.id == user_id).with_for_update().one()
    checkin = db.query(Checkin).filter(Checkin.user_id == user_id).first()
    if checkin is not None:
        checkin.status = "completed"
        checkin.checked_out_at = datetime.utcnow()
    db.commit()


async def require_active_checkin(user_id, bar_id, location_identifier=None):
    row = await database.fetch_one(Checkin.__table__.select().where(and_(
        Checkin.user_id == user_id, Checkin.bar_id == bar_id,
        Checkin.status == "active", Checkin.expires_at > datetime.utcnow(),
    )))
    if row is None:
        raise APIError.validation_error("Faça check-in neste bar antes de pedir", details={"checkin": ["required"]})
    checkin = dict(row)
    if location_identifier and checkin["table_number"] and location_identifier != checkin["table_number"]:
        raise APIError.validation_error("Confirme o local do seu check-in", details={"location_identifier": ["checkin_mismatch"]})
    if not checkin["table_number"] and not (location_identifier or "").strip():
        raise APIError.validation_error("Informe sua mesa ou local de entrega", details={"location_identifier": ["required"]})
    bar_row = await database.fetch_one(Bar.__table__.select().where(Bar.id == bar_id))
    if bar_row is None:
        raise APIError.partner_not_found("Bar não encontrado")
    from types import SimpleNamespace
    validate_location(SimpleNamespace(**dict(bar_row)), location_identifier or checkin["table_number"])
    return checkin
