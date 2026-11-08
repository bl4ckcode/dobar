from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, Index, Integer, String

from ..database import Base


class ContactChangeRequest(Base):
    """Server-side challenge for changing a login contact (email/phone).

    The row only stores a normalized target value and lifecycle state. The
    ownership proof (Firebase ID token) is validated, never persisted.
    status: pending -> completed | cancelled | expired
    """

    __tablename__ = "contact_change_requests"

    id = Column(Integer, primary_key=True, index=True)
    request_id = Column(String(64), unique=True, nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    channel = Column(String(10), nullable=False)  # "email" | "phone"
    new_value = Column(String, nullable=False)
    status = Column(String(12), nullable=False, default="pending", index=True)
    attempts = Column(Integer, nullable=False, default=0)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    __table_args__ = (Index("idx_contact_change_user_status", "user_id", "status"),)
