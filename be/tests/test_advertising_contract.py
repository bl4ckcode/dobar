import pytest
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from app.database import database
from app.advertising.models import AdvertisingSubscription
from app.advertising.models import AdvertisingSubscription, AdvertisingCampaign

from app.advertising.pricing import DEFAULT_CREDITS
from app.advertising.routes import _subscription_to_response, _validate_distribution_minimums
from app.advertising.schemas import BudgetTypeEnum, PlacementDistribution, SubscriptionStatusEnum
from app.advertising.services.subscription_service import build_default_subscription
from app.auth.rbac_models import BarRole, BarStaff
from app.errors import APIError


REGION_CREDITS = {
    "master": '{"featured_hours": 4, "search_clicks": 200, "map_hours": 2, "boost_impressions": 5000}',
    "vip": '{"featured_hours": 12, "search_clicks": 1000, "map_hours": 8, "boost_impressions": 25000}',
}

FRONTEND_CAMPAIGN_PAYLOAD = {
    "name": "Campanha Destaque",
    "campaign_type": "featured",
    "budget_type": "credits",
    "budget_amount": 100.0,
    "targeting": {
        "radius_km": 10,
        "age_min": 18,
        "age_max": 65,
        "peak_hours_only": True,
        "budget_optimizer_enabled": True,
    },
    "creative": {
        "title": "Campanha Destaque",
        "cta": "visit_now",
        "tagline": "Venha nos visitar!",
    },
    "placement_distribution": {"featured": 50.0, "search": 50.0},
}


async def _make_bar_owner(user_id: int, bar_id: int, role: str = BarRole.OWNER.value):
    now = datetime.now(timezone.utc)
    await database.execute(
        BarStaff.__table__.insert().values(
            user_id=user_id, bar_id=bar_id, role=role, is_active=True,
            created_at=now, updated_at=now
        )
    )


async def _seed_region_pricing():
    await database.execute(
        "INSERT INTO region_pricing (region_code, currency, master_monthly, master_annual, "
        "vip_monthly, vip_annual, regular_commission, master_commission, vip_commission, "
        "featured_cph, search_cpc_min, search_cpc_max, map_cph, boost_cpm, master_credits, "
        "vip_credits, effective_date) "
        "VALUES ('BR', 'BRL', 299.00, 2990.00, 699.00, 6990.00, 0.1500, 0.1200, 0.0800, "
        "25.00, 0.80, 2.50, 35.00, 8.00, :master, :vip, :now)",
        {"master": REGION_CREDITS["master"], "vip": REGION_CREDITS["vip"],
         "now": datetime.now(timezone.utc)}
    )


async def _seed_subscription(bar_id: int, tier: str = "regular", status: str = "active", credits=None):
    now = datetime.now(timezone.utc)
    await database.execute(
        AdvertisingSubscription.__table__.insert().values(
            bar_id=bar_id, tier=tier, status=status, region_code="BR",
            monthly_fee=Decimal("0.00"), commission_rate=Decimal("0.1500"),
            credits=dict(DEFAULT_CREDITS) if credits is None else credits,
            billing_cycle_start=now, next_billing_date=None, created_at=now, updated_at=now
        )
    )


