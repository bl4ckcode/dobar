"""Add campaign goal, distribution, targeting, and draft support columns

Revision ID: dob_82_campaign_extensions
Revises: a3f1d2e4b5c6
Create Date: 2026-07-10 21:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'dob_82_campaign_extensions'
down_revision: Union[str, None] = 'a3f1d2e4b5c6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add new columns to advertising_campaigns table
    
    # Campaign goal enum
    op.add_column('advertising_campaigns', sa.Column('campaign_goal', sa.String(length=50), nullable=True))
    
    # Distribution as JSON (list of placement objects with percentage and budget)
    op.add_column('advertising_campaigns', sa.Column('distribution', postgresql.JSONB(astext_type=sa.Text()), nullable=True, server_default='[]'))
    
    # Smart distribution flag
    op.add_column('advertising_campaigns', sa.Column('is_smart_distribution', sa.Boolean(), nullable=False, server_default='false'))
    
    # Budget optimizer flag
    op.add_column('advertising_campaigns', sa.Column('budget_optimizer_enabled', sa.Boolean(), nullable=False, server_default='false'))
    
    # Estimated performance as JSON
    op.add_column('advertising_campaigns', sa.Column('estimated_performance', postgresql.JSONB(astext_type=sa.Text()), nullable=True, server_default='{}'))
    
    # Update targeting column to include age_range if it doesn't exist
    # The column already exists as JSON, we just need to update the default structure in code
    
    # Add index on bar_id + status for filtered queries (already exists but let's ensure it covers our needs)
    op.create_index('idx_campaign_bar_status_goal', 'advertising_campaigns', ['bar_id', 'status', 'campaign_goal'], unique=False)


def downgrade() -> None:
    op.drop_index('idx_campaign_bar_status_goal', table_name='advertising_campaigns')
    op.drop_column('advertising_campaigns', 'estimated_performance')
    op.drop_column('advertising_campaigns', 'budget_optimizer_enabled')
    op.drop_column('advertising_campaigns', 'is_smart_distribution')
    op.drop_column('advertising_campaigns', 'distribution')
    op.drop_column('advertising_campaigns', 'campaign_goal')