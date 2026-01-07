from sqlalchemy import Column, Integer, String, Float, ForeignKey, BigInteger, DateTime, Boolean, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
from ...database import Base  # Ensure this is the correct import path

class BarOwner(Base):
    __tablename__ = "bar_owners"  # Separate table for bar owners

    id = Column(BigInteger, primary_key=True, index=True)
    name = Column(String, index=True, nullable=True)
    email = Column(String, unique=True, index=True)
    phone_number = Column(String)

    bars = relationship("Bar", back_populates="owner")  # Relationship with bars
    
class Bar(Base):
    __tablename__ = "bars"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    address = Column(String, unique=True, index=True, nullable=True)
    phone_number = Column(String, index=True, nullable=True)
    email = Column(String, index=True, nullable=True)
    owner_id = Column(BigInteger, ForeignKey("bar_owners.id"), index=True)

    owner = relationship("BarOwner", back_populates="bars")
    menus = relationship("Menu", back_populates="bar")
    promotions = relationship("Promotion", back_populates="bar")
    cashback_transactions = relationship("CashbackLedger", back_populates="bar")
    advertising_subscription = relationship("AdvertisingSubscription", back_populates="bar", uselist=False)

class Menu(Base):
    __tablename__ = "menus"

    id = Column(Integer, primary_key=True, index=True)
    bar_id = Column(Integer, ForeignKey("bars.id"), index=True)
    name = Column(String, nullable=True, default="Menu Principal")
    description = Column(String, nullable=True)
    is_active = Column(Boolean, nullable=True, default=True)

    # Relationship with bars
    bar = relationship("Bar", back_populates="menus")

class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    bar_id = Column(Integer, ForeignKey("bars.id"), index=True)
    status = Column(String, nullable=True, default="pending")  # pending, confirmed, preparing, ready, completed, cancelled
    total_price = Column(Float, nullable=True)
    subtotal = Column(Float, nullable=True)
    tax = Column(Float, nullable=True, default=0.0)
    tip = Column(Float, nullable=True, default=0.0)
    delivery_fee = Column(Float, nullable=True, default=0.0)
    discount = Column(Float, nullable=True, default=0.0)
    
    # Payment information
    payment_id = Column(String, nullable=True)  # Payment gateway transaction ID
    payment_status = Column(String, nullable=True)  # pending, paid, failed, refunded
    payment_method = Column(String, nullable=True)  # credit_card, debit_card, pix, etc.
    
    # Order type
    order_type = Column(String, nullable=True)  # delivery, pickup, dine_in
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    estimated_ready_time = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    
    # Relationships
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")
    status_history = relationship("OrderStatusHistory", back_populates="order", cascade="all, delete-orphan")
    cashback_transactions = relationship("CashbackLedger", back_populates="order")


class Promotion(Base):
    __tablename__ = "promotions"

    id = Column(Integer, primary_key=True, index=True)
    bar_id = Column(Integer, ForeignKey("bars.id"), index=True, nullable=False)
    title = Column(String(200), nullable=False)
    description = Column(String(1000), nullable=True)
    discount_type = Column(String(20), nullable=False, default="percentage")  # percentage, fixed, bogo
    discount_value = Column(Float, nullable=False, default=0.0)
    start_time = Column(String(5), nullable=True)  # HH:MM format for daily recurring
    end_time = Column(String(5), nullable=True)    # HH:MM format for daily recurring
    start_date = Column(DateTime, nullable=True)
    end_date = Column(DateTime, nullable=True)
    recurring = Column(Boolean, default=False)
    recurring_days = Column(JSON, nullable=True)  # ["monday", "tuesday", ...]
    terms = Column(String(500), nullable=True)
    is_active = Column(Boolean, default=True, index=True)
    image_url = Column(String, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationship
    bar = relationship("Bar", back_populates="promotions")