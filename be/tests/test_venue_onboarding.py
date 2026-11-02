import importlib.util
import io
import os
from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4
from unittest.mock import AsyncMock, patch
import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session
from fastapi import UploadFile
from starlette.datastructures import Headers
from app.database import Base, get_db
from app.main import app
from app.auth.auth_models import User
from app.auth.middleware import get_current_active_user
from app.auth.rbac_middleware import AuthUser
from app.auth.rbac_models import BarStaff
from app.bars_and_restaurants.models.relational_models import Bar
from app.bars_and_restaurants.models.bank_account import BarBankAccount
from app.bars_and_restaurants.models.onboarding import OnboardingAsset, OnboardingProjection
from app.bars_and_restaurants.schemas.onboarding import DraftPatch, DraftFinalize
from app.bars_and_restaurants.schemas.bars import Bar as BarResponse
from app.bars_and_restaurants.services import onboarding as service
from app.bars_and_restaurants.services import bank_account_service as bank
from app.errors import APIError

OWNER = AuthUser(id=8001, email="owner@example.com", phone_number=None, is_active=True, user_type="business")
OTHER = AuthUser(id=8002, email="other@example.com", phone_number=None, is_active=True, user_type="business")
PAYLOAD = {"name": "Bar Teste", "address": "Rua Teste, 123, Belo Horizonte", "latitude": -19.92, "longitude": -43.94, "location_confirmed": True}


@pytest.fixture(params=["sqlite", "postgres"])
def storage(request, tmp_path):
    schema = None
    if request.param == "postgres":
        url = os.environ.get("B02_TEST_DATABASE_URL")
        if not url:
            pytest.skip("B02_TEST_DATABASE_URL is required for PostgreSQL evidence")
        admin = create_engine(url)
        schema = "b02_" + uuid4().hex
        with admin.begin() as conn:
            conn.execute(text(f'CREATE SCHEMA "{schema}"'))
        engine = create_engine(url, connect_args={"options": f"-csearch_path={schema}"})
    else:
        engine = create_engine(f"sqlite:///{tmp_path}/drafts.db", connect_args={"check_same_thread": False})
    Base.metadata.create_all(engine)
    with Session(engine) as db:
        db.add_all([User(id=OWNER.id, email=OWNER.email), User(id=OTHER.id, email=OTHER.email)])
        db.commit()
    yield engine
    engine.dispose()
    if schema:
        with admin.begin() as conn:
            conn.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
        admin.dispose()


@pytest.fixture
def db(storage):
    with Session(storage) as session:
        yield session


def ready(db):
    draft = service.create(db, OWNER, "creation_test_001")
    return service.patch(db, OWNER, draft.id, DraftPatch(version=draft.version, payload=PAYLOAD))


def test_partial_save_resume_skip_and_conflict(db):
    draft = service.create(db, OWNER, "creation_test_001")
    assert service.create(db, OWNER, "creation_test_001").id == draft.id
    assert db.query(Bar).count() == 0
    draft = service.patch(db, OWNER, draft.id, DraftPatch(version=1, payload={"name": "Partial", "email": "unfinished@"}))
    db.expire_all()
    assert service.owned(db, draft.id, OWNER).payload["email"] == "unfinished@"
    with pytest.raises(APIError):
        service.patch(db, OWNER, draft.id, DraftPatch(version=1))
    db.rollback()
    draft = service.patch(db, OWNER, draft.id, DraftPatch(version=2, payload=PAYLOAD | {"email": None}, steps={"receiving": "skipped", "photos": "skipped"}))
    assert service.next_step(draft) == "hours"
    assert db.query(BarStaff).count() == 0


def test_other_owner_cannot_read_write_or_finalize(db):
    draft = ready(db)
    for operation in [lambda: service.owned(db, draft.id, OTHER), lambda: service.patch(db, OTHER, draft.id, DraftPatch(version=2)), lambda: service.finalize(db, OTHER, draft.id, DraftFinalize(version=2, operation_key="finalize_test_001"))]:
        with pytest.raises(APIError) as caught:
            operation()
        assert caught.value.status_code == 404
        db.rollback()


def test_bank_fail_closed_and_masked_resume(db, monkeypatch):
    draft = ready(db)
    data = {"method": "pix", "pix_key": "123", "pix_key_type": "cnpj"}
    monkeypatch.setattr(bank, "ENCRYPTION_KEY", None)
    with pytest.raises(APIError):
        service.patch(db, OWNER, draft.id, DraftPatch(version=2, bank_account=data))
    db.rollback()
    monkeypatch.setattr(bank, "ENCRYPTION_KEY", "isolated-test-key")
    draft = service.patch(db, OWNER, draft.id, DraftPatch(version=2, bank_account=data))
    assert draft.bank_summary["complete"] is False
    assert service.next_step(draft) == "receiving"
    assert draft.bank_encrypted != "123"
    result = service.serialize(db, draft)
    assert "bank_encrypted" not in result and "bank_account" not in result
    with pytest.raises(APIError):
        service.finalize(db, OWNER, draft.id, DraftFinalize(version=3, operation_key="finalize_test_001"))
    db.rollback()
    draft = service.patch(db, OWNER, draft.id, DraftPatch(version=3, bank_account=None))
    assert draft.bank_summary is None


