from typing import Any

from pydantic import field_validator

from app.schemas.base import CamelModel
from app.schemas.color_season import SeasonOut


class AnalysisSubmitIn(CamelModel):
    season_id: str
    raw_scores: dict[str, float]
    selfie_metadata: dict | None = None


class AnalysisResultOut(CamelModel):
    id: str
    season: SeasonOut
    raw_scores: dict[str, float]
    completed_at: str

    @field_validator("id", mode="before")
    @classmethod
    def coerce_uuid(cls, v: Any) -> str:
        return str(v)

    @field_validator("completed_at", mode="before")
    @classmethod
    def coerce_date(cls, v: Any) -> str:
        return str(v) if v else ""


class AnalysisFreeResult(CamelModel):
    """Free tier: only the top season, no detailed scores."""
    season: SeasonOut


class AnalysisPremiumResult(CamelModel):
    """Premium tier: full ranked breakdown with percentages."""
    primary_season: SeasonOut
    all_scores: list["SeasonScore"]


class SeasonScore(CamelModel):
    season: SeasonOut
    score: float
    percentage: float
