"""add idempotency_keys table

Revision ID: idempotency_001
Revises: bank_accounts_001
Create Date: 2026-01-14
"""
from alembic import op
import sqlalchemy as sa


revision = 'idempotency_001'
down_revision = 'bank_accounts_001'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        CREATE TABLE IF NOT EXISTS idempotency_keys (
            id SERIAL PRIMARY KEY,
            key VARCHAR(64) NOT NULL UNIQUE,
            user_id INTEGER NOT NULL,
            request_path VARCHAR(255) NOT NULL,
            response_status INTEGER,
            response_body JSONB,
            created_at TIMESTAMP DEFAULT NOW(),
            expires_at TIMESTAMP NOT NULL
        );
        CREATE UNIQUE INDEX IF NOT EXISTS ix_idempotency_keys_key ON idempotency_keys(key);
        CREATE INDEX IF NOT EXISTS ix_idempotency_keys_user_id ON idempotency_keys(user_id);
        CREATE INDEX IF NOT EXISTS ix_idempotency_keys_expires_at ON idempotency_keys(expires_at);
    """)


def downgrade():
    op.execute("DROP TABLE IF EXISTS idempotency_keys CASCADE;")