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
    # 1. Create bar_wallet table
    op.create_table('bar_wallet',
        sa.Column('bar_id', sa.Integer(), nullable=False),
        sa.Column('available_balance', sa.Numeric(precision=10, scale=2), server_default='0.00', nullable=False),
        sa.Column('reserved_balance', sa.Numeric(precision=10, scale=2), server_default='0.00', nullable=False),
        sa.Column('last_updated', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('bar_id')
    )

    # 2. Update cashback_ledger columns from UUID to Integer
    # Note: explicit casting using ::integer might fail if data is actual UUIDs.
    # We assume the table is empty or data is compatible, or user handles data migration.
    # For now, we will drop and recreate constraints if needed, but simple alters are shown.
    
    op.alter_column('cashback_ledger', 'id',
               existing_type=postgresql.UUID(),
               type_=sa.Integer(),
               existing_nullable=False,
               postgresql_using='id::integer')
               
    op.alter_column('cashback_ledger', 'user_id',
               existing_type=postgresql.UUID(),
               type_=sa.Integer(),
               existing_nullable=False,
               postgresql_using='user_id::integer')
               
    op.alter_column('cashback_ledger', 'bar_id',
               existing_type=postgresql.UUID(),
               type_=sa.Integer(),
               existing_nullable=False,
               postgresql_using='bar_id::integer')
               
    op.alter_column('cashback_ledger', 'order_id',
               existing_type=postgresql.UUID(),
               type_=sa.Integer(),
               existing_nullable=True,
               postgresql_using='order_id::integer')

    # 3. Update user_wallet column
    op.alter_column('user_wallet', 'user_id',
               existing_type=postgresql.UUID(),
               type_=sa.Integer(),
               existing_nullable=False,
               postgresql_using='user_id::integer')


def downgrade() -> None:
    # Revert user_wallet
    op.alter_column('user_wallet', 'user_id',
               existing_type=sa.Integer(),
               type_=postgresql.UUID(),
               existing_nullable=False,
               postgresql_using='user_id::uuid')

    # Revert cashback_ledger
    op.alter_column('cashback_ledger', 'order_id',
               existing_type=sa.Integer(),
               type_=postgresql.UUID(),
               existing_nullable=True,
               postgresql_using='order_id::uuid')
               
    op.alter_column('cashback_ledger', 'bar_id',
               existing_type=sa.Integer(),
               type_=postgresql.UUID(),
               existing_nullable=False,
               postgresql_using='bar_id::uuid')
               
    op.alter_column('cashback_ledger', 'user_id',
               existing_type=sa.Integer(),
               type_=postgresql.UUID(),
               existing_nullable=False,
               postgresql_using='user_id::uuid')
               
    op.alter_column('cashback_ledger', 'id',
               existing_type=sa.Integer(),
               type_=postgresql.UUID(),
               existing_nullable=False,
               postgresql_using='id::uuid')

    # Drop bar_wallet
    op.drop_table('bar_wallet')
