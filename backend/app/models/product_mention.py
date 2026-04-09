import uuid
from datetime import datetime, timezone

from sqlalchemy import Text, Float, ForeignKey, TIMESTAMP
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ProductMention(Base):
    __tablename__ = "product_mentions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    influencer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("influencers.id", ondelete="CASCADE"), nullable=False
    )
    product_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("products.id", ondelete="SET NULL")
    )
    raw_text: Mapped[str] = mapped_column(Text, nullable=False)
    source_url: Mapped[str | None] = mapped_column(Text)
    mention_type: Mapped[str | None] = mapped_column(Text)  # caption, comment, story
    confidence: Mapped[float | None] = mapped_column(Float)
    scraped_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True))

    influencer: Mapped["Influencer"] = relationship("Influencer", back_populates="mentions")
    product: Mapped["Product | None"] = relationship("Product", back_populates="mentions")
