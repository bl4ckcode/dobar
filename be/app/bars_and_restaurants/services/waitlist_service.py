"""
Waitlist service for managing bar signups from the landing page.
"""
import re
from typing import Optional, List, Dict, Any
from datetime import datetime
from app.database import database
from app.bars_and_restaurants.models.relational_models import WaitlistSignup
from app.errors import APIError, ErrorCode


# Valid Brazilian cities for the waitlist
VALID_CITIES = ["São Paulo", "Rio de Janeiro", "Belo Horizonte", "Outra"]
VALID_SOURCES = ["organic", "email_outreach", "instagram", "whatsapp", "google_places", "landing_page"]
VALID_STATUSES = ["pending", "contacted", "qualified", "converted", "declined"]


def normalize_phone_e164(phone: Optional[str]) -> Optional[str]:
    """
    Normalize phone number to E.164 format.
    For Brazil: +55 followed by 10-11 digits (DDD + number)
    """
    if not phone:
        return None
    
    # Remove all non-digit characters except +
    cleaned = re.sub(r'[^\d+]', '', phone)
    
    # If starts with +, keep it; if starts with 00, replace with +
    if cleaned.startswith('00'):
        cleaned = '+' + cleaned[2:]
    
    # If no + and looks like a Brazilian number (starts with 55 or 11-99 for DDD)
    if not cleaned.startswith('+'):
        # If it starts with 55 and has 12-13 digits, add +
        if cleaned.startswith('55') and len(cleaned) >= 12:
            cleaned = '+' + cleaned
        # Otherwise assume it's a Brazilian number without country code
        elif len(cleaned) >= 10:
            cleaned = '+55' + cleaned
        else:
            # Return as-is if we can't determine format
            return cleaned
    
    return cleaned


async def check_email_exists(email: str) -> bool:
    """Check if an email is already registered in the waitlist."""
    query = WaitlistSignup.__table__.select().where(WaitlistSignup.email == email.lower())
    result = await database.fetch_one(query)
    return result is not None


async def create_signup(
    bar_name: str,
    contact_name: str,
    email: str,
    phone: Optional[str],
    city: str,
    source: str = "organic",
    utm_source: Optional[str] = None,
    utm_medium: Optional[str] = None,
    utm_campaign: Optional[str] = None,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None
) -> Dict[str, Any]:
    """
    Create a new waitlist signup.
    
    Raises:
        APIError: If email already exists (409 CONFLICT)
    """
    # Normalize email
    email = email.lower().strip()
    
    # Check for duplicate email
    if await check_email_exists(email):
        raise APIError(
            status_code=409,
            error_code=ErrorCode.CONFLICT,
            message="Este email já está na nossa lista de espera!"
        )
    
    # Validate city
    if city not in VALID_CITIES:
        raise APIError(
            status_code=422,
            error_code=ErrorCode.VALIDATION_ERROR,
            message=f"Cidade inválida. Deve ser uma de: {', '.join(VALID_CITIES)}"
        )
    
    # Validate source
    if source not in VALID_SOURCES:
        source = "organic"  # Default to organic if invalid
    
    # Normalize phone
    normalized_phone = normalize_phone_e164(phone)
    
    # Create the signup
    query = WaitlistSignup.__table__.insert().values(
        bar_name=bar_name.strip(),
        contact_name=contact_name.strip(),
        email=email,
        phone=normalized_phone,
        city=city,
        source=source,
        utm_source=utm_source,
        utm_medium=utm_medium,
        utm_campaign=utm_campaign,
        status="pending",
        ip_address=ip_address,
        user_agent=user_agent,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow()
    )
    
    try:
        result = await database.execute(query)
        
        # Fetch the created record
        signup = await database.fetch_one(
            WaitlistSignup.__table__.select().where(WaitlistSignup.id == result)
        )
        
        return dict(signup) if signup else {"id": result}
    except Exception as e:
        # Handle unique constraint violation
        if "unique" in str(e).lower() or "duplicate" in str(e).lower():
            raise APIError(
                status_code=409,
                error_code=ErrorCode.CONFLICT,
                message="Este email já está na nossa lista de espera!"
            )
        raise


