"""
Add business settings columns to bars table

Revision ID: 20250526_business_settings
Revises: xyz_add_plan_features
Create Date: 2026-05-26 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSON

revision = '20250526_business_settings'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('bars', sa.Column('description', sa.Text(), nullable=True))
    op.add_column('bars', sa.Column('website', sa.String(255), nullable=True))
    op.add_column('bars', sa.Column('instagram', sa.String(100), nullable=True))
    op.add_column('bars', sa.Column('facebook', sa.String(100), nullable=True))
    op.add_column('bars', sa.Column('whatsapp', sa.String(20), nullable=True))
    op.add_column('bars', sa.Column('whatsapp_enabled', sa.Boolean(), server_default='false', nullable=False))
    op.add_column('bars', sa.Column('timezone', sa.String(50), server_default='America/Sao_Paulo', nullable=True))
    op.add_column('bars', sa.Column('status', sa.String(20), server_default='active', nullable=False))
    op.add_column('bars', sa.Column('deactivated_at', sa.DateTime(), nullable=True))
    op.add_column('bars', sa.Column('deactivation_reason', sa.String(50), nullable=True))
    op.add_column('bars', sa.Column('estimated_return_date', sa.DateTime(), nullable=True))
    op.add_column('bars', sa.Column('rating', sa.Float(), server_default='0.0', nullable=False))


def downgrade():
    op.drop_column('bars', 'rating')
    op.drop_column('bars', 'estimated_return_date')
    op.drop_column('bars', 'deactivation_reason')
    op.drop_column('bars', 'deactivated_at')
    op.drop_column('bars', 'status')
    op.drop_column('bars', 'timezone')
    op.drop_column('bars', 'whatsapp_enabled')
    op.drop_column('bars', 'whatsapp')
    op.drop_column('bars', 'facebook')
    op.drop_column('bars', 'instagram')
    op.drop_column('bars', 'website')
    op.drop_column('bars', 'description')