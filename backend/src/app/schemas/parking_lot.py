from datetime import date, datetime, time
from typing import Annotated

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from ..models.enums import ParkingLotStatus, PricingMode
from .user import _validate_password_strength


class ParkingLotCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: Annotated[str, Field(min_length=2, max_length=100)]
    address: Annotated[str, Field(min_length=5, max_length=255)]
    latitude: Annotated[float, Field(ge=-90, le=90)]
    longitude: Annotated[float, Field(ge=-180, le=180)]
    description: Annotated[str | None, Field(max_length=1000, default=None)]
    cover_image: Annotated[str | None, Field(max_length=255, default=None)]

    @field_validator("name", "address", mode="before")
    @classmethod
    def strip_required_text(cls, value: str) -> str:
        if not isinstance(value, str):
            raise ValueError("Field must be a string")
        stripped = value.strip()
        if not stripped:
            raise ValueError("Field is required")
        return stripped

    @field_validator("description", "cover_image", mode="before")
    @classmethod
    def strip_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None


class ParkingLotRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    lot_owner_id: int
    name: str
    address: str
    latitude: float
    longitude: float
    current_available: int
    status: str
    description: str | None = None
    cover_image: str | None = None
    created_at: datetime
    updated_at: datetime | None = None


class ParkingLotAdminRead(ParkingLotRead):
    owner_name: str | None = None
    owner_phone: str | None = None
    owner_business_license: str | None = None


class OperatorManagedParkingLotRead(ParkingLotRead):
    lease_id: int
    total_capacity: int | None = None
    occupied_count: int
    opening_time: time | None = None
    closing_time: time | None = None
    pricing_mode: PricingMode | None = None
    price_amount: float | None = None


class OperatorManagedParkingLotUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: Annotated[str, Field(min_length=2, max_length=100)]
    address: Annotated[str, Field(min_length=5, max_length=255)]
    total_capacity: Annotated[int, Field(ge=1, le=100000)]
    opening_time: time
    closing_time: time
    pricing_mode: PricingMode
    price_amount: Annotated[float, Field(gt=0, le=1000000000)]
    description: Annotated[str | None, Field(max_length=1000, default=None)]
    cover_image: Annotated[str | None, Field(max_length=255, default=None)]

    @field_validator("name", "address", mode="before")
    @classmethod
    def strip_required_text_update(cls, value: str) -> str:
        if not isinstance(value, str):
            raise ValueError("Field must be a string")
        stripped = value.strip()
        if not stripped:
            raise ValueError("Field is required")
        return stripped

    @field_validator("description", "cover_image", mode="before")
    @classmethod
    def strip_optional_text_update(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None

    @field_validator("pricing_mode")
    @classmethod
    def validate_pricing_mode(cls, value: PricingMode) -> PricingMode:
        if value not in {PricingMode.HOURLY, PricingMode.SESSION}:
            raise ValueError("Pricing mode must be HOURLY or SESSION")
        return value

    @field_validator("closing_time")
    @classmethod
    def validate_closing_time(cls, value: time, info) -> time:
        opening_time = info.data.get("opening_time")
        if opening_time is not None and value == opening_time:
            raise ValueError("Closing time must differ from opening time")
        return value


class OperatorManagedAttendantRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    parking_lot_id: int
    name: str
    username: str
    email: EmailStr
    phone: str | None = None
    is_active: bool
    hired_at: date | None = None


class OperatorManagedAttendantCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: Annotated[str, Field(min_length=2, max_length=30)]
    username: Annotated[str, Field(min_length=2, max_length=20, pattern=r"^[a-z0-9]+$")]
    email: EmailStr
    password: Annotated[str, Field(min_length=8)]
    phone: Annotated[str | None, Field(min_length=8, max_length=15, default=None)]

    @field_validator("name", "username", mode="before")
    @classmethod
    def strip_required_attendant_text(cls, value: str) -> str:
        if not isinstance(value, str):
            raise ValueError("Field must be a string")
        stripped = value.strip()
        if not stripped:
            raise ValueError("Field is required")
        return stripped

    @field_validator("phone", mode="before")
    @classmethod
    def strip_optional_phone(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        return _validate_password_strength(value)


class ParkingLotReview(BaseModel):
    model_config = ConfigDict(extra="forbid")

    decision: ParkingLotStatus
    rejection_reason: Annotated[str | None, Field(max_length=255, default=None)]

    @field_validator("rejection_reason", mode="before")
    @classmethod
    def normalize_reason(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None

    @field_validator("decision")
    @classmethod
    def validate_decision(cls, value: ParkingLotStatus) -> ParkingLotStatus:
        if value not in {ParkingLotStatus.APPROVED, ParkingLotStatus.REJECTED}:
            raise ValueError("Decision must be APPROVED or REJECTED")
        return value


class ParkingLotStatusUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: ParkingLotStatus

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: ParkingLotStatus) -> ParkingLotStatus:
        if value not in {ParkingLotStatus.APPROVED, ParkingLotStatus.CLOSED}:
            raise ValueError("Status must be APPROVED or CLOSED")
        return value