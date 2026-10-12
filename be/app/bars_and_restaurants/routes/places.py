from fastapi import APIRouter, Depends, Query
from typing import Optional

from app.auth.rbac_middleware import get_current_user, AuthUser
from app.errors import APIError
from ..services import places_service

places_router = APIRouter(prefix="/api/places", tags=["Places"])


@places_router.get("/autocomplete")
async def places_autocomplete(
    input: str = Query(..., min_length=2),
    countries: Optional[str] = Query(None),
    types: str = Query("establishment"),
    sessiontoken: Optional[str] = Query(None),
    language: str = Query("pt-BR"),
    current_user: AuthUser = Depends(get_current_user),
):
    country_list = None
    if countries:
        country_list = [c.strip().upper() for c in countries.split(",")]
    
    result = await places_service.autocomplete(
        input_text=input,
        countries=country_list,
        types=types,
        session_token=sessiontoken,
        language=language,
    )
    
    if result.get("status") == "ERROR":
        raise APIError.server_error(result.get("error_message", "Google Places API error"))
    
    return result


@places_router.get("/details")
async def place_details(
    place_id: str = Query(...),
    fields: Optional[str] = Query(None),
    sessiontoken: Optional[str] = Query(None),
    language: str = Query("pt-BR"),
    current_user: AuthUser = Depends(get_current_user),
):
    result = await places_service.get_place_details(
        place_id=place_id,
        fields=fields,
        session_token=sessiontoken,
        language=language,
    )
    
    if result.get("status") == "ERROR":
        raise APIError.server_error(result.get("error_message", "Google Places API error"))
    
    if result.get("status") == "INVALID_REQUEST":
        raise APIError.validation_error("Invalid place_id or request parameters")
    
    if result.get("status") == "NOT_FOUND":
        raise APIError.not_found("Place not found")
    
    return result


@places_router.get("/details/parsed")
async def place_details_parsed(
    place_id: str = Query(...),
    sessiontoken: Optional[str] = Query(None),
    current_user: AuthUser = Depends(get_current_user),
):
    result = await places_service.get_place_details(
        place_id=place_id,
        session_token=sessiontoken,
    )
    
    if result.get("status") != "OK":
        if result.get("status") == "NOT_FOUND":
            raise APIError.not_found("Place not found")
        raise APIError.server_error(result.get("error_message", "Google Places API error"))
    
    parsed = places_service.parse_place_for_bar_creation(result)
    parsed.pop("_raw_opening_hours", None)
    
    return parsed
