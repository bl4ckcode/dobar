"""Fix order timestamps

Revision ID: a1b2c3d4e5f6
Revises: e5826fa432e0
Create Date: 2026-05-02 16:40:00.000000

"""
from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: str | None = 'e5826fa432e0'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Fix orders with NULL timestamps by setting them to current timestamp."""
    # Update orders with NULL created_at
    op.execute("UPDATE orders SET created_at = now() WHERE created_at IS NULL")
    
    # Update orders with NULL updated_at  
    op.execute("UPDATE orders SET updated_at = now() WHERE updated_at IS NULL")


def downgrade() -> None:
    """Downgrade is not applicable for this fix."""
    pass
