"""add promotions table

Revision ID: promo001
Revises: abc123def456
Create Date: 2026-01-01

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'promo001'
down_revision = 'abc123def456'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'promotions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('bar_id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(200), nullable=False),
        sa.Column('description', sa.String(1000), nullable=True),
        sa.Column('discount_type', sa.String(20), nullable=False, server_default='percentage'),
        sa.Column('discount_value', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('start_time', sa.String(5), nullable=True),
        sa.Column('end_time', sa.String(5), nullable=True),
        sa.Column('start_date', sa.DateTime(), nullable=True),
        sa.Column('end_date', sa.DateTime(), nullable=True),
        sa.Column('recurring', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('recurring_days', sa.JSON(), nullable=True),
        sa.Column('terms', sa.String(500), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('image_url', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_promotions_bar_id'), 'promotions', ['bar_id'], unique=False)
    op.create_index(op.f('ix_promotions_id'), 'promotions', ['id'], unique=False)
    op.create_index(op.f('ix_promotions_is_active'), 'promotions', ['is_active'], unique=False)


def downgrade():
    op.drop_index(op.f('ix_promotions_is_active'), table_name='promotions')
    op.drop_index(op.f('ix_promotions_id'), table_name='promotions')
    op.drop_index(op.f('ix_promotions_bar_id'), table_name='promotions')
    op.drop_table('promotions')
