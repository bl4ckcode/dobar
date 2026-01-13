"""add bar_bank_accounts table

Revision ID: bank_accounts_001
Revises: bar_wizard_001
Create Date: 2026-01-11
"""
from alembic import op
import sqlalchemy as sa


revision = 'bank_accounts_001'
down_revision = 'bar_wizard_001'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        CREATE TABLE IF NOT EXISTS bar_bank_accounts (
            id SERIAL PRIMARY KEY,
            bar_id INTEGER NOT NULL REFERENCES bars(id) ON DELETE CASCADE,
            country_code VARCHAR(2) NOT NULL,
            bank_code VARCHAR(10),
            branch_code VARCHAR(10),
            account_number_encrypted TEXT,
            account_type VARCHAR(20),
            pix_key_encrypted TEXT,
            pix_key_type VARCHAR(20),
            clabe_encrypted TEXT,
            cbu_encrypted TEXT,
            routing_number VARCHAR(9),
            account_holder_name VARCHAR(255),
            is_verified BOOLEAN DEFAULT FALSE,
            stripe_external_account_id VARCHAR(255),
            created_at TIMESTAMP,
            updated_at TIMESTAMP
        );
        CREATE UNIQUE INDEX IF NOT EXISTS ix_bar_bank_accounts_bar_id ON bar_bank_accounts(bar_id);
        CREATE INDEX IF NOT EXISTS ix_bar_bank_accounts_country_code ON bar_bank_accounts(country_code);
        CREATE INDEX IF NOT EXISTS ix_bar_bank_accounts_is_verified ON bar_bank_accounts(is_verified);
    """)


def downgrade():
    op.drop_index('ix_bar_bank_accounts_is_verified')
    op.drop_index('ix_bar_bank_accounts_country_code')
    op.drop_index('ix_bar_bank_accounts_bar_id')
    op.drop_table('bar_bank_accounts')
