from datetime import datetime
from sqlalchemy import Column, String, Integer, ForeignKey, DateTime, JSON, Text, UniqueConstraint
from app.database import Base


class OnboardingDraft(Base):
    __tablename__ = "venue_onboarding_drafts"
    __table_args__ = (UniqueConstraint("owner_id", "creation_key", name="uq_venue_draft_owner_key"), UniqueConstraint("owner_id", "finalize_key", name="uq_venue_draft_finalize_key"))

    id = Column(String(36), primary_key=True)
    owner_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    creation_key = Column(String(80), nullable=False)
    version = Column(Integer, nullable=False, default=1)
    payload = Column(JSON, nullable=False, default=dict)
    steps = Column(JSON, nullable=False, default=dict)
    bank_encrypted = Column(Text, nullable=True)
    bank_summary = Column(JSON, nullable=True)
    bar_id = Column(Integer, ForeignKey("bars.id"), unique=True, nullable=True)
    finalize_key = Column(String(80), nullable=True)
    finalized_version = Column(Integer, nullable=True)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow)


class OnboardingAsset(Base):
    __tablename__ = "venue_onboarding_assets"
    __table_args__ = (UniqueConstraint("draft_id", "client_key", name="uq_venue_draft_asset_key"),)

    id = Column(String(36), primary_key=True)
    draft_id = Column(String(36), ForeignKey("venue_onboarding_drafts.id", ondelete="CASCADE"), nullable=False, index=True)
    client_key = Column(String(80), nullable=False)
    slot = Column(String(10), nullable=False)
    filename = Column(String(255), nullable=False)
    digest = Column(String(64), nullable=False)
    object_key = Column(String(255), nullable=False)
    removed = Column(Integer, nullable=False, default=0)
    status = Column(String(10), nullable=False, default="pending")


class OnboardingProjection(Base):
    __tablename__ = "venue_onboarding_projections"

    bar_id = Column(Integer, ForeignKey("bars.id", ondelete="CASCADE"), primary_key=True)
    payload = Column(JSON, nullable=False)
    completed_at = Column(DateTime, nullable=True)
    attempts = Column(Integer, nullable=False, default=0)
