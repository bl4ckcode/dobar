"""add waitlist_signups table

Revision ID: 20250503_add_waitlist
Revises: a1b2c3d4e5f6
Create Date: 2026-05-03 22:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20250503_add_waitlist'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create waitlist_signups table
    op.create_table('waitlist_signups',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('bar_name', sa.String(length=255), nullable=False),
        sa.Column('contact_name', sa.String(length=255), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=False),
        sa.Column('phone', sa.String(length=20), nullable=True),
        sa.Column('city', sa.String(length=50), nullable=False),
        sa.Column('source', sa.String(length=50), nullable=True),
        sa.Column('utm_source', sa.String(length=100), nullable=True),
        sa.Column('utm_medium', sa.String(length=100), nullable=True),
        sa.Column('utm_campaign', sa.String(length=100), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('ip_address', sa.String(length=45), nullable=True),
        sa.Column('user_agent', sa.String(length=500), nullable=True),
        sa.Column('confirmation_email_sent', sa.Boolean(), nullable=True),
        sa.Column('admin_notification_sent', sa.Boolean(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('email')
    )
    
    # Create indexes
    op.create_index(op.f('ix_waitlist_signups_city'), 'waitlist_signups', ['city'], unique=False)
    op.create_index(op.f('ix_waitlist_signups_created_at'), 'waitlist_signups', ['created_at'], unique=False)
    op.create_index(op.f('ix_waitlist_signups_email'), 'waitlist_signups', ['email'], unique=True)
    op.create_index(op.f('ix_waitlist_signups_id'), 'waitlist_signups', ['id'], unique=False)
    op.create_index(op.f('ix_waitlist_signups_source'), 'waitlist_signups', ['source'], unique=False)
    op.create_index(op.f('ix_waitlist_signups_status'), 'waitlist_signups', ['status'], unique=False)


def downgrade() -> None:
    # Drop indexes
    op.drop_index(op.f('ix_waitlist_signups_status'), table_name='waitlist_signups')
    op.drop_index(op.f('ix_waitlist_signups_source'), table_name='waitlist_signups')
    op.drop_index(op.f('ix_waitlist_signups_id'), table_name='waitlist_signups')
    op.drop_index(op.f('ix_waitlist_signups_email'), table_name='waitlist_signups')
    op.drop_index(op.f('ix_waitlist_signups_created_at'), table_name='waitlist_signups')
    op.drop_index(op.f('ix_waitlist_signups_city'), table_name='waitlist_signups')
    # Drop table
    op.drop_table('waitlist_signups')
