"""Add bar creation wizard fields

Revision ID: bar_wizard_001
Revises: 712e048e6d0b
Create Date: 2026-01-10
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers
revision = 'bar_wizard_001'
down_revision = '712e048e6d0b'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        DO $$ 
        BEGIN 
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bars' AND column_name='country_code') THEN
                ALTER TABLE bars ADD COLUMN country_code VARCHAR(2) DEFAULT 'BR';
            END IF;
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bars' AND column_name='business_id') THEN
                ALTER TABLE bars ADD COLUMN business_id VARCHAR(50);
            END IF;
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bars' AND column_name='business_id_type') THEN
                ALTER TABLE bars ADD COLUMN business_id_type VARCHAR(20);
            END IF;
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bars' AND column_name='state_registration') THEN
                ALTER TABLE bars ADD COLUMN state_registration VARCHAR(50);
            END IF;
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bars' AND column_name='verification_status') THEN
                ALTER TABLE bars ADD COLUMN verification_status VARCHAR(20) DEFAULT 'pending';
            END IF;
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bars' AND column_name='logo_url') THEN
                ALTER TABLE bars ADD COLUMN logo_url VARCHAR;
            END IF;
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bars' AND column_name='cover_url') THEN
                ALTER TABLE bars ADD COLUMN cover_url VARCHAR;
            END IF;
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bars' AND column_name='photo_urls') THEN
                ALTER TABLE bars ADD COLUMN photo_urls JSON;
            END IF;
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bars' AND column_name='operating_hours') THEN
                ALTER TABLE bars ADD COLUMN operating_hours JSON;
            END IF;
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bars' AND column_name='created_at') THEN
                ALTER TABLE bars ADD COLUMN created_at TIMESTAMP DEFAULT NOW();
            END IF;
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bars' AND column_name='updated_at') THEN
                ALTER TABLE bars ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();
            END IF;
        END $$;
    """)
    
    op.execute("CREATE INDEX IF NOT EXISTS ix_bars_country_code ON bars(country_code)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_bars_business_id ON bars(business_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_bars_verification_status ON bars(verification_status)")
    op.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS ix_bars_country_business_id 
        ON bars(country_code, business_id) 
        WHERE business_id IS NOT NULL
    """)


def downgrade():
    # Drop indexes
    op.execute('DROP INDEX IF EXISTS ix_bars_country_business_id')
    op.drop_index('ix_bars_verification_status')
    op.drop_index('ix_bars_business_id')
    op.drop_index('ix_bars_country_code')
    
    # Drop columns
    op.drop_column('bars', 'updated_at')
    op.drop_column('bars', 'created_at')
    op.drop_column('bars', 'operating_hours')
    op.drop_column('bars', 'photo_urls')
    op.drop_column('bars', 'cover_url')
    op.drop_column('bars', 'logo_url')
    op.drop_column('bars', 'verification_status')
    op.drop_column('bars', 'state_registration')
    op.drop_column('bars', 'business_id_type')
    op.drop_column('bars', 'business_id')
    op.drop_column('bars', 'country_code')
