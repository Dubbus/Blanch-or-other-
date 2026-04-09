import uuid

from sqlalchemy import Text
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ColorSeason(Base):
    __tablename__ = "color_seasons"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    name: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    undertone: Mapped[str] = mapped_column(Text, nullable=False)  # cool, warm, neutral
    category: Mapped[str] = mapped_column(Text, nullable=False)  # winter, spring, summer, autumn
    description: Mapped[str | None] = mapped_column(Text)
    hex_palette: Mapped[list[str]] = mapped_column(
        ARRAY(Text), nullable=False, default=list
    )

    products: Mapped[list["ProductSeasonMap"]] = relationship(  # noqa: F821
        "ProductSeasonMap", back_populates="season", cascade="all, delete-orphan"
    )
    influencers: Mapped[list["InfluencerSeasonMap"]] = relationship(  # noqa: F821
        "InfluencerSeasonMap", back_populates="season", cascade="all, delete-orphan"
    )
