"""Parking session endpoints and driver check-in token issuance."""

from datetime import UTC, datetime, timedelta
from secrets import token_urlsafe
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request
from jose import jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ...api.dependencies import get_current_user
from ...core.db.database import async_get_db
from ...core.exceptions.http_exceptions import BadRequestException, ForbiddenException, NotFoundException
from ...core.security import ALGORITHM, SECRET_KEY
from ...models.enums import SessionStatus, UserRole
from ...models.sessions import ParkingSession
from ...models.users import Driver
from ...models.vehicles import Vehicle
from ...schemas.session import DriverCheckInTokenCreate, DriverCheckInTokenRead
from ...schemas.vehicle import VehicleRead

router = APIRouter(tags=["sessions"])
DRIVER_CHECK_IN_TOKEN_TTL = timedelta(minutes=5)


def _utcnow() -> datetime:
    return datetime.now(UTC)


async def _get_driver_for_user(db: AsyncSession, current_user: dict[str, Any]) -> Driver:
    is_public_capable = current_user.get("role") in {
        UserRole.DRIVER.value,
        UserRole.LOT_OWNER.value,
        UserRole.MANAGER.value,
    }
    if not is_public_capable:
        raise ForbiddenException("Only driver-capable public accounts can generate check-in QR codes")

    driver_result = await db.execute(select(Driver).where(Driver.user_id == current_user["id"]).limit(1))
    driver = driver_result.scalar_one_or_none()
    if driver is None:
        raise ForbiddenException("Driver profile not found for current account")
    return driver


def _build_driver_check_in_token(driver: Driver, vehicle: Vehicle, expires_at: datetime) -> str:
    issued_at = _utcnow()
    payload = {
        "purpose": "driver_check_in",
        "driver_id": driver.id,
        "vehicle_id": vehicle.id,
        "license_plate": vehicle.license_plate,
        "vehicle_type": vehicle.vehicle_type,
        "jti": token_urlsafe(18),
        "iat": issued_at.replace(tzinfo=None),
        "exp": expires_at.replace(tzinfo=None),
    }
    return jwt.encode(payload, SECRET_KEY.get_secret_value(), algorithm=ALGORITHM)


@router.get("/sessions", status_code=200)
async def list_sessions(
    request: Request,
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> dict[str, str]:
    # Scaffold: full implementation in feature epics
    return {"message": "sessions endpoint scaffold"}


@router.post("/sessions/driver-check-in-token", response_model=DriverCheckInTokenRead, status_code=201)
async def create_driver_check_in_token(
    request: Request,
    payload: DriverCheckInTokenCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> DriverCheckInTokenRead:
    driver = await _get_driver_for_user(db, current_user)

    vehicle_result = await db.execute(select(Vehicle).where(Vehicle.id == payload.vehicle_id).limit(1))
    vehicle = vehicle_result.scalar_one_or_none()
    if vehicle is None:
        raise NotFoundException("Vehicle not found")
    if vehicle.driver_id != driver.id:
        raise ForbiddenException("Vehicle does not belong to current driver")

    active_session_result = await db.execute(
        select(ParkingSession)
        .where(
            ParkingSession.driver_id == driver.id,
            ParkingSession.status == SessionStatus.CHECKED_IN.value,
        )
        .limit(1)
    )
    active_session = active_session_result.scalar_one_or_none()
    if active_session is not None:
        raise BadRequestException("Current parking session is already in progress")

    expires_at = _utcnow() + DRIVER_CHECK_IN_TOKEN_TTL
    token = _build_driver_check_in_token(driver, vehicle, expires_at)
    return DriverCheckInTokenRead(
        token=token,
        expires_at=expires_at,
        expires_in_seconds=int(DRIVER_CHECK_IN_TOKEN_TTL.total_seconds()),
        vehicle=VehicleRead.model_validate(vehicle),
    )
