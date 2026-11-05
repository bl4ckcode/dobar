from datetime import datetime
import pytest
from unittest.mock import AsyncMock
from app.payment import routes
from app.auth.rbac_models import UserProfile
from app.bars_and_restaurants.models.relational_models import UserDocument
from conftest import test_database


@pytest.fixture(autouse=True)
async def card_provider(monkeypatch, test_user_in_db):
    monkeypatch.setattr(routes, "database", test_database)
    await test_database.execute(UserProfile.__table__.insert().values(user_id=test_user_in_db["id"], display_name="Test Customer"))
    await test_database.execute(UserDocument.__table__.insert().values(user_id=test_user_in_db["id"], type="cpf", number="52998224725"))
    async def save_card(user_id, token, customer, key):
        return {"card_id": token.replace("token_", "card_"), "customer_id": "cus_test", "brand": "Visa",
                "last_four": "4242", "exp_month": 12, "exp_year": 2030}
    provider = AsyncMock()
    provider.save_card.side_effect = save_card
    monkeypatch.setattr(routes, "get_dpe_client", lambda: provider)
    return provider


@pytest.mark.asyncio
async def test_add_card_success(client, auth_headers):
    card_data = {
        "card_token": "token_add_1",
        "last_four": "4242",
        "brand": "Visa",
        "exp_month": 12,
        "exp_year": 2029,
        "is_default": 1
    }
    response = await client.post("/me/cards", json=card_data, headers=auth_headers)
    assert response.status_code == 201
    data = response.json()
    assert data["card_token"] == card_data["card_token"].replace("token_", "card_")
    assert data["is_usable"] is True
    assert data["last_four"] == card_data["last_four"]
    assert data["is_default"] == 1
    assert "id" in data

@pytest.mark.asyncio
async def test_add_duplicate_card(client, auth_headers):
    card_data = {
        "card_token": "token_duplicate",
        "last_four": "1111",
        "brand": "MasterCard",
        "exp_month": 1,
        "exp_year": 2030,
        "is_default": 1
    }
    # Initial card creation
    await client.post("/me/cards", json=card_data, headers=auth_headers)

    # Attempt to create duplicate
    card_data["is_default"] = 0
    response = await client.post("/me/cards", json=card_data, headers=auth_headers)
    assert response.status_code == 201
    assert len((await client.get("/me/cards", headers=auth_headers)).json()) == 1

@pytest.mark.asyncio
async def test_get_cards(client, auth_headers):
    # Setup some cards
    await client.post("/me/cards", json={
        "card_token": "token_get_1",
        "last_four": "1234",
        "brand": "Visa",
        "exp_month": 1,
        "exp_year": 2030,
        "is_default": 0
    }, headers=auth_headers)
    
    await client.post("/me/cards", json={
        "card_token": "token_get_2",
        "last_four": "5678",
        "brand": "MasterCard",
        "exp_month": 2,
        "exp_year": 2031,
        "is_default": 1
    }, headers=auth_headers)

    response = await client.get("/me/cards", headers=auth_headers)
    assert response.status_code == 200
    data = response.json()
    
    tokens = [c["card_token"] for c in data]
    assert "card_get_1" in tokens
    assert "card_get_2" in tokens
    
    # Ensure one default card
    defaults = [c for c in data if c["is_default"]]
    assert len(defaults) == 1
    assert defaults[0]["card_token"] == "card_get_2"

@pytest.mark.asyncio
async def test_delete_card(client, auth_headers):
    # Setup card
    res = await client.post("/me/cards", json={
        "card_token": "token_del_1",
        "last_four": "9999",
        "brand": "Amex",
        "exp_month": 3,
        "exp_year": 2028,
        "is_default": 0
    }, headers=auth_headers)
    card_id = res.json()["id"]

    # Delete card
    response = await client.delete(f"/me/cards/{card_id}", headers=auth_headers)
    assert response.status_code == 204

    # Verify deleted by listing cards
    list_res = await client.get("/me/cards", headers=auth_headers)
    tokens = [c["card_token"] for c in list_res.json()]
    assert "card_del_1" not in tokens

@pytest.mark.asyncio
async def test_delete_nonexistent_card(client, auth_headers):
    response = await client.delete("/me/cards/99999", headers=auth_headers)
    assert response.status_code == 404


@pytest.mark.asyncio
@pytest.mark.parametrize("token", ["", " ", "tok_179000000", "card_unowned"])
async def test_invalid_card_rejected_before_provider(client, auth_headers, card_provider, token):
    response = await client.post("/me/cards", json={"card_token": token, "last_four": "4242", "brand": "Visa",
        "exp_month": 12, "exp_year": 2030}, headers=auth_headers)
    assert response.status_code == 422
    card_provider.save_card.assert_not_called()


@pytest.mark.asyncio
async def test_legacy_card_requires_readding(client, auth_headers, test_user_in_db):
    from app.payment.models import PaymentCard
    await test_database.execute(PaymentCard.__table__.insert().values(user_id=test_user_in_db["id"],
        card_token="", last_four="1234", brand="Visa", exp_month=12, exp_year=2030, is_default=0, created_at=datetime.utcnow()))
    response = await client.get("/me/cards", headers=auth_headers)
    assert response.json()[0]["is_usable"] is False


@pytest.mark.asyncio
async def test_postgres_duplicate_preserves_previous_default(client, auth_headers, monkeypatch):
    from asyncpg.exceptions import UniqueViolationError
    from sqlalchemy.sql.dml import Insert
    data = {"card_token": "token_first", "last_four": "4242", "brand": "Visa", "exp_month": 12,
            "exp_year": 2030, "is_default": True}
    first = await client.post("/me/cards", json=data, headers=auth_headers)
    assert first.status_code == 201
    execute = test_database.execute
    async def duplicate_insert(query, *args, **kwargs):
        if isinstance(query, Insert) and query.table.name == "payment_cards":
            raise UniqueViolationError("duplicate reference")
        return await execute(query, *args, **kwargs)
    monkeypatch.setattr(test_database, "execute", duplicate_insert)
    response = await client.post("/me/cards", json={**data, "card_token": "token_second"}, headers=auth_headers)
    assert response.status_code == 409
    listed = (await client.get("/me/cards", headers=auth_headers)).json()
    assert len(listed) == 1
    assert listed[0]["is_default"] is True
