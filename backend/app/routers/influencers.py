from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.influencer import InfluencerOut, InfluencerListResponse
from app.services.influencers import get_influencers, get_influencer_by_id

router = APIRouter()


@router.get("", response_model=InfluencerListResponse)
async def list_influencers(
    db: Annotated[AsyncSession, Depends(get_db)],
    season_id: str | None = None,
    platform: str | None = None,
    limit: int = Query(default=50, le=100),
    offset: int = 0,
):
    influencers, total = await get_influencers(
        db, season_id=season_id, platform=platform, limit=limit, offset=offset,
    )
    return InfluencerListResponse(
        total=total,
        influencers=[InfluencerOut.model_validate(i) for i in influencers],
    )


@router.get("/{influencer_id}", response_model=InfluencerOut)
async def get_influencer_detail(
    influencer_id: str, db: Annotated[AsyncSession, Depends(get_db)]
):
    influencer = await get_influencer_by_id(db, influencer_id)
    if not influencer:
        raise HTTPException(status_code=404, detail="Influencer not found")
    return InfluencerOut.model_validate(influencer)
