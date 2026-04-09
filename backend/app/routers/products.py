from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.product import ProductOut, ProductWithSeasons, ProductSeasonInfo, ProductListResponse
from app.services.products import get_products, get_product_by_id

router = APIRouter()


@router.get("", response_model=ProductListResponse)
async def list_products(
    db: Annotated[AsyncSession, Depends(get_db)],
    category: str | None = None,
    retailer: str | None = None,
    season_id: str | None = None,
    limit: int = Query(default=50, le=100),
    offset: int = 0,
):
    products, total = await get_products(
        db, category=category, retailer=retailer, season_id=season_id,
        limit=limit, offset=offset,
    )
    return ProductListResponse(
        total=total,
        products=[ProductOut.model_validate(p) for p in products],
    )


@router.get("/search", response_model=ProductListResponse)
async def search_products(
    db: Annotated[AsyncSession, Depends(get_db)],
    q: str = Query(min_length=1),
    limit: int = Query(default=50, le=100),
    offset: int = 0,
):
    products, total = await get_products(db, search=q, limit=limit, offset=offset)
    return ProductListResponse(
        total=total,
        products=[ProductOut.model_validate(p) for p in products],
    )


@router.get("/{product_id}", response_model=ProductWithSeasons)
async def get_product(product_id: str, db: Annotated[AsyncSession, Depends(get_db)]):
    product = await get_product_by_id(db, product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    seasons = [
        ProductSeasonInfo(
            season_id=sm.season_id,
            season_name=sm.season.name,
            confidence=sm.confidence,
        )
        for sm in product.season_maps
    ]
    out = ProductWithSeasons.model_validate(product)
    out.seasons = seasons
    return out
