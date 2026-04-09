from typing import Any

from pydantic import field_validator

from app.schemas.base import CamelModel


class InfluencerOut(CamelModel):
    id: str
    handle: str
    platform: str
    display_name: str | None = None
    avatar_url: str | None = None
    follower_count: int | None = None
    primary_season_id: str | None = None
    bio: str | None = None

    @field_validator("id", "primary_season_id", mode="before")
    @classmethod
    def coerce_uuid(cls, v: Any) -> str | None:
        return str(v) if v else None


class InfluencerListResponse(CamelModel):
    total: int
    influencers: list[InfluencerOut]
