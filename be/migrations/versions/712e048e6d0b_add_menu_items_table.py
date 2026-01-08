"""add_menu_items_table

Revision ID: 712e048e6d0b
Revises: advertising_001
Create Date: 2026-01-07 18:59:44.871726

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '712e048e6d0b'
down_revision: Union[str, None] = 'advertising_001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add timestamps to menus table (if not exists)
    op.add_column('menus', sa.Column('created_at', sa.DateTime(), nullable=True, server_default=sa.func.now()))
    op.add_column('menus', sa.Column('updated_at', sa.DateTime(), nullable=True, server_default=sa.func.now()))
    
    # Create menu_items table
    op.create_table(
        'menu_items',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('menu_id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(200), nullable=False),
        sa.Column('price', sa.Float(), nullable=False),
        sa.Column('description', sa.String(500), nullable=True),
        sa.Column('category', sa.String(100), nullable=True),
        sa.Column('picture', sa.String(), nullable=True),
        sa.Column('available', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('display_order', sa.Integer(), nullable=True, server_default='0'),
        sa.Column('created_at', sa.DateTime(), nullable=True, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=True, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['menu_id'], ['menus.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_menu_items_id', 'menu_items', ['id'])
    op.create_index('ix_menu_items_menu_id', 'menu_items', ['menu_id'])
    op.create_index('ix_menu_items_category', 'menu_items', ['category'])
    op.create_index('ix_menu_items_available', 'menu_items', ['available'])


def downgrade() -> None:
    # Drop menu_items table
    op.drop_index('ix_menu_items_available', table_name='menu_items')
    op.drop_index('ix_menu_items_category', table_name='menu_items')
    op.drop_index('ix_menu_items_menu_id', table_name='menu_items')
    op.drop_index('ix_menu_items_id', table_name='menu_items')
    op.drop_table('menu_items')
    
    # Remove timestamps from menus
    op.drop_column('menus', 'updated_at')
    op.drop_column('menus', 'created_at')