class TestMyPlanResilience:
    @pytest.mark.asyncio
    async def test_my_plan_does_not_500_on_sparse_legacy_row(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)

        await database.execute(
            AdvertisingSubscription.__table__.insert().values(
                bar_id=bar_id, tier="regular", status="trial", region_code="BR",
                monthly_fee=None, commission_rate=Decimal("0.1500"),
                credits={"banner": 100, "promo_boost": 50},
                billing_cycle_start=None, next_billing_date=None,
                created_at=None, updated_at=None
            )
        )

        response = await client.get(f"/advertising/my-plan?bar_id={bar_id}", headers=headers)

        assert response.status_code == 200, response.text
        body = response.json()
        assert body["tier"] == "regular"
        assert body["status"] == "trial"
        assert body["billing_cycle_start"] is None
        assert body["next_billing_date"] is None
        assert body["created_at"] is None
        assert body["region_code"] == "BR"
        assert float(body["monthly_fee"]) == 0.0
        # B6 decision: legacy keys fold into the canonical buckets instead of zeroing —
        # {"banner": 100, "promo_boost": 50} both paid impressions → boost_impressions = 150.
        assert body["credits"] == {
            "featured_hours": 0, "search_clicks": 0, "map_hours": 0, "boost_impressions": 150
        }

    @pytest.mark.asyncio
    async def test_my_plan_auto_provisions_regular_tier(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)

        response = await client.get(f"/advertising/my-plan?bar_id={bar_id}", headers=headers)

        assert response.status_code == 200, response.text
        body = response.json()
        assert body["tier"] == "regular"
        assert body["status"] == "active"
        assert body["id"] > 0
        assert body["billing_cycle_start"] is not None

    @pytest.mark.asyncio
    async def test_my_plan_falls_back_when_subscription_cannot_be_resolved(
        self, auth_client, test_bar_in_db, mocker
    ):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)

        mocker.patch(
            "app.advertising.routes.SubscriptionService.get_subscription",
            return_value=None
        )
        mocker.patch(
            "app.advertising.routes.SubscriptionService.create_default_subscription",
            return_value=None
        )

        response = await client.get(f"/advertising/my-plan?bar_id={bar_id}", headers=headers)

        assert response.status_code == 200, response.text
        body = response.json()
        assert body["tier"] == "regular"
        assert body["id"] == 0
        assert body["credits"] == {
            "featured_hours": 0, "search_clicks": 0, "map_hours": 0, "boost_impressions": 0
        }

    def test_subscription_to_response_tolerates_legacy_values(self):
        response = _subscription_to_response(
            {
                "id": None, "bar_id": 16, "tier": "platinum", "status": "unknown_state",
                "region_code": None, "monthly_fee": None, "commission_rate": None,
                "credits": {"banner": 100}, "billing_cycle_start": None,
                "next_billing_date": None, "created_at": None,
            },
            16
        )

        assert response.id == 0
        assert response.bar_id == 16
        assert response.tier.value == "regular"
        assert response.status.value == "active"
        assert response.region_code == "BR"
        assert response.monthly_fee == Decimal("0.00")
        assert response.commission_rate == Decimal("0.1500")

    def test_default_subscription_carries_zero_credits(self):
        default = build_default_subscription(42)

        assert default["tier"] == "regular"
        assert default["is_default"] is True
        assert default["bar_id"] == 42
        assert default["credits"] == DEFAULT_CREDITS

    def test_subscription_status_enum_accepts_legacy_db_values(self):
        assert SubscriptionStatusEnum("trial").value == "trial"
        assert SubscriptionStatusEnum("past_due").value == "past_due"

    @pytest.mark.asyncio
    async def test_credits_endpoint_survives_legacy_credit_keys(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_subscription(bar_id, credits={"banner": 100, "promo_boost": 50})

        response = await client.get(f"/advertising/credits?bar_id={bar_id}", headers=headers)

        assert response.status_code == 200, response.text
        # Legacy keys don't crash; B6 decision: their value is preserved by folding both
        # legacy impression pots {"banner": 100, "promo_boost": 50} into boost_impressions
        # (alias-at-read — see .docs/FE_BE_COMMUNICATION.md §10) instead of returning zeros.
        assert response.json() == {
            "featured_hours": 0, "search_clicks": 0, "map_hours": 0, "boost_impressions": 150
        }


class TestCampaignContractAlignment:
    @pytest.mark.asyncio
    async def test_frontend_payload_creates_campaign_with_distribution(
        self, auth_client, test_bar_in_db
    ):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_subscription(bar_id, tier="master")

        payload = dict(FRONTEND_CAMPAIGN_PAYLOAD)
        payload["start_time"] = datetime.now(timezone.utc).isoformat()
        payload["end_time"] = (datetime.now(timezone.utc) + timedelta(days=30)).isoformat()

        response = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}", json=payload, headers=headers
        )

        assert response.status_code == 201, response.text
        body = response.json()
        assert body["campaign_type"] == "featured"
        assert body["budget_type"] == "credits"
        assert body["creative"]["title"] == "Campanha Destaque"
        assert body["creative"]["cta"] == "visit_now"
        assert body["targeting"]["age_range"] == {"min": 18, "max": 65}

        row = dict(
            await database.fetch_one(
                AdvertisingCampaign.__table__.select().where(AdvertisingCampaign.id == body["id"])
            )
        )

        stored_distribution = [
            {
                "placement": entry["placement"],
                "percentage": float(entry["percentage"]),
                "budget": Decimal(str(entry["budget"])),
            }
            for entry in row["distribution"]
        ]
        assert stored_distribution == [
            {"placement": "featured", "percentage": 50.0, "budget": Decimal("50.00")},
            {"placement": "search", "percentage": 50.0, "budget": Decimal("50.00")},
        ]
        assert row["budget_optimizer_enabled"] is True
        assert row["targeting"]["age_range"] == {"min": 18, "max": 65}

    @pytest.mark.asyncio
    async def test_placement_distribution_map_is_converted_to_list(
        self, auth_client, test_bar_in_db
    ):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_subscription(bar_id, tier="master")

        response = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}",
            json={
                "name": "Cash Campaign",
                "budget_type": "fixed",
                "budget_amount": 1000.0,
                "start_time": datetime.now(timezone.utc).isoformat(),
                "end_time": (datetime.now(timezone.utc) + timedelta(days=7)).isoformat(),
                "placement_distribution": {"featured": 60, "search": 40},
            },
            headers=headers
        )

        assert response.status_code == 201, response.text
        row = dict(
            await database.fetch_one(
                AdvertisingCampaign.__table__.select().where(
                    AdvertisingCampaign.id == response.json()["id"]
                )
            )
        )
        placements = {entry["placement"]: entry for entry in row["distribution"]}
        assert set(placements) == {"featured", "search"}
        assert float(placements["featured"]["percentage"]) == 60.0
        assert Decimal(str(placements["featured"]["budget"])) == Decimal("600.00")
        assert Decimal(str(placements["search"]["budget"])) == Decimal("400.00")

    @pytest.mark.asyncio
    async def test_legacy_daily_budget_type_is_rejected(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_subscription(bar_id, tier="master")

        response = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}",
            json={
                "name": "Legacy Payload",
                "budget_type": "daily",
                "budget_amount": 50.0,
                "start_time": datetime.now(timezone.utc).isoformat(),
            },
            headers=headers
        )

        assert response.status_code == 422
        assert "hourly" in response.text and "credits" in response.text

    @pytest.mark.asyncio
    async def test_push_notification_campaign_is_gated_by_tier(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_subscription(bar_id, tier="regular")

        payload = {
            "name": "Happy Hour Push",
            "campaign_type": "push_notification",
            "budget_type": "fixed",
            "budget_amount": 50.0,
            "start_time": datetime.now(timezone.utc).isoformat(),
        }

        forbidden = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}", json=payload, headers=headers
        )
        assert forbidden.status_code == 403

        await database.execute(
            AdvertisingSubscription.__table__.update()
            .where(AdvertisingSubscription.bar_id == bar_id)
            .values(tier="master")
        )

        accepted = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}", json=payload, headers=headers
        )
        assert accepted.status_code == 201, accepted.text
        assert accepted.json()["campaign_type"] == "push_notification"

    def test_invalid_placement_name_is_rejected(self):
        from pydantic import ValidationError

        with pytest.raises(ValidationError):
            PlacementDistribution(placement="billboard", percentage=100, budget=100)

    def test_placement_aliases_are_normalized(self):
        assert PlacementDistribution(placement="mapPin", percentage=100, budget=10).placement == "map_pin"
        assert PlacementDistribution(placement="map", percentage=100, budget=10).placement == "map_pin"
        assert PlacementDistribution(placement="promo_boost", percentage=100, budget=10).placement == "promo"


