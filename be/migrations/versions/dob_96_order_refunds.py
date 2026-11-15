"""Add order_refunds ledger for refunds confirmed by the payment engine

Revision ID: dob_96_order_refunds
Revises: dob_95_contact_change_requests
Create Date: 2026-11-15 00:00:00.000000

Additive only: new table, no data backfill, safe to deploy before callers.
Rows are written as "pending" before the payment engine is called, so a
refund can never move money without a row here.
Refunds issued before this table existed are not in it; they can be
backfilled from the payment engine if historical revenue must be corrected.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "dob_96_order_refunds"
down_revision: Union[str, None] = "dob_95_contact_change_requests"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "order_refunds",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("order_id", sa.Integer(), sa.ForeignKey("orders.id", ondelete="CASCADE"), nullable=False),
        sa.Column("bar_id", sa.Integer(), sa.ForeignKey("bars.id"), nullable=False),
        sa.Column("payment_id", sa.String(100), nullable=False),
        sa.Column("idempotency_key", sa.String(128), nullable=False),
        sa.Column("gateway_refund_id", sa.String(100), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column("currency", sa.String(3), nullable=True, server_default="BRL"),
        sa.Column("reason", sa.String(500), nullable=True),
        sa.Column("requested_by_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_order_refunds_id", "order_refunds", ["id"])
    op.create_index("ix_order_refunds_order_id", "order_refunds", ["order_id"])
    op.create_index("ix_order_refunds_bar_id", "order_refunds", ["bar_id"])
    op.create_index("ix_order_refunds_payment_id", "order_refunds", ["payment_id"])
    op.create_index("ix_order_refunds_idempotency_key", "order_refunds", ["idempotency_key"], unique=True)
    op.create_index("ix_order_refunds_gateway_refund_id", "order_refunds", ["gateway_refund_id"], unique=True)
    op.create_index("ix_order_refunds_status", "order_refunds", ["status"])


def downgrade() -> None:
    op.drop_table("order_refunds")
