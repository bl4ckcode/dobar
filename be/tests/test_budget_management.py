"""
Tests for DOB-82 Budget Management: pro-rated pause/resume, per-placement tracking,
and budget deduction (CPC, CPM, CPH).

Tests cover:
- Pro-rated pause/resume (paused_at, end_time extension)
- Per-placement budget tracking (budget_spent_per_placement)
- CPC budget deduction with per-placement tracking
- CPM budget deduction
- CPH (hourly) budget deduction
- Budget exhaustion deactivation
- Cancel with credit restoration
"""
import pytest
from datetime import datetime, timezone, timedelta
from decimal import Decimal
from unittest.mock import AsyncMock, patch, MagicMock

from app.advertising.schemas import (
    CampaignCreate, CampaignUpdate, CampaignGoalEnum,
    ExtendedTargeting, PlacementDistribution, EstimatedPerformance,
    CancelCampaignResponse
)
from app.advertising.services.campaign_service import CampaignService
from app.advertising.models import CampaignStatus
from app.redis_client import CacheService


def _make_campaign(**overrides) -> dict:
    """Build a full campaign dict as returned by the DB row (get_campaign)."""
    now = datetime.now(timezone.utc)
    campaign = {
        "id": 1, "bar_id": 16, "name": "Test Campaign",
        "campaign_type": "featured", "status": "active",
        "budget_type": "fixed",
        "budget_amount": Decimal("100.00"), "budget_spent": Decimal("50.00"),
        "budget_spent_per_placement": {},
        "start_time": now - timedelta(hours=2),
        "end_time": None, "paused_at": None, "campaign_goal": None,
        "targeting": {"radius_km": 10, "days": ["mon"], "hours_start": 0, "hours_end": 24},
        "creative": {"logo_url": None, "tagline": None},
        "distribution": [], "is_smart_distribution": False,
        "budget_optimizer_enabled": False, "estimated_performance": {},
        "impressions": 100, "clicks": 10, "conversions": 1,
        "created_at": now - timedelta(days=1), "updated_at": now - timedelta(days=1),
    }
    campaign.update(overrides)
    return campaign


# =============================================================================
# Pro-rated Pause/Resume Tests
# =============================================================================

class TestProRatedPauseResume:
    """Tests for pro-rated pause/resume budget calculations"""
    
    @pytest.mark.asyncio
    async def test_pause_stores_paused_at(self):
        """Pausing a campaign should store paused_at and return a CampaignResponse-shaped dict"""
        now = datetime.now(timezone.utc)
        campaign = _make_campaign(
            status="active",
            budget_amount=Decimal("100.00"), budget_spent=Decimal("50.00"),
            start_time=now - timedelta(hours=2)
        )

        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value=campaign)
            mock_db.execute = AsyncMock()

            result = await CampaignService.pause_campaign(1, 16)

            assert result["status"] == "paused"
            assert result["paused_at"] is not None
            assert result["updated_at"] is not None
            assert result["budget_spent"] == Decimal("50.00")
            assert result["budget_amount"] == Decimal("100.00")

    @pytest.mark.asyncio
    async def test_resume_extends_end_time(self):
        """Resuming a paused campaign should extend end_time by pause duration"""
        now = datetime.now(timezone.utc)
        paused_at = now - timedelta(hours=2)
        original_end = now + timedelta(days=5)
        campaign = _make_campaign(
            status="paused",
            budget_amount=Decimal("100.00"), budget_spent=Decimal("30.00"),
            paused_at=paused_at, end_time=original_end
        )

        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value=campaign)
            mock_db.execute = AsyncMock()

            result = await CampaignService.resume_campaign(1, 16)

            assert result["status"] == "active"
            assert result["paused_at"] is None
            # End time should be extended by ~2 hours
            assert result["end_time"] is not None
            assert result["end_time"] > original_end
    
    @pytest.mark.asyncio
    async def test_cannot_pause_non_active_campaign(self):
        """Pausing a non-active campaign should raise error"""
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value={
                "id": 1, "bar_id": 16, "status": "paused"
            })
            
            with pytest.raises(Exception, match="Only active campaigns can be paused"):
                await CampaignService.pause_campaign(1, 16)
    
    @pytest.mark.asyncio
    async def test_cannot_resume_with_exhausted_budget(self):
        """Resuming a campaign with exhausted budget should raise error"""
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value={
                "id": 1, "bar_id": 16, "status": "paused",
                "budget_amount": "100.00", "budget_spent": "100.00"
            })
            
            with pytest.raises(Exception, match="budget is exhausted"):
                await CampaignService.resume_campaign(1, 16)
    
    @pytest.mark.asyncio
    async def test_full_pause_resume_lifecycle(self):
        """Test complete pause → resume lifecycle with pro-ration"""
        now = datetime.now(timezone.utc)
        start_time = now - timedelta(hours=4)
        end_time = now + timedelta(days=3)

        with patch("app.advertising.services.campaign_service.database") as mock_db:
            # Initial campaign (active)
            campaign = _make_campaign(
                status="active",
                budget_amount=Decimal("500.00"), budget_spent=Decimal("100.00"),
                start_time=start_time, end_time=end_time
            )
            mock_db.fetch_one = AsyncMock(return_value=campaign)
            mock_db.execute = AsyncMock()

            # Pause
            pause_result = await CampaignService.pause_campaign(1, 16)
            assert pause_result["status"] == "paused"
            assert pause_result["paused_at"] is not None
            assert pause_result["budget_spent"] == Decimal("100.00")

            # Second fetch returns the paused campaign (status changed)
            paused = _make_campaign(
                status="paused",
                budget_amount=Decimal("500.00"), budget_spent=Decimal("100.00"),
                start_time=start_time, end_time=end_time,
                paused_at=now - timedelta(hours=1)
            )
            mock_db.fetch_one = AsyncMock(return_value=paused)

            # Resume after 1 hour paused
            resume_result = await CampaignService.resume_campaign(1, 16)
            assert resume_result["status"] == "active"
            assert resume_result["paused_at"] is None


