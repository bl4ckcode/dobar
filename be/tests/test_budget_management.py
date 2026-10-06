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


def _update_values(mock_db) -> dict:
    """The `.values(...)` payload of the UPDATE statement passed to database.execute,
    keyed by column name with the raw Python values (SQLAlchemy wraps both in
    Column / BindParameter objects)."""
    update_query = mock_db.execute.call_args[0][0]
    return {
        (key.name if hasattr(key, "name") else key): getattr(value, "value", value)
        for key, value in update_query._values.items()
    }


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

            values = _update_values(mock_db)
            # Region pricing missing (the mocked fetches never yield a row) → fallback 0.50.
            # B2 regression: the canonical placement key is written, never a bogus "click" key.
            assert values["budget_spent_per_placement"] == {"search": 0.5}
            assert "click" not in values["budget_spent_per_placement"]
    
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

            values = _update_values(mock_db)
            # Region pricing missing (mock never yields a row) → fallback 10.00 on 100.00 spent,
            # recorded under the canonical placement key.
            assert float(values["budget_spent"]) == 110.0
            assert values["budget_spent_per_placement"] == {"featured": 110.0}
    
    @pytest.mark.asyncio
    async def test_cpm_billing_tracks_per_placement(self):
        """CPM billing bills promo at the regional boost_cpm (B5) and writes the canonical
        placement key, leaving a legacy campaign-type key untouched (B2 decision)."""
        campaign = {
            "id": 1, "bar_id": 16, "budget_type": "cpm",
            "campaign_type": "promo_boost",
            "budget_amount": "500.00", "budget_spent": "50.00",
            # legacy key written before this session; new writes go to canonical "promo"
            "budget_spent_per_placement": {"promo_boost": 50.0}
        }
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(side_effect=[
                campaign, {"region_code": "BR"}, {"boost_cpm": "8.00"}
            ])
            mock_db.execute = AsyncMock()

            await CampaignService._process_cpm_billing(1, impressions_since_last_bill=1000)

            values = _update_values(mock_db)
            # 8.00 per 1,000 impressions → cost 8.00 on top of the 50.00 already spent
            assert float(values["budget_spent"]) == 58.0
            assert values["budget_spent_per_placement"] == {"promo_boost": 50.0, "promo": 8.0}

    @pytest.mark.asyncio
    async def test_cpm_billing_banner_and_push_read_boost_cpm_not_the_15_fallback(self):
        """B5 regression: banner and push_notification bill through the same CPM function and
        used to silently fall back to 15.00 because only the promo_boost branch read boost_cpm."""
        for placement_key in ("banner", "push_notification"):
            campaign = {
                "id": 1, "bar_id": 16, "budget_type": "cpm",
                "campaign_type": placement_key,
                "budget_amount": "500.00", "budget_spent": "0.00",
                "budget_spent_per_placement": {}
            }
            with patch("app.advertising.services.campaign_service.database") as mock_db:
                mock_db.fetch_one = AsyncMock(side_effect=[
                    campaign, {"region_code": "BR"}, {"boost_cpm": "8.00"}
                ])
                mock_db.execute = AsyncMock()

                await CampaignService._process_cpm_billing(1, impressions_since_last_bill=1000)

                values = _update_values(mock_db)
                assert float(values["budget_spent"]) == 8.0  # boost_cpm, NOT the old 15.00
                assert values["budget_spent_per_placement"] == {placement_key: 8.0}

    @pytest.mark.asyncio
    async def test_cpm_billing_raises_when_region_has_no_rate(self):
        """B5 decision: no region rate → raise instead of inventing a price."""
        campaign = {
            "id": 1, "bar_id": 16, "budget_type": "cpm",
            "campaign_type": "promo_boost",
            "budget_amount": "500.00", "budget_spent": "50.00",
            "budget_spent_per_placement": {}
        }
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(side_effect=[
                campaign, {"region_code": "BR"}, None
            ])
            mock_db.execute = AsyncMock()

            with pytest.raises(ValueError, match="no usable CPM rate"):
                await CampaignService._process_cpm_billing(1)

            assert not mock_db.execute.called

    @pytest.mark.asyncio
    async def test_cpm_billing_rejects_non_cpm_placement(self):
        """A cpm budget_type on a non-CPM placement cannot be priced — refuse loudly."""
        campaign = {
            "id": 1, "bar_id": 16, "budget_type": "cpm",
            "campaign_type": "featured",
            "budget_amount": "500.00", "budget_spent": "0.00",
            "budget_spent_per_placement": {}
        }
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value=campaign)
            mock_db.execute = AsyncMock()

            with pytest.raises(ValueError, match="refusing to bill"):
                await CampaignService._process_cpm_billing(1)

            assert not mock_db.execute.called


# =============================================================================
# Click Placement Threading (handoff §B2)
# =============================================================================

class TestClickPlacementThreading:
    """The ad-event recorder must pass the placement through so per-placement spend is keyed
    by canonical placement — never by the old literal "click" fallback."""

    @pytest.mark.asyncio
    async def test_track_event_threads_placement_into_click_billing(self):
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.execute = AsyncMock()
            with patch.object(
                CampaignService, "_process_click_billing", new_callable=AsyncMock
            ) as mock_billing:
                await CampaignService.track_event(
                    campaign_id=7, action="click", placement="promo", user_id=None
                )

                mock_billing.assert_awaited_once_with(7, placement="promo")

    @pytest.mark.asyncio
    async def test_click_billing_normalizes_event_placement_aliases(self):
        """FE events send AdTrackEvent placements like "home" — must land on "featured"."""
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value={
                "id": 1, "bar_id": 16, "budget_type": "cpc",
                "campaign_type": "featured",
                "budget_amount": "100.00", "budget_spent": "0.00",
                "budget_spent_per_placement": {}
            })
            mock_db.execute = AsyncMock()

            await CampaignService._process_click_billing(1, placement="home")

            assert _update_values(mock_db)["budget_spent_per_placement"] == {"featured": 0.5}

    @pytest.mark.asyncio
    async def test_click_billing_falls_back_to_campaign_type_without_explicit_placement(self):
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value={
                "id": 1, "bar_id": 16, "budget_type": "cpc",
                "campaign_type": "promo_boost",
                "budget_amount": "100.00", "budget_spent": "0.00",
                "budget_spent_per_placement": {}
            })
            mock_db.execute = AsyncMock()

            await CampaignService._process_click_billing(1)

            values = _update_values(mock_db)
            assert values["budget_spent_per_placement"] == {"promo": 0.5}
            assert "click" not in values["budget_spent_per_placement"]

    @pytest.mark.asyncio
    async def test_click_billing_skips_the_write_when_placement_cannot_be_resolved(self):
        """No campaign_type and no explicit placement → write budget_spent but no
        per-placement entry, instead of inventing a key."""
        with patch("app.advertising.services.campaign_service.database") as mock_db:
            mock_db.fetch_one = AsyncMock(return_value={
                "id": 1, "bar_id": 16, "budget_type": "cpc",
                "budget_amount": "100.00", "budget_spent": "0.00",
                "budget_spent_per_placement": {}
            })
            mock_db.execute = AsyncMock()

            await CampaignService._process_click_billing(1)

            values = _update_values(mock_db)
            assert "budget_spent_per_placement" not in values
            assert "click" not in values


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