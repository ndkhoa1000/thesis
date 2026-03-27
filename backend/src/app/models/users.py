"""Role-specific user subtables and capability application records."""

from datetime import UTC, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from ..core.db.database import Base
from .enums import CapabilityApplicationStatus


class Driver(Base):
    __tablename__ = "driver"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"), unique=True, index=True)
    wallet_balance: Mapped[float] = mapped_column(Numeric(12, 2), default=0.00)


class LotOwner(Base):
    __tablename__ = "lot_owner"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"), unique=True, index=True)
    business_license: Mapped[str | None] = mapped_column(String(100), default=None)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)


class LotOwnerApplication(Base):
    __tablename__ = "lot_owner_application"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"), index=True)
    full_name: Mapped[str] = mapped_column(String(100))
    phone_number: Mapped[str] = mapped_column(String(20))
    business_license: Mapped[str] = mapped_column(String(100))
    document_reference: Mapped[str] = mapped_column(String(255))
    notes: Mapped[str | None] = mapped_column(String(500), default=None)
    status: Mapped[str] = mapped_column(String(20), default=CapabilityApplicationStatus.PENDING.value)
    rejection_reason: Mapped[str | None] = mapped_column(String(255), default=None)
    reviewed_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("user.id"), default=None)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)


class Manager(Base):
    __tablename__ = "manager"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"), unique=True, index=True)
    business_license: Mapped[str | None] = mapped_column(String(100), default=None)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)


class Attendant(Base):
    __tablename__ = "attendant"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("user.id"), unique=True, index=True)
    parking_lot_id: Mapped[int] = mapped_column(ForeignKey("parking_lot.id"), index=True)
    hired_at: Mapped[datetime | None] = mapped_column(Date, default=None)
