"""Add contact_change_requests for verified email/phone changes

Revision ID: dob_95_contact_change_requests
Revises: dob_94_unique_bar_staff
Create Date: 2026-11-08 00:00:00.000000

Additive only: new table, no data backfill, safe to deploy before callers.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "dob_95_contact_change_requests"
down_revision: Union[str, None] = "dob_94_unique_bar_staff"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "contact_change_requests",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("request_id", sa.String(64), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("channel", sa.String(10), nullable=False),
        sa.Column("new_value", sa.String(), nullable=False),
        sa.Column("status", sa.String(12), nullable=False, server_default="pending"),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_contact_change_requests_id", "contact_change_requests", ["id"])
    op.create_index("ix_contact_change_requests_request_id", "contact_change_requests", ["request_id"], unique=True)
    op.create_index("ix_contact_change_requests_user_id", "contact_change_requests", ["user_id"])
    op.create_index("ix_contact_change_requests_status", "contact_change_requests", ["status"])
    op.create_index("idx_contact_change_user_status", "contact_change_requests", ["user_id", "status"])


def downgrade() -> None:
    op.drop_table("contact_change_requests")
