from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, field_validator

from ..models.enums import CapabilityApplicationStatus


class LotOwnerApplicationCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    full_name: Annotated[str, Field(min_length=2, max_length=100)]
    phone_number: Annotated[str, Field(min_length=8, max_length=20)]
    business_license: Annotated[str, Field(min_length=4, max_length=100)]
    document_reference: Annotated[str, Field(min_length=4, max_length=255)]
    notes: Annotated[str | None, Field(max_length=500, default=None)]

    @field_validator(
        "full_name",
        "phone_number",
        "business_license",
        "document_reference",
        mode="before",
    )
    @classmethod
    def strip_required_text(cls, value: str) -> str:
        if not isinstance(value, str):
            raise ValueError("Field must be a string")
        stripped = value.strip()
        if not stripped:
            raise ValueError("Field is required")
        return stripped

    @field_validator("notes", mode="before")
    @classmethod
    def strip_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None


class LotOwnerApplicationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    full_name: str
    phone_number: str
    business_license: str
    document_reference: str
    notes: str | None = None
    status: str
    rejection_reason: str | None = None
    reviewed_by_user_id: int | None = None
    reviewed_at: datetime | None = None
    created_at: datetime
    updated_at: datetime | None = None


class LotOwnerApplicationReview(BaseModel):
    model_config = ConfigDict(extra="forbid")

    decision: CapabilityApplicationStatus
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
    def validate_decision(cls, value: CapabilityApplicationStatus) -> CapabilityApplicationStatus:
        if value not in {
            CapabilityApplicationStatus.APPROVED,
            CapabilityApplicationStatus.REJECTED,
        }:
            raise ValueError("Decision must be APPROVED or REJECTED")
        return value