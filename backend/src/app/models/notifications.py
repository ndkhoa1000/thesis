"""Notification domain models: ParkingLotAnnouncement, Notification."""

from datetime import UTC, datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from ..core.db.database import Base
from .enums import AnnouncementType, NotificationType


class ParkingLotAnnouncement(Base):
    __tablename__ = "parking_lot_announcement"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    parking_lot_id: Mapped[int] = mapped_column(ForeignKey("parking_lot.id"), index=True)
    posted_by: Mapped[int] = mapped_column(ForeignKey("manager.id"), index=True)
    title: Mapped[str] = mapped_column(String(100))
    # Optional / defaulted fields
    content: Mapped[str | None] = mapped_column(Text, default=None)
    announcement_type: Mapped[str] = mapped_column(String(30), default=AnnouncementType.GENERAL.value)
    visible_from: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))
    visible_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))


class Notification(Base):
    __tablename__ = "notification"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"), index=True)
    title: Mapped[str] = mapped_column(String(100))
    # Optional / defaulted fields
    sender_id: Mapped[int | None] = mapped_column(ForeignKey("user.id"), default=None)
    message: Mapped[str | None] = mapped_column(Text, default=None)
    notification_type: Mapped[str] = mapped_column(String(30), default=NotificationType.SYSTEM_ALERT.value)
    reference_type: Mapped[str | None] = mapped_column(String(20), default=None)
    reference_id: Mapped[int | None] = mapped_column(Integer, default=None)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))
