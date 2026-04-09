from typing import Any

from pydantic import field_validator

from app.schemas.base import CamelModel


class ProductOut(CamelModel):
    id: str
    brand: str
    name: str
    category: str
    shade_name: str | None = None
    hex_code: str | None = None
    swatch_url: str | None = None
    product_url: str | None = None
    affiliate_url: str | None = None
    retailer: str | None = None
    price_cents: int | None = None
    image_url: str | None = None

    @field_validator("id", mode="before")
    @classmethod
    def coerce_uuid(cls, v: Any) -> str:
        return str(v)


class ProductWithSeasons(ProductOut):
    seasons: list["ProductSeasonInfo"] = []


class ProductSeasonInfo(CamelModel):
    season_id: str
    season_name: str
    confidence: float

    @field_validator("season_id", mode="before")
    @classmethod
    def coerce_uuid(cls, v: Any) -> str:
        return str(v)


class ProductListResponse(CamelModel):
    total: int
    products: list[ProductOut]
