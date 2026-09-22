"""
Fix region_pricing tier data swap between Master and VIP tiers.

Revision ID: 20250720_fix_pricing_swap
Revises: dob_82_budget_management
Create Date: 2026-07-20 22:00:00.000000

Detects and corrects swapped Master/VIP pricing data in region_pricing table.
The seed data and i18n migration (MAY 25, 2026) caused Master and VIP tier
columns to be populated with each other's values — commission rates, annual
prices, and features JSON were all swapped.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.sql import text

revision = '20250720_fix_pricing_swap'
down_revision = 'dob_82_budget_management'
branch_labels = None
depends_on = None


def upgrade():
    conn = op.get_bind()
    
    # Check current state of region_pricing
    rows = conn.execute(
        text("SELECT id, region_code, master_monthly, master_annual, vip_monthly, vip_annual, "
             "master_commission, vip_commission, regular_commission, "
             "master_credits, vip_credits, "
             "master_features, vip_features, regular_features "
             "FROM region_pricing")
    ).fetchall()
    
    for row in rows:
        r = dict(row._mapping)
        region = r["region_code"]
        
        # Detect swap: correct data has Master annual < VIP annual and Master commission > VIP commission
        # If either is inverted, the Master/VIP columns were swapped by bad seed data
        master_annual = r.get("master_annual") or 0
        vip_annual = r.get("vip_annual") or 0
        master_commission = float(r.get("master_commission") or 0)
        vip_commission = float(r.get("vip_commission") or 0)
        regular_commission = float(r.get("regular_commission") or 0.15)
        
        needs_swap = False
        
        # Detection heuristic:
        # Correct order: Regular > Master > VIP (higher tiers get lower commission)
        # If Master commission < VIP commission, they're swapped
        if master_commission < vip_commission and master_commission > 0:
            needs_swap = True
        
        # Also detect: if Master annual > VIP annual (correct: Master < VIP in price)
        if not needs_swap and master_annual > vip_annual and vip_annual > 0:
            needs_swap = True
        
        if needs_swap:
            print(f"Detected Master/VIP data swap for region {region}. Correcting...")
            
            # Swap pricing columns
            conn.execute(
                text("""
                    UPDATE region_pricing SET
                        master_monthly = :vip_m, master_annual = :vip_a,
                        vip_monthly = :master_m, vip_annual = :master_a,
                        master_commission = :vip_c, vip_commission = :master_c,
                        master_credits = :vip_cred, vip_credits = :master_cred,
                        master_features = :vip_feat, vip_features = :master_feat
                    WHERE id = :id
                """),
                {
                    "id": r["id"],
                    "vip_m": r["vip_monthly"],
                    "vip_a": r["vip_annual"],
                    "master_m": r["master_monthly"],
                    "master_a": r["master_annual"],
                    "vip_c": r["vip_commission"],
                    "master_c": r["master_commission"],
                    "vip_cred": r["vip_credits"],
                    "master_cred": r["master_credits"],
                    "vip_feat": r["vip_features"],
                    "master_feat": r["master_features"],
                }
            )
            print(f"Fixed region_pricing for {region}")
        else:
            print(f"No swap detected for region {region}. Master={master_commission:.2%}, VIP={vip_commission:.2%}")
    
    # Ensure features arrays have correct tier-appropriate feature keys
    # This handles the case where features might be missing or empty
    expected_features = {
        "regular": [
            "feature_basic_listing",
            "feature_order_management",
            "feature_basic_analytics",
        ],
        "master": [
            "feature_everything_regular",
            "feature_reduced_commission",
            "feature_monthly_credits",
            "feature_featured_home",
            "feature_sponsored_search",
            "feature_priority_support",
        ],
        "vip": [
            "feature_everything_master",
            "feature_lowest_commission",
            "feature_max_credits",
            "feature_map_spotlight",
            "feature_promotion_boost",
            "feature_rich_media_banners",
            "feature_verified_badge",
            "feature_dedicated_manager",
        ],
    }
    
    import json
    
    # Fix regular_features if null or wrong count
    conn.execute(
        text("""
            UPDATE region_pricing 
            SET regular_features = :features 
            WHERE regular_features IS NULL 
               OR regular_features = '[]'::jsonb
               OR jsonb_array_length(regular_features::jsonb) < 3
        """),
        {"features": json.dumps(expected_features["regular"])}
    )
    
    # Fix master_features if null or wrong count
    conn.execute(
        text("""
            UPDATE region_pricing 
            SET master_features = :features 
            WHERE master_features IS NULL 
               OR master_features = '[]'::jsonb
               OR jsonb_array_length(master_features::jsonb) < 6
        """),
        {"features": json.dumps(expected_features["master"])}
    )
    
    # Fix vip_features if null or wrong count
    conn.execute(
        text("""
            UPDATE region_pricing 
            SET vip_features = :features 
            WHERE vip_features IS NULL 
               OR vip_features = '[]'::jsonb
               OR jsonb_array_length(vip_features::jsonb) < 8
        """),
        {"features": json.dumps(expected_features["vip"])}
    )
    
    print("Region pricing features corrected.")


def downgrade():
    # No downgrade — this is a data fix, not a schema change.
    # Re-applying the original seed data would be the reverse operation.
    pass