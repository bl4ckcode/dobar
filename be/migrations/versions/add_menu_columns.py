"""Add name, description, is_active columns to menus table

Revision ID: menu001
Revises: promo001
Create Date: 2026-01-02
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'menu001'
down_revision = 'promo001'
branch_labels = None
depends_on = None


def upgrade():
    # Add new columns to menus table
    op.add_column('menus', sa.Column('name', sa.String(), nullable=True, server_default='Menu Principal'))
    op.add_column('menus', sa.Column('description', sa.String(), nullable=True))
    op.add_column('menus', sa.Column('is_active', sa.Boolean(), nullable=True, server_default='true'))


def downgrade():
    op.drop_column('menus', 'is_active')
    op.drop_column('menus', 'description')
    op.drop_column('menus', 'name')
