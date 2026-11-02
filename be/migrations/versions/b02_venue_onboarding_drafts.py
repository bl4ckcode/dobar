from alembic import op
import sqlalchemy as sa

revision = "b02_venue_drafts"
down_revision = "dob_94_unique_bar_staff"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "venue_onboarding_drafts",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("owner_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("creation_key", sa.String(80), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("steps", sa.JSON(), nullable=False),
        sa.Column("bank_encrypted", sa.Text()),
        sa.Column("bank_summary", sa.JSON()),
        sa.Column("bar_id", sa.Integer(), sa.ForeignKey("bars.id"), unique=True),
        sa.Column("finalize_key", sa.String(80)),
        sa.Column("finalized_version", sa.Integer()),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("owner_id", "creation_key", name="uq_venue_draft_owner_key"),
        sa.UniqueConstraint("owner_id", "finalize_key", name="uq_venue_draft_finalize_key"),
    )
    op.create_index("ix_venue_onboarding_drafts_owner_id", "venue_onboarding_drafts", ["owner_id"])
    op.create_table(
        "venue_onboarding_assets",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("draft_id", sa.String(36), sa.ForeignKey("venue_onboarding_drafts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("client_key", sa.String(80), nullable=False),
        sa.Column("slot", sa.String(10), nullable=False),
        sa.Column("filename", sa.String(255), nullable=False),
        sa.Column("digest", sa.String(64), nullable=False),
        sa.Column("object_key", sa.String(255), nullable=False),
        sa.Column("removed", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("status", sa.String(10), nullable=False, server_default="pending"),
        sa.UniqueConstraint("draft_id", "client_key", name="uq_venue_draft_asset_key"),
    )
    op.create_index("ix_venue_onboarding_assets_draft_id", "venue_onboarding_assets", ["draft_id"])
    op.create_table(
        "venue_onboarding_projections",
        sa.Column("bar_id", sa.Integer(), sa.ForeignKey("bars.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("completed_at", sa.DateTime()),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
    )


def downgrade():
    op.drop_table("venue_onboarding_projections")
    op.drop_table("venue_onboarding_assets")
    op.drop_table("venue_onboarding_drafts")
