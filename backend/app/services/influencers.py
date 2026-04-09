import uuid

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.influencer import Influencer, InfluencerSeasonMap


async def get_influencers(
    db: AsyncSession,
    *,
    season_id: str | None = None,
    platform: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[Influencer], int]:
    query = select(Influencer)
    count_query = select(func.count()).select_from(Influencer)

    if platform:
        query = query.where(Influencer.platform == platform)
        count_query = count_query.where(Influencer.platform == platform)
    if season_id:
        query = query.join(InfluencerSeasonMap).where(
            InfluencerSeasonMap.season_id == uuid.UUID(season_id)
        )
        count_query = count_query.join(InfluencerSeasonMap).where(
            InfluencerSeasonMap.season_id == uuid.UUID(season_id)
        )

    total = (await db.execute(count_query)).scalar_one()
    result = await db.execute(
        query.order_by(Influencer.display_name).limit(limit).offset(offset)
    )
    return result.scalars().all(), total


async def get_influencer_by_id(db: AsyncSession, influencer_id: str) -> Influencer | None:
    result = await db.execute(
        select(Influencer)
        .options(
            selectinload(Influencer.lip_combos),
            selectinload(Influencer.season_maps).selectinload(InfluencerSeasonMap.season),
        )
        .where(Influencer.id == uuid.UUID(influencer_id))
    )
    return result.scalar_one_or_none()


async def get_influencers_by_season(
    db: AsyncSession,
    season_id: str,
) -> list[Influencer]:
    result = await db.execute(
        select(Influencer)
        .join(InfluencerSeasonMap)
        .where(InfluencerSeasonMap.season_id == uuid.UUID(season_id))
        .order_by(Influencer.follower_count.desc().nulls_last())
    )
    return result.scalars().all()
