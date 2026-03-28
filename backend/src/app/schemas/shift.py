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


class AttendantFinalShiftCloseOutRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    close_out_id: int
    shift_id: int
    parking_lot_id: int
    expected_cash: float = Field(ge=0)
    current_available: int = Field(ge=0)
    active_session_count: int = Field(ge=0)
    status: str
    requested_at: datetime


class OperatorFinalShiftCloseOutRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    close_out_id: int
    shift_id: int
    parking_lot_id: int
    parking_lot_name: str
    attendant_id: int
    attendant_name: str
    expected_cash: float = Field(ge=0)
    current_available: int = Field(ge=0)
    active_session_count: int = Field(ge=0)
    status: str
    requested_at: datetime
    completed_at: datetime | None = None
