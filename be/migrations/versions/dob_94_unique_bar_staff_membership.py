from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "dob_94_unique_bar_staff"
down_revision: Union[str, None] = "dob_93_pro_monthly_coupons"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    connection = op.get_bind()
    duplicates = connection.execute(
        sa.text(
            """
            SELECT user_id, bar_id, COUNT(*) AS membership_count
            FROM bar_staff
            GROUP BY user_id, bar_id
            HAVING COUNT(*) > 1
            LIMIT 1
            """
        )
    ).first()
    if duplicates is not None:
        raise RuntimeError(
            "Duplicate bar_staff memberships must be reconciled before migration"
        )
    op.create_unique_constraint(
        "uq_bar_staff_user_bar",
        "bar_staff",
        ["user_id", "bar_id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_bar_staff_user_bar",
        "bar_staff",
        type_="unique",
    )
