from sqlalchemy import Column, Integer, String, DateTime, JSON
from datetime import datetime
from ..database import Base


class IdempotencyKey(Base):
    __tablename__ = "idempotency_keys"

    id = Column(Integer, primary_key=True, index=True)
    key = Column(String(64), unique=True, index=True, nullable=False)
    user_id = Column(Integer, index=True, nullable=False)
    request_path = Column(String(255), nullable=False)
    response_status = Column(Integer, nullable=True)
    response_body = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=False)


class PaymentCard(Base):
    __tablename__ = "payment_cards"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True, nullable=False)
    card_token = Column(String(255), unique=True, index=True, nullable=False)
    last_four = Column(String(4), nullable=False)
    brand = Column(String(50), nullable=False)
    exp_month = Column(Integer, nullable=False)
    exp_year = Column(Integer, nullable=False)
    is_default = Column(Integer, default=0) # SQLite/general boolean workaround
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
