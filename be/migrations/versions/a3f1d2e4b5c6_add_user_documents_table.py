"""add_user_documents_table

Revision ID: a3f1d2e4b5c6
Revises: cacfd7f5927b
Create Date: 2026-04-22 09:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'a3f1d2e4b5c6'
down_revision: Union[str, None] = 'cacfd7f5927b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'user_documents',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('type', sa.String(length=20), nullable=False),
        sa.Column('number', sa.String(length=50), nullable=False),
        sa.Column('issuing_authority', sa.String(length=100), nullable=True),
        sa.Column('issue_date', sa.DateTime(), nullable=True),
        sa.Column('expiry_date', sa.DateTime(), nullable=True),
        sa.Column('verified', sa.Boolean(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_user_documents_id'), 'user_documents', ['id'], unique=False)
    op.create_index(op.f('ix_user_documents_user_id'), 'user_documents', ['user_id'], unique=False)
    op.create_index(op.f('ix_user_documents_type'), 'user_documents', ['type'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_user_documents_type'), table_name='user_documents')
    op.drop_index(op.f('ix_user_documents_user_id'), table_name='user_documents')
    op.drop_index(op.f('ix_user_documents_id'), table_name='user_documents')
    op.drop_table('user_documents')
