"""Add ondelete cascade/set_null to user FK constraints

Revision ID: 20250610_add_ondelete_to_user_fks
Revises: 20250531_add_city_state_to_bars
Create Date: 2026-06-10 08:56:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20250610_add_ondelete_to_user_fks"
down_revision: Union[str, None] = "20250531_city_state"
branch_labels: Union[str, None] = None
depends_on: Union[str, None] = None


def upgrade() -> None:
    # --- orders.user_id -> SET NULL (preserve orders when user is deleted) ---
    op.drop_constraint("orders_user_id_fkey", "orders", type_="foreignkey")
    op.create_foreign_key(
        "orders_user_id_fkey",
        "orders", "users",
        ["user_id"], ["id"],
        ondelete="SET NULL",
    )

    # --- carts.user_id -> CASCADE (delete cart when user is deleted) ---
    op.drop_constraint("carts_user_id_fkey", "carts", type_="foreignkey")
    op.create_foreign_key(
        "carts_user_id_fkey",
        "carts", "users",
        ["user_id"], ["id"],
        ondelete="CASCADE",
    )

    # --- user_profiles.user_id -> CASCADE ---
    op.drop_constraint("user_profiles_user_id_fkey", "user_profiles", type_="foreignkey")
    op.create_foreign_key(
        "user_profiles_user_id_fkey",
        "user_profiles", "users",
        ["user_id"], ["id"],
        ondelete="CASCADE",
    )

    # --- tokens.user_id -> CASCADE ---
    op.drop_constraint("tokens_user_id_fkey", "tokens", type_="foreignkey")
    op.create_foreign_key(
        "tokens_user_id_fkey",
        "tokens", "users",
        ["user_id"], ["id"],
        ondelete="CASCADE",
    )

    # --- refresh_tokens.user_id -> CASCADE ---
    op.drop_constraint("refresh_tokens_user_id_fkey", "refresh_tokens", type_="foreignkey")
    op.create_foreign_key(
        "refresh_tokens_user_id_fkey",
        "refresh_tokens", "users",
        ["user_id"], ["id"],
        ondelete="CASCADE",
    )

    # --- recovery_tokens.user_id -> CASCADE ---
    op.drop_constraint("recovery_tokens_user_id_fkey", "recovery_tokens", type_="foreignkey")
    op.create_foreign_key(
        "recovery_tokens_user_id_fkey",
        "recovery_tokens", "users",
        ["user_id"], ["id"],
        ondelete="CASCADE",
    )

    # --- mfa_secrets.user_id -> CASCADE ---
    op.drop_constraint("mfa_secrets_user_id_fkey", "mfa_secrets", type_="foreignkey")
    op.create_foreign_key(
        "mfa_secrets_user_id_fkey",
        "mfa_secrets", "users",
        ["user_id"], ["id"],
        ondelete="CASCADE",
    )

    # --- bar_staff.user_id -> CASCADE ---
    op.drop_constraint("bar_staff_user_id_fkey", "bar_staff", type_="foreignkey")
    op.create_foreign_key(
        "bar_staff_user_id_fkey",
        "bar_staff", "users",
        ["user_id"], ["id"],
        ondelete="CASCADE",
    )

    # --- bar_staff.invited_by_id -> SET NULL ---
    op.drop_constraint("bar_staff_invited_by_id_fkey", "bar_staff", type_="foreignkey")
    op.create_foreign_key(
        "bar_staff_invited_by_id_fkey",
        "bar_staff", "users",
        ["invited_by_id"], ["id"],
        ondelete="SET NULL",
    )

    # --- staff_invitations.invited_by_id -> SET NULL ---
    op.drop_constraint("staff_invitations_invited_by_id_fkey", "staff_invitations", type_="foreignkey")
    op.create_foreign_key(
        "staff_invitations_invited_by_id_fkey",
        "staff_invitations", "users",
        ["invited_by_id"], ["id"],
        ondelete="SET NULL",
    )

    # --- order_status_history.updated_by_user_id -> SET NULL ---
    op.drop_constraint("order_status_history_updated_by_user_id_fkey", "order_status_history", type_="foreignkey")
    op.create_foreign_key(
        "order_status_history_updated_by_user_id_fkey",
        "order_status_history", "users",
        ["updated_by_user_id"], ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    # Reverse: restore all FKs without ondelete
    op.drop_constraint("orders_user_id_fkey", "orders", type_="foreignkey")
    op.create_foreign_key("orders_user_id_fkey", "orders", "users", ["user_id"], ["id"])

    op.drop_constraint("carts_user_id_fkey", "carts", type_="foreignkey")
    op.create_foreign_key("carts_user_id_fkey", "carts", "users", ["user_id"], ["id"])

    op.drop_constraint("user_profiles_user_id_fkey", "user_profiles", type_="foreignkey")
    op.create_foreign_key("user_profiles_user_id_fkey", "user_profiles", "users", ["user_id"], ["id"])

    op.drop_constraint("tokens_user_id_fkey", "tokens", type_="foreignkey")
    op.create_foreign_key("tokens_user_id_fkey", "tokens", "users", ["user_id"], ["id"])

    op.drop_constraint("refresh_tokens_user_id_fkey", "refresh_tokens", type_="foreignkey")
    op.create_foreign_key("refresh_tokens_user_id_fkey", "refresh_tokens", "users", ["user_id"], ["id"])

    op.drop_constraint("recovery_tokens_user_id_fkey", "recovery_tokens", type_="foreignkey")
    op.create_foreign_key("recovery_tokens_user_id_fkey", "recovery_tokens", "users", ["user_id"], ["id"])

    op.drop_constraint("mfa_secrets_user_id_fkey", "mfa_secrets", type_="foreignkey")
    op.create_foreign_key("mfa_secrets_user_id_fkey", "mfa_secrets", "users", ["user_id"], ["id"])

    op.drop_constraint("bar_staff_user_id_fkey", "bar_staff", type_="foreignkey")
    op.create_foreign_key("bar_staff_user_id_fkey", "bar_staff", "users", ["user_id"], ["id"])

    op.drop_constraint("bar_staff_invited_by_id_fkey", "bar_staff", type_="foreignkey")
    op.create_foreign_key("bar_staff_invited_by_id_fkey", "bar_staff", "users", ["invited_by_id"], ["id"])

    op.drop_constraint("staff_invitations_invited_by_id_fkey", "staff_invitations", type_="foreignkey")
    op.create_foreign_key("staff_invitations_invited_by_id_fkey", "staff_invitations", "users", ["invited_by_id"], ["id"])

    op.drop_constraint("order_status_history_updated_by_user_id_fkey", "order_status_history", type_="foreignkey")
    op.create_foreign_key("order_status_history_updated_by_user_id_fkey", "order_status_history", "users", ["updated_by_user_id"], ["id"])