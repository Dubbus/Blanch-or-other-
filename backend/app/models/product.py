import uuid
from datetime import datetime, timezone

from sqlalchemy import Text, Integer, Float, ForeignKey, TIMESTAMP, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Product(Base):
    __tablename__ = "products"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    brand: Mapped[str] = mapped_column(Text, nullable=False)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str] = mapped_column(Text, nullable=False)  # lipstick, blush, foundation, etc.
    shade_name: Mapped[str | None] = mapped_column(Text)
    hex_code: Mapped[str | None] = mapped_column(Text)
    swatch_url: Mapped[str | None] = mapped_column(Text)
    product_url: Mapped[str | None] = mapped_column(Text)
    affiliate_url: Mapped[str | None] = mapped_column(Text)
    retailer: Mapped[str | None] = mapped_column(Text)  # sephora, ulta
    price_cents: Mapped[int | None] = mapped_column(Integer)
    image_url: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    season_maps: Mapped[list["ProductSeasonMap"]] = relationship(
        "ProductSeasonMap", back_populates="product", cascade="all, delete-orphan"
    )
    mentions: Mapped[list["ProductMention"]] = relationship(  # noqa: F821
        "ProductMention", back_populates="product", cascade="all, delete-orphan"
    )
    combo_items: Mapped[list["LipComboItem"]] = relationship(  # noqa: F821
        "LipComboItem", back_populates="product", cascade="all, delete-orphan"
    )


class ProductSeasonMap(Base):
    __tablename__ = "product_season_map"
    __table_args__ = (
        UniqueConstraint("product_id", "season_id", name="uq_product_season"),
    )

    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("products.id", ondelete="CASCADE"), primary_key=True
    )
    season_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("color_seasons.id", ondelete="CASCADE"), primary_key=True
    )
    confidence: Mapped[float] = mapped_column(Float, default=0.0)

    product: Mapped["Product"] = relationship("Product", back_populates="season_maps")
    season: Mapped["ColorSeason"] = relationship("ColorSeason", back_populates="products")
