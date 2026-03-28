"""Shift handover domain models."""

from datetime import UTC, datetime

from sqlalchemy import DateTime, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from ..core.db.database import Base
from .enums import ShiftStatus


class Shift(Base):
    __tablename__ = "shift"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    parking_lot_id: Mapped[int] = mapped_column(ForeignKey("parking_lot.id"), index=True)
    attendant_id: Mapped[int] = mapped_column(ForeignKey("attendant.id"), index=True)
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default_factory=lambda: datetime.now(UTC),
    )
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    status: Mapped[str] = mapped_column(String(30), default=ShiftStatus.OPEN.value)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default_factory=lambda: datetime.now(UTC),
    )


class ShiftHandover(Base):
    __tablename__ = "shift_handover"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    outgoing_shift_id: Mapped[int] = mapped_column(ForeignKey("shift.id"), unique=True, index=True)
    incoming_shift_id: Mapped[int] = mapped_column(ForeignKey("shift.id"), index=True)
    incoming_attendant_id: Mapped[int] = mapped_column(ForeignKey("attendant.id"), index=True)
    expected_cash: Mapped[float] = mapped_column(Numeric(12, 2))
    actual_cash: Mapped[float] = mapped_column(Numeric(12, 2))
    discrepancy_reason: Mapped[str | None] = mapped_column(String(255), default=None)
    operator_notification_id: Mapped[int | None] = mapped_column(
        ForeignKey("notification.id"),
        default=None,
        index=True,
    )
    completed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default_factory=lambda: datetime.now(UTC),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default_factory=lambda: datetime.now(UTC),
    )
