"""add_cashback_and_wallet_tables

Revision ID: abc123def456
Revises: 10234e849701
Create Date: 2025-10-15 14:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'abc123def456'
down_revision: Union[str, None] = '10234e849701'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create enums
    cashback_type_enum = postgresql.ENUM('EARN', 'REDEEM', 'EXPIRE', 'ADJUST', name='cashbacktype')
    cashback_type_enum.create(op.get_bind())
    
    funding_source_enum = postgresql.ENUM('BAR', 'BARZ', 'SPONSORED', name='fundingsource')
    funding_source_enum.create(op.get_bind())
    
    cashback_status_enum = postgresql.ENUM('PENDING', 'AVAILABLE', 'USED', 'EXPIRED', name='cashbackstatus')
    cashback_status_enum.create(op.get_bind())
    
    # Create user_wallet table
    op.create_table(
        'user_wallet',
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('available_balance', sa.Numeric(precision=10, scale=2), nullable=False, server_default='0.00'),
        sa.Column('pending_balance', sa.Numeric(precision=10, scale=2), nullable=False, server_default='0.00'),
        sa.Column('last_updated', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('user_id')
    )
    
    # Create cashback_ledger table
    op.create_table(
        'cashback_ledger',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('order_id', sa.Integer(), nullable=True),
        sa.Column('bar_id', sa.Integer(), nullable=False),
        sa.Column('amount', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column('type', cashback_type_enum, nullable=False),
        sa.Column('funded_by', funding_source_enum, nullable=False),
        sa.Column('status', cashback_status_enum, nullable=False, server_default='PENDING'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    
    # Create indexes for performance
    op.create_index('idx_cashback_user_id', 'cashback_ledger', ['user_id'])
    op.create_index('idx_cashback_type', 'cashback_ledger', ['type'])
    op.create_index('idx_cashback_status', 'cashback_ledger', ['status'])
    op.create_index('idx_cashback_user_status', 'cashback_ledger', ['user_id', 'status'])
    op.create_index('idx_cashback_user_created', 'cashback_ledger', ['user_id', 'created_at'])
    op.create_index('idx_cashback_expires', 'cashback_ledger', ['expires_at'])


def downgrade() -> None:
    # Drop indexes
    op.drop_index('idx_cashback_expires', table_name='cashback_ledger')
    op.drop_index('idx_cashback_user_created', table_name='cashback_ledger')
    op.drop_index('idx_cashback_user_status', table_name='cashback_ledger')
    op.drop_index('idx_cashback_status', table_name='cashback_ledger')
    op.drop_index('idx_cashback_type', table_name='cashback_ledger')
    op.drop_index('idx_cashback_user_id', table_name='cashback_ledger')
    
    # Drop tables
    op.drop_table('cashback_ledger')
    op.drop_table('user_wallet')
    
    # Drop enums
    cashback_status_enum = postgresql.ENUM('PENDING', 'AVAILABLE', 'USED', 'EXPIRED', name='cashbackstatus')
    cashback_status_enum.drop(op.get_bind())
    
    funding_source_enum = postgresql.ENUM('BAR', 'BARZ', 'SPONSORED', name='fundingsource')
    funding_source_enum.drop(op.get_bind())
    
    cashback_type_enum = postgresql.ENUM('EARN', 'REDEEM', 'EXPIRE', 'ADJUST', name='cashbacktype')
    cashback_type_enum.drop(op.get_bind())
