import pytest
from httpx import AsyncClient
from unittest.mock import AsyncMock, patch


class TestFcmTokenEndpoint:

    @pytest.mark.asyncio
    async def test_update_fcm_token_success(self, auth_client):
        client, headers, user = auth_client
        response = await client.put(
            "/me/fcm-token",
            json={"token": "test_fcm_token_abc123", "platform": "android"},
            headers=headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["message"] == "FCM token updated"

    @pytest.mark.asyncio
    async def test_update_fcm_token_ios(self, auth_client):
        client, headers, user = auth_client
        response = await client.put(
            "/me/fcm-token",
            json={"token": "apns_device_token_xyz", "platform": "ios"},
            headers=headers,
        )
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_update_fcm_token_requires_auth(self, client: AsyncClient):
        response = await client.put(
            "/me/fcm-token",
            json={"token": "some_token"},
        )
        assert response.status_code in (401, 403)

    @pytest.mark.asyncio
    async def test_update_fcm_token_persisted(self, auth_client):
        client, headers, user = auth_client
        from app.database import database
        from app.auth.rbac_models import UserProfile

        await client.put(
            "/me/fcm-token",
            json={"token": "persisted_token_999", "platform": "android"},
            headers=headers,
        )
        profile = await database.fetch_one(
            UserProfile.__table__.select().where(UserProfile.user_id == user["id"])
        )
        assert profile["fcm_token"] == "persisted_token_999"
        assert profile["fcm_token_updated_at"] is not None


class TestPushNotificationWiring:

    @pytest.mark.asyncio
    async def test_push_sent_on_new_order(self):
        from app.order_worker import handle_order_created

        with patch(
            "app.order_worker.notify_new_order", new_callable=AsyncMock
        ) as mock_ws, patch(
            "app.order_worker._get_bar_owner_tokens", new_callable=AsyncMock, return_value=["tok1"]
        ), patch(
            "app.order_worker.notify_new_order_push", new_callable=AsyncMock
        ) as mock_push:
            await handle_order_created(42, {"bar_id": 1, "total_price": 99.0})
            mock_ws.assert_awaited_once()
            mock_push.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_push_skipped_when_no_tokens(self):
        from app.order_worker import handle_order_created

        with patch(
            "app.order_worker.notify_new_order", new_callable=AsyncMock
        ), patch(
            "app.order_worker._get_bar_owner_tokens", new_callable=AsyncMock, return_value=[]
        ), patch(
            "app.order_worker.notify_new_order_push", new_callable=AsyncMock
        ) as mock_push:
            await handle_order_created(42, {"bar_id": 1, "total_price": 50.0})
            mock_push.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_push_sent_on_status_change(self):
        from app.order_worker import handle_status_change

        with patch(
            "app.order_worker.notify_order_status_change", new_callable=AsyncMock
        ) as mock_ws, patch(
            "app.order_worker._get_order_user_token", new_callable=AsyncMock, return_value="user_tok"
        ), patch(
            "app.order_worker.notify_order_status_push", new_callable=AsyncMock
        ) as mock_push:
            await handle_status_change(7, {"bar_id": 1, "new_status": "ready"})
            mock_ws.assert_awaited_once()
            mock_push.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_push_sent_on_cancellation(self):
        from app.order_worker import handle_order_cancelled

        with patch(
            "app.order_worker.notify_order_status_change", new_callable=AsyncMock
        ), patch(
            "app.order_worker._get_order_user_token", new_callable=AsyncMock, return_value="user_tok"
        ), patch(
            "app.order_worker.notify_order_status_push", new_callable=AsyncMock
        ) as mock_push:
            await handle_order_cancelled(8, {"bar_id": 1})
            mock_push.assert_awaited_once()
