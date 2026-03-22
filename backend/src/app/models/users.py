"""Role-specific user subtables: Driver, LotOwner, Manager, Attendant (Class Table Inheritance)."""

from datetime import UTC, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from ..core.db.database import Base


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
