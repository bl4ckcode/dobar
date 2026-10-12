"""
BARZ Ad Serving Engine

High-performance ad serving for consumer-facing endpoints.
Serves featured ads, sponsored search results, and map spotlights.
"""
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.advertising.models import (
    AdvertisingCampaign, AdvertisingSubscription, AdvertisingImpression,
    CampaignStatus, CampaignType, AdAction, SubscriptionTier
)
from app.advertising.services.campaign_service import CampaignService
from app.bars_and_restaurants.models.relational_models import Bar


class AdServer:
    """
    High-performance ad serving engine.
    
    Responsible for:
    - Fetching active campaigns by type and location
    - Prioritizing by subscription tier (VIP > Master)
    - Logging impressions and clicks
    - Budget tracking
    """
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def get_featured_ads(
        self,
        latitude: float,
        longitude: float,
        limit: int = 10
    ) -> List[dict]:
        """
        Get featured ads for home screen carousel.
        
        Args:
            latitude: User's current latitude
            longitude: User's current longitude  
            limit: Maximum number of ads to return
            
        Returns:
            List of featured ad data with bar info
        """
        return await self._get_ads_by_type(
            CampaignType.FEATURED, 
            latitude, 
            longitude, 
            limit,
            placement="home"
        )
    
    async def get_search_ads(
        self,
        latitude: float,
        longitude: float,
        query: Optional[str] = None,
        category: Optional[str] = None,
        limit: int = 3
    ) -> List[dict]:
        """
        Get sponsored search results.
        
        Args:
            latitude: User's current latitude
            longitude: User's current longitude
            query: Search query (optional)
            category: Category filter (optional)
            limit: Maximum number of ads to return
            
        Returns:
            List of sponsored bar results
        """
        return await self._get_ads_by_type(
            CampaignType.SEARCH,
            latitude,
            longitude,
            limit,
            placement="search"
        )
    
    async def get_map_ads(
        self,
        latitude: float,
        longitude: float,
        limit: int = 5
    ) -> List[dict]:
        """
        Get map spotlight ads (highlighted pins).
        
        Args:
            latitude: User's current latitude
            longitude: User's current longitude
            limit: Maximum number of ads to return
            
        Returns:
            List of bars with spotlight pins
        """
        return await self._get_ads_by_type(
            CampaignType.MAP,
            latitude,
            longitude,
            limit,
            placement="map"
        )
    
    async def _get_ads_by_type(
        self,
        campaign_type: CampaignType,
        latitude: float,
        longitude: float,
        limit: int,
        placement: str
    ) -> List[dict]:
        """
        Internal method to fetch ads by type with priority ordering.
        
        Priority order:
        1. VIP subscribers first
        2. Master subscribers second
        3. Within tier, order by remaining budget (most budget = more exposure)
        """
        now = datetime.now(timezone.utc)
        
        # Query active campaigns with bar and subscription info
        query = (
            select(
                AdvertisingCampaign,
                Bar,
                AdvertisingSubscription
            )
            .join(Bar, AdvertisingCampaign.bar_id == Bar.id)
            .join(
                AdvertisingSubscription,
                AdvertisingCampaign.subscription_id == AdvertisingSubscription.id
            )
            .where(
                and_(
                    AdvertisingCampaign.campaign_type == campaign_type,
                    AdvertisingCampaign.status == CampaignStatus.ACTIVE,
                    AdvertisingCampaign.start_time <= now,
                    or_(
                        AdvertisingCampaign.end_time.is_(None),
                        AdvertisingCampaign.end_time > now
                    ),
                    # Has budget remaining
                    AdvertisingCampaign.budget_spent < AdvertisingCampaign.budget_amount
                )
            )
            # Order by tier priority (VIP=1, Master=2) then by budget remaining
            .order_by(
                # VIP gets priority 1, Master gets 2, Regular gets 3
                AdvertisingSubscription.tier.desc(),
                # More budget remaining = higher priority
                (AdvertisingCampaign.budget_amount - AdvertisingCampaign.budget_spent).desc()
            )
            .limit(limit)
        )
        
        result = await self.db.execute(query)
        rows = result.all()
        
        ads = []
        for campaign, bar, subscription in rows:
            # Log impression
            await self._log_impression(campaign.id, placement)
            
            # Build response
            creative = campaign.creative or {}
            ads.append({
                "campaign_id": campaign.id,
                "bar_id": bar.id,
                "bar_name": bar.name,
                "bar_image": bar.image_url,
                "logo_url": creative.get("logo_url") or bar.image_url,
                "tagline": creative.get("tagline") or bar.description,
                "latitude": float(bar.latitude) if bar.latitude else None,
                "longitude": float(bar.longitude) if bar.longitude else None,
                "tier": subscription.tier.value,
                "is_sponsored": True,
                "placement": placement
            })
        
        return ads
    
    async def _log_impression(
        self,
        campaign_id: int,
        placement: str,
        user_id: Optional[int] = None
    ):
        """Log an ad impression asynchronously."""
        impression = AdvertisingImpression(
            campaign_id=campaign_id,
            action=AdAction.IMPRESSION,
            placement=placement,
            user_id=user_id,
            timestamp=datetime.now(timezone.utc)
        )
        self.db.add(impression)
        
        # Update campaign impression count
        campaign_query = select(AdvertisingCampaign).where(
            AdvertisingCampaign.id == campaign_id
        )
        result = await self.db.execute(campaign_query)
        campaign = result.scalar_one_or_none()
        
        if campaign:
            campaign.impressions = (campaign.impressions or 0) + 1
        
        await self.db.commit()
    
    async def log_click(
        self,
        campaign_id: int,
        placement: str,
        user_id: Optional[int] = None
    ) -> bool:
        """
        Log an ad click; CPC billing is delegated to CampaignService.
        
        Returns:
            True if click was logged, False if campaign not found
        """
        # Get campaign
        campaign_query = select(AdvertisingCampaign).where(
            AdvertisingCampaign.id == campaign_id
        )
        result = await self.db.execute(campaign_query)
        campaign = result.scalar_one_or_none()
        
        if not campaign:
            return False
        
        # Log click
        click = AdvertisingImpression(
            campaign_id=campaign_id,
            action=AdAction.CLICK,
            placement=placement,
            user_id=user_id,
            timestamp=datetime.now(timezone.utc)
        )
        self.db.add(click)
        
        # Update campaign click count.
        # NOTE: CampaignService.track_event is the *other* click recorder (atomic SQL counter
        # plus CPC billing). Wire exactly one recorder per click event — if both ran for the
        # same click, the click counter would double-count (handoff §B1/§B4).
        campaign.clicks = (campaign.clicks or 0) + 1
        
        await self.db.commit()
        
        # CPC billing has a single source of truth: CampaignService._process_click_billing
        # (region-aware rate, budget_spent_per_placement tracking, _exhaust_campaign).
        # This class used to hardcode its own Decimal("0.50") price above a "use min rate"
        # comment — that copy is gone; delegate instead (handoff §B1).
        if campaign.budget_type and campaign.budget_type.value == "cpc":
            await CampaignService._process_click_billing(campaign_id, placement=placement)
        return True
    
    async def log_conversion(
        self,
        campaign_id: int,
        user_id: int,
        order_id: Optional[int] = None
    ) -> bool:
        """
        Log a conversion (user placed order at advertised bar).
        
        Returns:
            True if conversion was logged
        """
        campaign_query = select(AdvertisingCampaign).where(
            AdvertisingCampaign.id == campaign_id
        )
        result = await self.db.execute(campaign_query)
        campaign = result.scalar_one_or_none()
        
        if not campaign:
            return False
        
        # Log conversion
        conversion = AdvertisingImpression(
            campaign_id=campaign_id,
            action=AdAction.CONVERSION,
            placement="order",
            user_id=user_id,
            timestamp=datetime.now(timezone.utc)
        )
        self.db.add(conversion)
        
        # Update campaign conversion count
        campaign.conversions = (campaign.conversions or 0) + 1
        
        await self.db.commit()
        return True
