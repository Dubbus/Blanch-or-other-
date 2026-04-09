import uuid
from datetime import datetime, timezone

from sqlalchemy import Text, TIMESTAMP
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    display_name: Mapped[str] = mapped_column(Text, nullable=False)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(Text)
    subscription_tier: Mapped[str] = mapped_column(Text, default="free")
    subscription_expires_at: Mapped[datetime | None] = mapped_column(
        TIMESTAMP(timezone=True)
    )
    created_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    analysis_results: Mapped[list["UserAnalysisResult"]] = relationship(  # noqa: F821
        "UserAnalysisResult", back_populates="user", cascade="all, delete-orphan"
    )
    saved_products: Mapped[list["UserSavedProduct"]] = relationship(  # noqa: F821
        "UserSavedProduct", back_populates="user", cascade="all, delete-orphan"
    )
