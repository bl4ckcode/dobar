"""Add profile completion fields

Revision ID: profile001
Revises: rbac001
Create Date: 2026-01-04
"""
from alembic import op
import sqlalchemy as sa

revision = 'profile001'
down_revision = 'rbac001'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('user_profiles', sa.Column('terms_accepted', sa.Boolean(), nullable=True, server_default='false'))
    op.add_column('user_profiles', sa.Column('terms_accepted_at', sa.DateTime(), nullable=True))
    op.add_column('user_profiles', sa.Column('privacy_accepted', sa.Boolean(), nullable=True, server_default='false'))
    op.add_column('user_profiles', sa.Column('privacy_accepted_at', sa.DateTime(), nullable=True))

def downgrade():
    op.drop_column('user_profiles', 'privacy_accepted_at')
    op.drop_column('user_profiles', 'privacy_accepted')
    op.drop_column('user_profiles', 'terms_accepted_at')
    op.drop_column('user_profiles', 'terms_accepted')
