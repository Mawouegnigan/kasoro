"""auth_secret_hash sur users, dates created_at/updated_at obligatoires

Migration reconstituee : le fichier d'origine a ete perdu alors que la base
etait deja a cette revision. Le contenu est deduit de la comparaison entre le
schema initial et le schema reel de la base (users, messages,
message_translations).

Revision ID: beb9fc09a28c
Revises: 4a7b74efeb7e
Create Date: 2026-09-14

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "beb9fc09a28c"
down_revision: Union[str, None] = "4a7b74efeb7e"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_TIMESTAMP = sa.DateTime(timezone=True)


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("auth_secret_hash", sa.String(255), nullable=False),
    )
    op.alter_column("users", "created_at", existing_type=_TIMESTAMP, nullable=False)
    op.alter_column("users", "updated_at", existing_type=_TIMESTAMP, nullable=False)
    op.alter_column("messages", "created_at", existing_type=_TIMESTAMP, nullable=False)
    op.alter_column(
        "message_translations", "created_at", existing_type=_TIMESTAMP, nullable=False
    )


def downgrade() -> None:
    op.alter_column(
        "message_translations", "created_at", existing_type=_TIMESTAMP, nullable=True
    )
    op.alter_column("messages", "created_at", existing_type=_TIMESTAMP, nullable=True)
    op.alter_column("users", "updated_at", existing_type=_TIMESTAMP, nullable=True)
    op.alter_column("users", "created_at", existing_type=_TIMESTAMP, nullable=True)
    op.drop_column("users", "auth_secret_hash")