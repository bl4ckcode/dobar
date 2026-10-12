from sqlalchemy import Column, Integer, String, BigInteger, DateTime, Boolean, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime
from ...database import Base


class BarBankAccount(Base):
    __tablename__ = "bar_bank_accounts"

    id = Column(Integer, primary_key=True, index=True)
    bar_id = Column(Integer, ForeignKey("bars.id", ondelete="CASCADE"), unique=True, index=True, nullable=False)
    country_code = Column(String(2), nullable=False, index=True)
    
    bank_code = Column(String(10), nullable=True)
    branch_code = Column(String(10), nullable=True)
    account_number_encrypted = Column(Text, nullable=True)
    account_type = Column(String(20), nullable=True)
    
    pix_key_encrypted = Column(Text, nullable=True)
    pix_key_type = Column(String(20), nullable=True)
    
    clabe_encrypted = Column(Text, nullable=True)
    
    cbu_encrypted = Column(Text, nullable=True)
    
    routing_number = Column(String(9), nullable=True)
    
    account_holder_name = Column(String(255), nullable=True)
    is_verified = Column(Boolean, default=False, index=True)
    stripe_external_account_id = Column(String(255), nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    bar = relationship("Bar", backref="bank_account")
