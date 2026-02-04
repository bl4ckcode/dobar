"""add_place_location_and_active_promotions

Revision ID: 8e2a1b190669
Revises: bundle_promotions_001
Create Date: 2026-02-04 15:37:53.945163

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '8e2a1b190669'
down_revision: Union[str, None] = 'bundle_promotions_001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 🆕 Place Location Logic
    op.execute("ALTER TABLE bars ADD COLUMN IF NOT EXISTS location_method VARCHAR(20) DEFAULT 'table_number'")
    # JSON columns need explicit casting or just ADD COLUMN if not exists
    op.execute("ALTER TABLE bars ADD COLUMN IF NOT EXISTS location_spots JSON DEFAULT '[]'::json")
    
    # 🆕 Order Location & Promotions
    op.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS location_identifier VARCHAR")
    op.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS active_promotion_ids JSON")

    # 🆕 Promotion benefits (Assuming 'promotions' table exists, if not we skip or create it? 
    # Based on models, Promotion model maps to 'promotions' table. 
    # If table doesn't exist, we might need to create it, but let's assume it does for now or check.)
    # Note: If 'promotions' doesn't exist, this will fail. We'll wrap in check or just try.
    # Checking if table exists before adding columns is good practice.
    op.execute("""
        DO $$ 
        BEGIN 
            IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'promotions') THEN
                ALTER TABLE promotions ADD COLUMN IF NOT EXISTS benefit_text VARCHAR(200);
                ALTER TABLE promotions ADD COLUMN IF NOT EXISTS promotion_type VARCHAR(20) DEFAULT 'discount';
            END IF;
        END $$;
    """)

def downgrade() -> None:
    # Remove added columns
    op.execute("ALTER TABLE bars DROP COLUMN IF EXISTS location_method")
    op.execute("ALTER TABLE bars DROP COLUMN IF EXISTS location_spots")
    op.execute("ALTER TABLE orders DROP COLUMN IF EXISTS location_identifier")
    op.execute("ALTER TABLE orders DROP COLUMN IF EXISTS active_promotion_ids")
    
    op.execute("""
        DO $$ 
        BEGIN 
            IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'promotions') THEN
                ALTER TABLE promotions DROP COLUMN IF EXISTS benefit_text;
                ALTER TABLE promotions DROP COLUMN IF EXISTS promotion_type;
            END IF;
        END $$;
    """)


# Duplicate downgrade function removed
