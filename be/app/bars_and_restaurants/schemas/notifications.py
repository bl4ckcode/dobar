from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from datetime import datetime

class NotificationBase(BaseModel):
    title: str
    message: Optional[str] = None
    notification_type: str = "system"
    reference_id: Optional[str] = None
    is_read: bool = False

class NotificationResponse(NotificationBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)
