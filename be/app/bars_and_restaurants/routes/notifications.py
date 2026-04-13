from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from app.database import database
from app.auth.middleware import get_current_active_user
from app.auth.auth_models import User
from app.bars_and_restaurants.models.relational_models import Notification
from app.bars_and_restaurants.schemas.notifications import NotificationResponse

notifications_router = APIRouter(prefix="/notifications", tags=["Notifications"])

@notifications_router.get("/", response_model=List[NotificationResponse])
async def get_notifications(
    current_user: User = Depends(get_current_active_user),
    limit: int = 50,
    offset: int = 0
):
    """Get the user's recent notifications, ordered by newest first."""
    query = (
        Notification.__table__.select()
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    results = await database.fetch_all(query)
    return results

@notifications_router.put("/read-all", response_model=dict)
async def mark_all_as_read(
    current_user: User = Depends(get_current_active_user)
):
    """Mark all unread notifications for the user as read."""
    update_stmt = (
        Notification.__table__.update()
        .where(
            (Notification.user_id == current_user.id) & 
            (Notification.is_read == False)
        )
        .values(is_read=True)
    )
    result = await database.execute(update_stmt)
    return {"message": "All notifications marked as read.", "count": result}

@notifications_router.put("/{notification_id}/read", response_model=NotificationResponse)
async def mark_notification_as_read(
    notification_id: int,
    current_user: User = Depends(get_current_active_user)
):
    """Mark a specific notification as read."""
    # First verify it exists and belongs to user
    query = Notification.__table__.select().where(
        (Notification.id == notification_id) & 
        (Notification.user_id == current_user.id)
    )
    notification = await database.fetch_one(query)
    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, 
            detail="Notification not found"
        )
        
    update_stmt = (
        Notification.__table__.update()
        .where(Notification.id == notification_id)
        .values(is_read=True)
    )
    await database.execute(update_stmt)
    
    # Return updated notification
    updated = await database.fetch_one(query)
    return updated
