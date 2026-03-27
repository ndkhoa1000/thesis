from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, field_validator

from ..models.enums import ParkingLotStatus


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