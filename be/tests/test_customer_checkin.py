import importlib.util
import math
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from uuid import uuid4
from unittest.mock import AsyncMock

import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

from app.database import Base
from app.auth.auth_models import User
from app.bars_and_restaurants.models.relational_models import Bar
from app.bars_and_restaurants.models.checkin import Checkin
from app.bars_and_restaurants.schemas.checkin import CheckinCreate
from app.bars_and_restaurants.services import checkin as service
from app.errors import APIError


NOW = datetime(2026, 11, 2, 15)


@pytest.fixture(params=["sqlite", "postgres"])
def checkin_storage(request, tmp_path):
    schema = None
    if request.param == "postgres":
        url = os.environ.get("CHECKIN_TEST_DATABASE_URL")
        if not url:
            pytest.skip("CHECKIN_TEST_DATABASE_URL required for PostgreSQL verification")
        admin = create_engine(url)
        schema = "checkin_" + uuid4().hex
        with admin.begin() as connection:
            connection.execute(text(f'CREATE SCHEMA "{schema}"'))
        engine = create_engine(url, connect_args={"options": f"-csearch_path={schema}"})
    else:
        engine = create_engine(f"sqlite:///{tmp_path}/checkins.db", connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    with Session(engine) as db:
        db.add_all([User(id=501, email="first@example.com"), User(id=502, email="second@example.com")])
        db.add_all([
            Bar(id=601, name="Primeiro", latitude=0, longitude=0),
            Bar(id=602, name="Segundo", latitude=0, longitude=0, location_method="spot_list", location_spots=[{"id": "vip", "name": "VIP"}]),
        ])
        db.commit()
    yield engine
    engine.dispose()
    if schema:
        with admin.begin() as connection:
            connection.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
        admin.dispose()


def sample(distance=9, **changes):
    return CheckinCreate(**({
        "bar_id": 601, "latitude": math.degrees(distance / 6371000), "longitude": 0,
        "measured_at": NOW.replace(tzinfo=timezone.utc), "table_number": "5",
    } | changes))


@pytest.mark.parametrize("distance,allowed", [(9, True), (10, False), (11, False)])
def test_strict_radius_is_enforced(checkin_storage, distance, allowed):
    with Session(checkin_storage) as db:
        if allowed:
            record = service.create(db, 501, sample(distance), now=NOW)
            assert record.user_id == 501
            assert record.distance_meters == pytest.approx(9)
        else:
            with pytest.raises(APIError) as caught:
                service.create(db, 501, sample(distance), now=NOW)
            assert caught.value.details == {"location": ["outside_checkin_radius"]}
            assert db.query(Checkin).count() == 0


@pytest.mark.parametrize("seconds", [-121, 16])
def test_stale_or_future_position_cannot_check_in(checkin_storage, seconds):
    with Session(checkin_storage) as db:
        with pytest.raises(APIError):
            service.create(db, 501, sample(measured_at=NOW + timedelta(seconds=seconds)), now=NOW)
        assert service.current(db, 501, now=NOW) is None


def test_resume_is_user_scoped_expires_and_checkout_ends_session(checkin_storage):
    with Session(checkin_storage) as db:
        record = service.create(db, 501, sample(), now=NOW)
        identifier = record.id
    with Session(checkin_storage) as db:
        assert service.current(db, 502, now=NOW) is None
        resumed = service.current(db, 501, now=NOW)
        assert resumed.id == identifier
        assert service.serialize(db, resumed)["table_number"] == "5"
        assert service.current(db, 501, now=resumed.expires_at) is None
        service.end(db, 501)
        assert service.current(db, 501, now=NOW) is None


def test_invalid_or_occupied_spot_is_rejected(checkin_storage):
    with Session(checkin_storage) as db:
        with pytest.raises(APIError):
            service.create(db, 501, sample(bar_id=602, table_number="unknown"), now=NOW)
        db.rollback()
        service.create(db, 501, sample(bar_id=602, table_number="vip"), now=NOW)
        with pytest.raises(APIError) as caught:
            service.create(db, 502, sample(bar_id=602, table_number="vip"), now=NOW)
        assert caught.value.status_code == 409


def test_new_confirmation_replaces_previous_venue_session(checkin_storage):
    with Session(checkin_storage) as db:
        service.create(db, 501, sample(), now=NOW)
        service.create(db, 501, sample(bar_id=602, table_number="vip"), now=NOW)
        assert db.query(Checkin).filter_by(user_id=501).count() == 1
        assert service.current(db, 501, now=NOW).bar_id == 602


@pytest.mark.asyncio
async def test_order_guard_rejects_absent_wrong_venue_and_mismatched_table(monkeypatch):
    database = AsyncMock()
    monkeypatch.setattr(service, "database", database)
    database.fetch_one.return_value = None
    with pytest.raises(APIError) as caught:
        await service.require_active_checkin(501, 601)
    assert caught.value.details == {"checkin": ["required"]}
    database.fetch_one.return_value = {"id": 1, "table_number": "5"}
    with pytest.raises(APIError) as caught:
        await service.require_active_checkin(501, 601, "6")
    assert caught.value.details == {"location_identifier": ["checkin_mismatch"]}


def test_postgres_concurrent_confirmations_keep_one_session(checkin_storage):
    if checkin_storage.dialect.name != "postgresql":
        pytest.skip("PostgreSQL row-lock evidence required")

    def confirm():
        with Session(checkin_storage) as db:
            return service.create(db, 501, sample(), now=NOW).id

    with ThreadPoolExecutor(max_workers=2) as workers:
        identifiers = list(workers.map(lambda _: confirm(), range(2)))
    assert identifiers[0] == identifiers[1]


def test_additive_checkin_migration_preserves_existing_venue(checkin_storage):
    path = os.path.join(os.path.dirname(__file__), "../migrations/versions/c05_customer_checkins.py")
    spec = importlib.util.spec_from_file_location("checkin_migration", path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    with checkin_storage.begin() as connection:
        Checkin.__table__.drop(connection)
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()
        assert connection.execute(text("SELECT name FROM bars WHERE id = 601")).scalar() == "Primeiro"
        with Operations.context(MigrationContext.configure(connection)):
            migration.downgrade()
            migration.upgrade()


@pytest.mark.asyncio
async def test_authenticated_http_confirmation_resume_and_end(checkin_storage):
    from fastapi import FastAPI
    from httpx import AsyncClient, ASGITransport
    from app.auth.rbac_middleware import get_current_user
    from app.database import get_db
    from app.bars_and_restaurants.routes.checkin import checkin_router
    from types import SimpleNamespace

    application = FastAPI()
    from app.main import api_error_handler
    application.add_exception_handler(APIError, api_error_handler)
    application.include_router(checkin_router)
    with Session(checkin_storage) as db:
        application.dependency_overrides[get_db] = lambda: db
        transport = ASGITransport(app=application)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            denied = await client.get("/checkins/active")
            assert denied.status_code == 401
            application.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=501)
            payload = sample(measured_at=datetime.now(timezone.utc)).model_dump(mode="json")
            confirmed = await client.post("/checkins", json=payload)
            assert confirmed.status_code == 200
            assert confirmed.json()["user_id"] == 501
            assert confirmed.json()["table_number"] == "5"
            resumed = await client.get("/checkins/active")
            assert resumed.json()["id"] == confirmed.json()["id"]
            application.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=502)
            assert (await client.get("/checkins/active")).json() is None
            await client.delete("/checkins/active")
            application.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=501)
            assert (await client.get("/checkins/active")).json() is not None
            ended = await client.delete("/checkins/active")
            assert ended.status_code == 204
            assert (await client.get("/checkins/active")).json() is None


