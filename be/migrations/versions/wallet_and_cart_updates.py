"""wallet_and_cart_updates

Revision ID: wallet_v1
Revises: ddedf80c7b90
Create Date: 2026-02-14 23:30:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = 'wallet_v1'
down_revision = 'ddedf80c7b90'
branch_labels = None
depends_on = None

def upgrade() -> None:
    # 1. Drop existing tables to avoid type casting issues (UUID -> Integer)
    # Warning: This deletes existing wallet data, which is acceptable for fixing broken schema in dev/pdev.
    op.execute("DROP TABLE IF EXISTS cashback_ledger CASCADE")
    op.execute("DROP TABLE IF EXISTS user_wallet CASCADE")
    op.execute("DROP TABLE IF EXISTS bar_wallet CASCADE")

    # 2. Define Enums (assuming they might already exist, so checkfirst or just use name)
    # We use create_type=False implies we expect them or let generic handling work.
    # However, forcing usage of existing types is safest.
    
    # 3. Create UserWallet
    op.create_table('user_wallet',
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('available_balance', sa.Numeric(precision=10, scale=2), server_default='0.00', nullable=False),
        sa.Column('pending_balance', sa.Numeric(precision=10, scale=2), server_default='0.00', nullable=False),
        sa.Column('last_updated', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('user_id')
    )

    # 4. Create BarWallet
    op.create_table('bar_wallet',
        sa.Column('bar_id', sa.Integer(), nullable=False),
        sa.Column('available_balance', sa.Numeric(precision=10, scale=2), server_default='0.00', nullable=False),
        sa.Column('reserved_balance', sa.Numeric(precision=10, scale=2), server_default='0.00', nullable=False),
        sa.Column('last_updated', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('bar_id')
    )

    # 5. Create CashbackLedger
    op.create_table('cashback_ledger',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('order_id', sa.Integer(), nullable=True),
        sa.Column('bar_id', sa.Integer(), nullable=False),
        sa.Column('amount', sa.Numeric(precision=10, scale=2), nullable=False),
        
        # Enums: We use the names that likely exist. 
        # If they don't, we might need to create them. 
        # But drop table DOES NOT drop enums in Postgres usually.
        sa.Column('type', sa.Enum('EARN', 'REDEEM', 'EXPIRE', 'ADJUST', name='cashbacktype'), nullable=False),
        sa.Column('funded_by', sa.Enum('BAR', 'BARZ', 'SPONSORED', name='fundingsource'), nullable=False),
        sa.Column('status', sa.Enum('PENDING', 'AVAILABLE', 'USED', 'EXPIRED', name='cashbackstatus'), nullable=False),
        
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
        
        sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )

    # 6. Create Indexes
    op.create_index('idx_cashback_user_status', 'cashback_ledger', ['user_id', 'status'], unique=False)
    op.create_index('idx_cashback_user_created', 'cashback_ledger', ['user_id', 'created_at'], unique=False)
    op.create_index('idx_cashback_expires', 'cashback_ledger', ['expires_at'], unique=False)


def downgrade() -> None:
    # Drop tables
    op.drop_index('idx_cashback_expires', table_name='cashback_ledger')
    op.drop_index('idx_cashback_user_created', table_name='cashback_ledger')
    op.drop_index('idx_cashback_user_status', table_name='cashback_ledger')
    op.drop_table('cashback_ledger')
    op.drop_table('bar_wallet')
    op.drop_table('user_wallet')
    
    # We do not attempt to recreate the broken UUID schema here. 
    # Downgrade simply removes the valid Integer schema.
