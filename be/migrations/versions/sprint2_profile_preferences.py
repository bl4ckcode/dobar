"""sprint2 profile preferences

Revision ID: sprint2_profile_prefs
Revises: fcf6c6a011db
Create Date: 2026-03-03
"""
from alembic import op
import sqlalchemy as sa

revision = 'sprint2_profile_prefs'
down_revision = 'fcf6c6a011db'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('user_profiles', sa.Column('push_notifications_enabled', sa.Boolean(), server_default='1'))
    op.add_column('user_profiles', sa.Column('order_updates_enabled', sa.Boolean(), server_default='1'))
    op.add_column('user_profiles', sa.Column('promotions_enabled', sa.Boolean(), server_default='1'))
    op.add_column('user_profiles', sa.Column('data_sharing_enabled', sa.Boolean(), server_default='0'))
    op.add_column('user_profiles', sa.Column('location_enabled', sa.Boolean(), server_default='0'))


def downgrade() -> None:
    op.drop_column('user_profiles', 'location_enabled')
    op.drop_column('user_profiles', 'data_sharing_enabled')
    op.drop_column('user_profiles', 'promotions_enabled')
    op.drop_column('user_profiles', 'order_updates_enabled')
    op.drop_column('user_profiles', 'push_notifications_enabled')
