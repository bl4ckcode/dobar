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
    # Add new columns to menus table using raw SQL to support IF NOT EXISTS
    op.execute("ALTER TABLE menus ADD COLUMN IF NOT EXISTS name VARCHAR DEFAULT 'Menu Principal'")
    op.execute("ALTER TABLE menus ADD COLUMN IF NOT EXISTS description VARCHAR")
    op.execute("ALTER TABLE menus ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true")


def downgrade():
    op.drop_column('menus', 'is_active')
    op.drop_column('menus', 'description')
    op.drop_column('menus', 'name')
