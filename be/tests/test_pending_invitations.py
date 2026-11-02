from datetime import datetime, timedelta
from unittest.mock import AsyncMock

import pytest
from app.auth.rbac_middleware import AuthUser, get_current_user
from app.bars_and_restaurants.routes import staff
from app.main import app


def recipient(**changes):
    return AuthUser(**dict(id=9001, email="staff@example.com", phone_number="+55 31 99999-0000",
                           is_active=True, user_type="client", email_verified=True, phone_verified=True, **changes))


def invitation(**changes):
    return dict(id=1, bar_id=42, email=" STAFF@example.com ", phone=None, role="cashier",
                status="pending", invitation_code="CaseSensitive_Token_123",
                expires_at=datetime.utcnow() + timedelta(days=1)) | changes


@pytest.mark.asyncio
async def test_discovery_filters_lifecycle_contact_and_masks_results(monkeypatch):
    pending = invitation()
    rows = [pending, invitation(id=2, status="accepted"), invitation(id=3, status="revoked"),
            invitation(id=4, expires_at=datetime.utcnow() - timedelta(days=1)),
            invitation(id=5, email="other@example.com"), invitation(id=6, email=None, phone=None),
            invitation(id=7, email=None, phone="+55 (31) 99999-0000")]
    database = AsyncMock()
    database.fetch_all.return_value = rows
    database.fetch_one.return_value = dict(id=42, name="Bar Teste", address="BH")
    monkeypatch.setattr(staff, "database", database)
    result = await staff.get_pending_invitations(recipient())
    assert [row.invitation_id for row in result] == [1, 7]
    assert result[0].invitation_code == pending["invitation_code"]
    assert result[0].masked_recipient != pending["email"]
    assert result[0].venue_name == "Bar Teste"
    assert "order:process" in result[0].permissions
    database.execute.assert_not_called()


@pytest.mark.asyncio
async def test_unverified_contacts_are_not_discovered(monkeypatch):
    database = AsyncMock()
    monkeypatch.setattr(staff, "database", database)
    user = recipient()
    user.email_verified = False
    user.phone_verified = False
    assert await staff.get_pending_invitations(user) == []
    database.fetch_all.assert_not_called()


@pytest.mark.asyncio
async def test_verified_other_contact_does_not_bypass_recipient_verification(monkeypatch):
    database = AsyncMock()
    database.fetch_all.return_value = [invitation(phone="+5531999990000")]
    monkeypatch.setattr(staff, "database", database)
    user = recipient()
    user.phone_verified = False
    assert await staff.get_pending_invitations(user) == []
    database.fetch_one.assert_not_called()


@pytest.mark.asyncio
async def test_discovery_failure_is_not_empty_list(monkeypatch):
    database = AsyncMock()
    database.fetch_all.side_effect = RuntimeError("database unavailable")
    monkeypatch.setattr(staff, "database", database)
    with pytest.raises(RuntimeError):
        await staff.get_pending_invitations(recipient())


@pytest.mark.asyncio
async def test_authenticated_http_contract_and_preview_rechecks(client, monkeypatch):
    user = recipient()
    app.dependency_overrides[get_current_user] = lambda: user
    database = AsyncMock()
    database.fetch_all.return_value = [invitation()]
    database.fetch_one.side_effect = [dict(id=42, name="Bar Teste"), invitation(email="other@example.com")]
    monkeypatch.setattr(staff, "database", database)
    try:
        response = await client.get('/me/bars/invitations/pending')
        assert response.status_code == 200
        assert response.json()[0]['bar_id'] == 42
        response = await client.post('/me/bars/invitations/preview', json={
            'invitation_code': response.json()[0]['invitation_code']})
        assert response.status_code == 403
        assert response.json()['error_code'] == 'INVITATION_CONTACT_MISMATCH'
        database.execute.assert_not_called()
    finally:
        app.dependency_overrides.pop(get_current_user, None)


@pytest.mark.asyncio
async def test_discovery_requires_authentication(client):
    response = await client.get('/me/bars/invitations/pending')
    assert response.status_code in (401, 403)


def test_malformed_phone_does_not_match():
    user = recipient()
    user.phone_number = 'invalid'
    assert not staff._recipient_matches(invitation(email=None, phone='invalid'), user)


