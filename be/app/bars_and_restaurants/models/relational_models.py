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
    
    # 🆕 Country & Business ID fields (for Create Bar Wizard)
    country_code = Column(String(2), index=True, default="BR")  # ISO 3166-1 alpha-2
    business_id = Column(String(50), index=True, nullable=True)  # CNPJ, NIF, EIN, etc.
    business_id_type = Column(String(20), nullable=True)  # "CNPJ", "NIF", "EIN", "CIF", "RFC", "CUIT"
    state_registration = Column(String(50), nullable=True)  # Brazil-specific (Inscrição Estadual)
    verification_status = Column(String(20), default="pending", index=True)  # pending, under_review, verified, rejected
    
    # 🆕 Media fields
    logo_url = Column(String, nullable=True)
    cover_url = Column(String, nullable=True)
    photo_urls = Column(JSON, nullable=True)  # Array of gallery image URLs
    
    # 🆕 Operating hours (stored as JSON for flexibility)
    operating_hours = Column(JSON, nullable=True)
    
    category = Column(String(50), index=True, nullable=True)
    google_types = Column(JSON, nullable=True)
    
    # 🆕 Place Location Logic (Where are you?)
    location_method = Column(String(20), default="table_number")  # table_number, spot_list, free_text
    location_spots = Column(JSON, nullable=True, default=list)  # List of {id, name} objects
    
    # 🆕 Subscription caching for fast search weighting
    subscription_tier = Column(String(20), default="regular", index=True)  # regular, master, vip
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    owner = relationship("BarOwner", back_populates="bars")
    menus = relationship("Menu", back_populates="bar")
    promotions = relationship("Promotion", back_populates="bar")
    bundle_promotions = relationship("BundlePromotion", back_populates="bar")
    cashback_transactions = relationship("CashbackLedger", back_populates="bar")
    advertising_subscription = relationship("AdvertisingSubscription", back_populates="bar", uselist=False)

class Menu(Base):
    __tablename__ = "menus"

    id = Column(Integer, primary_key=True, index=True)
    bar_id = Column(Integer, ForeignKey("bars.id"), index=True)
    name = Column(String, nullable=True, default="Menu Principal")
    description = Column(String, nullable=True)
    is_active = Column(Boolean, nullable=True, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    bar = relationship("Bar", back_populates="menus")
    items = relationship("MenuItem", back_populates="menu", cascade="all, delete-orphan")


class MenuItem(Base):
    """Menu item stored in PostgreSQL for referential integrity with orders."""
    __tablename__ = "menu_items"

    id = Column(Integer, primary_key=True, index=True)
    menu_id = Column(Integer, ForeignKey("menus.id", ondelete="CASCADE"), index=True, nullable=False)
    name = Column(String(200), nullable=False)
    price = Column(Float, nullable=False)
    promotional_price = Column(Float, nullable=True)
    description = Column(String(500), nullable=True)
    category = Column(String(100), nullable=True, index=True)  # drinks, food, appetizers, etc.
    picture = Column(String, nullable=True)
    available = Column(Boolean, default=True, index=True)
    display_order = Column(Integer, default=0)  # For sorting items in menu
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    menu = relationship("Menu", back_populates="items")


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
    delivery_address = Column(String, nullable=True)
    special_instructions = Column(String, nullable=True)
    
    # 🆕 Location & Promotions
    location_identifier = Column(String, nullable=True)  # "5", "vip_1"
    active_promotion_ids = Column(JSON, nullable=True)  # List of promo IDs selected by user
    is_priority = Column(Boolean, default=False, index=True)
    
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
    benefit_text = Column(String(200), nullable=True)  # "5% cashback" - Short text for UI
    promotion_type = Column(String(20), default="discount")  # discount, cashback, points
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
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    bar = relationship("Bar", back_populates="promotions")


class BundlePromotion(Base):
    __tablename__ = "bundle_promotions"

    id = Column(Integer, primary_key=True, index=True)
    bar_id = Column(Integer, ForeignKey("bars.id"), index=True, nullable=False)
    
    name = Column(String(100), nullable=False)
    description = Column(String(500), nullable=True)
    
    bundle_type = Column(String(20), nullable=False, default="quantity")
    
    min_quantity = Column(Integer, nullable=True, default=2)
    target_items = Column(JSON, nullable=True)
    target_category = Column(String(100), nullable=True)
    
    discount_type = Column(String(20), nullable=False, default="percentage")
    discount_value = Column(Float, nullable=False, default=0.0)
    
    start_time = Column(String(5), nullable=True)
    end_time = Column(String(5), nullable=True)
    recurring_days = Column(JSON, nullable=True)
    start_date = Column(DateTime, nullable=True)
    end_date = Column(DateTime, nullable=True)
    
    max_uses_per_user = Column(Integer, nullable=True)
    is_active = Column(Boolean, default=True, index=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    bar = relationship("Bar", back_populates="bundle_promotions")


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    title = Column(String(200), nullable=False)
    message = Column(String(500), nullable=True)
    notification_type = Column(String(50), nullable=False, default="system")
    is_read = Column(Boolean, default=False, index=True)
    reference_id = Column(String, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)