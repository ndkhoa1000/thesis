"""Vehicle and subscription domain models: Vehicle, Subscription, SubscriptionLot."""

from datetime import UTC, datetime

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from ..core.db.database import Base
from .enums import SubscriptionStatus, SubscriptionType, VehicleType


class Vehicle(Base):
    __tablename__ = "vehicle"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    driver_id: Mapped[int] = mapped_column(ForeignKey("driver.id"), index=True)
    license_plate: Mapped[str] = mapped_column(String(15), unique=True, index=True)
    # Optional / defaulted fields
    vehicle_type: Mapped[str] = mapped_column(String(20), default=VehicleType.MOTORBIKE.value)
    brand: Mapped[str | None] = mapped_column(String(50), default=None)
    color: Mapped[str | None] = mapped_column(String(20), default=None)
    front_image: Mapped[str | None] = mapped_column(String(255), default=None)
    back_image: Mapped[str | None] = mapped_column(String(255), default=None)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))


class Subscription(Base):
    __tablename__ = "subscription"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    driver_id: Mapped[int] = mapped_column(ForeignKey("driver.id"), index=True)
    price: Mapped[float] = mapped_column(Numeric(10, 2))
    # Optional / defaulted fields
    vehicle_id: Mapped[int | None] = mapped_column(ForeignKey("vehicle.id"), default=None, index=True)
    vehicle_type: Mapped[str] = mapped_column(String(20), default=VehicleType.MOTORBIKE.value)
    subscription_type: Mapped[str] = mapped_column(String(20), default=SubscriptionType.MONTHLY.value)
    start_date: Mapped[datetime | None] = mapped_column(Date, default=None)
    end_date: Mapped[datetime | None] = mapped_column(Date, default=None)
    status: Mapped[str] = mapped_column(String(20), default=SubscriptionStatus.ACTIVE.value)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))


class SubscriptionLot(Base):
    __tablename__ = "subscription_lot"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    subscription_id: Mapped[int] = mapped_column(ForeignKey("subscription.id"), index=True)
    parking_lot_id: Mapped[int] = mapped_column(ForeignKey("parking_lot.id"), index=True)
