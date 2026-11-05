from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime
from app.database import Base


class Checkin(Base):
    __tablename__ = "customer_checkins"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    bar_id = Column(Integer, ForeignKey("bars.id", ondelete="CASCADE"), nullable=False, index=True)
    table_number = Column(String(120), nullable=True)
    status = Column(String(20), nullable=False, default="active")
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    distance_meters = Column(Float, nullable=False)
    measured_at = Column(DateTime, nullable=False)
    checked_in_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=False)
    checked_out_at = Column(DateTime, nullable=True)
