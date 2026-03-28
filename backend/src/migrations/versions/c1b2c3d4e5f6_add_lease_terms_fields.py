"""add lease commercial term fields

Revision ID: c1b2c3d4e5f6
Revises: ad35d5ac66d9
Create Date: 2026-03-28 12:30:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c1b2c3d4e5f6"
down_revision: Union[str, None] = "ad35d5ac66d9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "lot_lease",
        sa.Column("revenue_share_percentage", sa.Numeric(5, 2), nullable=False, server_default="0"),
    )
    op.add_column(
        "lot_lease",
        sa.Column("term_months", sa.Integer(), nullable=False, server_default="1"),
    )


def downgrade() -> None:
    op.drop_column("lot_lease", "term_months")
    op.drop_column("lot_lease", "revenue_share_percentage")
