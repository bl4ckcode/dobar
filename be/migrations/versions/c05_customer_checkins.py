from alembic import op
import sqlalchemy as sa

revision = "c05_customer_checkins"
down_revision = "b02_venue_drafts"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "customer_checkins",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True),
        sa.Column("bar_id", sa.Integer(), sa.ForeignKey("bars.id", ondelete="CASCADE"), nullable=False),
        sa.Column("table_number", sa.String(120)),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("distance_meters", sa.Float(), nullable=False),
        sa.Column("measured_at", sa.DateTime(), nullable=False),
        sa.Column("checked_in_at", sa.DateTime(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("checked_out_at", sa.DateTime()),
    )
    op.create_index("ix_customer_checkins_bar_id", "customer_checkins", ["bar_id"])


def downgrade():
    op.drop_table("customer_checkins")
