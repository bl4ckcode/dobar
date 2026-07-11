"""merge heads for campaign extensions

Revision ID: 20250711_merge_heads
Revises: a3f1d2e4b5c6, 20250610_add_ondelete
Create Date: 2026-07-11 22:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '20250711_merge_heads'
down_revision: Union[str, None] = ('a3f1d2e4b5c6', '20250610_add_ondelete')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass