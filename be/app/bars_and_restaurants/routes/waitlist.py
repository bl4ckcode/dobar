"""
Waitlist API routes for the MVP landing page.

Public endpoint:
- POST /api/v1/waitlist/signup - Submit a new waitlist entry

Admin endpoints (protected):
- GET /api/v1/admin/waitlist - List all signups with stats
- PATCH /api/v1/admin/waitlist/{id} - Update signup status/notes
"""
from fastapi import APIRouter, Request, Depends, Query
from typing import Optional
from app.database import database
from app.rate_limiter import limiter, RateLimits
from app.errors import APIError, ErrorCode
from app.auth.admin import get_admin_user, verify_admin_api_key
from ..schemas.waitlist import (
    WaitlistSignupCreate,
    WaitlistSignupSuccess,
    WaitlistSignupDuplicate,
    WaitlistListResponse,
    WaitlistUpdateRequest,
    WaitlistFilterParams
)
from ..services import waitlist_service
from ..services.email_service import send_confirmation_email, send_admin_notification


# Public router for signups
waitlist_public_router = APIRouter(prefix="/api/v1/waitlist", tags=["Waitlist"])

# Admin router for management
waitlist_admin_router = APIRouter(prefix="/api/v1/admin/waitlist", tags=["Waitlist Admin"])


@waitlist_public_router.post(
    "/signup",
    response_model=WaitlistSignupSuccess,
    status_code=201,
    responses={
        201: {"description": "Signup created successfully"},
        409: {"description": "Duplicate email", "model": WaitlistSignupDuplicate},
        422: {"description": "Validation error"},
        429: {"description": "Rate limit exceeded"}
    }
)
@limiter.limit("5/hour")  # 5 requests per IP per hour as specified
async def create_waitlist_signup(
    request: Request,
    data: WaitlistSignupCreate
):
    """
    Submit a new waitlist signup from the landing page.
    
    Rate limited to 5 requests per IP per hour to prevent abuse.
    """
    # Extract client info
    client_ip = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")
    
    # Extract UTM params if provided
    utm_source = data.utm_params.source if data.utm_params else None
    utm_medium = data.utm_params.medium if data.utm_params else None
    utm_campaign = data.utm_params.campaign if data.utm_params else None
    
    try:
        # Create the signup
        signup = await waitlist_service.create_signup(
            bar_name=data.bar_name,
            contact_name=data.contact_name,
            email=data.email,
            phone=data.phone,
            city=data.city,
            source=data.source,
            utm_source=utm_source,
            utm_medium=utm_medium,
            utm_campaign=utm_campaign,
            ip_address=client_ip,
            user_agent=user_agent
        )
        
        # Send confirmation email to the user
        try:
            await send_confirmation_email(
                to_email=data.email,
                contact_name=data.contact_name,
                bar_name=data.bar_name,
                city=data.city
            )
            await waitlist_service.mark_email_sent(signup["id"], "confirmation")
        except Exception as e:
            # Log but don't fail the request if email fails
            print(f"⚠️ Failed to send confirmation email to {data.email}: {e}")
        
        # Send admin notification
        try:
            await send_admin_notification(signup)
            await waitlist_service.mark_email_sent(signup["id"], "admin")
        except Exception as e:
            print(f"⚠️ Failed to send admin notification for signup {signup['id']}: {e}")
        
        return WaitlistSignupSuccess(
            success=True,
            data={
                "id": signup["id"],
                "message": "Você está na lista! Entraremos em contato em breve."
            }
        )
        
    except APIError:
        raise
    except Exception as e:
        print(f"❌ Error creating waitlist signup: {e}")
        raise APIError(
            status_code=500,
            error_code=ErrorCode.UNKNOWN,
            message="Ocorreu um erro ao processar sua inscrição. Tente novamente."
        )


@waitlist_admin_router.get(
    "",
    response_model=WaitlistListResponse
)
async def list_waitlist_signups(
    city: Optional[str] = Query(None, description="Filter by city"),
    status: Optional[str] = Query(None, description="Filter by status"),
    source: Optional[str] = Query(None, description="Filter by source"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    admin=Depends(get_admin_user)
):
    """
    List all waitlist signups with optional filters.
    Returns signups and aggregated statistics by city and status.
    
    **Requires admin authentication.**
    """
    result = await waitlist_service.list_signups(
        city=city,
        status=status,
        source=source,
        limit=limit,
        offset=offset
    )
    
    return WaitlistListResponse(
        success=True,
        data=result
    )


@waitlist_admin_router.patch(
    "/{signup_id}",
    response_model=dict
)
async def update_waitlist_signup(
    signup_id: int,
    data: WaitlistUpdateRequest,
    admin=Depends(get_admin_user)
):
    """
    Update a waitlist signup's status and/or notes.
    
    **Requires admin authentication.**
    """
    updated = await waitlist_service.update_signup(
        signup_id=signup_id,
        status=data.status,
        notes=data.notes
    )
    
    return {
        "success": True,
        "data": {
            "id": updated["id"],
            "status": updated["status"],
            "notes": updated.get("notes"),
            "updated_at": updated["updated_at"]
        }
    }


@waitlist_admin_router.get(
    "/stats",
    response_model=dict
)
async def get_waitlist_stats(
    admin=Depends(get_admin_user)
):
    """
    Get aggregated waitlist statistics.
    
    **Requires admin authentication.**
    """
    stats = await waitlist_service.get_statistics()
    
    # Get total count
    total_query = "SELECT COUNT(*) as total FROM waitlist_signups"
    total_result = await database.fetch_one(total_query)
    total = total_result["total"] if total_result else 0
    
    return {
        "success": True,
        "data": {
            "total": total,
            **stats
        }
    }