class TestRateCard:
    @pytest.mark.asyncio
    async def test_rate_card_exposes_rates_and_credit_mapping(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_region_pricing()
        await _seed_subscription(bar_id, tier="master")

        response = await client.get(f"/advertising/rates?bar_id={bar_id}", headers=headers)

        assert response.status_code == 200, response.text
        body = response.json()

        assert body["region_code"] == "BR"
        assert body["currency"] == "BRL"
        assert body["tier"] == "master"
        assert set(body["placements"]) == {
            "featured", "search", "map_pin", "promo", "banner", "push_notification"
        }

        # A2: `usable` mirrors the create-endpoint tier gate (master may create featured,
        # search, push_notification and promo_boost — promo was widened to Master per PDF §5.2;
        # banner/map stay VIP-only by deliberate restriction).
        assert {name: card["usable"] for name, card in body["placements"].items()} == {
            "featured": True, "search": True, "map_pin": False,
            "promo": True, "banner": False, "push_notification": True,
        }

        featured = body["placements"]["featured"]
        assert featured["pricing_model"] == "cph"
        assert featured["rate_unit"] == "per_hour"
        assert float(featured["rate"]) == 25.0
        assert featured["credit_bucket"] == "featured_hours"
        assert featured["credit_backed"] is True
        # A3 decision: `allowed_budget_types` carries the API-legal budget_type token (`hourly`),
        # never the pricing-model string `cph` — `cph` is not in BudgetTypeEnum/DB BudgetType.
        assert featured["allowed_budget_types"] == ["credits", "hourly", "fixed"]
        assert "cph" not in featured["allowed_budget_types"]
        assert float(featured["min_daily_budget"]) == 40.0

        search = body["placements"]["search"]
        assert search["pricing_model"] == "cpc"
        assert float(search["rate"]) == 0.80
        assert float(search["rate_max"]) == 2.50
        assert search["credit_bucket"] == "search_clicks"

        # `promo` is impressions-priced (ground truth: Dobar_Market_Analysis_Brazil_2026.pdf §5.2
        # "Product 4: Promotion Boost (CPM)"). It reads the same `boost_cpm` column as `banner` and
        # `push_notification`, so it must report the CPM model, not CPC.
        promo = body["placements"]["promo"]
        assert promo["pricing_model"] == "cpm"
        assert promo["rate_unit"] == "per_1000_impressions"
        assert promo["allowed_budget_types"] == ["credits", "cpm", "fixed"]
        assert promo["rate"] == body["placements"]["banner"]["rate"]
        assert promo["rate"] == body["placements"]["push_notification"]["rate"]
        assert float(promo["rate"]) == 8.0

        assert body["placements"]["map_pin"]["credit_bucket"] == "map_hours"
        assert body["placements"]["promo"]["credit_bucket"] == "boost_impressions"
        assert body["placements"]["banner"]["credit_bucket"] == "boost_impressions"
        assert body["placements"]["push_notification"]["credit_bucket"] is None
        assert body["placements"]["push_notification"]["credit_backed"] is False

        assert body["credit_buckets"] == [
            "featured_hours", "search_clicks", "map_hours", "boost_impressions"
        ]
        assert body["credits_by_tier"]["master"] == {
            "featured_hours": 4, "search_clicks": 200, "map_hours": 2, "boost_impressions": 5000
        }
        assert body["credits_by_tier"]["vip"] == {
            "featured_hours": 12, "search_clicks": 1000, "map_hours": 8, "boost_impressions": 25000
        }
        assert body["credits_available"] == {
            "featured_hours": 0, "search_clicks": 0, "map_hours": 0, "boost_impressions": 0
        }

    @pytest.mark.asyncio
    async def test_rate_card_returns_zero_rates_when_region_has_no_pricing(
        self, auth_client, test_bar_in_db
    ):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)

        response = await client.get(f"/advertising/rates?bar_id={bar_id}", headers=headers)

        assert response.status_code == 200, response.text
        body = response.json()
        assert float(body["placements"]["featured"]["rate"]) == 0.0
        assert body["placements"]["featured"]["allowed_budget_types"] == ["credits", "fixed"]
        assert body["placements"]["banner"]["allowed_budget_types"] == ["credits", "fixed"]
        # `promo` is CPM too, so with no regional rate it degrades to credits + fixed as well.
        assert body["placements"]["promo"]["pricing_model"] == "cpm"
        assert body["placements"]["promo"]["allowed_budget_types"] == ["credits", "fixed"]
        # A2: the bar is auto-provisioned as `regular`, which may create nothing — all six
        # placements are still advertised (quirk #6) but marked unusable.
        assert {name: card["usable"] for name, card in body["placements"].items()} == {
            name: False for name in body["placements"]
        }


