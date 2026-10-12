"""Add paused_at and budget_spent_per_placement columns

Revision ID: dob_82_budget_management
Revises: 20250711_campaign_extensions
Create Date: 2026-07-12 16:31:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'dob_82_budget_management'
down_revision: Union[str, None] = '20250711_campaign_extensions'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add paused_at for pro-ration calculations
    op.add_column('advertising_campaigns', sa.Column('paused_at', sa.DateTime(timezone=True), nullable=True))
    
    # Add budget_spent_per_placement for per-placement tracking
    op.add_column('advertising_campaigns', sa.Column('budget_spent_per_placement', postgresql.JSONB(astext_type=sa.Text()), nullable=True, server_default='{}'))


def downgrade() -> None:
    op.drop_column('advertising_campaigns', 'budget_spent_per_placement')
    op.drop_column('advertising_campaigns', 'paused_at')