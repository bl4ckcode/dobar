"""Add country_code to user_profiles

Revision ID: country001
Revises: profile001
Create Date: 2026-01-06

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'country001'
down_revision = 'profile001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add country_code column to user_profiles
    op.add_column('user_profiles', sa.Column('country_code', sa.String(2), nullable=True))
    
    # Create index for faster country-based queries
    op.create_index('ix_user_profiles_country_code', 'user_profiles', ['country_code'])


def downgrade() -> None:
    op.drop_index('ix_user_profiles_country_code', table_name='user_profiles')
    op.drop_column('user_profiles', 'country_code')