async def get_signup_by_id(signup_id: int) -> Optional[Dict[str, Any]]:
    """Get a single signup by ID."""
    query = WaitlistSignup.__table__.select().where(WaitlistSignup.id == signup_id)
    result = await database.fetch_one(query)
    return dict(result) if result else None


async def list_signups(
    city: Optional[str] = None,
    status: Optional[str] = None,
    source: Optional[str] = None,
    limit: int = 50,
    offset: int = 0
) -> Dict[str, Any]:
    """
    List waitlist signups with optional filters.
    Returns signups and aggregated statistics.
    """
    # Build the base query
    base_query = WaitlistSignup.__table__.select()
    
    if city:
        base_query = base_query.where(WaitlistSignup.city == city)
    if status:
        base_query = base_query.where(WaitlistSignup.status == status)
    if source:
        base_query = base_query.where(WaitlistSignup.source == source)
    
    # Get total count
    count_query = base_query.with_only_columns(WaitlistSignup.id)
    count_result = await database.fetch_all(count_query)
    total = len(count_result)
    
    # Get paginated results ordered by created_at DESC
    query = base_query.order_by(WaitlistSignup.created_at.desc()).limit(limit).offset(offset)
    results = await database.fetch_all(query)
    
    signups = [dict(row) for row in results]
    
    # Get statistics
    stats = await get_statistics(city=city, status=status, source=source)
    
    return {
        "signups": signups,
        "total": total,
        "by_city": stats["by_city"],
        "by_status": stats["by_status"],
        "by_source": stats.get("by_source", {})
    }


async def get_statistics(
    city: Optional[str] = None,
    status: Optional[str] = None,
    source: Optional[str] = None
) -> Dict[str, Dict[str, int]]:
    """Get aggregated statistics for the waitlist."""
    
    # By city
    city_query = """
        SELECT city, COUNT(*) as count 
        FROM waitlist_signups 
        GROUP BY city
    """
    city_results = await database.fetch_all(city_query)
    by_city = {row["city"]: row["count"] for row in city_results}
    
    # By status
    status_query = """
        SELECT status, COUNT(*) as count 
        FROM waitlist_signups 
        GROUP BY status
    """
    status_results = await database.fetch_all(status_query)
    by_status = {row["status"]: row["count"] for row in status_results}
    
    # By source
    source_query = """
        SELECT source, COUNT(*) as count 
        FROM waitlist_signups 
        GROUP BY source
    """
    source_results = await database.fetch_all(source_query)
    by_source = {row["source"]: row["count"] for row in source_results}
    
    return {
        "by_city": by_city,
        "by_status": by_status,
        "by_source": by_source
    }


async def update_signup(
    signup_id: int,
    status: Optional[str] = None,
    notes: Optional[str] = None
) -> Dict[str, Any]:
    """
    Update a signup's status and/or notes.
    
    Raises:
        APIError: If signup not found (404)
    """
    # Check if signup exists
    existing = await get_signup_by_id(signup_id)
    if not existing:
        raise APIError.not_found("Signup not found")
    
    # Validate status if provided
    if status and status not in VALID_STATUSES:
        raise APIError(
            status_code=422,
            error_code=ErrorCode.VALIDATION_ERROR,
            message=f"Status inválido. Deve ser um de: {', '.join(VALID_STATUSES)}"
        )
    
    # Build update values
    values = {"updated_at": datetime.utcnow()}
    if status:
        values["status"] = status
    if notes is not None:
        values["notes"] = notes
    
    # Execute update
    query = (
        WaitlistSignup.__table__.update()
        .where(WaitlistSignup.id == signup_id)
        .values(**values)
    )
    await database.execute(query)
    
    # Return updated record
    return await get_signup_by_id(signup_id)


async def mark_email_sent(signup_id: int, email_type: str) -> None:
    """Mark that a confirmation or admin email was sent."""
    column = "confirmation_email_sent" if email_type == "confirmation" else "admin_notification_sent"
    query = (
        WaitlistSignup.__table__.update()
        .where(WaitlistSignup.id == signup_id)
        .values(**{column: True, "updated_at": datetime.utcnow()})
    )
    await database.execute(query)
