"""add product indexes

Revision ID: 3f8a1c92d4e7
Revises: ca472ec20b68
Create Date: 2026-04-18

Indexes added:
- products.category      — primary filter on Discover tab
- products.brand         — secondary filter + brands list query
- products.retailer      — retailer filter (future)
- product_season_map.season_id — right-side of composite PK; JOINs on season_id
                                  alone don't use the PK index efficiently
- products.name + shade_name   — GIN trgm indexes for ilike search at scale
                                  (requires pg_trgm extension)
"""
from alembic import op
import sqlalchemy as sa


revision = '3f8a1c92d4e7'
down_revision = 'ca472ec20b68'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Enable pg_trgm for efficient ilike search — no-op if already enabled.
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    # Standard btree indexes for equality filters
    op.create_index('ix_products_category', 'products', ['category'])
    op.create_index('ix_products_brand',    'products', ['brand'])
    op.create_index('ix_products_retailer', 'products', ['retailer'])

    # season_id alone on the join table — the composite PK (product_id, season_id)
    # doesn't help when filtering only on season_id (right-side of composite).
    op.create_index('ix_product_season_map_season_id',
                    'product_season_map', ['season_id'])

    # GIN trigram indexes for ilike search across name, brand, shade_name.
    # Turns O(n) pattern scan into O(log n) at 10k+ rows.
    op.create_index('ix_products_name_trgm', 'products', ['name'],
                    postgresql_using='gin',
                    postgresql_ops={'name': 'gin_trgm_ops'})
    op.create_index('ix_products_shade_name_trgm', 'products', ['shade_name'],
                    postgresql_using='gin',
                    postgresql_ops={'shade_name': 'gin_trgm_ops'})


def downgrade() -> None:
    op.drop_index('ix_products_shade_name_trgm', table_name='products')
    op.drop_index('ix_products_name_trgm',       table_name='products')
    op.drop_index('ix_product_season_map_season_id', table_name='product_season_map')
    op.drop_index('ix_products_retailer', table_name='products')
    op.drop_index('ix_products_brand',    table_name='products')
    op.drop_index('ix_products_category', table_name='products')
