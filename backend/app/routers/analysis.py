from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_user, require_premium
from app.models.user import User
from app.schemas.analysis import (
    AnalysisSubmitIn,
    AnalysisResultOut,
    AnalysisFreeResult,
    AnalysisPremiumResult,
    SeasonScore,
)
from app.schemas.color_season import SeasonOut
from app.services.analysis import submit_analysis, get_user_analysis, get_recommendation_seasons

router = APIRouter()


@router.post("", response_model=AnalysisResultOut, status_code=201)
async def submit(
    body: AnalysisSubmitIn,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    result = await submit_analysis(
        db,
        user_id=current_user.id,
        season_id=body.season_id,
        raw_scores=body.raw_scores,
        selfie_metadata=body.selfie_metadata,
    )
    # Reload with season relationship
    analysis = await get_user_analysis(db, current_user.id)
    return AnalysisResultOut(
        id=analysis.id,
        season=SeasonOut.model_validate(analysis.season),
        raw_scores=analysis.raw_scores,
        completed_at=analysis.completed_at,
    )


@router.get("/me", response_model=AnalysisFreeResult)
async def my_analysis_free(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    """Free tier: returns only the primary season."""
    analysis = await get_user_analysis(db, current_user.id)
    if not analysis:
        raise HTTPException(status_code=404, detail="No analysis found. Take the quiz first.")
    return AnalysisFreeResult(season=SeasonOut.model_validate(analysis.season))


@router.get("/me/full", response_model=AnalysisPremiumResult)
async def my_analysis_premium(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(require_premium)],
):
    """Premium tier: full ranked breakdown with percentages."""
    analysis = await get_user_analysis(db, current_user.id)
    if not analysis:
        raise HTTPException(status_code=404, detail="No analysis found. Take the quiz first.")

    total = sum(analysis.raw_scores.values()) or 1.0
    ranked = await get_recommendation_seasons(db, analysis.raw_scores, limit=12)

    return AnalysisPremiumResult(
        primary_season=SeasonOut.model_validate(analysis.season),
        all_scores=[
            SeasonScore(
                season=SeasonOut.model_validate(season),
                score=score,
                percentage=round((score / total) * 100, 1),
            )
            for season, score in ranked
        ],
    )
