from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class AttendantShiftHandoverStartRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    shift_id: int
    parking_lot_id: int
    expected_cash: float = Field(ge=0)
    token: str
    expires_at: datetime
    expires_in_seconds: int = Field(ge=1)


class AttendantShiftHandoverFinalizeCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    token: str = Field(min_length=1)
    actual_cash: float = Field(ge=0)
    discrepancy_reason: str | None = Field(default=None, max_length=255)


class AttendantShiftHandoverFinalizeRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    handover_id: int
    outgoing_shift_id: int
    incoming_shift_id: int
    expected_cash: float = Field(ge=0)
    actual_cash: float = Field(ge=0)
    discrepancy_flagged: bool
    completed_at: datetime


class OperatorShiftAlertRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    message: str | None = None
    notification_type: str
    reference_type: str | None = None
    reference_id: int | None = None
    is_read: bool
    created_at: datetime