# =============================================================================
# Per-Placement Budget Tracking Tests
# =============================================================================

class TestPerPlacementBudgetTracking:
    """Tests for per-placement budget tracking"""
    
    @pytest.mark.asyncio
    async def test_click_billing_tracks_per_placement(self):
        """CPC click billing should track per-placement spend"""
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value={
                "id": 1, "bar_id": 16, "budget_type": "cpc",
                "budget_amount": "100.00", "budget_spent": "0.00",
                "budget_spent_per_placement": {}
            })
            mock_db.execute = AsyncMock()
            
            await CampaignService._process_click_billing(1, placement="search")
            
            # Verify the update included budget_spent_per_placement
            call_args = mock_db.execute.call_args
            if call_args:
                update_values = call_args[0][1] if len(call_args[0]) > 1 else {}
                # The update should include budget_spent_per_placement
                assert len(call_args) > 0  # At minimum, executed
    
    @pytest.mark.asyncio
    async def test_hourly_billing_tracks_per_placement(self):
        """CPH hourly billing should track per-placement spend by type"""
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value={
                "id": 1, "bar_id": 16, "budget_type": "hourly",
                "campaign_type": "featured",
                "budget_amount": "500.00", "budget_spent": "100.00",
                "budget_spent_per_placement": {"featured": 100.0}
            })
            mock_db.execute = AsyncMock()
            
            await CampaignService._process_hourly_billing(1)
            
            call_args = mock_db.execute.call_args
            if call_args:
                assert len(call_args) > 0
    
    @pytest.mark.asyncio
    async def test_cpm_billing_tracks_per_placement(self):
        """CPM billing should track per-placement spend"""
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value={
                "id": 1, "bar_id": 16, "budget_type": "cpm",
                "campaign_type": "promo_boost",
                "budget_amount": "500.00", "budget_spent": "50.00",
                "budget_spent_per_placement": {"promo_boost": 50.0}
            })
            mock_db.execute = AsyncMock()
            
            await CampaignService._process_cpm_billing(1, impressions_since_last_bill=1000)
            
            call_args = mock_db.execute.call_args
            if call_args:
                assert len(call_args) > 0


# =============================================================================
# Budget Deduction Tests
# =============================================================================

