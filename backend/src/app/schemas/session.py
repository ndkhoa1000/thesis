from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from .vehicle import VehicleRead


class DriverCheckInTokenCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    vehicle_id: int = Field(gt=0)


class DriverCheckInTokenRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    token: str
    expires_at: datetime
    expires_in_seconds: int
    vehicle: VehicleRead


class DriverActiveSessionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    session_id: int
    parking_lot_id: int
    parking_lot_name: str
    license_plate: str
    vehicle_type: str
    checked_in_at: datetime
    elapsed_minutes: int
    estimated_cost: float
    pricing_mode: str | None = None


class DriverCheckOutTokenRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    token: str
    expires_at: datetime
    expires_in_seconds: int
    session_id: int
    license_plate: str


class AttendantCheckOutPreviewCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    token: str = Field(min_length=1)


class AttendantCheckOutPreviewRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    session_id: int
    parking_lot_id: int
    parking_lot_name: str
    license_plate: str
    vehicle_type: str
    checked_in_at: datetime
    elapsed_minutes: int
    final_fee: float
    pricing_mode: str


class AttendantCheckInCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    token: str = Field(min_length=1)


class AttendantCheckInRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    session_id: int
    parking_lot_id: int
    current_available: int
    license_plate: str
    vehicle_type: str
    checked_in_at: datetime