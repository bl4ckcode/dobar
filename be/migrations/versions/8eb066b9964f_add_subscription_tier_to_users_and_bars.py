"""add_subscription_tier_to_users_and_bars

Revision ID: 8eb066b9964f
Revises: 05ad11a8d585
Create Date: 2026-04-08 23:09:05.129965

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '8eb066b9964f'
down_revision: Union[str, None] = '05ad11a8d585'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add subscription_tier to bars
    op.add_column('bars', sa.Column('subscription_tier', sa.String(length=20), nullable=True))
    op.create_index(op.f('ix_bars_subscription_tier'), 'bars', ['subscription_tier'], unique=False)
    # Set default for existing bars
    op.execute("UPDATE bars SET subscription_tier = 'regular' WHERE subscription_tier IS NULL")
    
    # Add subscription_tier to users
    op.add_column('users', sa.Column('subscription_tier', sa.String(length=20), nullable=True))
    op.create_index(op.f('ix_users_subscription_tier'), 'users', ['subscription_tier'], unique=False)
    # Set default for existing users
    op.execute("UPDATE users SET subscription_tier = 'regular' WHERE subscription_tier IS NULL")


def downgrade() -> None:
    # Remove from users
    op.drop_index(op.f('ix_users_subscription_tier'), table_name='users')
    op.drop_column('users', 'subscription_tier')
    
    # Remove from bars
    op.drop_index(op.f('ix_bars_subscription_tier'), table_name='bars')
    op.drop_column('bars', 'subscription_tier')
