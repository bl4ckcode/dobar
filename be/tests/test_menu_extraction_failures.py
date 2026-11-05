import json
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import httpx
import openai
import pytest

from app.bars_and_restaurants.services.menu_extraction import MenuExtractionService, MenuExtractionUnavailable
from app.bars_and_restaurants.routes import menus
from app.errors import APIError, ErrorCode


def completion(content, finish_reason="stop"):
    return SimpleNamespace(choices=[SimpleNamespace(finish_reason=finish_reason, message=SimpleNamespace(content=content))])


@pytest.mark.asyncio
async def test_configured_async_model_preserves_brazilian_menu_values(monkeypatch):
    monkeypatch.setenv("OPENAI_MENU_MODEL", "gpt-5.6-terra")
    service = MenuExtractionService()
    client = SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=AsyncMock(return_value=completion(json.dumps({
        "currency": "BRL", "categories": [{"name": "Porções", "items": [{"name": "Batata", "price": 25.90, "description": None}]}]
    }))))))
    service.openai_client = client
    result = await service.parse_menu_with_llm("Batata R$25,90", "pt-BR")
    assert result["categories"][0]["items"][0]["price"] == 25.9
    args = client.chat.completions.create.call_args.kwargs
    assert args["model"] == "gpt-5.6-terra"
    assert "max_tokens" not in args
    assert "temperature" not in args


@pytest.mark.asyncio
@pytest.mark.parametrize("content,finish_reason", [(None, "stop"), ("{}", "stop"), ("not json", "stop"), ("{}", "length"), (json.dumps({"currency": "BRL", "categories": [{"name": "Bebidas", "items": [{"name": "Água", "price": -1, "description": None}]}]}), "stop")])
async def test_malformed_refused_or_truncated_output_is_actionable(content, finish_reason):
    service = MenuExtractionService()
    service.openai_client = SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=AsyncMock(return_value=completion(content, finish_reason)))))
    with pytest.raises(MenuExtractionUnavailable):
        await service.parse_menu_with_llm("sample menu")


@pytest.mark.asyncio
async def test_retired_model_error_does_not_escape_as_unhandled_500():
    request = httpx.Request("POST", "https://api.openai.com/v1/chat/completions")
    error = openai.NotFoundError("model retired", response=httpx.Response(404, request=request), body={"error": "model_not_found"})
    service = MenuExtractionService()
    service.openai_client = SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=AsyncMock(side_effect=error))))
    with pytest.raises(MenuExtractionUnavailable):
        await service.parse_menu_with_llm("sample menu")


@pytest.mark.asyncio
async def test_url_route_returns_canonical_service_unavailable_without_provider_details():
    from app.bars_and_restaurants.schemas.menus import MenuExtractionURLRequest
    with patch.object(menus, "get_bar_by_id", AsyncMock(return_value={"id": 1})), patch.object(menus, "authorize_menu_extraction", AsyncMock()), patch("app.bars_and_restaurants.services.menu_extraction.menu_extraction_service.extract_menu_from_url", AsyncMock(side_effect=MenuExtractionUnavailable("secret provider detail"))):
        with pytest.raises(APIError) as caught:
            await menus.extract_menu_from_url(MenuExtractionURLRequest(menu_url="https://example.com/menu", bar_id=1), object())
    assert caught.value.status_code == 503
    assert caught.value.error_code == ErrorCode.SERVER_UNAVAILABLE
    assert "secret" not in caught.value.message


@pytest.mark.asyncio
@pytest.mark.parametrize("credentials", ["invalid base64", "e30="])
async def test_misconfigured_ocr_credentials_are_controlled(monkeypatch, credentials):
    monkeypatch.setenv("GOOGLE_CREDENTIALS_BASE64", credentials)
    with pytest.raises(MenuExtractionUnavailable):
        await MenuExtractionService().extract_text_from_image(b"menu image")


@pytest.mark.asyncio
async def test_rejected_ocr_credentials_are_controlled():
    from google.auth.exceptions import RefreshError
    service = MenuExtractionService()
    service.vision_client = SimpleNamespace(document_text_detection=lambda **kwargs: (_ for _ in ()).throw(RefreshError("secret rejected credential")))
    with pytest.raises(MenuExtractionUnavailable) as caught:
        await service.extract_text_from_image(b"menu image")
    assert "secret" not in str(caught.value)
