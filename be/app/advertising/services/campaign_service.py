"""
BARZ Campaign Service

Handles campaign lifecycle, ad serving, and analytics.
"""
from datetime import datetime, timezone, date, timedelta
from decimal import Decimal
from typing import Optional, List, Dict, Any
import hashlib

from app.database import database
from app.errors import APIError
from sqlalchemy import func, cast, Date, select
from app.advertising.models import (
    AdvertisingCampaign, AdvertisingImpression,
    CampaignStatus, CampaignType, AdAction, BudgetType
)
from app.advertising.schemas import (
    CampaignCreate, CampaignUpdate, CampaignStatusEnum,
    FeaturedAd, SearchAd, MapSpotlight,
    DashboardAnalytics, CampaignAnalytics, DailyAnalytics
)


class CampaignService:
    """Service for managing advertising campaigns"""
    
    # =========================================================================
    # CAMPAIGN CRUD
    # =========================================================================
    
    @staticmethod
    async def list_campaigns(
        bar_id: int,
        status: Optional[CampaignStatusEnum] = None
    ) -> List[Dict[str, Any]]:
        """List all campaigns for a bar"""
        query = AdvertisingCampaign.__table__.select().where(
            AdvertisingCampaign.bar_id == bar_id
        )
        
        if status:
            query = query.where(AdvertisingCampaign.status == status.value)
        
        query = query.order_by(AdvertisingCampaign.created_at.desc())
        
        results = await database.fetch_all(query)
        return [dict(r) for r in results]
    
    @staticmethod
    async def get_campaign(campaign_id: int, bar_id: int) -> Optional[Dict[str, Any]]:
        """Get a specific campaign"""
        query = AdvertisingCampaign.__table__.select().where(
            AdvertisingCampaign.id == campaign_id,
            AdvertisingCampaign.bar_id == bar_id
        )
        result = await database.fetch_one(query)
        return dict(result) if result else None
    
    @staticmethod
    async def create_campaign(
        bar_id: int,
        subscription_id: int,
        data: CampaignCreate
    ) -> Dict[str, Any]:
        """Create a new campaign"""
        now = datetime.now(timezone.utc)
        
        # Determine initial status
        if data.start_time <= now:
            initial_status = CampaignStatus.ACTIVE.value
        else:
            initial_status = CampaignStatus.SCHEDULED.value
        
        # Prepare targeting and creative
        targeting = data.targeting.model_dump() if data.targeting else {
            "radius_km": 10,
            "days": ["mon", "tue", "wed", "thu", "fri", "sat", "sun"],
            "hours_start": 0,
            "hours_end": 24,
            "categories": [],
            "keywords": []
        }
        
        creative = data.creative.model_dump() if data.creative else {
            "logo_url": None,
            "tagline": None,
            "banner_url": None,
            "animation_url": None
        }
        
        insert_query = AdvertisingCampaign.__table__.insert().values(
            subscription_id=subscription_id,
            bar_id=bar_id,
            name=data.name,
            campaign_type=data.campaign_type.value,
            status=initial_status,
            budget_type=data.budget_type.value,
            budget_amount=data.budget_amount,
            budget_spent=Decimal("0.00"),
            start_time=data.start_time,
            end_time=data.end_time,
            targeting=targeting,
            creative=creative,
            impressions=0,
            clicks=0,
            conversions=0,
            created_at=now,
            updated_at=now
        )
        
        campaign_id = await database.execute(insert_query)
        
        # 🔔 If it's a push notification campaign, trigger the broadcast asynchronously
        if data.campaign_type.value == "push_notification":
            from app.push_queue import PushQueue
            await PushQueue.publish_campaign_launch(
                campaign_id=campaign_id,
                bar_id=bar_id,
                targeting=targeting,
                creative=creative
            )
        
        return await CampaignService.get_campaign(campaign_id, bar_id)
    
    @staticmethod
    async def update_campaign(
        campaign_id: int,
        bar_id: int,
        updates: CampaignUpdate
    ) -> Optional[Dict[str, Any]]:
        """Update campaign settings"""
        existing = await CampaignService.get_campaign(campaign_id, bar_id)
        
        if not existing:
            return None
        
        # Build update values
        update_values = {"updated_at": datetime.now(timezone.utc)}
        
        if updates.name is not None:
            update_values["name"] = updates.name
        
        if updates.budget_amount is not None:
            if updates.budget_amount < existing["budget_spent"]:
                raise APIError.bad_request("New budget cannot be less than amount already spent")
            update_values["budget_amount"] = updates.budget_amount
        
        if updates.end_time is not None:
            update_values["end_time"] = updates.end_time
        
        if updates.targeting is not None:
            update_values["targeting"] = updates.targeting.model_dump()
        
        if updates.creative is not None:
            update_values["creative"] = updates.creative.model_dump()
        
        update_query = AdvertisingCampaign.__table__.update().where(
            AdvertisingCampaign.id == campaign_id,
            AdvertisingCampaign.bar_id == bar_id
        ).values(**update_values)
        
        await database.execute(update_query)
        
        return await CampaignService.get_campaign(campaign_id, bar_id)
    
    @staticmethod
    async def pause_campaign(campaign_id: int, bar_id: int) -> None:
        """Pause an active campaign"""
        existing = await CampaignService.get_campaign(campaign_id, bar_id)
        
        if not existing:
            raise APIError.not_found("Campaign not found")
        
        if existing["status"] != "active":
            raise APIError.bad_request("Only active campaigns can be paused")
        
        update_query = AdvertisingCampaign.__table__.update().where(
            AdvertisingCampaign.id == campaign_id
        ).values(
            status=CampaignStatus.PAUSED.value,
            updated_at=datetime.now(timezone.utc)
        )
        
        await database.execute(update_query)
    
    @staticmethod
    async def resume_campaign(campaign_id: int, bar_id: int) -> None:
        """Resume a paused campaign"""
        existing = await CampaignService.get_campaign(campaign_id, bar_id)
        
        if not existing:
            raise APIError.not_found("Campaign not found")
        
        if existing["status"] != "paused":
            raise APIError.bad_request("Only paused campaigns can be resumed")
        
        # Check if budget is exhausted
        if existing["budget_spent"] >= existing["budget_amount"]:
            raise APIError.bad_request("Campaign budget is exhausted. Add more budget to resume.")
        
        update_query = AdvertisingCampaign.__table__.update().where(
            AdvertisingCampaign.id == campaign_id
        ).values(
            status=CampaignStatus.ACTIVE.value,
            updated_at=datetime.now(timezone.utc)
        )
        
        await database.execute(update_query)
    
    @staticmethod
    async def cancel_campaign(campaign_id: int, bar_id: int) -> Dict[str, Any]:
        """Cancel campaign and calculate refund"""
        existing = await CampaignService.get_campaign(campaign_id, bar_id)
        
        if not existing:
            raise APIError.not_found("Campaign not found")
        
        if existing["status"] in ["completed", "cancelled"]:
            raise APIError.bad_request("Campaign is already completed or cancelled")
        
        # Calculate refund
        budget_remaining = Decimal(str(existing["budget_amount"])) - Decimal(str(existing["budget_spent"]))
        
        update_query = AdvertisingCampaign.__table__.update().where(
            AdvertisingCampaign.id == campaign_id
        ).values(
            status=CampaignStatus.CANCELLED.value,
            updated_at=datetime.now(timezone.utc)
        )
        
        await database.execute(update_query)
        
        # TODO: Process refund via payment gateway or restore credits
        
        return {
            "amount": float(budget_remaining),
            "credits": {}  # TODO: Return refunded credits if budget_type was credits
        }
    
    # =========================================================================
    # AD SERVING
    # =========================================================================
    
    @staticmethod
    async def serve_featured(
        latitude: float,
        longitude: float,
        limit: int = 10
    ) -> List[FeaturedAd]:
        """Get featured ads for home screen based on location"""
        now = datetime.now(timezone.utc)
        current_day = now.strftime("%a").lower()[:3]
        current_hour = now.hour
        
        # Query active featured campaigns
        # Note: In production, this would use MongoDB with geospatial index
        # For now, we fetch all active featured campaigns and filter
        query = AdvertisingCampaign.__table__.select().where(
            AdvertisingCampaign.campaign_type == "featured",
            AdvertisingCampaign.status == "active",
            AdvertisingCampaign.budget_spent < AdvertisingCampaign.budget_amount
        ).limit(limit * 2)  # Fetch more to allow filtering
        
        results = await database.fetch_all(query)
        
        featured_ads = []
        for campaign in results:
            targeting = campaign["targeting"] or {}
            
            # Filter by day
            days = targeting.get("days", ["mon", "tue", "wed", "thu", "fri", "sat", "sun"])
            if current_day not in days:
                continue
            
            # Filter by hour
            hours_start = targeting.get("hours_start", 0)
            hours_end = targeting.get("hours_end", 24)
            if not (hours_start <= current_hour < hours_end):
                continue
            
            # Get bar info (simplified - in production, join with bars table)
            creative = campaign["creative"] or {}
            
            featured_ads.append(FeaturedAd(
                bar_id=campaign["bar_id"],
                bar_name=f"Bar {campaign['bar_id']}",  # TODO: Get actual bar name
                logo_url=creative.get("logo_url"),
                tagline=creative.get("tagline"),
                distance_km=0.0,  # TODO: Calculate actual distance
                campaign_id=campaign["id"]
            ))
            
            if len(featured_ads) >= limit:
                break
        
        return featured_ads
    
    @staticmethod
    async def serve_search(
        latitude: float,
        longitude: float,
        search_query: Optional[str] = None,
        category: Optional[str] = None,
        limit: int = 3
    ) -> List[SearchAd]:
        """Get sponsored search results"""
        now = datetime.now(timezone.utc)
        
        query = AdvertisingCampaign.__table__.select().where(
            AdvertisingCampaign.campaign_type == "search",
            AdvertisingCampaign.status == "active",
            AdvertisingCampaign.budget_spent < AdvertisingCampaign.budget_amount
        ).limit(limit)
        
        results = await database.fetch_all(query)
        
        search_ads = []
        for i, campaign in enumerate(results):
            creative = campaign["creative"] or {}
            
            search_ads.append(SearchAd(
                bar_id=campaign["bar_id"],
                bar_name=f"Bar {campaign['bar_id']}",
                logo_url=creative.get("logo_url"),
                tagline=creative.get("tagline"),
                position=i,
                campaign_id=campaign["id"]
            ))
        
        return search_ads
    
    @staticmethod
    async def serve_map(
        latitude: float,
        longitude: float,
        zoom_level: int,
        limit: int = 5
    ) -> List[MapSpotlight]:
        """Get map spotlight ads"""
        query = AdvertisingCampaign.__table__.select().where(
            AdvertisingCampaign.campaign_type == "map",
            AdvertisingCampaign.status == "active",
            AdvertisingCampaign.budget_spent < AdvertisingCampaign.budget_amount
        ).limit(limit)
        
        results = await database.fetch_all(query)
        
        map_ads = []
        for campaign in results:
            creative = campaign["creative"] or {}
            
            # TODO: Get actual bar location
            map_ads.append(MapSpotlight(
                bar_id=campaign["bar_id"],
                bar_name=f"Bar {campaign['bar_id']}",
                latitude=latitude + 0.001,  # Placeholder
                longitude=longitude + 0.001,
                logo_url=creative.get("logo_url"),
                campaign_id=campaign["id"]
            ))
        
        return map_ads
    
    # =========================================================================
    # EVENT TRACKING
    # =========================================================================
    
    @staticmethod
    async def track_event(
        campaign_id: int,
        action: str,
        placement: str,
        user_id: Optional[int] = None,
        session_id: Optional[str] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None
    ) -> None:
        """Track an ad impression, click, or conversion"""
        now = datetime.now(timezone.utc)
        
        # Hash IP for privacy
        ip_hash = None
        if ip_address:
            ip_hash = hashlib.sha256(ip_address.encode()).hexdigest()[:64]
        
        # Get action enum value
        action_value = action.value if hasattr(action, 'value') else action
        
        # Insert impression record
        insert_query = AdvertisingImpression.__table__.insert().values(
            campaign_id=campaign_id,
            action=action_value,
            placement=placement,
            user_id=str(user_id) if user_id else None,  # Convert to string for DB
            session_id=session_id,
            latitude=latitude,
            longitude=longitude,
            ip_address=ip_address[:45] if ip_address else None,
            ip_hash=ip_hash,
            user_agent=user_agent[:500] if user_agent else None,
            timestamp=now
        )
        
        await database.execute(insert_query)
        
        # Update campaign counters
        if action_value == "impression":
            await CampaignService._increment_counter(campaign_id, "impressions")
        elif action_value == "click":
            await CampaignService._increment_counter(campaign_id, "clicks")
            # For CPC campaigns, deduct from budget
            await CampaignService._process_click_billing(campaign_id)
        elif action_value == "conversion":
            await CampaignService._increment_counter(campaign_id, "conversions")
    
    @staticmethod
    async def _increment_counter(campaign_id: int, counter: str) -> None:
        """Increment a campaign counter"""
        # Use raw SQL for atomic increment
        query = f"""
            UPDATE advertising_campaigns 
            SET {counter} = {counter} + 1, updated_at = :now
            WHERE id = :campaign_id
        """
        await database.execute(query, {"campaign_id": campaign_id, "now": datetime.now(timezone.utc)})
    
    @staticmethod
    async def _process_click_billing(campaign_id: int) -> None:
        """Process billing for CPC campaigns"""
        # Get campaign
        query = AdvertisingCampaign.__table__.select().where(
            AdvertisingCampaign.id == campaign_id
        )
        campaign = await database.fetch_one(query)
        
        if not campaign or campaign["budget_type"] != "cpc":
            return
        
        # TODO: Get CPC rate from region pricing
        cpc_rate = Decimal("0.50")  # Placeholder
        
        new_spent = Decimal(str(campaign["budget_spent"])) + cpc_rate
        
        # Update budget spent
        update_query = AdvertisingCampaign.__table__.update().where(
            AdvertisingCampaign.id == campaign_id
        ).values(
            budget_spent=new_spent,
            updated_at=datetime.now(timezone.utc)
        )
        await database.execute(update_query)
        
        # Check if budget exhausted
        if new_spent >= Decimal(str(campaign["budget_amount"])):
            await CampaignService._exhaust_campaign(campaign_id)
    
    @staticmethod
    async def _exhaust_campaign(campaign_id: int) -> None:
        """Mark campaign as completed when budget is exhausted"""
        update_query = AdvertisingCampaign.__table__.update().where(
            AdvertisingCampaign.id == campaign_id
        ).values(
            status=CampaignStatus.COMPLETED.value,
            updated_at=datetime.now(timezone.utc)
        )
        await database.execute(update_query)
    
    # =========================================================================
    # ANALYTICS
    # =========================================================================
    
    @staticmethod
    async def get_dashboard_analytics(
        bar_id: int,
        start_date: date,
        end_date: date
    ) -> DashboardAnalytics:
        """Get aggregated analytics for all campaigns"""
        start_dt = datetime.combine(start_date, datetime.min.time()).replace(tzinfo=timezone.utc)
        end_dt = datetime.combine(end_date, datetime.max.time()).replace(tzinfo=timezone.utc)
        
        # Get all campaigns for the bar
        campaigns_query = AdvertisingCampaign.__table__.select().where(
            AdvertisingCampaign.bar_id == bar_id
        )
        campaigns = await database.fetch_all(campaigns_query)
        
        total_impressions = 0
        total_clicks = 0
        total_conversions = 0
        total_spend = Decimal("0.00")
        
        campaign_analytics = []
        campaign_ids = [c["id"] for c in campaigns]
        
        # Get overall daily stats
        daily_stats = await CampaignService._get_daily_stats(campaign_ids, start_dt, end_dt) if campaign_ids else []
        
        for campaign in campaigns:
            impressions = campaign["impressions"] or 0
            clicks = campaign["clicks"] or 0
            conversions = campaign["conversions"] or 0
            spend = Decimal(str(campaign["budget_spent"]))
            ctr = (clicks / impressions * 100) if impressions > 0 else 0.0
            
            total_impressions += impressions
            total_clicks += clicks
            total_conversions += conversions
            total_spend += spend
            
            # For each campaign, get its own daily stats
            c_daily = await CampaignService._get_daily_stats([campaign["id"]], start_dt, end_dt)
            
            campaign_analytics.append(CampaignAnalytics(
                campaign_id=campaign["id"],
                campaign_name=campaign["name"],
                impressions=impressions,
                clicks=clicks,
                conversions=conversions,
                ctr=ctr,
                spend=spend,
                period_start=start_dt,
                period_end=end_dt,
                daily_stats=c_daily
            ))
        
        average_ctr = (total_clicks / total_impressions * 100) if total_impressions > 0 else 0.0
        
        return DashboardAnalytics(
            total_impressions=total_impressions,
            total_clicks=total_clicks,
            total_conversions=total_conversions,
            total_spend=total_spend,
            average_ctr=average_ctr,
            campaigns=campaign_analytics,
            daily_stats=daily_stats,
            period_start=start_dt,
            period_end=end_dt
        )
    
    @staticmethod
    async def get_campaign_analytics(
        campaign_id: int,
        bar_id: int,
        start_date: date,
        end_date: date
    ) -> Optional[CampaignAnalytics]:
        """Get analytics for a specific campaign"""
        campaign = await CampaignService.get_campaign(campaign_id, bar_id)
        
        if not campaign:
            return None
        
        start_dt = datetime.combine(start_date, datetime.min.time()).replace(tzinfo=timezone.utc)
        end_dt = datetime.combine(end_date, datetime.max.time()).replace(tzinfo=timezone.utc)
        
        impressions = campaign["impressions"] or 0
        clicks = campaign["clicks"] or 0
        conversions = campaign["conversions"] or 0
        spend = Decimal(str(campaign["budget_spent"]))
        ctr = (clicks / impressions * 100) if impressions > 0 else 0.0
        
        daily_stats = await CampaignService._get_daily_stats([campaign_id], start_dt, end_dt)
        
        return CampaignAnalytics(
            campaign_id=campaign["id"],
            campaign_name=campaign["name"],
            impressions=impressions,
            clicks=clicks,
            conversions=conversions,
            ctr=ctr,
            spend=spend,
            period_start=start_dt,
            period_end=end_dt,
            daily_stats=daily_stats
        )

    @staticmethod
    async def _get_daily_stats(
        campaign_ids: List[int],
        start_dt: datetime,
        end_dt: datetime
    ) -> List[DailyAnalytics]:
        """Fetch daily stats from impressions log"""
        # Group by date and action using SQLAlchemy
        # Note: func.date() works for Postgres. For SQLite, it might be different, but we assume Postgres.
        query = select(
            func.date(AdvertisingImpression.timestamp).label("day"),
            AdvertisingImpression.action,
            func.count(AdvertisingImpression.id).label("count")
        ).where(
            AdvertisingImpression.campaign_id.in_(campaign_ids),
            AdvertisingImpression.timestamp >= start_dt,
            AdvertisingImpression.timestamp <= end_dt
        ).group_by(
            func.date(AdvertisingImpression.timestamp),
            AdvertisingImpression.action
        )
        
        results = await database.fetch_all(query)
        
        # Consolidate results by day
        stats_by_day = {}
        for row in results:
            # Row access depends on the raw database result format
            # day can be a date object or string
            day_val = row["day"]
            day_str = day_val.isoformat() if hasattr(day_val, 'isoformat') else str(day_val)
            
            if day_str not in stats_by_day:
                stats_by_day[day_str] = DailyAnalytics(date=day_str)
            
            action = row["action"]
            count = row["count"]
            
            # AdAction values are lowercase strings
            if action == AdAction.IMPRESSION.value:
                stats_by_day[day_str].impressions = count
            elif action == AdAction.CLICK.value:
                stats_by_day[day_str].clicks = count
            elif action == AdAction.CONVERSION.value:
                stats_by_day[day_str].conversions = count
        
        # Sort by date and return
        return sorted(stats_by_day.values(), key=lambda x: x.date)