def test_optional_contact_and_replay_do_not_duplicate(db, monkeypatch):
    monkeypatch.setattr(bank, "ENCRYPTION_KEY", "isolated-test-key")
    draft = ready(db)
    draft = service.patch(db, OWNER, draft.id, DraftPatch(version=2, bank_account={"method": "pix", "pix_key": "owner@example.com", "pix_key_type": "email"}))
    request = DraftFinalize(version=3, operation_key="finalize_test_001")
    result = service.finalize(db, OWNER, draft.id, request)
    assert service.finalize(db, OWNER, draft.id, request).bar_id == result.bar_id
    assert db.query(Bar).count() == db.query(BarStaff).count() == db.query(BarBankAccount).count() == 1
    assert db.query(OnboardingProjection).count() == 1
    assert db.get(Bar, result.bar_id).email is None
    assert result.bank_encrypted is None
    account = db.query(BarBankAccount).one()
    assert account.is_verified is False and bank.decrypt_value(account.pix_key_encrypted) == "owner@example.com"
    legacy = BarResponse.model_validate({"id": result.bar_id, "name": "Bar", "address": "Rua", "phone_number": None, "email": None, "owner_id": OWNER.id})
    assert legacy.email == legacy.phone_number == ""
    with pytest.raises(APIError):
        service.finalize(db, OWNER, draft.id, DraftFinalize(version=3, operation_key="different_key_001"))


def test_invalid_identity_hours_and_coordinates(db):
    draft = ready(db)
    draft = service.patch(db, OWNER, draft.id, DraftPatch(version=2, payload={"latitude": 0, "longitude": 0, "operating_hours": {"monday": {"open": "20:00", "close": "20:00"}}}))
    with pytest.raises(APIError) as caught:
        service.finalize(db, OWNER, draft.id, DraftFinalize(version=3, operation_key="finalize_test_001"))
    assert caught.value.status_code == 422
    assert db.query(Bar).count() == 0


def image():
    return UploadFile(file=io.BytesIO(b"\x89PNG\r\n\x1a\n" + b"data" * 50), filename="logo.png", headers=Headers({"content-type": "image/png"}))


def test_upload_retry_and_owner_scope(db):
    draft = ready(db)
    with patch("app.bars_and_restaurants.services.image_upload.s3_client") as s3, patch.dict(os.environ, {"AWS_S3_BUCKET": "test-only"}):
        s3.put_object.side_effect = RuntimeError("storage unavailable")
        with pytest.raises(APIError):
            service.store_asset(db, OWNER, draft.id, image(), "asset_test_001", "logo")
        db.rollback()
        assert db.query(OnboardingAsset).one().status == "failed"
        s3.put_object.side_effect = None
        service.store_asset(db, OWNER, draft.id, image(), "asset_test_001", "logo")
        service.store_asset(db, OWNER, draft.id, image(), "asset_test_001", "logo")
        assert db.query(OnboardingAsset).count() == 1
        with pytest.raises(APIError):
            service.store_asset(db, OTHER, draft.id, image(), "asset_test_002", "logo")
        db.rollback()
        assert s3.put_object.call_count == 2


@pytest.mark.asyncio
async def test_http_owner_boundary_and_route_precedence(client, db):
    app.dependency_overrides[get_current_active_user] = lambda: OWNER
    app.dependency_overrides[get_db] = lambda: db
    try:
        created = await client.post("/bars/onboarding-drafts", json={"creation_key": "creation_http_001"})
        assert created.status_code == 200
        draft_id = created.json()["id"]
        assert (await client.get("/bars/onboarding-drafts")).status_code == 200
        app.dependency_overrides[get_current_active_user] = lambda: OTHER
        for method, path, payload in [("GET", f"/{draft_id}", None), ("PATCH", f"/{draft_id}", {"version": 1}), ("POST", f"/{draft_id}/finalize", {"version": 1, "operation_key": "finalize_http_001"}), ("DELETE", f"/{draft_id}/assets/missing", None)]:
            response = await client.request(method, "/bars/onboarding-drafts" + path, json=payload)
            assert response.status_code == 404
            assert response.json()["error_code"] == "NOT_FOUND"
    finally:
        app.dependency_overrides.pop(get_current_active_user, None)
        app.dependency_overrides.pop(get_db, None)


