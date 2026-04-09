from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_user, require_premium
from app.models.user import User
from app.schemas.lip_combo import LipComboOut, LipComboListResponse, ComboItemOut
from app.schemas.product import ProductOut
from app.services.combos import get_combos_by_influencer, get_combo_by_id

router = APIRouter()


def _serialize_combo(combo) -> LipComboOut:
    return LipComboOut(
        id=combo.id,
        influencer_id=combo.influencer_id,
        name=combo.name,
        items=[
            ComboItemOut(
                product=ProductOut.model_validate(item.product),
                role=item.role,
                sort_order=item.sort_order,
            )
            for item in combo.items
        ],
    )


@router.get("/influencer/{influencer_id}", response_model=LipComboListResponse)
async def list_combos_for_influencer(
    influencer_id: str,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(require_premium)],
    limit: int = Query(default=50, le=100),
    offset: int = 0,
):
    """Get all lip combos for an influencer. Premium only."""
    combos, total = await get_combos_by_influencer(
        db, influencer_id, limit=limit, offset=offset
    )
    return LipComboListResponse(
        total=total,
        combos=[_serialize_combo(c) for c in combos],
    )


@router.get("/{combo_id}", response_model=LipComboOut)
async def get_combo(
    combo_id: str,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    combo = await get_combo_by_id(db, combo_id)
    if not combo:
        raise HTTPException(status_code=404, detail="Combo not found")
    return _serialize_combo(combo)
