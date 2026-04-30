"""create_payout_and_dispute_models

Revision ID: e5826fa432e0
Revises: 967fcf155de3
Create Date: 2026-04-30 17:49:47.831008

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'e5826fa432e0'
down_revision: Union[str, None] = '967fcf155de3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Payouts Table
    op.create_table('payouts',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('bar_id', sa.Integer(), nullable=False),
    sa.Column('amount', sa.Float(), nullable=False),
    sa.Column('currency', sa.String(length=3), nullable=True),
    sa.Column('status', sa.String(length=20), nullable=True),
    sa.Column('gateway_payout_id', sa.String(length=100), nullable=True),
    sa.Column('gateway_name', sa.String(length=50), nullable=True),
    sa.Column('bank_account_info', sa.JSON(), nullable=True),
    sa.Column('failure_code', sa.String(length=50), nullable=True),
    sa.Column('failure_message', sa.String(length=500), nullable=True),
    sa.Column('arrival_date', sa.DateTime(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=True),
    sa.Column('updated_at', sa.DateTime(), nullable=True),
    sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_payouts_bar_id'), 'payouts', ['bar_id'], unique=False)
    op.create_index(op.f('ix_payouts_gateway_payout_id'), 'payouts', ['gateway_payout_id'], unique=False)
    op.create_index(op.f('ix_payouts_id'), 'payouts', ['id'], unique=False)
    op.create_index(op.f('ix_payouts_status'), 'payouts', ['status'], unique=False)

    # Disputes Table
    op.create_table('disputes',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('bar_id', sa.Integer(), nullable=False),
    sa.Column('order_id', sa.Integer(), nullable=True),
    sa.Column('amount', sa.Float(), nullable=False),
    sa.Column('currency', sa.String(length=3), nullable=True),
    sa.Column('gateway_dispute_id', sa.String(length=100), nullable=False),
    sa.Column('gateway_transaction_id', sa.String(length=100), nullable=False),
    sa.Column('gateway_name', sa.String(length=50), nullable=True),
    sa.Column('status', sa.String(length=50), nullable=True),
    sa.Column('reason', sa.String(length=100), nullable=True),
    sa.Column('is_refundable', sa.Boolean(), nullable=True),
    sa.Column('has_evidence', sa.Boolean(), nullable=True),
    sa.Column('evidence_due_date', sa.DateTime(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=True),
    sa.Column('updated_at', sa.DateTime(), nullable=True),
    sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ),
    sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_disputes_bar_id'), 'disputes', ['bar_id'], unique=False)
    op.create_index(op.f('ix_disputes_gateway_dispute_id'), 'disputes', ['gateway_dispute_id'], unique=True)
    op.create_index(op.f('ix_disputes_gateway_transaction_id'), 'disputes', ['gateway_transaction_id'], unique=False)
    op.create_index(op.f('ix_disputes_id'), 'disputes', ['id'], unique=False)
    op.create_index(op.f('ix_disputes_order_id'), 'disputes', ['order_id'], unique=False)
    op.create_index(op.f('ix_disputes_status'), 'disputes', ['status'], unique=False)


def downgrade() -> None:
    op.drop_table('disputes')
    op.drop_table('payouts')