def test_postgres_concurrent_finalize_and_saves(storage):
    if storage.dialect.name != "postgresql":
        pytest.skip("Row locking needs PostgreSQL")
    with Session(storage) as db:
        draft_id = ready(db).id
    def finalize_once(_):
        with Session(storage) as db:
            return service.finalize(db, OWNER, draft_id, DraftFinalize(version=2, operation_key="concurrent_op_001")).bar_id
    with ThreadPoolExecutor(max_workers=2) as pool:
        ids = list(pool.map(finalize_once, range(2)))
    assert ids[0] == ids[1]
    with Session(storage) as db:
        assert db.query(Bar).count() == db.query(BarStaff).count() == 1
        second = service.create(db, OWNER, "creation_race_002").id
    def save_once(n):
        with Session(storage) as db:
            try:
                service.patch(db, OWNER, second, DraftPatch(version=1, payload={"name": str(n)}))
                return "saved"
            except APIError:
                return "conflict"
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(save_once, range(2))) == ["conflict", "saved"]


def test_migration_upgrade_and_downgrade(storage):
    if storage.dialect.name != "postgresql":
        pytest.skip("Migration evidence needs PostgreSQL")
    spec = importlib.util.spec_from_file_location("b02_migration", "migrations/versions/b02_venue_onboarding_drafts.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with storage.begin() as conn:
        module.op = Operations(MigrationContext.configure(conn))
        module.downgrade()
        module.upgrade()
        assert conn.execute(text("SELECT count(*) FROM venue_onboarding_drafts")).scalar() == 0


@pytest.mark.asyncio
async def test_projection_failure_retries_same_venue(db, storage, monkeypatch):
    from app.bars_and_restaurants.services import onboarding_projection as projection
    result = service.finalize(db, OWNER, ready(db).id, DraftFinalize(version=2, operation_key="projection_op_001"))
    monkeypatch.setattr(projection, "SessionLocal", lambda: Session(storage))
    collection = AsyncMock()
    monkeypatch.setattr(projection, "bars_collection", collection)
    collection.update_one.side_effect = RuntimeError("Mongo unavailable")
    await projection.project_pending()
    db.expire_all()
    assert db.get(OnboardingProjection, result.bar_id).completed_at is None
    collection.update_one.side_effect = None
    await projection.project_pending()
    db.expire_all()
    assert db.get(OnboardingProjection, result.bar_id).completed_at is not None
    assert db.query(Bar).count() == 1


@pytest.mark.asyncio
async def test_unauthenticated_drafts_are_rejected(client):
    response = await client.get("/bars/onboarding-drafts")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_all_menu_extraction_entries_require_membership(client, monkeypatch):
    from app.bars_and_restaurants.routes import menus
    monkeypatch.setattr(menus, "get_bar_by_id", AsyncMock(return_value={"id": 42}))
    monkeypatch.setattr(menus.database, "fetch_one", AsyncMock(return_value=None))
    app.dependency_overrides[get_current_active_user] = lambda: OWNER
    try:
        first = await client.post("/menus/extract", json={"bar_id": 42, "menu_url": "https://example.com/menu"})
        second = await client.post("/menus/extract-url", json={"bar_id": 42, "menu_url": "https://example.com/menu"})
        third = await client.post("/menus/extract", data={"bar_id": "42"}, files={"image": ("menu.png", b"test image", "image/png")})
        assert [first.status_code, second.status_code, third.status_code] == [403, 403, 403]
    finally:
        app.dependency_overrides.pop(get_current_active_user, None)


def test_bank_settings_use_authenticated_owner_id():
    from app.bars_and_restaurants.routes.bank_accounts import check_bar_ownership
    venue = Bar(owner_id=OWNER.id)
    check_bar_ownership(venue, OWNER)
    with pytest.raises(APIError):
        check_bar_ownership(venue, OTHER)


@pytest.mark.asyncio
@pytest.mark.parametrize("role,custom,allowed", [("manager", "[]", True), ("cashier", '["menu:edit"]', True), ("cashier", None, False)])
async def test_extraction_preserves_role_permissions_and_custom_grants(monkeypatch, role, custom, allowed):
    from datetime import datetime
    from app.bars_and_restaurants.routes import menus
    monkeypatch.setattr(menus.database, "fetch_one", AsyncMock(return_value={"role": role, "custom_permissions": custom, "accepted_at": datetime.utcnow()}))
    if allowed:
        await menus.authorize_menu_extraction(42, OWNER)
    else:
        with pytest.raises(APIError):
            await menus.authorize_menu_extraction(42, OWNER)
