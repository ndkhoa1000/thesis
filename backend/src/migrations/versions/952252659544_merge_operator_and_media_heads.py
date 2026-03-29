"""merge operator and media heads

Revision ID: 952252659544
Revises: 1a2b3c4d5e6f, e7c9a1b2d3f4
Create Date: 2026-03-29 13:58:22.484252

"""
from typing import Sequence, Union


# revision identifiers, used by Alembic.
revision: str = '952252659544'
down_revision: Union[str, None] = ('1a2b3c4d5e6f', 'e7c9a1b2d3f4')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
