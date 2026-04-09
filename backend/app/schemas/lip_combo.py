from typing import Any

from pydantic import field_validator

from app.schemas.base import CamelModel
from app.schemas.product import ProductOut


class ComboItemOut(CamelModel):
    product: ProductOut
    role: str
    sort_order: int = 0


class LipComboOut(CamelModel):
    id: str
    influencer_id: str
    name: str | None = None
    items: list[ComboItemOut] = []

    @field_validator("id", "influencer_id", mode="before")
    @classmethod
    def coerce_uuid(cls, v: Any) -> str:
        return str(v)


class LipComboListResponse(CamelModel):
    total: int
    combos: list[LipComboOut]
