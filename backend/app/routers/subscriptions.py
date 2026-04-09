from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.deps import get_current_user
from app.models.user import User
from app.schemas.base import CamelModel

router = APIRouter()


class VerifyReceiptIn(CamelModel):
    receipt_data: str
    product_id: str


class SubscriptionStatusOut(CamelModel):
    tier: str
    expires_at: str | None = None


@router.post("/verify", response_model=SubscriptionStatusOut)
async def verify_receipt(
    body: VerifyReceiptIn,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    # TODO: Implement App Store Server API receipt validation
    # For now, this is a scaffold that upgrades the user to premium
    # In production, verify with Apple's App Store Server API
    current_user.subscription_tier = "premium"
    current_user.subscription_expires_at = datetime.now(timezone.utc) + timedelta(days=30)
    await db.commit()
    await db.refresh(current_user)

    return SubscriptionStatusOut(
        tier=current_user.subscription_tier,
        expires_at=str(current_user.subscription_expires_at) if current_user.subscription_expires_at else None,
    )


@router.get("/status", response_model=SubscriptionStatusOut)
async def subscription_status(
    current_user: Annotated[User, Depends(get_current_user)],
):
    return SubscriptionStatusOut(
        tier=current_user.subscription_tier,
        expires_at=str(current_user.subscription_expires_at) if current_user.subscription_expires_at else None,
    )
