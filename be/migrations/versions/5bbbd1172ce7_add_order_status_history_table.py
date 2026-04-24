"""add order_status_history table

Revision ID: 5bbbd1172ce7
Revises: a3f1d2e4b5c6
Create Date: 2026-04-24 19:57:46.034290

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5bbbd1172ce7'
down_revision: Union[str, None] = 'a3f1d2e4b5c6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'order_status_history',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('order_id', sa.Integer(), nullable=True),
        sa.Column('status', sa.String(), nullable=True),
        sa.Column('timestamp', sa.DateTime(), nullable=True),
        sa.Column('updated_by_user_id', sa.Integer(), nullable=True),
        sa.Column('updated_by_owner_id', sa.Integer(), nullable=True),
        sa.Column('notes', sa.String(), nullable=True),
        sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ),
        sa.ForeignKeyConstraint(['updated_by_owner_id'], ['bar_owners.id'], ),
        sa.ForeignKeyConstraint(['updated_by_user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_order_status_history_id'), 'order_status_history', ['id'], unique=False)
    op.create_index(op.f('ix_order_status_history_order_id'), 'order_status_history', ['order_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_order_status_history_order_id'), table_name='order_status_history')
    op.drop_index(op.f('ix_order_status_history_id'), table_name='order_status_history')
    op.drop_table('order_status_history')
