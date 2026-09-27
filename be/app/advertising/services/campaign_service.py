"""
BARZ Campaign Service

Handles campaign lifecycle, ad serving, and analytics.
"""
from datetime import datetime, timezone, date, timedelta
from decimal import Decimal
from typing import Optional, List, Dict, Any
import hashlib

from app.database import database
from app.redis_client import get_redis, CacheService
from app.errors import APIError
from sqlalchemy import func, select
from app.advertising.models import (
    AdvertisingCampaign, AdvertisingImpression, AdvertisingSubscription,
    CampaignStatus, AdAction
)
from app.advertising.schemas import (
    CampaignCreate, CampaignUpdate, CampaignStatusEnum,
    FeaturedAd, SearchAd, MapSpotlight,
    DashboardAnalytics, CampaignAnalytics, DailyAnalytics,
    EstimatedPerformance, CampaignGoalEnum
)
from app.advertising.pricing import credit_bucket_for_placement, distribution_to_storage

class CampaignService:
    """Service for managing advertising campaigns"""
    
    # =========================================================================
    # CAMPAIGN CRUD
    # =========================================================================
    
    @staticmethod
    async def list_campaigns(
        bar_id: int,
        status: Optional[str] = None,
        sort: Optional[str] = None,
        search: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """List all campaigns for a bar with optional filtering and sorting."""
        query = AdvertisingCampaign.__table__.select().where(
            AdvertisingCampaign.bar_id == bar_id
        )
        
        # Filter by status
        if status and status != "all":
            # Map status values to handle both the enum values and "all"
            status_map = {
                "draft": "draft",
                "scheduled": "scheduled",
                "active": "active",
                "paused": "paused",
                "completed": "completed",
                "cancelled": "cancelled"
            }
            query_status = status_map.get(status)
            if query_status:
                query = query.where(AdvertisingCampaign.status == query_status)
        
        # Search by name
        if search:
            query = query.where(AdvertisingCampaign.name.ilike(f"%{search}%"))
        
        # Sorting
        if sort == "budget_amount":
            query = query.order_by(AdvertisingCampaign.budget_amount.desc())
        elif sort == "performance":
            # Sort by clicks (as a proxy for performance)
            query = query.order_by(AdvertisingCampaign.clicks.desc())
        else:
            # Default: sort by created_at descending
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
        """Create a new campaign with support for multi-placement campaigns."""
        now = datetime.now(timezone.utc)
        
        # Draft campaigns remain in draft status
        initial_status = CampaignStatus.DRAFT.value
        
        # Infer campaign_goal from campaign_type if not provided (backward compatibility)
        campaign_goal = data.campaign_goal
        if campaign_goal is None and data.campaign_type is not None:
            goal_mapping = {
                "featured": "discovery",
                "search": "foot_traffic",
                "map": "foot_traffic",
                "promo_boost": "promotion",
                "banner": "promotion"
            }
            campaign_goal = CampaignGoalEnum(goal_mapping.get(data.campaign_type.value, "discovery"))
        
        # Prepare targeting (use ExtendedTargeting structure)
        targeting = data.targeting.model_dump() if data.targeting else {
            "radius_km": 5,
            "peak_hours_only": False,
            "age_range": None
        }
        
        # Prepare creative
        creative = data.creative.model_dump() if data.creative else {
            "logo_url": None,
            "tagline": None,
            "banner_url": None,
            "animation_url": None,
            "promoted_item_id": None
        }
        
        # Prepare distribution
        distribution = distribution_to_storage(data.distribution)
        
        # Generate estimated performance
        estimated_performance = None
        if data.is_smart_distribution or data.distribution:
            estimated_performance = CampaignService._estimate_performance(data.budget_amount, data.distribution or [])
        elif data.campaign_type is not None:
            # Generate estimated performance for single-placement campaigns too
            estimated_performance = CampaignService._estimate_performance(data.budget_amount, [])
        
        # Generate campaign name if not provided
        campaign_name = data.name or f"Campaign {now.strftime('%Y-%m-%d')}"
        
        insert_values = {
            "subscription_id": subscription_id,
            "bar_id": bar_id,
            "name": campaign_name,
            "status": initial_status,
            "budget_type": data.budget_type.value,
            "budget_amount": data.budget_amount,
            "budget_spent": Decimal("0.00"),
            "start_time": data.start_time,
            "end_time": data.end_time,
            "targeting": targeting,
            "creative": creative,
            "impressions": 0,
            "clicks": 0,
            "conversions": 0,
            "created_at": now,
            "updated_at": now,
            "campaign_goal": campaign_goal.value if campaign_goal else None,
            "distribution": distribution,
            "is_smart_distribution": data.is_smart_distribution,
            "budget_optimizer_enabled": data.budget_optimizer_enabled,
            "estimated_performance": estimated_performance.model_dump() if estimated_performance else None
        }
        
        # Add campaign_type only if specified (for backward compatibility with single-type campaigns)
        if data.campaign_type:
            insert_values["campaign_type"] = data.campaign_type.value
        
        insert_query = AdvertisingCampaign.__table__.insert().values(**insert_values)
        
        campaign_id = await database.execute(insert_query)
        
        # Invalidate cache for this bar's campaigns
        await CacheService.delete_pattern(f"campaigns:{bar_id}:*")
        await CacheService.delete(f"campaigns:analytics:summary:{bar_id}")
        
        return await CampaignService.get_campaign(campaign_id, bar_id)
    
    @staticmethod
    def _estimate_performance(budget_amount: Decimal, distribution: List) -> EstimatedPerformance:
        """Estimate performance based on budget and distribution."""
        # Simple estimation logic based on campaign_creation_strategy.md
        # Assumes 7-day campaign period
        daily_budget = float(budget_amount) / 7
        
        # Rough estimates per placement type (impressions/clicks per BRL)
        estimates = {
            "featured": {"impressions": 1500, "clicks": 40},
            "search": {"impressions": 800, "clicks": 80},
            "map_pin": {"impressions": 2000, "clicks": 30},
            "promo": {"impressions": 600, "clicks": 60},
            "banner": {"impressions": 1000, "clicks": 25}
        }
        
        total_impressions = 0
        total_clicks = 0
        
        for dist in distribution:
            # Handle both dict and Pydantic model
            if hasattr(dist, "model_dump"):
                placement = dist.placement
                pct = dist.percentage / 100
            else:
                placement = dist.get("placement", "")
                pct = dist.get("percentage", 0) / 100
            if placement in estimates:
                total_impressions += int(estimates[placement]["impressions"] * daily_budget * pct / 40)
                total_clicks += int(estimates[placement]["clicks"] * daily_budget * pct / 20)
        
        return EstimatedPerformance(
            daily_reach=total_impressions // 2,
            estimated_clicks=total_clicks,
            estimated_impressions=total_impressions
        )
    
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
            if float(updates.budget_amount) < float(existing["budget_spent"]):
                raise APIError.bad_request("New budget cannot be less than amount already spent")
            update_values["budget_amount"] = updates.budget_amount
        
        if updates.end_time is not None:
            update_values["end_time"] = updates.end_time
        
        if updates.targeting is not None:
            update_values["targeting"] = updates.targeting.model_dump()
        
        if updates.creative is not None:
            update_values["creative"] = updates.creative.model_dump()
        
        if updates.distribution is not None:
            update_values["distribution"] = distribution_to_storage(updates.distribution)
            # Recalculate estimated performance
            from app.advertising.schemas import EstimatedPerformance
            est = CampaignService._estimate_performance(existing["budget_amount"], update_values["distribution"])
            update_values["estimated_performance"] = est.model_dump()
        
        if updates.campaign_goal is not None:
            update_values["campaign_goal"] = updates.campaign_goal.value
        
        if updates.budget_optimizer_enabled is not None:
            update_values["budget_optimizer_enabled"] = updates.budget_optimizer_enabled
        
        update_query = AdvertisingCampaign.__table__.update().where(
            AdvertisingCampaign.id == campaign_id,
            AdvertisingCampaign.bar_id == bar_id
        ).values(**update_values)
        
        await database.execute(update_query)
        
        # Invalidate cache
        await CacheService.delete_pattern(f"campaigns:{bar_id}:*")
        
        return await CampaignService.get_campaign(campaign_id, bar_id)
    
    @staticmethod
    async def publish_campaign(campaign_id: int, bar_id: int) -> Optional[Dict[str, Any]]:
        """Convert draft to active and trigger budget reservation."""
        existing = await CampaignService.get_campaign(campaign_id, bar_id)
        
        if not existing:
            return None
        
        if existing["status"] != "draft":
            raise APIError.bad_request("Only draft campaigns can be published")
        
        now = datetime.now(timezone.utc)
        
        # Determine target status based on start_time
        target_status = CampaignStatus.ACTIVE.value if existing["start_time"] <= now else CampaignStatus.SCHEDULED.value
        
        update_query = AdvertisingCampaign.__table__.update().where(
            AdvertisingCampaign.id == campaign_id
        ).values(
            status=target_status,
            updated_at=now
        )
        
        await database.execute(update_query)
        
        # Invalidate cache
        await CacheService.delete_pattern(f"campaigns:{bar_id}:*")
        await CacheService.delete(f"campaigns:analytics:summary:{bar_id}")
        
        # Return with estimated performance
        estimated = existing.get("estimated_performance") or {"daily_reach": 0, "estimated_clicks": 0, "estimated_impressions": 0}
        
        return {
            "id": campaign_id,
            "status": target_status,
            "estimated_performance": estimated
        }
    
    @staticmethod
    async def get_campaigns_summary(bar_id: int) -> Dict[str, Any]:
        """Get aggregated stats for all campaigns of a bar."""
        query = AdvertisingCampaign.__table__.select().where(
            AdvertisingCampaign.bar_id == bar_id
        )
        campaigns = await database.fetch_all(query)
        
        total_campaigns = len(campaigns)
        active_campaigns = sum(1 for c in campaigns if c["status"] == "active")
        scheduled_campaigns = sum(1 for c in campaigns if c["status"] == "scheduled")
        draft_campaigns = sum(1 for c in campaigns if c["status"] == "draft")
        completed_campaigns = sum(1 for c in campaigns if c["status"] == "completed")
        
        total_spent = sum(Decimal(str(c["budget_spent"])) for c in campaigns)
        total_budget = sum(Decimal(str(c["budget_amount"])) for c in campaigns)
        total_remaining = total_budget - total_spent
        
        total_impressions = sum(c["impressions"] or 0 for c in campaigns)
        total_clicks = sum(c["clicks"] or 0 for c in campaigns)
        
        return {
            "total_campaigns": total_campaigns,
            "active_campaigns": active_campaigns,
            "scheduled_campaigns": scheduled_campaigns,
            "draft_campaigns": draft_campaigns,
            "completed_campaigns": completed_campaigns,
            "total_spent": float(total_spent),
            "total_remaining": float(total_remaining),
            "total_impressions": total_impressions,
            "total_clicks": total_clicks
        }
    
    @staticmethod
    async def get_campaigns_analytics_summary(bar_id: int) -> Dict[str, Any]:
        """Get aggregated analytics summary for all campaigns of a bar (DOB-83)."""
        now = datetime.now(timezone.utc)
        
        # Try cache first
        cache_key = f"campaigns:analytics:summary:{bar_id}"
        cached = await CacheService.get(cache_key)
        if cached:
            return cached
        
        # Get campaigns for performance metrics
        campaigns_query = AdvertisingCampaign.__table__.select().where(
            AdvertisingCampaign.bar_id == bar_id
        )
        campaigns = await database.fetch_all(campaigns_query)
        
        campaign_ids = [c["id"] for c in campaigns]
        
        total_impressions = sum(c["impressions"] or 0 for c in campaigns)
        total_clicks = sum(c["clicks"] or 0 for c in campaigns)
        total_spent = sum(Decimal(str(c["budget_spent"])) for c in campaigns)
        budget_remaining = sum(Decimal(str(c["budget_amount"])) - Decimal(str(c["budget_spent"])) for c in campaigns)
        
        # Calculate average CTR
        average_ctr = (total_clicks / total_impressions * 100) if total_impressions > 0 else 0.0
        
        # Determine best performing placement by distribution percentage
        best_placement = None
        highest_percentage = 0
        for campaign in campaigns:
            distribution = campaign.get("distribution") or []
            for dist in distribution:
                if dist.get("percentage", 0) > highest_percentage:
                    highest_percentage = dist.get("percentage", 0)
                    best_placement = dist.get("placement")
        
        # Get 7-day trend using raw SQL for simpler aggregation
        if campaign_ids:
            trend_query = """
                SELECT 
                    DATE(timestamp) as day,
                    COUNT(CASE WHEN action = 'impression' THEN 1 END) as impressions,
                    COUNT(CASE WHEN action = 'click' THEN 1 END) as clicks
                FROM advertising_impressions 
                WHERE campaign_id = ANY(%s) 
                GROUP BY DATE(timestamp)
                ORDER BY day ASC
            """
            trend_results = await database.fetch_all(trend_query, [campaign_ids])
        else:
            trend_results = []
        
        trend = []
        for row in trend_results:
            day_val = row["day"]
            day_str = day_val.isoformat() if hasattr(day_val, 'isoformat') else str(day_val)
            clicks_count = int(row["clicks"] or 0)
            trend.append({
                "date": day_str,
                "impressions": int(row["impressions"] or 0),
                "clicks": clicks_count,
                "spend": float(Decimal(str(clicks_count)) * Decimal("0.50"))
            })
        
        result = {
            "total_impressions": total_impressions,
            "total_clicks": total_clicks,
            "average_ctr": round(average_ctr, 2),
            "total_spent": float(total_spent),
            "active_campaigns": sum(1 for c in campaigns if c["status"] == "active"),
            "total_campaigns": len(campaigns),
            "budget_remaining": float(budget_remaining),
            "daily_avg_spend": float(total_spent / 7) if total_spent > 0 else 0.0,
            "best_performing_placement": best_placement,
            "trend": trend
        }
        
        # Cache for 5 minutes
        await CacheService.set(cache_key, result, ttl=300)
        
        return result
    
    @staticmethod
    async def pause_campaign(campaign_id: int, bar_id: int) -> Dict[str, Any]:
        """
        Pause an active campaign and store paused_at for pro-ration.
        
        Pro-ration is calculated based on the time the campaign was active
        vs. the total scheduled duration. When resumed, the end_time will
        be extended to compensate for paused time, ensuring the bar owner
        gets the full value of their budget.
        """
        existing = await CampaignService.get_campaign(campaign_id, bar_id)
        
        if not existing:
            raise APIError.not_found("Campaign not found")
        
        if existing["status"] != "active":
            raise APIError.bad_request("Only active campaigns can be paused")
        
        now = datetime.now(timezone.utc)
        
        update_query = AdvertisingCampaign.__table__.update().where(
            AdvertisingCampaign.id == campaign_id
        ).values(
            status=CampaignStatus.PAUSED.value,
            paused_at=now,
            updated_at=now
        )
        
        await database.execute(update_query)
        
        # Reflect the pause in the returned campaign so clients get the same
        # CampaignResponse shape as get_campaign / list_campaigns.
        existing["status"] = CampaignStatus.PAUSED.value
        existing["paused_at"] = now
        existing["updated_at"] = now
        return existing
    
    @staticmethod
    async def resume_campaign(campaign_id: int, bar_id: int) -> Dict[str, Any]:
        """
        Resume a paused campaign.
        
        When resuming, the end_time is automatically extended by the
        duration the campaign was paused, ensuring the full budget value.
        """
        existing = await CampaignService.get_campaign(campaign_id, bar_id)
        
        if not existing:
            raise APIError.not_found("Campaign not found")
        
        if existing["status"] != "paused":
            raise APIError.bad_request("Only paused campaigns can be resumed")
        
        # Check if budget is exhausted
        if Decimal(str(existing["budget_spent"])) >= Decimal(str(existing["budget_amount"])):
            raise APIError.bad_request("Campaign budget is exhausted. Add more budget to resume.")
        
        now = datetime.now(timezone.utc)
        
        # Calculate pause duration to extend end_time (pro-ration)
        paused_at = existing.get("paused_at")
        update_values = {
            "status": CampaignStatus.ACTIVE.value,
            "updated_at": now
        }
        
        if paused_at:
            pause_duration = now - paused_at
            # Extend end_time by pause duration if end_time exists
            existing_end = existing.get("end_time")
            if existing_end:
                new_end_time = existing_end + pause_duration
                update_values["end_time"] = new_end_time
        
        # Clear paused_at
        update_values["paused_at"] = None
        
        update_query = AdvertisingCampaign.__table__.update().where(
            AdvertisingCampaign.id == campaign_id
        ).values(**update_values)
        
        await database.execute(update_query)
        
        # Reflect the resume in the returned campaign so clients get the same
        # CampaignResponse shape as get_campaign / list_campaigns.
        existing["status"] = CampaignStatus.ACTIVE.value
        existing["updated_at"] = now
        if "end_time" in update_values:
            existing["end_time"] = update_values["end_time"]
        existing["paused_at"] = None
        return existing
    
    @staticmethod
    async def cancel_campaign(campaign_id: int, bar_id: int) -> Dict[str, Any]:
        """
        Cancel campaign and calculate refund.
        
        Refund is calculated on a pro-rated basis:
        - For fixed-budget campaigns: refund = unused budget
        - For hourly campaigns: refund = remaining hours * hourly rate
        - For credit campaigns: refund = remaining credits back to subscription
        """
        existing = await CampaignService.get_campaign(campaign_id, bar_id)
        
        if not existing:
            raise APIError.not_found("Campaign not found")
        
        if existing["status"] in ["completed", "cancelled"]:
            raise APIError.bad_request("Campaign is already completed or cancelled")
        
        now = datetime.now(timezone.utc)
        budget_amount = Decimal(str(existing["budget_amount"]))
        budget_spent = Decimal(str(existing["budget_spent"]))
        budget_remaining = budget_amount - budget_spent
        
        # Calculate refund and credit restoration
        credits_refunded = {}
        if existing["budget_type"] == "credits":
            # For credit campaigns, restore credits based on distribution
            distribution = existing.get("distribution") or []
            if distribution:
                for dist in distribution:
                    placement = dist.get("placement", "")
                    spent_on_placement = Decimal(str(existing.get("budget_spent_per_placement", {}).get(placement, 0)))
                    allocated = Decimal(str(dist.get("budget", 0)))
                    remaining_for_placement = allocated - spent_on_placement
                    if remaining_for_placement > 0:
                        # Map placement back to credit type
                        credit_type = credit_bucket_for_placement(placement)
                        if credit_type:
                            credits_refunded[credit_type] = float(remaining_for_placement)
        
        update_query = AdvertisingCampaign.__table__.update().where(
            AdvertisingCampaign.id == campaign_id
        ).values(
            status=CampaignStatus.CANCELLED.value,
            updated_at=now
        )
        
        await database.execute(update_query)
        
        # If credit campaign, restore credits to subscription
        if credits_refunded and existing.get("subscription_id"):
            try:
                from app.advertising.services.subscription_service import SubscriptionService
                sub = await SubscriptionService.get_subscription_by_id(existing["subscription_id"])
                if sub:
                    current_credits = sub.get("credits", {})
                    for credit_type, amount in credits_refunded.items():
                        if credit_type in current_credits:
                            current_credits[credit_type] = current_credits.get(credit_type, 0) + int(amount)
                    # Restore credits
                    update_credits_query = AdvertisingSubscription.__table__.update().where(
                        AdvertisingSubscription.id == existing["subscription_id"]
                    ).values(credits=current_credits, updated_at=now)
                    await database.execute(update_credits_query)
            except Exception:
                pass  # Credit restoration is best-effort
        
        return {
            "amount": float(budget_remaining),
            "credits": credits_refunded
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
            
            # Cache the click for attribution (DOB-57)
            if user_id:
                query = "SELECT bar_id FROM advertising_campaigns WHERE id = :idx"
                campaign_rec = await database.fetch_one(query, {"idx": campaign_id})
                if campaign_rec:
                    await get_redis().set(
                        f"user:{user_id}:campaign_click:{campaign_rec['bar_id']}", 
                        str(campaign_id), 
                        ex=86400  # 24 hours
                    )
                    
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
    async def _process_click_billing(campaign_id: int, placement: Optional[str] = None) -> None:
        """Process billing for CPC campaigns with per-placement tracking"""
        # Get campaign
        query = AdvertisingCampaign.__table__.select().where(
            AdvertisingCampaign.id == campaign_id
        )
        campaign = await database.fetch_one(query)
        
        if not campaign or campaign["budget_type"] != "cpc":
            return
        
        # Get CPC rate from region pricing if available
        cpc_rate = Decimal("0.50")  # Default fallback
        
        try:
            bar_id = campaign["bar_id"]
            from app.advertising.models import AdvertisingSubscription, RegionPricing
            sub_query = AdvertisingSubscription.__table__.select().where(
                AdvertisingSubscription.bar_id == bar_id
            )
            sub = await database.fetch_one(sub_query)
            if sub:
                region = sub["region_code"]
                pricing_query = RegionPricing.__table__.select().where(
                    RegionPricing.region_code == region
                )
                pricing = await database.fetch_one(pricing_query)
                if pricing:
                    # Use the average of min and max CPC
                    cpc_rate = (Decimal(str(pricing["search_cpc_min"])) + Decimal(str(pricing["search_cpc_max"]))) / Decimal("2")
        except Exception:
            pass  # Fall back to default CPC rate
        
        now = datetime.now(timezone.utc)
        new_spent = Decimal(str(campaign["budget_spent"])) + cpc_rate
        update_values = {
            "budget_spent": new_spent,
            "updated_at": now
        }
        
        # Track per-placement budget if placement is known
        actual_placement = placement or "click"
        if actual_placement:
            budget_spent_per_placement = dict(campaign.get("budget_spent_per_placement") or {})
            current_placement_spent = Decimal(str(budget_spent_per_placement.get(actual_placement, 0)))
            budget_spent_per_placement[actual_placement] = float(current_placement_spent + cpc_rate)
            update_values["budget_spent_per_placement"] = budget_spent_per_placement
        
        update_query = AdvertisingCampaign.__table__.update().where(
            AdvertisingCampaign.id == campaign_id
        ).values(**update_values)
        await database.execute(update_query)
        
        # Check if budget exhausted
        if new_spent >= Decimal(str(campaign["budget_amount"])):
            await CampaignService._exhaust_campaign(campaign_id)
    
    @staticmethod
    async def _process_hourly_billing(campaign_id: int) -> None:
        """Process billing for CPH (hourly) campaigns - called by scheduler"""
        query = AdvertisingCampaign.__table__.select().where(
            AdvertisingCampaign.id == campaign_id
        )
        campaign = await database.fetch_one(query)
        
        if not campaign or campaign["budget_type"] != "hourly":
            return
        
        # Get hourly rate from region pricing
        hourly_rate = Decimal("10.00")  # Default fallback
        placement = campaign.get("campaign_type", "featured")
        
        try:
            bar_id = campaign["bar_id"]
            from app.advertising.models import AdvertisingSubscription, RegionPricing
            sub_query = AdvertisingSubscription.__table__.select().where(
                AdvertisingSubscription.bar_id == bar_id
            )
            sub = await database.fetch_one(sub_query)
            if sub:
                region = sub["region_code"]
                pricing_query = RegionPricing.__table__.select().where(
                    RegionPricing.region_code == region
                )
                pricing = await database.fetch_one(pricing_query)
                if pricing:
                    if placement == "featured":
                        hourly_rate = Decimal(str(pricing["featured_cph"]))
                    elif placement == "map":
                        hourly_rate = Decimal(str(pricing["map_cph"]))
        except Exception:
            pass
        
        now = datetime.now(timezone.utc)
        new_spent = Decimal(str(campaign["budget_spent"])) + hourly_rate
        update_values = {
            "budget_spent": new_spent,
            "updated_at": now
        }
        
        # Track per-placement budget
        budget_spent_per_placement = dict(campaign.get("budget_spent_per_placement") or {})
        current_placement_spent = Decimal(str(budget_spent_per_placement.get(placement, 0)))
        budget_spent_per_placement[placement] = float(current_placement_spent + hourly_rate)
        update_values["budget_spent_per_placement"] = budget_spent_per_placement
        
        update_query = AdvertisingCampaign.__table__.update().where(
            AdvertisingCampaign.id == campaign_id
        ).values(**update_values)
        await database.execute(update_query)
        
        # Check if budget exhausted
        if new_spent >= Decimal(str(campaign["budget_amount"])):
            await CampaignService._exhaust_campaign(campaign_id)
    
    @staticmethod
    async def _process_cpm_billing(campaign_id: int, impressions_since_last_bill: int = 1000) -> None:
        """Process billing for CPM campaigns (per 1000 impressions)"""
        query = AdvertisingCampaign.__table__.select().where(
            AdvertisingCampaign.id == campaign_id
        )
        campaign = await database.fetch_one(query)
        
        if not campaign or campaign["budget_type"] != "cpm":
            return
        
        # Get CPM rate from region pricing
        cpm_rate = Decimal("15.00")  # Default fallback
        placement = campaign.get("campaign_type", "featured")
        
        try:
            bar_id = campaign["bar_id"]
            from app.advertising.models import AdvertisingSubscription, RegionPricing
            sub_query = AdvertisingSubscription.__table__.select().where(
                AdvertisingSubscription.bar_id == bar_id
            )
            sub = await database.fetch_one(sub_query)
            if sub:
                region = sub["region_code"]
                pricing_query = RegionPricing.__table__.select().where(
                    RegionPricing.region_code == region
                )
                pricing = await database.fetch_one(pricing_query)
                if pricing:
                    if placement == "promo_boost":
                        cpm_rate = Decimal(str(pricing["boost_cpm"]))
        except Exception:
            pass
        
        # Calculate cost: rate * (impressions / 1000)
        cost = cpm_rate * Decimal(str(impressions_since_last_bill)) / Decimal("1000")
        
        now = datetime.now(timezone.utc)
        new_spent = Decimal(str(campaign["budget_spent"])) + cost
        update_values = {
            "budget_spent": new_spent,
            "updated_at": now
        }
        
        # Track per-placement budget
        budget_spent_per_placement = dict(campaign.get("budget_spent_per_placement") or {})
        current_placement_spent = Decimal(str(budget_spent_per_placement.get(placement, 0)))
        budget_spent_per_placement[placement] = float(current_placement_spent + cost)
        update_values["budget_spent_per_placement"] = budget_spent_per_placement
        
        update_query = AdvertisingCampaign.__table__.update().where(
            AdvertisingCampaign.id == campaign_id
        ).values(**update_values)
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