@pytest.mark.asyncio
async def test_real_postgres_discovery_and_explicit_acceptance(monkeypatch):
    import os
    from uuid import uuid4
    from databases import Database
    from sqlalchemy import create_engine, text
    from app.database import Base
    from app.auth.auth_models import User
    from app.auth.rbac_models import StaffInvitation, BarStaff
    from app.bars_and_restaurants.models.relational_models import Bar
    from app.auth import rbac_middleware

    url = os.environ.get('ENTRY_TEST_DATABASE_URL')
    if not url:
        pytest.skip('ENTRY_TEST_DATABASE_URL is required for real PostgreSQL evidence')
    schema = 'entry_' + uuid4().hex
    admin = create_engine(url)
    with admin.begin() as connection:
        connection.execute(text(f'CREATE SCHEMA "{schema}"'))
    engine = create_engine(url, connect_args={'options': f'-csearch_path={schema}'})
    database = Database(url, server_settings={'search_path': schema})
    try:
        Base.metadata.create_all(engine)
        with engine.begin() as connection:
            connection.execute(User.__table__.insert().values(id=9001, email='staff@example.com'))
            connection.execute(Bar.__table__.insert().values(id=42, name='Bar Teste'))
            rows = [invitation(), invitation(id=2, email=None, phone='+55 (31) 99999-0000'),
                    invitation(id=3, status='revoked'), invitation(id=4, status='accepted'),
                    invitation(id=5, expires_at=datetime.utcnow() - timedelta(days=1)),
                    invitation(id=6, email='other@example.com')]
            for row in rows:
                row['invitation_code'] = f"CaseSensitive_Token_{row['id']}"
                connection.execute(StaffInvitation.__table__.insert().values(**row))
        await database.connect()
        monkeypatch.setattr(staff, 'database', database)
        monkeypatch.setattr(rbac_middleware, 'database', database)
        user = recipient()
        pending = await staff.get_pending_invitations(user)
        assert [item.invitation_id for item in pending] == [1, 2]
        assert await database.fetch_val('SELECT count(*) FROM bar_staff') == 0
        preview = await staff.preview_invitation(staff.InvitationCodeRequest(invitation_code=pending[0].invitation_code), user)
        assert preview.venue_name == 'Bar Teste'
        accepted = await staff.accept_invitation(
            payload=staff.InvitationCodeRequest(invitation_code=pending[0].invitation_code),
            invitation_code=None, user=user)
        assert accepted.bar_id == 42
        replay = await staff.accept_invitation(
            payload=staff.InvitationCodeRequest(invitation_code=pending[0].invitation_code),
            invitation_code=None, user=user)
        assert replay.bar_id == 42
        assert await database.fetch_val('SELECT count(*) FROM bar_staff') == 1
        assert [item.invitation_id for item in await staff.get_pending_invitations(user)] == [2]
        user.email_verified = False
        assert [item.invitation_id for item in await staff.get_pending_invitations(user)] == [2]
        import asyncio
        phone_payload = staff.InvitationCodeRequest(invitation_code="CaseSensitive_Token_2")
        concurrent = await asyncio.gather(*[
            staff.accept_invitation(payload=phone_payload, invitation_code=None, user=user)
            for _ in range(2)
        ])
        assert [item.bar_id for item in concurrent] == [42, 42]
        assert await database.fetch_val('SELECT count(*) FROM bar_staff') == 1
        assert await staff.get_pending_invitations(user) == []
        user.phone_verified = False
        assert await staff.get_pending_invitations(user) == []
    finally:
        if database.is_connected:
            await database.disconnect()
        engine.dispose()
        with admin.begin() as connection:
            connection.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
        admin.dispose()


def test_access_logging_redacts_legacy_invitation_query():
    import logging
    from app.logging_redaction import InvitationAccessLogFilter
    record = logging.LogRecord('uvicorn.access', logging.INFO, '', 1,
        '%s - "%s %s HTTP/%s" %d',
        ('127.0.0.1', 'POST', '/me/bars/accept-invitation?invitation_code=SecretToken&email=staff@example.com', '1.1', 200), None)
    assert InvitationAccessLogFilter().filter(record)
    message = record.getMessage()
    assert 'SecretToken' not in message
    assert 'staff@example.com' not in message
    assert '/me/bars/accept-invitation?[REDACTED]' in message
