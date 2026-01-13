"""add_menu_items_table

Revision ID: 712e048e6d0b
Revises: advertising_001
Create Date: 2026-01-07 18:59:44.871726

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '712e048e6d0b'
down_revision: Union[str, None] = 'advertising_001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("""
        DO $$ 
        BEGIN 
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='menus' AND column_name='created_at') THEN
                ALTER TABLE menus ADD COLUMN created_at TIMESTAMP DEFAULT NOW();
            END IF;
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='menus' AND column_name='updated_at') THEN
                ALTER TABLE menus ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();
            END IF;
        END $$;
    """)
    
    op.execute("""
        CREATE TABLE IF NOT EXISTS menu_items (
            id SERIAL PRIMARY KEY,
            menu_id INTEGER NOT NULL REFERENCES menus(id) ON DELETE CASCADE,
            name VARCHAR(200) NOT NULL,
            price FLOAT NOT NULL,
            description VARCHAR(500),
            category VARCHAR(100),
            picture VARCHAR,
            available BOOLEAN DEFAULT TRUE,
            display_order INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT NOW(),
            updated_at TIMESTAMP DEFAULT NOW()
        );
        CREATE INDEX IF NOT EXISTS ix_menu_items_id ON menu_items(id);
        CREATE INDEX IF NOT EXISTS ix_menu_items_menu_id ON menu_items(menu_id);
        CREATE INDEX IF NOT EXISTS ix_menu_items_category ON menu_items(category);
        CREATE INDEX IF NOT EXISTS ix_menu_items_available ON menu_items(available);
    """)


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS menu_items CASCADE")
    op.execute("ALTER TABLE menus DROP COLUMN IF EXISTS updated_at")
    op.execute("ALTER TABLE menus DROP COLUMN IF EXISTS created_at")
