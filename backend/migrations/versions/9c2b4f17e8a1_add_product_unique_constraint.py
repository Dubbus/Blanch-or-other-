"""add unique constraint on products (brand, shade_name, category)

Revision ID: 9c2b4f17e8a1
Revises: 3f8a1c92d4e7
Create Date: 2026-04-18

The existing code comments state (brand, shade_name, category) is the
product lookup key, but no DB constraint enforced it. Required for
ON CONFLICT DO UPDATE upserts in the spreadsheet importers.
"""
from alembic import op


revision = '9c2b4f17e8a1'
down_revision = '3f8a1c92d4e7'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_unique_constraint(
        'uq_product_brand_shade_category',
        'products',
        ['brand', 'shade_name', 'category'],
    )


def downgrade() -> None:
    op.drop_constraint(
        'uq_product_brand_shade_category',
        'products',
        type_='unique',
    )
