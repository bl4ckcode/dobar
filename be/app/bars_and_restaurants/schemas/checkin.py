from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict


class CheckinCreate(BaseModel):
    model_config = ConfigDict(allow_inf_nan=False)

    bar_id: int = Field(gt=0)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    measured_at: datetime
    accuracy_meters: Optional[float] = Field(default=None, ge=0)
    table_number: Optional[str] = Field(default=None, max_length=120)


class CheckinResponse(BaseModel):
    id: int
    user_id: int
    bar_id: int
    bar_name: str
    bar_image_url: Optional[str] = None
    table_number: Optional[str] = None
    status: str
    checked_in_at: datetime
    expires_at: datetime
    checked_out_at: Optional[datetime] = None
    distance_meters: float
