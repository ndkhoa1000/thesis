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


class DriverParkingHistoryItemRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    session_id: int
    parking_lot_id: int
    parking_lot_name: str
    license_plate: str
    vehicle_type: str
    checked_in_at: datetime
    checked_out_at: datetime
    duration_minutes: int = Field(ge=0)
    amount_paid: float | None = None
    payment_method: str | None = None


class AttendantOccupancyVehicleBreakdownRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    vehicle_type: str
    occupied_count: int = Field(ge=0)


class AttendantOccupancySummaryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    parking_lot_id: int
    parking_lot_name: str
    has_active_capacity_config: bool
    total_capacity: int | None = None
    free_count: int | None = Field(default=None, ge=0)
    occupied_count: int | None = Field(default=None, ge=0)
    vehicle_type_breakdown: list[AttendantOccupancyVehicleBreakdownRead] = []


class AttendantActiveSessionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    session_id: int
    parking_lot_id: int
    license_plate: str
    vehicle_type: str
    checked_in_at: datetime
    elapsed_minutes: int = Field(ge=0)


class AttendantForceCloseTimeoutCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    session_id: int = Field(gt=0)
    reason: str = Field(min_length=5, max_length=255)


class AttendantForceCloseTimeoutRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    session_id: int
    parking_lot_id: int
    license_plate: str
    vehicle_type: str
    timeout_at: datetime
    current_available: int
    status: str
    reason: str


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


class AttendantCheckOutFinalizeCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    session_id: int = Field(gt=0)
    payment_method: str = Field(pattern="^(CASH|ONLINE)$")
    quoted_final_fee: float = Field(ge=0)


class AttendantCheckOutFinalizeRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    session_id: int
    parking_lot_id: int
    parking_lot_name: str
    license_plate: str
    vehicle_type: str
    final_fee: float
    payment_method: str
    checked_out_at: datetime
    current_available: int


class AttendantCheckOutUndoCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    session_id: int = Field(gt=0)


class AttendantCheckOutUndoRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    session_id: int
    parking_lot_id: int
    current_available: int
    status: str


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