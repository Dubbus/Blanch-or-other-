"""add_influencer_social_urls

Revision ID: ca472ec20b68
Revises: dea98e341b0c
Create Date: 2026-04-09 10:33:49.094349

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ca472ec20b68'
down_revision: Union[str, None] = 'dea98e341b0c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('influencers', sa.Column('instagram_url', sa.Text(), nullable=True))
    op.add_column('influencers', sa.Column('tiktok_url', sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column('influencers', 'tiktok_url')
    op.drop_column('influencers', 'instagram_url')
