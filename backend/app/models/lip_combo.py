import uuid
from datetime import datetime, timezone

from sqlalchemy import Text, Integer, ForeignKey, TIMESTAMP, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class LipCombo(Base):
    __tablename__ = "lip_combos"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    influencer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("influencers.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    influencer: Mapped["Influencer"] = relationship("Influencer", back_populates="lip_combos")
    items: Mapped[list["LipComboItem"]] = relationship(
        "LipComboItem", back_populates="combo", cascade="all, delete-orphan",
        order_by="LipComboItem.sort_order"
    )


class LipComboItem(Base):
    __tablename__ = "lip_combo_items"
    __table_args__ = (
        UniqueConstraint("combo_id", "product_id", name="uq_combo_product"),
    )

    combo_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("lip_combos.id", ondelete="CASCADE"), primary_key=True
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("products.id", ondelete="CASCADE"), primary_key=True
    )
    role: Mapped[str] = mapped_column(Text, nullable=False)  # liner, lipstick, gloss
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    combo: Mapped["LipCombo"] = relationship("LipCombo", back_populates="items")
    product: Mapped["Product"] = relationship("Product", back_populates="combo_items")
