from datetime import date
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class OwnerRevenuePeriod(str, Enum):
    DAY = "DAY"
    WEEK = "WEEK"
    MONTH = "MONTH"


class OwnerRevenueSummaryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    parking_lot_id: int
    parking_lot_name: str
    period: OwnerRevenuePeriod
    range_start: date
    range_end: date
    lease_status: str | None = None
    operator_name: str | None = None
    revenue_share_percentage: float | None = None
    lease_start_date: date | None = None
    lease_end_date: date | None = None
    completed_payment_count: int = Field(ge=0)
    completed_session_count: int = Field(ge=0)
    has_data: bool
    gross_revenue: float | None = Field(default=None, ge=0)
    owner_share: float | None = Field(default=None, ge=0)
    operator_share: float | None = Field(default=None, ge=0)
    empty_reason: str | None = None
    empty_message: str | None = None