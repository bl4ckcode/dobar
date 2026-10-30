"""Add pro_coupon_usages table for consumer monthly coupon allowance

Revision ID: dob_93_pro_monthly_coupons
Revises: dob_92_user_contact_verification
Create Date: 2026-10-30 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = 'dob_93_pro_monthly_coupons'
down_revision: Union[str, None] = 'dob_92_user_contact_verification'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'pro_coupon_usages',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('promotion_id', sa.Integer(), nullable=True),
        sa.Column('order_id', sa.Integer(), nullable=True),
        sa.Column('period_key', sa.String(length=7), nullable=False),
        sa.Column('status', sa.Enum('RESERVED', 'REDEEMED', 'RELEASED', 'REFUNDED', name='procouponstatus'), nullable=False),
        sa.Column('cashback_amount', sa.Numeric(precision=10, scale=2), nullable=True),
        sa.Column('cashback_ledger_id', sa.Integer(), nullable=True),
        sa.Column('bar_id', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['cashback_ledger_id'], ['cashback_ledger.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['promotion_id'], ['promotions.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('idx_pro_coupon_user_period_status', 'pro_coupon_usages', ['user_id', 'period_key', 'status'], unique=False)
    op.create_index('uq_pro_coupon_order_promo', 'pro_coupon_usages', ['order_id', 'promotion_id'], unique=True)
    op.create_index(op.f('ix_pro_coupon_usages_id'), 'pro_coupon_usages', ['id'], unique=False)
    op.create_index(op.f('ix_pro_coupon_usages_order_id'), 'pro_coupon_usages', ['order_id'], unique=False)
    op.create_index(op.f('ix_pro_coupon_usages_period_key'), 'pro_coupon_usages', ['period_key'], unique=False)
    op.create_index(op.f('ix_pro_coupon_usages_promotion_id'), 'pro_coupon_usages', ['promotion_id'], unique=False)
    op.create_index(op.f('ix_pro_coupon_usages_status'), 'pro_coupon_usages', ['status'], unique=False)
    op.create_index(op.f('ix_pro_coupon_usages_user_id'), 'pro_coupon_usages', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_pro_coupon_usages_user_id'), table_name='pro_coupon_usages')
    op.drop_index(op.f('ix_pro_coupon_usages_status'), table_name='pro_coupon_usages')
    op.drop_index(op.f('ix_pro_coupon_usages_promotion_id'), table_name='pro_coupon_usages')
    op.drop_index(op.f('ix_pro_coupon_usages_period_key'), table_name='pro_coupon_usages')
    op.drop_index(op.f('ix_pro_coupon_usages_order_id'), table_name='pro_coupon_usages')
    op.drop_index(op.f('ix_pro_coupon_usages_id'), table_name='pro_coupon_usages')
    op.drop_index('uq_pro_coupon_order_promo', table_name='pro_coupon_usages')
    op.drop_index('idx_pro_coupon_user_period_status', table_name='pro_coupon_usages')
    op.drop_table('pro_coupon_usages')
    op.execute("DROP TYPE IF EXISTS procouponstatus")
