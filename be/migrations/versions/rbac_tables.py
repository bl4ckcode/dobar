"""RBAC tables for user profiles and bar staff

Revision ID: rbac001
Revises: menu001
Create Date: 2026-01-03

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'rbac001'
down_revision = 'menu001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create user_profiles table
    op.create_table(
        'user_profiles',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=True),
        sa.Column('display_name', sa.String(100), nullable=True),
        sa.Column('avatar_url', sa.String(500), nullable=True),
        sa.Column('user_type', sa.String(20), nullable=True, server_default='client'),
        sa.Column('business_name', sa.String(200), nullable=True),
        sa.Column('business_email', sa.String(255), nullable=True),
        sa.Column('business_phone', sa.String(20), nullable=True),
        sa.Column('tax_id', sa.String(20), nullable=True),
        sa.Column('preferred_language', sa.String(5), nullable=True, server_default='pt-BR'),
        sa.Column('notification_enabled', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('fcm_token', sa.String(500), nullable=True),
        sa.Column('fcm_token_updated_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_user_profiles_id', 'user_profiles', ['id'])
    op.create_index('ix_user_profiles_user_id', 'user_profiles', ['user_id'], unique=True)
    op.create_index('ix_user_profiles_user_type', 'user_profiles', ['user_type'])
    
    # Create bar_staff table
    op.create_table(
        'bar_staff',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=True),
        sa.Column('bar_id', sa.Integer(), nullable=True),
        sa.Column('role', sa.String(20), nullable=False),
        sa.Column('custom_permissions', sa.String(1000), nullable=True),
        sa.Column('nickname', sa.String(50), nullable=True),
        sa.Column('employee_id', sa.String(50), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=True, server_default='true'),
        sa.Column('invited_at', sa.DateTime(), nullable=True),
        sa.Column('accepted_at', sa.DateTime(), nullable=True),
        sa.Column('invited_by_id', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['invited_by_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_bar_staff_id', 'bar_staff', ['id'])
    op.create_index('ix_bar_staff_user_id', 'bar_staff', ['user_id'])
    op.create_index('ix_bar_staff_bar_id', 'bar_staff', ['bar_id'])
    op.create_index('ix_bar_staff_role', 'bar_staff', ['role'])
    op.create_index('ix_bar_staff_is_active', 'bar_staff', ['is_active'])
    
    # Create staff_invitations table
    op.create_table(
        'staff_invitations',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('bar_id', sa.Integer(), nullable=True),
        sa.Column('email', sa.String(255), nullable=True),
        sa.Column('phone', sa.String(20), nullable=True),
        sa.Column('role', sa.String(20), nullable=False),
        sa.Column('invitation_code', sa.String(50), nullable=True),
        sa.Column('status', sa.String(20), nullable=True, server_default='pending'),
        sa.Column('expires_at', sa.DateTime(), nullable=False),
        sa.Column('invited_by_id', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('accepted_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['invited_by_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_staff_invitations_id', 'staff_invitations', ['id'])
    op.create_index('ix_staff_invitations_bar_id', 'staff_invitations', ['bar_id'])
    op.create_index('ix_staff_invitations_email', 'staff_invitations', ['email'])
    op.create_index('ix_staff_invitations_phone', 'staff_invitations', ['phone'])
    op.create_index('ix_staff_invitations_invitation_code', 'staff_invitations', ['invitation_code'], unique=True)
    op.create_index('ix_staff_invitations_status', 'staff_invitations', ['status'])


def downgrade() -> None:
    op.drop_table('staff_invitations')
    op.drop_table('bar_staff')
    op.drop_table('user_profiles')
