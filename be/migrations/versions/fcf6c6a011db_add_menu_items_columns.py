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
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    existing_columns = [col['name'] for col in inspector.get_columns('menu_items')]

    # Add new columns to menu_items table if they don't exist
    if 'promotional_price' not in existing_columns:
        op.add_column('menu_items', sa.Column('promotional_price', sa.Float(), nullable=True))
    if 'picture' not in existing_columns:
        op.add_column('menu_items', sa.Column('picture', sa.String(), nullable=True))
    if 'available' not in existing_columns:
        op.add_column('menu_items', sa.Column('available', sa.Boolean(), server_default='true', nullable=True))
    if 'category' not in existing_columns:
        op.add_column('menu_items', sa.Column('category', sa.String(length=100), nullable=True))
    if 'display_order' not in existing_columns:
        op.add_column('menu_items', sa.Column('display_order', sa.Integer(), server_default='0', nullable=True))
    
    # Create indexes for new columns
    # Check if indexes exist first to avoid errors (though create_index usually has if_not_exists in some dialects, explicit check is safer)
    existing_indexes = [idx['name'] for idx in inspector.get_indexes('menu_items')]
    
    if 'ix_menu_items_available' not in existing_indexes:
        op.create_index(op.f('ix_menu_items_available'), 'menu_items', ['available'], unique=False)
    if 'ix_menu_items_category' not in existing_indexes:
        op.create_index(op.f('ix_menu_items_category'), 'menu_items', ['category'], unique=False)


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    existing_columns = [col['name'] for col in inspector.get_columns('menu_items')]
    existing_indexes = [idx['name'] for idx in inspector.get_indexes('menu_items')]

    # Drop indexes
    if 'ix_menu_items_category' in existing_indexes:
        op.drop_index(op.f('ix_menu_items_category'), table_name='menu_items')
    if 'ix_menu_items_available' in existing_indexes:
        op.drop_index(op.f('ix_menu_items_available'), table_name='menu_items')
    
    # Drop columns
    if 'display_order' in existing_columns:
        op.drop_column('menu_items', 'display_order')
    if 'category' in existing_columns:
        op.drop_column('menu_items', 'category')
    if 'available' in existing_columns:
        op.drop_column('menu_items', 'available')
    if 'picture' in existing_columns:
        op.drop_column('menu_items', 'picture')
    if 'promotional_price' in existing_columns:
        op.drop_column('menu_items', 'promotional_price')

