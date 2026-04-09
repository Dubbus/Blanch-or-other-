import uuid
from datetime import datetime, timezone

from sqlalchemy import Text, Integer, ForeignKey, TIMESTAMP, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Influencer(Base):
    __tablename__ = "influencers"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    handle: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    platform: Mapped[str] = mapped_column(Text, nullable=False)  # instagram, tiktok
    display_name: Mapped[str | None] = mapped_column(Text)
    avatar_url: Mapped[str | None] = mapped_column(Text)
    follower_count: Mapped[int | None] = mapped_column(Integer)
    primary_season_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("color_seasons.id")
    )
    bio: Mapped[str | None] = mapped_column(Text)
    instagram_url: Mapped[str | None] = mapped_column(Text)
    tiktok_url: Mapped[str | None] = mapped_column(Text)
    scraped_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    primary_season: Mapped["ColorSeason"] = relationship(  # noqa: F821
        "ColorSeason", foreign_keys=[primary_season_id]
    )
    season_maps: Mapped[list["InfluencerSeasonMap"]] = relationship(
        "InfluencerSeasonMap", back_populates="influencer", cascade="all, delete-orphan"
    )
    lip_combos: Mapped[list["LipCombo"]] = relationship(  # noqa: F821
        "LipCombo", back_populates="influencer", cascade="all, delete-orphan"
    )
    mentions: Mapped[list["ProductMention"]] = relationship(  # noqa: F821
        "ProductMention", back_populates="influencer", cascade="all, delete-orphan"
    )


class InfluencerSeasonMap(Base):
    __tablename__ = "influencer_season_map"
    __table_args__ = (
        UniqueConstraint("influencer_id", "season_id", name="uq_influencer_season"),
    )

    influencer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("influencers.id", ondelete="CASCADE"), primary_key=True
    )
    season_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("color_seasons.id", ondelete="CASCADE"), primary_key=True
    )

    influencer: Mapped["Influencer"] = relationship("Influencer", back_populates="season_maps")
    season: Mapped["ColorSeason"] = relationship("ColorSeason", back_populates="influencers")
