from datetime import date, datetime
from typing import Annotated

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class LeaseContractCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    manager_user_id: int
    monthly_fee: Annotated[float, Field(ge=0, le=1000000000)] = 0
    revenue_share_percentage: Annotated[float, Field(gt=0, le=100)]
    term_months: Annotated[int, Field(ge=1, le=120)]
    additional_terms: Annotated[str | None, Field(max_length=4000, default=None)] = None

    @field_validator("additional_terms", mode="before")
    @classmethod
    def strip_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None


class LeaseContractRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    contract_id: int
    lease_id: int
    parking_lot_id: int
    parking_lot_name: str
    manager_id: int
    manager_user_id: int
    operator_name: str
    operator_email: EmailStr
    owner_name: str
    owner_email: EmailStr
    lease_status: str
    contract_status: str
    monthly_fee: float
    revenue_share_percentage: float
    term_months: int
    contract_number: str
    content: str | None = None
    generated_at: datetime
    start_date: date | None = None
    end_date: date | None = None
