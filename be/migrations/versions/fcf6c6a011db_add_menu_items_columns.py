"""add menu items columns

Revision ID: fcf6c6a011db
Revises: recovery_tokens_001
Create Date: 2026-02-17 19:02:27.712054

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'fcf6c6a011db'
down_revision: Union[str, None] = 'recovery_tokens_001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None



def upgrade() -> None:
    # Add new columns to menu_items table
    op.add_column('menu_items', sa.Column('promotional_price', sa.Float(), nullable=True))
    op.add_column('menu_items', sa.Column('picture', sa.String(), nullable=True))
    op.add_column('menu_items', sa.Column('available', sa.Boolean(), server_default='true', nullable=True))
    op.add_column('menu_items', sa.Column('category', sa.String(length=100), nullable=True))
    op.add_column('menu_items', sa.Column('display_order', sa.Integer(), server_default='0', nullable=True))
    
    # Create indexes for new columns
    op.create_index(op.f('ix_menu_items_available'), 'menu_items', ['available'], unique=False)
    op.create_index(op.f('ix_menu_items_category'), 'menu_items', ['category'], unique=False)


def downgrade() -> None:
    # Drop indexes
    op.drop_index(op.f('ix_menu_items_category'), table_name='menu_items')
    op.drop_index(op.f('ix_menu_items_available'), table_name='menu_items')
    
    # Drop columns
    op.drop_column('menu_items', 'display_order')
    op.drop_column('menu_items', 'category')
    op.drop_column('menu_items', 'available')
    op.drop_column('menu_items', 'picture')
    op.drop_column('menu_items', 'promotional_price')

