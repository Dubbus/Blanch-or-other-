import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.color_season import ColorSeason


async def get_all_seasons(db: AsyncSession) -> list[ColorSeason]:
    result = await db.execute(select(ColorSeason).order_by(ColorSeason.category, ColorSeason.name))
    return result.scalars().all()


async def get_season_by_id(db: AsyncSession, season_id: str) -> ColorSeason | None:
    result = await db.execute(
        select(ColorSeason).where(ColorSeason.id == uuid.UUID(season_id))
    )
    return result.scalar_one_or_none()
