"""
Add plan features JSON columns to region_pricing

Revision ID: xyz_add_plan_features
Revises: cacfd7f5927b
Create Date: 2026-05-25 23:00:00.000000
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSON
import json

revision = 'xyz_add_plan_features'
down_revision = '20250503_add_waitlist'
branch_labels = None
depends_on = None


REGULAR_FEATURES = json.dumps([
    "feature_basic_listing",
    "feature_order_management",
    "feature_basic_analytics",
])

MASTER_FEATURES = json.dumps([
    "feature_everything_regular",
    "feature_reduced_commission",
    "feature_monthly_credits",
    "feature_featured_home",
    "feature_sponsored_search",
    "feature_priority_support",
])

VIP_FEATURES = json.dumps([
    "feature_everything_master",
    "feature_lowest_commission",
    "feature_max_credits",
    "feature_map_spotlight",
    "feature_promotion_boost",
    "feature_rich_media_banners",
    "feature_verified_badge",
    "feature_dedicated_manager",
])


def upgrade():
    op.add_column('region_pricing', sa.Column('regular_features', JSON, nullable=False, server_default=REGULAR_FEATURES))
    op.add_column('region_pricing', sa.Column('master_features', JSON, nullable=False, server_default=MASTER_FEATURES))
    op.add_column('region_pricing', sa.Column('vip_features', JSON, nullable=False, server_default=VIP_FEATURES))


def downgrade():
    op.drop_column('region_pricing', 'regular_features')
    op.drop_column('region_pricing', 'master_features')
    op.drop_column('region_pricing', 'vip_features')