class TestDistributionMinimums:
    @pytest.mark.asyncio
    async def test_credit_campaigns_skip_currency_minimums(self):
        distribution = [
            PlacementDistribution(placement="featured", percentage=50, budget=Decimal("2.00"))
        ]

        await _validate_distribution_minimums(
            distribution, BudgetTypeEnum.CREDITS, datetime.now(timezone.utc),
            datetime.now(timezone.utc) + timedelta(days=30)
        )

    @pytest.mark.asyncio
    async def test_cash_campaigns_enforce_currency_minimums(self):
        distribution = [
            PlacementDistribution(placement="featured", percentage=100, budget=Decimal("70.00"))
        ]

        with pytest.raises(APIError):
            await _validate_distribution_minimums(
                distribution, BudgetTypeEnum.FIXED, datetime.now(timezone.utc),
                datetime.now(timezone.utc) + timedelta(days=7)
            )

    @pytest.mark.asyncio
    async def test_cash_campaigns_scale_minimums_with_duration(self):
        distribution = [
            PlacementDistribution(placement="featured", percentage=100, budget=Decimal("280.00"))
        ]

        await _validate_distribution_minimums(
            distribution, BudgetTypeEnum.FIXED, datetime.now(timezone.utc),
            datetime.now(timezone.utc) + timedelta(days=7)
        )

        with pytest.raises(APIError):
            await _validate_distribution_minimums(
                distribution, BudgetTypeEnum.FIXED, datetime.now(timezone.utc),
                datetime.now(timezone.utc) + timedelta(days=30)
            )


