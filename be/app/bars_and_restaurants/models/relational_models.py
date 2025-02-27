from sqlalchemy import Column, Integer, String, Float, ForeignKey
from sqlalchemy.orm import relationship
from ...database import Base  # Ensure this is the correct import path

class BarOwner(Base):
    __tablename__ = "bar_owners"  # Separate table for bar owners

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True, nullable=True)
    email = Column(String, unique=True, index=True)
    phone_number = Column(String)
    
class Bar(Base):
    __tablename__ = "bars"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    address = Column(String, unique=True, index=True, nullable=True)
    phone_number = Column(String, unique=True, index=True, nullable=True)
    email = Column(String, unique=True, index=True, nullable=True)
    owner_id = Column(Integer, ForeignKey("bar_owners.id"), index=True)  # Link to bar owner

    # Relationship with menus
    menus = relationship("Menu", back_populates="bar")

class Menu(Base):
    __tablename__ = "menus"

    id = Column(Integer, primary_key=True, index=True)
    bar_id = Column(Integer, ForeignKey("bars.id"), index=True)

    # Relationship with bars
    bar = relationship("Bar", back_populates="menus")

class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    bar_id = Column(Integer, ForeignKey("bars.id"), index=True)
    status = Column(String, nullable=True)  # e.g., "pending", "completed", "cancelled"
    total_price = Column(Float, nullable=True)