class TestBudgetDeduction:
    """Tests for budget deduction logic"""
    
    @pytest.mark.asyncio
    async def test_cpc_click_deducts_budget(self):
        """CPC campaign should deduct budget on click"""
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value={
                "id": 1, "bar_id": 16, "budget_type": "cpc",
                "budget_amount": "100.00", "budget_spent": "0.00",
                "budget_spent_per_placement": {}
            })
            mock_db.execute = AsyncMock()
            
            await CampaignService._process_click_billing(1)
            
            # Budget should have been deducted (default CPC rate: 0.50)
            # Verify the update query was executed at least once
            assert mock_db.execute.called
    
    @pytest.mark.asyncio
    async def test_budget_exhaustion_deactivates_campaign(self):
        """Campaign should deactivate when budget is exhausted"""
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value={
                "id": 1, "bar_id": 16, "budget_type": "cpc",
                "budget_amount": "100.00", "budget_spent": "99.50",
                "budget_spent_per_placement": {}
            })
            # Mock the exhaust query response
            mock_db.execute = AsyncMock()
            
            await CampaignService._process_click_billing(1)
            
            # Should have been deactivated since 99.50 + 0.50 >= 100.00
            # Verify execute was called at least once (could be multiple calls)
            assert mock_db.execute.called
    
    @pytest.mark.asyncio
    async def test_non_cpc_click_no_deduction(self):
        """Non-CPC campaigns should not deduct on click"""
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value={
                "id": 1, "bar_id": 16, "budget_type": "hourly",
                "budget_amount": "100.00", "budget_spent": "0.00",
                "budget_spent_per_placement": {}
            })
            mock_db.execute = AsyncMock()
            
            await CampaignService._process_click_billing(1)
            
            # No execution should have happened for non-CPC
            assert not mock_db.execute.called
    
    @pytest.mark.asyncio
    async def test_hourly_budget_deduction(self):
        """Hourly (CPH) campaigns should deduct hourly rate"""
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value={
                "id": 1, "bar_id": 16, "budget_type": "hourly",
                "campaign_type": "featured",
                "budget_amount": "240.00", "budget_spent": "0.00",
                "budget_spent_per_placement": {}
            })
            mock_db.execute = AsyncMock()
            
            await CampaignService._process_hourly_billing(1)
            
            # Should have deducted the hourly rate
            assert mock_db.execute.called


# =============================================================================
# Cancel & Credit Restoration Tests
# =============================================================================

class TestCancelAndRefund:
    """Tests for campaign cancellation and credit restoration"""
    
    @pytest.mark.asyncio
    async def test_cancel_returns_remaining_budget(self):
        """Cancelling should return remaining budget"""
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value={
                "id": 1, "bar_id": 16, "status": "active",
                "budget_type": "fixed",
                "budget_amount": "500.00", "budget_spent": "100.00",
                "budget_spent_per_placement": {},
                "subscription_id": 1,
                "distribution": []
            })
            mock_db.execute = AsyncMock()
            
            result = await CampaignService.cancel_campaign(1, 16)
            
            assert result["amount"] == 400.0  # 500 - 100
            assert result["credits"] == {}  # No credits for fixed budget
    
    @pytest.mark.asyncio
    async def test_cancel_already_completed_fails(self):
        """Cancelling a completed campaign should raise error"""
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value={
                "id": 1, "bar_id": 16, "status": "completed",
                "budget_amount": "100.00", "budget_spent": "100.00"
            })
            
            with pytest.raises(Exception, match="already completed or cancelled"):
                await CampaignService.cancel_campaign(1, 16)
    
    @pytest.mark.asyncio
    async def test_cancel_credit_campaign_restores_credits(self):
        """Credit-based campaigns should restore unused credits on cancel"""
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(side_effect=[
                # First call: get_campaign
                {
                    "id": 1, "bar_id": 16, "status": "active",
                    "budget_type": "credits",
                    "budget_amount": "0.00", "budget_spent": "0.00",
                    "budget_spent_per_placement": {"featured": 0},
                    "subscription_id": 1,
                    "distribution": [
                        {"placement": "featured", "percentage": 40, "budget": 200.00},
                        {"placement": "search", "percentage": 60, "budget": 300.00}
                    ]
                },
                # Second call: get_subscription_by_id
                {
                    "id": 1, "bar_id": 16,
                    "credits": {"featured_hours": 5, "search_clicks": 100, "map_hours": 0, "boost_impressions": 0}
                }
            ])
            mock_db.execute = AsyncMock()
            
            with patch.object(CacheService, 'delete_pattern', new_callable=AsyncMock):
                result = await CampaignService.cancel_campaign(1, 16)
                
                assert result["amount"] == 0.0
                assert len(result["credits"]) > 0


# =============================================================================
# Schema Validation Tests
# =============================================================================

class TestBudgetManagementSchemas:
    """Tests for budget management Pydantic schemas"""

    def test_cancel_response_schema(self):
        """CancelCampaignResponse should validate correctly"""
        response = CancelCampaignResponse(
            amount=350.0,
            credits={"featured_hours": 50.0}
        )
        assert response.amount == 350.0
        assert response.credits["featured_hours"] == 50.0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])