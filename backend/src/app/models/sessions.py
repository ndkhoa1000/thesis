"""Parking session domain models: Booking, ParkingSession, SessionEdit."""

from datetime import UTC, datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from ..core.db.database import Base
from .enums import BookingStatus, SessionStatus, VehicleType


class Booking(Base):
    __tablename__ = "booking"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    driver_id: Mapped[int] = mapped_column(ForeignKey("driver.id"), index=True)
    parking_lot_id: Mapped[int] = mapped_column(ForeignKey("parking_lot.id"), index=True)
    vehicle_id: Mapped[int] = mapped_column(ForeignKey("vehicle.id"), index=True)
    # Optional / defaulted fields
    slot_id: Mapped[int | None] = mapped_column(ForeignKey("slot.id"), default=None, index=True)
    booking_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))
    expected_arrival: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    expiration_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    status: Mapped[str] = mapped_column(String(20), default=BookingStatus.PENDING.value)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))


class ParkingSession(Base):
    __tablename__ = "parking_session"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    parking_lot_id: Mapped[int] = mapped_column(ForeignKey("parking_lot.id"), index=True)
    license_plate: Mapped[str] = mapped_column(String(15), index=True)
    # Optional / defaulted fields
    driver_id: Mapped[int | None] = mapped_column(ForeignKey("driver.id"), default=None, index=True)
    slot_id: Mapped[int | None] = mapped_column(ForeignKey("slot.id"), default=None, index=True)
    booking_id: Mapped[int | None] = mapped_column(ForeignKey("booking.id"), default=None, index=True)
    subscription_id: Mapped[int | None] = mapped_column(ForeignKey("subscription.id"), default=None, index=True)
    attendant_checkin_id: Mapped[int | None] = mapped_column(ForeignKey("attendant.id"), default=None)
    attendant_checkout_id: Mapped[int | None] = mapped_column(ForeignKey("attendant.id"), default=None)
    vehicle_type: Mapped[str] = mapped_column(String(20), default=VehicleType.MOTORBIKE.value)
    checkin_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))
    checkout_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    checkin_image: Mapped[str | None] = mapped_column(String(255), default=None)
    checkin_image_public_id: Mapped[str | None] = mapped_column(String(255), default=None)
    overview_image: Mapped[str | None] = mapped_column(String(255), default=None)
    overview_image_public_id: Mapped[str | None] = mapped_column(String(255), default=None)
    checkout_image: Mapped[str | None] = mapped_column(String(255), default=None)
    checkout_image_public_id: Mapped[str | None] = mapped_column(String(255), default=None)
    qr_code: Mapped[str | None] = mapped_column(String(100), unique=True, default=None)
    nfc_card_id: Mapped[str | None] = mapped_column(String(50), default=None)
    status: Mapped[str] = mapped_column(String(20), default=SessionStatus.CHECKED_IN.value)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))


class SessionEdit(Base):
    __tablename__ = "session_edit"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    session_id: Mapped[int] = mapped_column(ForeignKey("parking_session.id"), index=True)
    edited_by: Mapped[int] = mapped_column(ForeignKey("attendant.id"), index=True)
    field_changed: Mapped[str] = mapped_column(String(50))
    # Optional / defaulted fields
    old_value: Mapped[str | None] = mapped_column(String(255), default=None)
    new_value: Mapped[str | None] = mapped_column(String(255), default=None)
    reason: Mapped[str | None] = mapped_column(String(255), default=None)
    edited_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))
