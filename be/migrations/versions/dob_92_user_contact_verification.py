"""Add email_verified and phone_verified to users

Revision ID: dob_92_user_contact_verification
Revises: dob_91_staff_inv_accepted_by
Create Date: 2026-10-25 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'dob_92_user_contact_verification'
down_revision: Union[str, None] = 'dob_91_staff_inv_accepted_by'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'users',
        sa.Column('email_verified', sa.Boolean(), nullable=False, server_default=sa.false())
    )
    op.add_column(
        'users',
        sa.Column('phone_verified', sa.Boolean(), nullable=False, server_default=sa.false())
    )


def downgrade() -> None:
    op.drop_column('users', 'phone_verified')
    op.drop_column('users', 'email_verified')
