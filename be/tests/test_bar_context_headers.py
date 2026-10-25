"""
Tests for the front-end bar context headers (X-Bar-*).

These headers are emitted by the RBAC dependencies (require_bar_role /
require_bar_permission) on every bar-scoped business endpoint so the
front-end can decide what to show/hide based on the active bar's role and
permissions.
"""
import pytest
from datetime import datetime, timezone

from app.database import database
from app.auth.rbac_models import Permission, BarRole, BarStaff


@pytest.mark.asyncio
class TestBarContextHeaders:
    async def _create_user(self, email_suffix: str) -> dict:
        from app.auth.auth_models import User

        user_data = {
            "firebase_uid": f"fb_{email_suffix}",
            "phone_number": f"+1500000{abs(hash(email_suffix)) % 100000:05d}",
            "email": f"{email_suffix}@test.com",
            "is_active": True,
            "email_verified": False,
            "phone_verified": False,
        }
        user_id = await database.execute(User.__table__.insert().values(**user_data))
        return {"id": user_id, **user_data}

    async def test_owner_gets_bar_headers_on_ads_view(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]

        await database.execute(
            BarStaff.__table__.insert().values(
                user_id=user["id"],
                bar_id=bar_id,
                role=BarRole.OWNER.value,
                is_active=True,
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc),
            )
        )

        response = await client.get(
            f"/advertising/campaigns?bar_id={bar_id}", headers=headers
        )

        assert response.status_code == 200
        assert response.headers.get("x-bar-id") == str(bar_id)
        assert response.headers.get("x-bar-role") == BarRole.OWNER.value
        permissions = response.headers.get("x-bar-permissions", "")
        assert Permission.ADS_VIEW.value in permissions
        assert Permission.ADS_MANAGE.value in permissions

    async def test_bar_id_can_come_from_header(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]

        await database.execute(
            BarStaff.__table__.insert().values(
                user_id=user["id"],
                bar_id=bar_id,
                role=BarRole.OWNER.value,
                is_active=True,
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc),
            )
        )

        # No ?bar_id query param — bar_id is resolved from X-Bar-Id header.
        response = await client.get(
            "/advertising/campaigns",
            headers={**headers, "X-Bar-Id": str(bar_id)},
        )

        assert response.status_code == 200
        assert response.headers.get("x-bar-id") == str(bar_id)

    async def test_unauthorized_raises_forbidden(self, client, test_bar_in_db):
        # Fresh user with NO role at the bar.
        user = await self._create_user("outsider")
        from conftest import create_test_token

        token = create_test_token(user["id"])
        headers = {"Authorization": f"Bearer {token}"}
        bar_id = test_bar_in_db["id"]

        response = await client.get(
            f"/advertising/campaigns?bar_id={bar_id}", headers=headers
        )

        assert response.status_code == 403

    async def test_staff_without_ads_permission_gets_403(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]

        # 'staff' role has no ADS_VIEW / ADS_MANAGE permissions.
        await database.execute(
            BarStaff.__table__.insert().values(
                user_id=user["id"],
                bar_id=bar_id,
                role=BarRole.STAFF.value,
                is_active=True,
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc),
            )
        )

        get_resp = await client.get(
            f"/advertising/campaigns?bar_id={bar_id}", headers=headers
        )
        assert get_resp.status_code == 403

        post_resp = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}",
            json={
                "name": "x",
                "campaign_type": "featured",
                "budget_type": "hourly",
                "budget_amount": 10.0,
            },
            headers=headers,
        )
        assert post_resp.status_code == 403