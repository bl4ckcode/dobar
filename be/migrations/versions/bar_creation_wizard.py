"""Add bar creation wizard fields

Revision ID: bar_wizard_001
Revises: advertising_tables_001
Create Date: 2026-01-10
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers
revision = 'bar_wizard_001'
down_revision = 'advertising_tables_001'
branch_labels = None
depends_on = None


def upgrade():
    # Add new columns to bars table for Create Bar Wizard
    op.add_column('bars', sa.Column('country_code', sa.String(2), nullable=True, server_default='BR'))
    op.add_column('bars', sa.Column('business_id', sa.String(50), nullable=True))
    op.add_column('bars', sa.Column('business_id_type', sa.String(20), nullable=True))
    op.add_column('bars', sa.Column('state_registration', sa.String(50), nullable=True))
    op.add_column('bars', sa.Column('verification_status', sa.String(20), nullable=True, server_default='pending'))
    
    # Media fields
    op.add_column('bars', sa.Column('logo_url', sa.String(), nullable=True))
    op.add_column('bars', sa.Column('cover_url', sa.String(), nullable=True))
    op.add_column('bars', sa.Column('photo_urls', sa.JSON(), nullable=True))
    
    # Operating hours
    op.add_column('bars', sa.Column('operating_hours', sa.JSON(), nullable=True))
    
    # Timestamps
    op.add_column('bars', sa.Column('created_at', sa.DateTime(), nullable=True, server_default=sa.func.now()))
    op.add_column('bars', sa.Column('updated_at', sa.DateTime(), nullable=True, server_default=sa.func.now()))
    
    # Create indexes
    op.create_index('ix_bars_country_code', 'bars', ['country_code'])
    op.create_index('ix_bars_business_id', 'bars', ['business_id'])
    op.create_index('ix_bars_verification_status', 'bars', ['verification_status'])
    
    # Create unique constraint on (country_code, business_id) where business_id is not null
    # Note: PostgreSQL partial unique index
    op.execute('''
        CREATE UNIQUE INDEX ix_bars_country_business_id 
        ON bars(country_code, business_id) 
        WHERE business_id IS NOT NULL
    ''')


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
