"""add_cart_and_order_enhancements

Revision ID: 10234e849701
Revises: 
Create Date: 2025-10-14 00:08:57.331718

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '10234e849701'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create carts table
    op.create_table(
        'carts',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_carts_user_id', 'carts', ['user_id'])
    
    # Create cart_items table
    op.create_table(
        'cart_items',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('cart_id', sa.Integer(), nullable=False),
        sa.Column('menu_item_id', sa.Integer(), nullable=False),
        sa.Column('bar_id', sa.Integer(), nullable=False),
        sa.Column('menu_item_name', sa.String(), nullable=False),
        sa.Column('quantity', sa.Integer(), nullable=False),
        sa.Column('unit_price', sa.Float(), nullable=False),
        sa.Column('special_instructions', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.ForeignKeyConstraint(['cart_id'], ['carts.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['menu_item_id'], ['menu_items.id'], ),
        sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_cart_items_cart_id', 'cart_items', ['cart_id'])
    
    # Create order_items table
    op.create_table(
        'order_items',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('order_id', sa.Integer(), nullable=False),
        sa.Column('menu_item_id', sa.Integer(), nullable=False),
        sa.Column('menu_item_name', sa.String(), nullable=False),
        sa.Column('quantity', sa.Integer(), nullable=False),
        sa.Column('unit_price', sa.Float(), nullable=False),
        sa.Column('subtotal', sa.Float(), nullable=False),
        sa.Column('special_instructions', sa.String(), nullable=True),
        sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['menu_item_id'], ['menu_items.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_order_items_order_id', 'order_items', ['order_id'])
    
    # Create order_status_history table
    op.create_table(
        'order_status_history',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('order_id', sa.Integer(), nullable=False),
        sa.Column('previous_status', sa.String(), nullable=False),
        sa.Column('new_status', sa.String(), nullable=False),
        sa.Column('changed_at', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('changed_by_user_id', sa.Integer(), nullable=True),
        sa.Column('note', sa.String(), nullable=True),
        sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['changed_by_user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_order_status_history_order_id', 'order_status_history', ['order_id'])
    
    # Add new columns to orders table
    op.add_column('orders', sa.Column('order_type', sa.String(), nullable=True))
    op.add_column('orders', sa.Column('subtotal', sa.Float(), nullable=True))
    op.add_column('orders', sa.Column('tax', sa.Float(), nullable=True))
    op.add_column('orders', sa.Column('tip', sa.Float(), nullable=True))
    op.add_column('orders', sa.Column('delivery_fee', sa.Float(), nullable=True))
    op.add_column('orders', sa.Column('discount', sa.Float(), nullable=True))
    op.add_column('orders', sa.Column('payment_id', sa.String(), nullable=True))
    op.add_column('orders', sa.Column('payment_status', sa.String(), nullable=True))
    op.add_column('orders', sa.Column('payment_method', sa.String(), nullable=True))
    op.add_column('orders', sa.Column('created_at', sa.DateTime(), nullable=True, server_default=sa.text('CURRENT_TIMESTAMP')))
    op.add_column('orders', sa.Column('updated_at', sa.DateTime(), nullable=True, server_default=sa.text('CURRENT_TIMESTAMP')))
    op.add_column('orders', sa.Column('estimated_ready_time', sa.DateTime(), nullable=True))
    op.add_column('orders', sa.Column('completed_at', sa.DateTime(), nullable=True))
    op.add_column('orders', sa.Column('delivery_address', sa.String(), nullable=True))
    op.add_column('orders', sa.Column('special_instructions', sa.String(), nullable=True))


def downgrade() -> None:
    # Drop new columns from orders table
    op.drop_column('orders', 'special_instructions')
    op.drop_column('orders', 'delivery_address')
    op.drop_column('orders', 'completed_at')
    op.drop_column('orders', 'estimated_ready_time')
    op.drop_column('orders', 'updated_at')
    op.drop_column('orders', 'created_at')
    op.drop_column('orders', 'payment_method')
    op.drop_column('orders', 'payment_status')
    op.drop_column('orders', 'payment_id')
    op.drop_column('orders', 'discount')
    op.drop_column('orders', 'delivery_fee')
    op.drop_column('orders', 'tip')
    op.drop_column('orders', 'tax')
    op.drop_column('orders', 'subtotal')
    op.drop_column('orders', 'order_type')
    
    # Drop order_status_history table
    op.drop_index('ix_order_status_history_order_id', table_name='order_status_history')
    op.drop_table('order_status_history')
    
    # Drop order_items table
    op.drop_index('ix_order_items_order_id', table_name='order_items')
    op.drop_table('order_items')
    
    # Drop cart_items table
    op.drop_index('ix_cart_items_cart_id', table_name='cart_items')
    op.drop_table('cart_items')
    
    # Drop carts table
    op.drop_index('ix_carts_user_id', table_name='carts')
    op.drop_table('carts')
