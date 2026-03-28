"""Parking lot domain models: ParkingLot, ParkingLotConfig, ParkingLotFeature, ParkingLotTag, Slot, Pricing."""

from datetime import UTC, date, datetime, time

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, Numeric, String, Text, Time
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.orm import Mapped, mapped_column

from ..core.db.database import Base
from .enums import FeatureType, ParkingLotStatus, PricingMode, SlotType, VehicleTypeAll


class ParkingLot(Base):
    __tablename__ = "parking_lot"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    lot_owner_id: Mapped[int] = mapped_column(ForeignKey("lot_owner.id"), index=True)
    name: Mapped[str] = mapped_column(String(100))
    address: Mapped[str] = mapped_column(String(255))
    latitude: Mapped[float] = mapped_column(Numeric(10, 8))
    longitude: Mapped[float] = mapped_column(Numeric(11, 8))
    # Optional / defaulted fields
    current_available: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(20), default=ParkingLotStatus.PENDING.value)
    description: Mapped[str | None] = mapped_column(Text, default=None)
    cover_image: Mapped[str | None] = mapped_column(String(255), default=None)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)


class ParkingLotConfig(Base):
    __tablename__ = "parking_lot_config"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    parking_lot_id: Mapped[int] = mapped_column(ForeignKey("parking_lot.id"), index=True)
    set_by: Mapped[int] = mapped_column(ForeignKey("manager.id"), index=True)
    total_capacity: Mapped[int] = mapped_column(Integer)
    # Optional / defaulted fields
    vehicle_type: Mapped[str] = mapped_column(String(20), default=VehicleTypeAll.ALL.value)
    opening_time: Mapped[time | None] = mapped_column(Time, default=None)
    closing_time: Mapped[time | None] = mapped_column(Time, default=None)
    effective_from: Mapped[date | None] = mapped_column(Date, default=None)
    effective_to: Mapped[date | None] = mapped_column(Date, default=None)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default_factory=lambda: datetime.now(UTC))


class ParkingLotFeature(Base):
    __tablename__ = "parking_lot_feature"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    parking_lot_id: Mapped[int] = mapped_column(ForeignKey("parking_lot.id"), index=True)
    # Optional / defaulted fields
    feature_type: Mapped[str] = mapped_column(String(30), default=FeatureType.CAMERA.value)
    config_data: Mapped[dict | None] = mapped_column(JSON, default=None)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)


class ParkingLotTag(Base):
    __tablename__ = "parking_lot_tag"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    parking_lot_id: Mapped[int] = mapped_column(ForeignKey("parking_lot.id"), index=True)
    tag_name: Mapped[str] = mapped_column(String(50))


class Slot(Base):
    __tablename__ = "slot"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    parking_lot_id: Mapped[int] = mapped_column(ForeignKey("parking_lot.id"), index=True)
    slot_code: Mapped[str] = mapped_column(String(10))
    # Optional / defaulted fields
    slot_type: Mapped[str] = mapped_column(String(20), default=SlotType.STANDARD.value)
    is_occupied: Mapped[bool] = mapped_column(Boolean, default=False)
    sensor_id: Mapped[str | None] = mapped_column(String(50), default=None)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)


class Pricing(Base):
    __tablename__ = "pricing"

    id: Mapped[int] = mapped_column(autoincrement=True, primary_key=True, init=False)
    # Required fields first
    parking_lot_id: Mapped[int] = mapped_column(ForeignKey("parking_lot.id"), index=True)
    price_amount: Mapped[float] = mapped_column(Numeric(10, 2))
    # Optional / defaulted fields
    vehicle_type: Mapped[str] = mapped_column(String(20), default=VehicleTypeAll.ALL.value)
    pricing_mode: Mapped[str] = mapped_column(String(20), default=PricingMode.SESSION.value)
    note: Mapped[str | None] = mapped_column(String(100), default=None)
    effective_from: Mapped[date | None] = mapped_column(Date, default=None)
    effective_to: Mapped[date | None] = mapped_column(Date, default=None)
