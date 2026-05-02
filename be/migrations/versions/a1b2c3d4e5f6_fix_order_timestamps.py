"""Fix order timestamps

Revision ID: a1b2c3d4e5f6
Revises: e5826fa432e0
Create Date: 2026-05-02 16:40:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.sql import text

# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: str | None = 'e5826fa432e0'
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Fix orders with NULL timestamps by setting them to current timestamp."""
    # Get current timestamp
    current_time = sa.func.now()
    
    # Update orders with NULL created_at
    op.execute(
        text("UPDATE orders SET created_at = :current_time WHERE created_at IS NULL"),
        {'current_time': current_time}
    )
    
    # Update orders with NULL updated_at  
    op.execute(
        text("UPDATE orders SET updated_at = :current_time WHERE updated_at IS NULL"),
        {'current_time': current_time}
    )


def downgrade() -> None:
    """Downgrade is not applicable for this fix."""
    pass
