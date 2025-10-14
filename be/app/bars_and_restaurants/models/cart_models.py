"""
Cart and Checkout models for the order flow.
"""

from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
from ...database import Base


class Cart(Base):
    """Shopping cart for a user."""
    __tablename__ = "carts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True, unique=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    items = relationship("CartItem", back_populates="cart", cascade="all, delete-orphan")


class CartItem(Base):
    """Item in a shopping cart."""
    __tablename__ = "cart_items"

    id = Column(Integer, primary_key=True, index=True)
    cart_id = Column(Integer, ForeignKey("carts.id"), index=True)
    menu_item_id = Column(Integer, index=True)  # Reference to menu item
    menu_item_name = Column(String)
    bar_id = Column(Integer, ForeignKey("bars.id"))
    quantity = Column(Integer, default=1)
    unit_price = Column(Float)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    cart = relationship("Cart", back_populates="items")


class OrderItem(Base):
    """Item in an order."""
    __tablename__ = "order_items"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), index=True)
    menu_item_id = Column(Integer)
    menu_item_name = Column(String)
    quantity = Column(Integer)
    unit_price = Column(Float)
    total_price = Column(Float)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    order = relationship("Order", back_populates="items")


class OrderStatusHistory(Base):
    """History of order status changes."""
    __tablename__ = "order_status_history"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), index=True)
    status = Column(String)
    timestamp = Column(DateTime, default=datetime.utcnow)
    updated_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    updated_by_owner_id = Column(Integer, ForeignKey("bar_owners.id"), nullable=True)
    notes = Column(String, nullable=True)

    # Relationships
    order = relationship("Order", back_populates="status_history")
