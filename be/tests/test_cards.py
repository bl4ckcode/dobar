import pytest

@pytest.mark.asyncio
async def test_add_card_success(client, auth_headers):
    card_data = {
        "card_token": "tok_add_1",
        "last_four": "4242",
        "brand": "Visa",
        "exp_month": 12,
        "exp_year": 2029,
        "is_default": 1
    }
    response = await client.post("/me/cards", json=card_data, headers=auth_headers)
    assert response.status_code == 201
    data = response.json()
    assert data["card_token"] == card_data["card_token"]
    assert data["last_four"] == card_data["last_four"]
    assert data["is_default"] == 1
    assert "id" in data

@pytest.mark.asyncio
async def test_add_duplicate_card(client, auth_headers):
    card_data = {
        "card_token": "tok_duplicate",
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
    assert response.status_code == 409
    assert "added" in str(response.json()).lower()

@pytest.mark.asyncio
async def test_get_cards(client, auth_headers):
    # Setup some cards
    await client.post("/me/cards", json={
        "card_token": "tok_get_1",
        "last_four": "1234",
        "brand": "Visa",
        "exp_month": 1,
        "exp_year": 2030,
        "is_default": 0
    }, headers=auth_headers)
    
    await client.post("/me/cards", json={
        "card_token": "tok_get_2",
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
    assert "tok_get_1" in tokens
    assert "tok_get_2" in tokens
    
    # Ensure one default card
    defaults = [c for c in data if c["is_default"]]
    assert len(defaults) == 1
    assert defaults[0]["card_token"] == "tok_get_2"

@pytest.mark.asyncio
async def test_delete_card(client, auth_headers):
    # Setup card
    res = await client.post("/me/cards", json={
        "card_token": "tok_del_1",
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
    assert "tok_del_1" not in tokens

@pytest.mark.asyncio
async def test_delete_nonexistent_card(client, auth_headers):
    response = await client.delete("/me/cards/99999", headers=auth_headers)
    assert response.status_code == 404
