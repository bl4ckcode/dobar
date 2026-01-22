"""Add bar category fields

Revision ID: bar_categories_001
Revises: bar_wizard_001
Create Date: 2026-01-22
"""
from alembic import op
import sqlalchemy as sa

revision = 'bar_categories_001'
down_revision = 'idempotency_001'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        DO $$ 
        BEGIN 
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bars' AND column_name='category') THEN
                ALTER TABLE bars ADD COLUMN category VARCHAR(50);
            END IF;
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bars' AND column_name='google_types') THEN
                ALTER TABLE bars ADD COLUMN google_types JSONB;
            END IF;
        END $$;
    """)
    
    op.execute("CREATE INDEX IF NOT EXISTS ix_bars_category ON bars(category)")


def downgrade():
    op.execute('DROP INDEX IF EXISTS ix_bars_category')
    op.drop_column('bars', 'google_types')
    op.drop_column('bars', 'category')
