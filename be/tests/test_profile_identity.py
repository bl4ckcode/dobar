from unittest.mock import AsyncMock

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.auth import profile
from app.auth.rbac_middleware import AuthUser, get_current_user
from app.errors import APIError
from app.main import api_error_handler


@pytest.mark.asyncio
@pytest.mark.parametrize("user_id", [501, 502])
async def test_profile_serializes_authenticated_account_identity(monkeypatch, user_id):
    app = FastAPI()
    app.include_router(profile.profile_router)
    app.dependency_overrides[get_current_user] = lambda: AuthUser(
        id=user_id, email=None, phone_number=None, is_active=True, user_type="client"
    )
    monkeypatch.setattr(
        profile, "get_or_create_profile",
        AsyncMock(return_value={"id": 999, "user_id": user_id, "terms_accepted": True}),
    )
    monkeypatch.setattr(profile.database, "fetch_one", AsyncMock(return_value=None))
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/me/profile")
    assert response.status_code == 200
    assert response.json()["id"] == user_id


@pytest.mark.asyncio
async def test_profile_identity_requires_authentication():
    app = FastAPI()
    app.add_exception_handler(APIError, api_error_handler)
    app.include_router(profile.profile_router)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/me/profile")
    assert response.status_code == 401
