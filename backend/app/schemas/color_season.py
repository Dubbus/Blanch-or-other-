from typing import Any

from pydantic import field_validator

from app.schemas.base import CamelModel


class SeasonOut(CamelModel):
    id: str
    name: str
    undertone: str
    category: str
    description: str | None = None
    hex_palette: list[str] = []

    @field_validator("id", mode="before")
    @classmethod
    def coerce_uuid(cls, v: Any) -> str:
        return str(v)

    @field_validator("hex_palette", mode="before")
    @classmethod
    def default_palette(cls, v: Any) -> list[str]:
        return v or []


class SeasonListResponse(CamelModel):
    seasons: list[SeasonOut]
