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