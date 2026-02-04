"""add bundle promotions table

Revision ID: bundle_promotions_001
Revises: bar_categories_001
Create Date: 2026-02-04

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'bundle_promotions_001'
down_revision: Union[str, None] = 'bar_categories_001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'bundle_promotions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('bar_id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('description', sa.String(500), nullable=True),
        sa.Column('bundle_type', sa.String(20), nullable=False, server_default='quantity'),
        sa.Column('min_quantity', sa.Integer(), nullable=True, server_default='2'),
        sa.Column('target_items', sa.JSON(), nullable=True),
        sa.Column('target_category', sa.String(100), nullable=True),
        sa.Column('discount_type', sa.String(20), nullable=False, server_default='percentage'),
        sa.Column('discount_value', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('start_time', sa.String(5), nullable=True),
        sa.Column('end_time', sa.String(5), nullable=True),
        sa.Column('recurring_days', sa.JSON(), nullable=True),
        sa.Column('start_date', sa.DateTime(), nullable=True),
        sa.Column('end_date', sa.DateTime(), nullable=True),
        sa.Column('max_uses_per_user', sa.Integer(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=True, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('updated_at', sa.DateTime(), nullable=True, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_bundle_promotions_bar_id'), 'bundle_promotions', ['bar_id'], unique=False)
    op.create_index(op.f('ix_bundle_promotions_id'), 'bundle_promotions', ['id'], unique=False)
    op.create_index(op.f('ix_bundle_promotions_is_active'), 'bundle_promotions', ['is_active'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_bundle_promotions_is_active'), table_name='bundle_promotions')
    op.drop_index(op.f('ix_bundle_promotions_id'), table_name='bundle_promotions')
    op.drop_index(op.f('ix_bundle_promotions_bar_id'), table_name='bundle_promotions')
    op.drop_table('bundle_promotions')
