"""Add Bar latitude longitude models

Revision ID: 280c4dca44c3
Revises: cacfd7f5927b
Create Date: 2026-04-13 23:11:30.505399

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '280c4dca44c3'
down_revision: Union[str, None] = 'cacfd7f5927b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add geofencing geometry to bars
    op.add_column('bars', sa.Column('latitude', sa.Float(), nullable=True))
    op.add_column('bars', sa.Column('longitude', sa.Float(), nullable=True))
    op.create_index(op.f('ix_bars_latitude'), 'bars', ['latitude'], unique=False)
    op.create_index(op.f('ix_bars_longitude'), 'bars', ['longitude'], unique=False)


def downgrade() -> None:
    # Remove geofencing geometry from bars
    op.drop_index(op.f('ix_bars_longitude'), table_name='bars')
    op.drop_index(op.f('ix_bars_latitude'), table_name='bars')
    op.drop_column('bars', 'longitude')
    op.drop_column('bars', 'latitude')
