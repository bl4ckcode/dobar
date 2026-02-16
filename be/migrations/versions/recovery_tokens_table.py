"""recovery tokens table

Revision ID: recovery_tokens_001
Revises: mfa_secrets_001
Create Date: 2026-02-16
"""
from alembic import op
import sqlalchemy as sa

revision = "recovery_tokens_001"
down_revision = "mfa_secrets_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "recovery_tokens",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column("token", sa.String(), unique=True, nullable=False, index=True),
        sa.Column("method", sa.String(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("recovery_tokens")
