import pytest
from httpx import AsyncClient
from conftest import create_test_token


@pytest.mark.asyncio
async def test_create_cpf_document(auth_client):
    client, headers, user = auth_client
    response = await client.post(
        "/users/me/documents",
        json={
            "type": "cpf",
            "number": "93095135270",
            "verified": False
        },
        headers=headers
    )
    assert response.status_code == 201
    data = response.json()
    assert data["type"] == "cpf"
    assert data["number"] == "93095135270"
    assert data["user_id"] == user["id"]
    assert data["verified"] is False


@pytest.mark.asyncio
async def test_create_cpf_invalid(auth_client):
    client, headers, user = auth_client
    response = await client.post(
        "/users/me/documents",
        json={
            "type": "cpf",
            "number": "00000000000",
            "verified": False
        },
        headers=headers
    )
    assert response.status_code == 422
    data = response.json()
    assert data["error_code"] == "INVALID_CPF"


@pytest.mark.asyncio
async def test_upsert_document(auth_client):
    client, headers, user = auth_client
    response1 = await client.post(
        "/users/me/documents",
        json={"type": "cpf", "number": "93095135270"},
        headers=headers
    )
    assert response1.status_code == 201
    doc_id = response1.json()["id"]

    response2 = await client.post(
        "/users/me/documents",
        json={"type": "cpf", "number": "52998224725"},
        headers=headers
    )
    assert response2.status_code == 201
    assert response2.json()["id"] == doc_id
    assert response2.json()["number"] == "52998224725"


@pytest.mark.asyncio
async def test_list_documents(auth_client):
    client, headers, user = auth_client
    await client.post(
        "/users/me/documents",
        json={"type": "cpf", "number": "93095135270"},
        headers=headers
    )
    response = await client.get("/users/me/documents", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["type"] == "cpf"


@pytest.mark.asyncio
async def test_create_rg_document(auth_client):
    client, headers, user = auth_client
    response = await client.post(
        "/users/me/documents",
        json={
            "type": "rg",
            "number": "MG12345678",
            "issuing_authority": "SSP-MG"
        },
        headers=headers
    )
    assert response.status_code == 201
    data = response.json()
    assert data["type"] == "rg"
    assert data["issuing_authority"] == "SSP-MG"


@pytest.mark.asyncio
async def test_documents_require_auth(client):
    response = await client.get("/users/me/documents")
    assert response.status_code in [401, 403]


@pytest.mark.asyncio
async def test_invalid_document_type(auth_client):
    client, headers, user = auth_client
    response = await client.post(
        "/users/me/documents",
        json={"type": "invalid_type", "number": "123"},
        headers=headers
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_notifications_no_redirect(auth_client):
    client, headers, user = auth_client
    response = await client.get(
        "/notifications?limit=50&offset=0",
        headers=headers,
        follow_redirects=False
    )
    assert response.status_code == 200
