"""
Wallet and Cashback Models for BarZ Platform
"""
from datetime import datetime, timezone
from decimal import Decimal
from sqlalchemy import Column, String, Numeric, DateTime, ForeignKey, Enum as SQLEnum, Index, Integer, BigInteger
from sqlalchemy.orm import relationship
import enum

from app.database import Base


class CashbackType(str, enum.Enum):
    """Type of cashback transaction"""
    EARN = "EARN"           # User earned cashback
    REDEEM = "REDEEM"       # User redeemed/used cashback
    EXPIRE = "EXPIRE"       # Cashback expired
    ADJUST = "ADJUST"       # Manual adjustment by admin


class FundingSource(str, enum.Enum):
    """Who funded the cashback"""
    BAR = "BAR"             # Merchant covers cashback (marketing credit)
    BARZ = "BARZ"           # Platform covers (e.g., first-order cashback)
    SPONSORED = "SPONSORED"  # Third party co-funds (future partnerships)


class CashbackStatus(str, enum.Enum):
    """Lifecycle status of cashback"""
    PENDING = "PENDING"         # Awaiting clearance (e.g., after refund period)
    AVAILABLE = "AVAILABLE"     # Redeemable by user
    USED = "USED"              # Already redeemed
    EXPIRED = "EXPIRED"        # Past expiration date


class CashbackLedger(Base):
    """
    Transaction log for all cashback operations.
    Each row represents earning, redeeming, expiring, or adjusting cashback.
    """
    __tablename__ = "cashback_ledger"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    order_id = Column(Integer, ForeignKey("orders.id", ondelete="SET NULL"), nullable=True)
    bar_id = Column(Integer, ForeignKey("bars.id", ondelete="CASCADE"), nullable=False)
    
    # Financial details
    amount = Column(Numeric(10, 2), nullable=False)  # Positive for EARN, negative for REDEEM
    
    # Transaction metadata
    type = Column(SQLEnum(CashbackType), nullable=False, index=True)
    funded_by = Column(SQLEnum(FundingSource), nullable=False)
    status = Column(SQLEnum(CashbackStatus), nullable=False, default=CashbackStatus.PENDING, index=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=True)  # Optional expiry date
    
    # Relationships
    user = relationship("User", back_populates="cashback_transactions")
    order = relationship("Order", back_populates="cashback_transactions")
    bar = relationship("Bar", back_populates="cashback_transactions")

    # Indexes for performance
    __table_args__ = (
        Index('idx_cashback_user_status', 'user_id', 'status'),
        Index('idx_cashback_user_created', 'user_id', 'created_at'),
        Index('idx_cashback_expires', 'expires_at'),
    )

    def __repr__(self):
        return f"<CashbackLedger(id={self.id}, user_id={self.user_id}, type={self.type}, amount={self.amount}, status={self.status})>"


class UserWallet(Base):
    """
    Aggregate view of user's cashback balance.
    Denormalized table for fast balance lookups.
    Updated via triggers or application logic when CashbackLedger changes.
    """
    __tablename__ = "user_wallet"

    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    
    # Balance fields (in currency units, e.g., USD cents or BRL centavos)
    available_balance = Column(Numeric(10, 2), nullable=False, default=Decimal("0.00"))
    pending_balance = Column(Numeric(10, 2), nullable=False, default=Decimal("0.00"))
    
    # Metadata
    last_updated = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    
    # Relationships
    user = relationship("User", back_populates="wallet", uselist=False)

    def __repr__(self):
        return f"<UserWallet(user_id={self.user_id}, available={self.available_balance}, pending={self.pending_balance})>"

    @property
    def total_balance(self) -> Decimal:
        return self.available_balance + self.pending_balance


class BarWallet(Base):
    __tablename__ = "bar_wallet"

    bar_id = Column(Integer, ForeignKey("bars.id", ondelete="CASCADE"), primary_key=True)
    
    available_balance = Column(Numeric(10, 2), nullable=False, default=Decimal("0.00"))
    reserved_balance = Column(Numeric(10, 2), nullable=False, default=Decimal("0.00"))
    
    last_updated = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    
    bar = relationship("Bar", backref="wallet", uselist=False)

    def __repr__(self):
        return f"<BarWallet(bar_id={self.bar_id}, available={self.available_balance}, reserved={self.reserved_balance})>"

    @property
    def total_balance(self) -> Decimal:
        return self.available_balance + self.reserved_balance


class ProCouponStatus(str, enum.Enum):
    RESERVED = "RESERVED"
    REDEEMED = "REDEEMED"
    RELEASED = "RELEASED"
    REFUNDED = "REFUNDED"


class ProCouponUsage(Base):
    __tablename__ = "pro_coupon_usages"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    promotion_id = Column(Integer, ForeignKey("promotions.id", ondelete="SET NULL"), nullable=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id", ondelete="SET NULL"), nullable=True, index=True)
    period_key = Column(String(7), nullable=False, index=True)
    status = Column(SQLEnum(ProCouponStatus), nullable=False, default=ProCouponStatus.RESERVED, index=True)
    cashback_amount = Column(Numeric(10, 2), nullable=True)
    cashback_ledger_id = Column(Integer, ForeignKey("cashback_ledger.id", ondelete="SET NULL"), nullable=True)
    bar_id = Column(Integer, ForeignKey("bars.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)

    __table_args__ = (
        Index("idx_pro_coupon_user_period_status", "user_id", "period_key", "status"),
        Index("uq_pro_coupon_order_promo", "order_id", "promotion_id", unique=True),
    )
