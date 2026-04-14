"""Add PaymentCard model

Revision ID: 2de27a110c1e
Revises: sprint2_profile_prefs
Create Date: 2026-03-04 19:15:15.811694

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '2de27a110c1e'
down_revision: Union[str, None] = 'fcf6c6a011db'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('payment_cards',
    sa.Column('id', sa.Integer(), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('card_token', sa.String(length=255), nullable=False),
    sa.Column('last_four', sa.String(length=4), nullable=False),
    sa.Column('brand', sa.String(length=50), nullable=False),
    sa.Column('exp_month', sa.Integer(), nullable=False),
    sa.Column('exp_year', sa.Integer(), nullable=False),
    sa.Column('is_default', sa.Integer(), server_default='0', nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=True),
    sa.Column('updated_at', sa.DateTime(), nullable=True),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_payment_cards_card_token', 'payment_cards', ['card_token'], unique=True)
    op.create_index('ix_payment_cards_id', 'payment_cards', ['id'], unique=False)
    op.create_index('ix_payment_cards_user_id', 'payment_cards', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_payment_cards_user_id', table_name='payment_cards')
    op.drop_index('ix_payment_cards_id', table_name='payment_cards')
    op.drop_index('ix_payment_cards_card_token', table_name='payment_cards')
    op.drop_table('payment_cards')
