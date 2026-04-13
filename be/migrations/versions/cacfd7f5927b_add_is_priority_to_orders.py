"""add_is_priority_to_orders

Revision ID: cacfd7f5927b
Revises: 8eb066b9964f
Create Date: 2026-04-08 23:10:16.404481

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'cacfd7f5927b'
down_revision: Union[str, None] = '8eb066b9964f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add is_priority to orders
    op.add_column('orders', sa.Column('is_priority', sa.Boolean(), nullable=True))
    op.create_index(op.f('ix_orders_is_priority'), 'orders', ['is_priority'], unique=False)
    # Set default for existing orders
    op.execute("UPDATE orders SET is_priority = False WHERE is_priority IS NULL")


def downgrade() -> None:
    # Remove from orders
    op.drop_index(op.f('ix_orders_is_priority'), table_name='orders')
    op.drop_column('orders', 'is_priority')
