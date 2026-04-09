import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.analysis import UserAnalysisResult
from app.models.color_season import ColorSeason


async def submit_analysis(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    season_id: str,
    raw_scores: dict[str, float],
    selfie_metadata: dict | None = None,
) -> UserAnalysisResult:
    result = UserAnalysisResult(
        user_id=user_id,
        season_id=uuid.UUID(season_id),
        raw_scores=raw_scores,
        selfie_metadata=selfie_metadata,
    )
    db.add(result)
    await db.commit()
    await db.refresh(result)
    return result


async def get_user_analysis(
    db: AsyncSession, user_id: uuid.UUID
) -> UserAnalysisResult | None:
    result = await db.execute(
        select(UserAnalysisResult)
        .options(selectinload(UserAnalysisResult.season))
        .where(UserAnalysisResult.user_id == user_id)
        .order_by(UserAnalysisResult.completed_at.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def get_recommendation_seasons(
    db: AsyncSession, raw_scores: dict[str, float], *, limit: int = 3
) -> list[tuple[ColorSeason, float]]:
    """Get top matching seasons from raw scores for recommendations."""
    sorted_scores = sorted(raw_scores.items(), key=lambda x: x[1], reverse=True)
    results = []
    for season_name, score in sorted_scores[:limit]:
        result = await db.execute(
            select(ColorSeason).where(ColorSeason.name == season_name)
        )
        season = result.scalar_one_or_none()
        if season:
            results.append((season, score))
    return results