def _promo_payload(**overrides):
    payload = {
        "name": "Promo Campaign",
        "campaign_type": "promo_boost",
        "budget_type": "credits",
        "budget_amount": 1000,
        "start_time": datetime.now(timezone.utc).isoformat(),
        "end_time": (datetime.now(timezone.utc) + timedelta(days=30)).isoformat(),
    }
    payload.update(overrides)
    return payload


class TestPromoTierGating:
    """A2: promo tier gating per PDF §5.2 (Master + VIP) and the fail-closed rule.

    Before this session the gate also had a fail-open hole: a payload that omitted
    `campaign_type` and had no resolvable `placement_distribution` skipped the check entirely.
    """

    @pytest.mark.asyncio
    async def test_regular_bar_is_rejected_with_403(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_subscription(bar_id, tier="regular")

        response = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}", json=_promo_payload(), headers=headers
        )

        assert response.status_code == 403
        assert "requires a higher subscription tier" in response.text

    @pytest.mark.asyncio
    async def test_master_bar_is_accepted(self, auth_client, test_bar_in_db):
        """PDF §5.2 gates Promotion Boost at Master + VIP — master must get 201 (it used to
        403 because the code allowed VIP only)."""
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_subscription(bar_id, tier="master")

        response = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}", json=_promo_payload(), headers=headers
        )

        assert response.status_code == 201, response.text
        assert response.json()["campaign_type"] == "promo_boost"

    @pytest.mark.asyncio
    async def test_vip_bar_is_accepted(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_subscription(bar_id, tier="vip")

        response = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}", json=_promo_payload(), headers=headers
        )

        assert response.status_code == 201, response.text
        assert response.json()["campaign_type"] == "promo_boost"

    @pytest.mark.asyncio
    async def test_omitted_campaign_type_fails_closed(self, auth_client, test_bar_in_db):
        """A payload with neither campaign_type nor placement_distribution can be neither
        gated, priced nor served — it used to bypass the tier gate (fail-open by omission)."""
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_subscription(bar_id, tier="regular")

        payload = {
            "name": "Typeless Campaign",
            "budget_type": "fixed",
            "budget_amount": 100.0,
            "start_time": datetime.now(timezone.utc).isoformat(),
        }
        response = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}", json=payload, headers=headers
        )

        assert response.status_code == 400
        assert "campaign_type or placement_distribution is required" in response.text


