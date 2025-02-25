from sqlalchemy import Column, Integer, String, Boolean, ForeignKey
from ..database import Base

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

class Token(Base):
    __tablename__ = "tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)  # Foreign key to User
    token = Column(String, unique=True, index=True)  # Authentication token
    expiry_date = Column(Integer)  # Expiry date in timestamp format