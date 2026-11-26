from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Boolean, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
from ...database import Base

class Payout(Base):
    __tablename__ = "payouts"

    id = Column(Integer, primary_key=True, index=True)
    bar_id = Column(Integer, ForeignKey("bars.id"), index=True, nullable=False)
    
    amount = Column(Float, nullable=False)
    currency = Column(String(3), default="BRL")
    
    status = Column(String(20), default="pending", index=True)  # pending, in_transit, paid, failed, cancelled
    
    # External gateway info
    gateway_payout_id = Column(String(100), nullable=True, index=True)
    gateway_name = Column(String(50), nullable=True) # stone, stripe, etc.
    
    # Bank account snapshot (what was used for this payout)
    bank_account_info = Column(JSON, nullable=True)
    
    # Metadata
    failure_code = Column(String(50), nullable=True)
    failure_message = Column(String(500), nullable=True)
    
    arrival_date = Column(DateTime, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class Dispute(Base):
    __tablename__ = "disputes"

    id = Column(Integer, primary_key=True, index=True)
    bar_id = Column(Integer, ForeignKey("bars.id"), index=True, nullable=False)
    order_id = Column(Integer, ForeignKey("orders.id"), index=True, nullable=True)
    
    # Transaction Info
    amount = Column(Float, nullable=False)
    currency = Column(String(3), default="BRL")
    
    # External gateway info
    gateway_dispute_id = Column(String(100), nullable=False, unique=True, index=True)
    gateway_transaction_id = Column(String(100), nullable=False, index=True)
    gateway_name = Column(String(50), nullable=True)
    
    # Status
    status = Column(String(50), default="needs_response", index=True) # needs_response, warning_needs_response, under_review, won, lost, warning_closed
    reason = Column(String(100), nullable=True) # chargeback, fraudulent, etc.
    
    # Financial Impact
    is_refundable = Column(Boolean, default=False)
    has_evidence = Column(Boolean, default=False)
    
    # Deadlines
    evidence_due_date = Column(DateTime, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class OrderRefund(Base):
    """A refund of an order's payment, recorded *before* the payment engine
    (DPE) is asked to move the money.

    Lifecycle (``status``):
    * ``pending``   - written before calling DPE. If anything fails after the
      money may have moved (DPE timeout / 5xx, or recording the outcome), the
      row stays pending. The dashboard subtracts pending refunds, so revenue
      is never overstated while the outcome is unknown.
    * ``succeeded`` - DPE confirmed the refund; ``amount`` is the confirmed
      amount and ``gateway_refund_id`` its id.
    * ``failed``    - DPE definitively rejected it (4xx), or reconciliation
      found DPE never refunded it. Not subtracted.

    Pending rows are settled by a retry with the same idempotency key, or by
    ``reconcile_pending_refunds`` (read-only: compares with the refunded total
    DPE reports for the payment; it never issues refunds).

    Refunds are amount-based and an order can have several (partial) refunds,
    so they live here instead of on the order. ``orders.payment_status`` keeps
    describing the payment itself ("paid"): the charge, webhook and
    status-polling flows treat any other value as "not paid yet" and would
    re-open or re-settle a refunded order.
    """
    __tablename__ = "order_refunds"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id", ondelete="CASCADE"), index=True, nullable=False)
    bar_id = Column(Integer, ForeignKey("bars.id"), index=True, nullable=False)

    payment_id = Column(String(100), nullable=False, index=True)
    # Key sent to DPE for this refund; one row per refund attempt.
    idempotency_key = Column(String(128), nullable=False, unique=True, index=True)
    gateway_refund_id = Column(String(100), nullable=True, unique=True, index=True)

    status = Column(String(20), nullable=False, default="pending", index=True)
    # Requested amount while pending; the amount DPE confirmed once succeeded.
    amount = Column(Float, nullable=False)
    currency = Column(String(3), default="BRL")
    reason = Column(String(500), nullable=True)

    requested_by_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
