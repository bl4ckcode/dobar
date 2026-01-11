"""add bar_bank_accounts table

Revision ID: bank_accounts_001
Revises: bar_creation_wizard
Create Date: 2026-01-11
"""
from alembic import op
import sqlalchemy as sa


revision = 'bank_accounts_001'
down_revision = 'bar_creation_wizard'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'bar_bank_accounts',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('bar_id', sa.Integer(), nullable=False),
        sa.Column('country_code', sa.String(2), nullable=False),
        sa.Column('bank_code', sa.String(10), nullable=True),
        sa.Column('branch_code', sa.String(10), nullable=True),
        sa.Column('account_number_encrypted', sa.Text(), nullable=True),
        sa.Column('account_type', sa.String(20), nullable=True),
        sa.Column('pix_key_encrypted', sa.Text(), nullable=True),
        sa.Column('pix_key_type', sa.String(20), nullable=True),
        sa.Column('clabe_encrypted', sa.Text(), nullable=True),
        sa.Column('cbu_encrypted', sa.Text(), nullable=True),
        sa.Column('routing_number', sa.String(9), nullable=True),
        sa.Column('account_holder_name', sa.String(255), nullable=True),
        sa.Column('is_verified', sa.Boolean(), default=False),
        sa.Column('stripe_external_account_id', sa.String(255), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['bar_id'], ['bars.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_bar_bank_accounts_bar_id', 'bar_bank_accounts', ['bar_id'], unique=True)
    op.create_index('ix_bar_bank_accounts_country_code', 'bar_bank_accounts', ['country_code'])
    op.create_index('ix_bar_bank_accounts_is_verified', 'bar_bank_accounts', ['is_verified'])


def downgrade():
    op.drop_index('ix_bar_bank_accounts_is_verified')
    op.drop_index('ix_bar_bank_accounts_country_code')
    op.drop_index('ix_bar_bank_accounts_bar_id')
    op.drop_table('bar_bank_accounts')
