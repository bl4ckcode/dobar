"""mfa secrets table

Revision ID: mfa_secrets_001
Revises:
Create Date: 2026-02-16
"""
from alembic import op
import sqlalchemy as sa

revision = "mfa_secrets_001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "mfa_secrets",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), unique=True, nullable=False, index=True),
        sa.Column("secret", sa.String(), nullable=False),
        sa.Column("is_enabled", sa.Boolean(), default=False),
        sa.Column("backup_codes", sa.Text(), nullable=True),
        sa.Column("phone_fallback_enabled", sa.Boolean(), default=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("mfa_secrets")
