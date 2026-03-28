from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from .vehicle import VehicleRead


class DriverBookingCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    parking_lot_id: int = Field(gt=0)
    vehicle_id: int = Field(gt=0)


class BookingPaymentRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    payment_id: int
    amount: float
    final_amount: float
    payment_method: str
    payment_status: str


class DriverBookingRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    booking_id: int
    parking_lot_id: int
    parking_lot_name: str
    status: str
    booking_time: datetime
    expected_arrival: datetime | None = None
    expiration_time: datetime | None = None
    expires_in_seconds: int = Field(ge=0)
    current_available: int = Field(ge=0)
    token: str
    vehicle: VehicleRead
    payment: BookingPaymentRead


class DriverBookingCancelRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    booking_id: int
    status: str
    current_available: int = Field(ge=0)
