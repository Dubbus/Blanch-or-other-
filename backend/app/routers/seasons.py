from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.color_season import SeasonOut, SeasonListResponse
from app.schemas.product import ProductOut, ProductListResponse
from app.schemas.influencer import InfluencerOut, InfluencerListResponse
from app.services.seasons import get_all_seasons, get_season_by_id
from app.services.products import get_products_by_season
from app.services.influencers import get_influencers_by_season

router = APIRouter()


@router.get("", response_model=SeasonListResponse)
async def list_seasons(db: Annotated[AsyncSession, Depends(get_db)]):
    seasons = await get_all_seasons(db)
    return SeasonListResponse(
        seasons=[SeasonOut.model_validate(s) for s in seasons]
    )


@router.get("/{season_id}", response_model=SeasonOut)
async def get_season(season_id: str, db: Annotated[AsyncSession, Depends(get_db)]):
    season = await get_season_by_id(db, season_id)
    if not season:
        raise HTTPException(status_code=404, detail="Season not found")
    return SeasonOut.model_validate(season)


@router.get("/{season_id}/products", response_model=ProductListResponse)
async def season_products(
    season_id: str,
    db: Annotated[AsyncSession, Depends(get_db)],
    limit: int = 50,
    offset: int = 0,
):
    season = await get_season_by_id(db, season_id)
    if not season:
        raise HTTPException(status_code=404, detail="Season not found")
    products = await get_products_by_season(db, season_id, limit=limit, offset=offset)
    return ProductListResponse(
        total=len(products),
        products=[ProductOut.model_validate(p) for p in products],
    )


@router.get("/{season_id}/influencers", response_model=InfluencerListResponse)
async def season_influencers(
    season_id: str,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    season = await get_season_by_id(db, season_id)
    if not season:
        raise HTTPException(status_code=404, detail="Season not found")
    influencers = await get_influencers_by_season(db, season_id)
    return InfluencerListResponse(
        total=len(influencers),
        influencers=[InfluencerOut.model_validate(i) for i in influencers],
    )
