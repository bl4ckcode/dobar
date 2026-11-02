import asyncio
import logging
from datetime import datetime
from app.database import SessionLocal
from ..models.onboarding import OnboardingProjection, OnboardingAsset
from ..models.nosql_models import bars_collection

logger = logging.getLogger(__name__)


async def project_pending():
    with SessionLocal() as db:
        entries = db.query(OnboardingProjection).filter_by(completed_at=None).order_by(OnboardingProjection.bar_id).limit(20).with_for_update(skip_locked=True).all()
        for entry in entries:
            entry.attempts += 1
            try:
                await asyncio.wait_for(bars_collection.update_one({"bar_id": entry.bar_id}, {"$set": entry.payload}, upsert=True), timeout=8)
                entry.completed_at = datetime.utcnow()
            except Exception:
                logger.warning("Venue projection retry pending for bar_id=%s", entry.bar_id)
        db.commit()
    from .image_upload import s3_client
    import os
    with SessionLocal() as db:
        assets = db.query(OnboardingAsset).filter_by(removed=1).limit(20).with_for_update(skip_locked=True).all()
        for asset in assets:
            try:
                await asyncio.to_thread(s3_client.delete_object, Bucket=os.environ["AWS_S3_BUCKET"], Key=asset.object_key)
                asset.removed = 2
            except Exception:
                logger.warning("Draft asset cleanup pending for asset_id=%s", asset.id)
        db.commit()


async def projection_worker():
    while True:
        try:
            await project_pending()
        except Exception:
            logger.warning("Venue projection worker unavailable")
        await asyncio.sleep(30)