@pytest.mark.parametrize("distance,allowed", [(9, True), (11, False)])
def test_address_only_venue_resolves_before_distance_check(checkin_storage, monkeypatch, distance, allowed):
    from unittest.mock import Mock
    resolve = Mock(return_value=(0.0, 0.0))
    monkeypatch.setattr(service, "geocode_address", resolve)
    address = "R. Fernandes Tourinho, 241 - Funcionários, Belo Horizonte - MG, Brasil"
    with Session(checkin_storage) as db:
        bar = db.get(Bar, 601)
        bar.address, bar.country_code = address, "BR"
        bar.latitude = bar.longitude = None
        db.commit()
        if allowed:
            record = service.create(db, 501, sample(distance), now=NOW)
            assert record.distance_meters == pytest.approx(distance)
            db.expire_all()
            assert (db.get(Bar, 601).latitude, db.get(Bar, 601).longitude) == (0, 0)
        else:
            with pytest.raises(APIError) as caught:
                service.create(db, 501, sample(distance), now=NOW)
            assert caught.value.details == {"location": ["outside_checkin_radius"]}
            assert db.query(Checkin).count() == 0
        resolve.assert_called_once_with(address, "BR")


def test_unresolvable_address_cannot_use_customer_coordinates(checkin_storage, monkeypatch):
    monkeypatch.setattr(service, "geocode_address", lambda *args: None)
    with Session(checkin_storage) as db:
        bar = db.get(Bar, 601)
        bar.latitude = bar.longitude = None
        db.commit()
        with pytest.raises(APIError) as caught:
            service.create(db, 501, sample(), now=NOW)
        assert caught.value.details == {"bar_id": ["location_unavailable"]}
        assert db.query(Checkin).count() == 0


def test_configured_coordinates_do_not_call_geocoding(checkin_storage, monkeypatch):
    from unittest.mock import Mock
    resolve = Mock(side_effect=AssertionError("Unexpected provider call"))
    monkeypatch.setattr(service, "geocode_address", resolve)
    with Session(checkin_storage) as db:
        service.create(db, 501, sample(), now=NOW)
    resolve.assert_not_called()
