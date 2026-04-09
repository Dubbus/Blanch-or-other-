import uuid

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.lip_combo import LipCombo, LipComboItem


async def get_combos_by_influencer(
    db: AsyncSession,
    influencer_id: str,
    *,
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[LipCombo], int]:
    uid = uuid.UUID(influencer_id)

    count_query = select(func.count()).select_from(LipCombo).where(
        LipCombo.influencer_id == uid
    )
    total = (await db.execute(count_query)).scalar_one()

    result = await db.execute(
        select(LipCombo)
        .options(selectinload(LipCombo.items).selectinload(LipComboItem.product))
        .where(LipCombo.influencer_id == uid)
        .order_by(LipCombo.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    return result.scalars().unique().all(), total


async def get_combo_by_id(db: AsyncSession, combo_id: str) -> LipCombo | None:
    result = await db.execute(
        select(LipCombo)
        .options(selectinload(LipCombo.items).selectinload(LipComboItem.product))
        .where(LipCombo.id == uuid.UUID(combo_id))
    )
    return result.scalar_one_or_none()
