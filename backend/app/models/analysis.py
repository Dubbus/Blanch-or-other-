import uuid
from datetime import datetime, timezone

from sqlalchemy import ForeignKey, TIMESTAMP
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class UserAnalysisResult(Base):
    __tablename__ = "user_analysis_results"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    season_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("color_seasons.id"), nullable=False
    )
    raw_scores: Mapped[dict] = mapped_column(JSONB, nullable=False)
    selfie_metadata: Mapped[dict | None] = mapped_column(JSONB)
    completed_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    user: Mapped["User"] = relationship("User", back_populates="analysis_results")
    season: Mapped["ColorSeason"] = relationship("ColorSeason")
