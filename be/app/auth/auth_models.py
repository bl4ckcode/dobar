import sqlalchemy as sa
from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from ..database import Base
from .rbac_models import ConsumerSubscriptionTier
from datetime import datetime, timezone

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    firebase_uid = Column(String, unique=True, index=True, nullable=True)  # Firebase UID (nullable for non-Firebase users)
    phone_number = Column(String, unique=True, index=True, nullable=True)  # User's phone number
    email = Column(String, unique=True, index=True, nullable=True)  # User's email
    google_id = Column(String, unique=True, nullable=True)  # Google ID for OAuth
    apple_id = Column(String, unique=True, nullable=True)  # Apple ID for OAuth
    facebook_id = Column(String, unique=True, nullable=True)  # Facebook ID for OAuth
    is_active = Column(Boolean, default=True)  # Whether the user is active
    email_verified = Column(Boolean, default=False, nullable=False, server_default=sa.false())  # Email ownership verified
    phone_verified = Column(Boolean, default=False, nullable=False, server_default=sa.false())  # Phone ownership verified
    
    # Dobar PRO features
    subscription_tier = Column(String(20), default=ConsumerSubscriptionTier.REGULAR.value, index=True)
    
    # Regional settings
    country_code = Column(String(2), index=True, default="BR")  # ISO 3166-1 alpha-2

    
    # Wallet relationships
    wallet = relationship("UserWallet", back_populates="user", uselist=False, cascade="all, delete-orphan")
    cashback_transactions = relationship("CashbackLedger", back_populates="user", cascade="all, delete-orphan")
    refresh_tokens = relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")

class Token(Base):
    """Legacy token table - kept for backwards compatibility"""
    __tablename__ = "tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True)  # Foreign key to User
    token = Column(String, unique=True, index=True)  # Authentication token
    expiry_date = Column(Integer)  # Expiry date in timestamp format


class RefreshToken(Base):
    """
    Refresh tokens for long-lived sessions.
    - Access tokens are short-lived (configurable, default 1 hour)
    - Refresh tokens are long-lived (30 days or matches provider token expiry)
    - Refresh tokens can be revoked on logout
    """
    __tablename__ = "refresh_tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    token = Column(String, unique=True, index=True, nullable=False)  # Unique refresh token
    expires_at = Column(DateTime(timezone=True), nullable=False)  # When the refresh token expires
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    revoked_at = Column(DateTime(timezone=True), nullable=True)  # If revoked, when
    device_info = Column(String, nullable=True)  # Optional: device identifier for multi-device support
    provider = Column(String, nullable=True)  # "phone", "google", "apple" - which OAuth provider
    
    # Relationship
    user = relationship("User", back_populates="refresh_tokens")
    
    @property
    def is_valid(self) -> bool:
        """Check if token is still valid (not expired and not revoked)"""
        now = datetime.now(timezone.utc)
        return self.revoked_at is None and self.expires_at > now