"""add last_read_at to conversation_members

Revision ID: c3f1a9d2b7e4
Revises: 877a24003067
Create Date: 2026-11-09

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'c3f1a9d2b7e4'
down_revision: Union[str, None] = '877a24003067'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('conversation_members', sa.Column('last_read_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False))


def downgrade() -> None:
    op.drop_column('conversation_members', 'last_read_at')
