"""fix_missing_order_columns

Revision ID: fix_orders_001
Revises: wallet_v1
Create Date: 2026-02-15 12:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.engine.reflection import Inspector

# revision identifiers, used by Alembic.
revision: str = 'fix_orders_001'
down_revision: Union[str, None] = 'wallet_v1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = Inspector.from_engine(conn)
    current_columns = [c['name'] for c in inspector.get_columns('orders')]

    # List of columns that might be missing due to conditional migration skipping
    columns_to_check = {
        'special_instructions': sa.Column('special_instructions', sa.String(), nullable=True),
        'location_identifier': sa.Column('location_identifier', sa.String(), nullable=True),
        'active_promotion_ids': sa.Column('active_promotion_ids', sa.JSON(), nullable=True),
        'delivery_address': sa.Column('delivery_address', sa.String(), nullable=True),
        'order_type': sa.Column('order_type', sa.String(), nullable=True),
        'payment_method': sa.Column('payment_method', sa.String(), nullable=True),
        'payment_status': sa.Column('payment_status', sa.String(), nullable=True),
        'payment_id': sa.Column('payment_id', sa.String(), nullable=True),
        'discount': sa.Column('discount', sa.Float(), server_default='0.0', nullable=True),
        'delivery_fee': sa.Column('delivery_fee', sa.Float(), server_default='0.0', nullable=True),
        'tip': sa.Column('tip', sa.Float(), server_default='0.0', nullable=True),
        'tax': sa.Column('tax', sa.Float(), server_default='0.0', nullable=True),
        'subtotal': sa.Column('subtotal', sa.Float(), nullable=True),
        'estimated_ready_time': sa.Column('estimated_ready_time', sa.DateTime(), nullable=True),
        'completed_at': sa.Column('completed_at', sa.DateTime(), nullable=True),
        'created_at': sa.Column('created_at', sa.DateTime(), server_default=sa.text('now()'), nullable=True),
        'updated_at': sa.Column('updated_at', sa.DateTime(), server_default=sa.text('now()'), nullable=True),
    }

    for col_name, col_def in columns_to_check.items():
        if col_name not in current_columns:
            print(f"Adding missing column: {col_name}")
            op.add_column('orders', col_def)


def downgrade() -> None:
    # We can perform a safe downgrade by checking if these columns exist, 
    # but typically downgrade removes what upgrade added.
    # Since we're fixing a state where columns might be missing, strict downgrade is tricky.
    # We'll just reverse the operation: drop the columns if they exist.
    
    conn = op.get_bind()
    inspector = Inspector.from_engine(conn)
    current_columns = [c['name'] for c in inspector.get_columns('orders')]
    
    columns_to_drop = [
        'special_instructions', 'location_identifier', 'active_promotion_ids'
        # We probably shouldn't drop the others (tax, subtotal, etc) as they might have existed before
        # and we only added them if they were missing.
        # But for strict correctness of this migration, we revert what we *would* have added.
        # However, verifying what WAS added vs what existed is hard in downgrade without tracking.
        # So we will only drop the specific ones that were definitely causing issues.
    ]

    for col_name in columns_to_drop:
        if col_name in current_columns:
            op.drop_column('orders', col_name)