class TestBudgetTypeValidation:
    """A3: `budget_type` is validated against the placement's `allowed_budget_types` —
    the FE-doc sentence ("exactly the budget_type values accepted by POST") is enforced."""

    @pytest.mark.asyncio
    async def test_cph_is_never_a_legal_budget_type(self, auth_client, test_bar_in_db):
        """`cph` is a pricing model, not a budget_type: it is absent from BudgetTypeEnum and
        from the DB BudgetType enum, so create rejects it at the schema level (422)."""
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_subscription(bar_id, tier="master")

        response = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}",
            json=_promo_payload(campaign_type="featured", budget_type="cph"),
            headers=headers,
        )

        assert response.status_code == 422
        assert "hourly" in response.text

    @pytest.mark.asyncio
    async def test_metered_budget_type_rejected_for_wrong_placement(
        self, auth_client, test_bar_in_db
    ):
        """`cpc` belongs to search, not featured — previously any budget_type was accepted."""
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_subscription(bar_id, tier="master")
        await _seed_region_pricing()

        response = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}",
            json=_promo_payload(campaign_type="featured", budget_type="cpc"),
            headers=headers,
        )

        assert response.status_code == 400
        assert "not accepted for placement 'featured'" in response.text
        assert "hourly" in response.text

    @pytest.mark.asyncio
    async def test_search_accepts_cpc_when_region_has_a_rate(self, auth_client, test_bar_in_db):
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_subscription(bar_id, tier="master")
        await _seed_region_pricing()

        response = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}",
            json=_promo_payload(campaign_type="search", budget_type="cpc"),
            headers=headers,
        )

        assert response.status_code == 201, response.text

    @pytest.mark.asyncio
    async def test_credits_rejected_for_non_credit_backed_placement(
        self, auth_client, test_bar_in_db
    ):
        """push_notification has no credit bucket, so budget_type=credits is invalid there."""
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_subscription(bar_id, tier="master")

        response = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}",
            json=_promo_payload(
                campaign_type="push_notification", budget_type="credits", budget_amount=10
            ),
            headers=headers,
        )

        assert response.status_code == 400
        assert "not accepted for placement 'push_notification'" in response.text

    @pytest.mark.asyncio
    async def test_metered_budget_type_requires_a_configured_rate(
        self, auth_client, test_bar_in_db
    ):
        """The rate card only advertises a metered token when the region has a rate > 0;
        create enforces the same rule, so the advertised and accepted sets match exactly."""
        client, headers, user = auth_client
        bar_id = test_bar_in_db["id"]
        await _make_bar_owner(user["id"], bar_id)
        await _seed_subscription(bar_id, tier="master")

        payload = _promo_payload(campaign_type="featured", budget_type="hourly")

        rejected = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}", json=payload, headers=headers
        )
        assert rejected.status_code == 400
        assert "hourly" in rejected.text

        await _seed_region_pricing()
        accepted = await client.post(
            f"/advertising/campaigns?bar_id={bar_id}", json=payload, headers=headers
        )
        assert accepted.status_code == 201, accepted.text

