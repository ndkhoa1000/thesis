from pydantic import BaseModel, ConfigDict, Field

from ..models.enums import VehicleType


class VehicleCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    license_plate: str = Field(min_length=1, max_length=15, examples=["59A-12345"])
    vehicle_type: VehicleType = VehicleType.MOTORBIKE


class VehicleRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    license_plate: str
    vehicle_type: str
