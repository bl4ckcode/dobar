"""Add city and state columns to bars table

Revision ID: 20250531_city_state
Revises: 20250526_business_settings
Create Date: 2026-05-31 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


revision = '20250531_city_state'
down_revision = '20250526_business_settings'
branch_labels = None
depends_on = None


def upgrade():
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    existing_columns = [col['name'] for col in inspector.get_columns('bars')]
    
    if 'city' not in existing_columns:
        op.add_column('bars', sa.Column('city', sa.String(100), nullable=True))
    if 'state' not in existing_columns:
        op.add_column('bars', sa.Column('state', sa.String(100), nullable=True))


def downgrade():
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    existing_columns = [col['name'] for col in inspector.get_columns('bars')]
    
    if 'state' in existing_columns:
        op.drop_column('bars', 'state')
    if 'city' in existing_columns:
        op.drop_column('bars', 'city')