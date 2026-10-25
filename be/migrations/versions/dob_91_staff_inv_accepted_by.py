"""Add accepted_by_user_id to staff_invitations

Revision ID: dob_91_staff_inv_accepted_by
Revises: 20250720_fix_pricing_swap
Create Date: 2026-10-24 00:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'dob_91_staff_inv_accepted_by'
down_revision: Union[str, None] = '20250720_fix_pricing_swap'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'staff_invitations',
        sa.Column('accepted_by_user_id', sa.Integer(), nullable=True)
    )
    op.create_foreign_key(
        'fk_staff_invitations_accepted_by_user_id_users',
        'staff_invitations', 'users',
        ['accepted_by_user_id'], ['id'], ondelete='SET NULL'
    )


def downgrade() -> None:
    op.drop_constraint('fk_staff_invitations_accepted_by_user_id_users', 'staff_invitations', type_='foreignkey')
    op.drop_column('staff_invitations', 'accepted_by_user_id')
