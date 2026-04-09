import uuid

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.product import Product, ProductSeasonMap


async def get_products(
    db: AsyncSession,
    *,
    category: str | None = None,
    retailer: str | None = None,
    season_id: str | None = None,
    search: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[Product], int]:
    query = select(Product)
    count_query = select(func.count()).select_from(Product)

    if category:
        query = query.where(Product.category == category)
        count_query = count_query.where(Product.category == category)
    if retailer:
        query = query.where(Product.retailer == retailer)
        count_query = count_query.where(Product.retailer == retailer)
    if season_id:
        query = query.join(ProductSeasonMap).where(
            ProductSeasonMap.season_id == uuid.UUID(season_id)
        )
        count_query = count_query.join(ProductSeasonMap).where(
            ProductSeasonMap.season_id == uuid.UUID(season_id)
        )
    if search:
        pattern = f"%{search}%"
        query = query.where(
            Product.name.ilike(pattern)
            | Product.brand.ilike(pattern)
            | Product.shade_name.ilike(pattern)
        )
        count_query = count_query.where(
            Product.name.ilike(pattern)
            | Product.brand.ilike(pattern)
            | Product.shade_name.ilike(pattern)
        )

    total = (await db.execute(count_query)).scalar_one()
    result = await db.execute(
        query.order_by(Product.brand, Product.name).limit(limit).offset(offset)
    )
    return result.scalars().all(), total


async def get_product_by_id(db: AsyncSession, product_id: str) -> Product | None:
    result = await db.execute(
        select(Product)
        .options(selectinload(Product.season_maps).selectinload(ProductSeasonMap.season))
        .where(Product.id == uuid.UUID(product_id))
    )
    return result.scalar_one_or_none()


async def get_products_by_season(
    db: AsyncSession,
    season_id: str,
    *,
    limit: int = 50,
    offset: int = 0,
) -> list[Product]:
    result = await db.execute(
        select(Product)
        .join(ProductSeasonMap)
        .where(ProductSeasonMap.season_id == uuid.UUID(season_id))
        .order_by(ProductSeasonMap.confidence.desc())
        .limit(limit)
        .offset(offset)
    )
    return result.scalars().all()
