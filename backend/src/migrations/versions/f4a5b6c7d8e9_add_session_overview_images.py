"""add session overview image columns

Revision ID: f4a5b6c7d8e9
Revises: 952252659544
Create Date: 2026-03-29 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "f4a5b6c7d8e9"
down_revision = "952252659544"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("parking_session", sa.Column("overview_image", sa.String(length=255), nullable=True))
    op.add_column("parking_session", sa.Column("overview_image_public_id", sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column("parking_session", "overview_image_public_id")
    op.drop_column("parking_session", "overview_image")