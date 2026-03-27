"""Parking session endpoints, driver token issuance, and attendant check-in."""

from datetime import UTC, datetime, timedelta
from pathlib import Path
from secrets import token_urlsafe
from typing import Annotated, Any

from fastapi import APIRouter, Depends, File, Form, Request, UploadFile
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ...api.dependencies import get_current_user
from ...core.db.database import async_get_db
from ...core.exceptions.http_exceptions import BadRequestException, ForbiddenException, NotFoundException
from ...core.security import ALGORITHM, SECRET_KEY
from ...models.parking import ParkingLot
from ...models.enums import SessionStatus, UserRole, VehicleType
from ...models.sessions import ParkingSession
from ...models.users import Attendant, Driver
from ...models.vehicles import Vehicle
from ...schemas.session import AttendantCheckInCreate, AttendantCheckInRead, DriverCheckInTokenCreate, DriverCheckInTokenRead
from ...schemas.vehicle import VehicleRead

router = APIRouter(tags=["sessions"])
DRIVER_CHECK_IN_TOKEN_TTL = timedelta(minutes=5)
WALK_IN_IMAGE_DIR = Path(__file__).resolve().parents[2] / "uploads" / "walk_in_check_in"


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


async def _get_attendant_for_user(db: AsyncSession, current_user: dict[str, Any]) -> Attendant:
    if current_user.get("role") != UserRole.ATTENDANT.value:
        raise ForbiddenException("Only attendant accounts can process gate check-ins")

    attendant_result = await db.execute(select(Attendant).where(Attendant.user_id == current_user["id"]).limit(1))
    attendant = attendant_result.scalar_one_or_none()
    if attendant is None:
        raise ForbiddenException("Attendant profile not found for current account")
    return attendant


async def _get_attendant_lot(db: AsyncSession, attendant: Attendant) -> ParkingLot:
    parking_lot_result = await db.execute(select(ParkingLot).where(ParkingLot.id == attendant.parking_lot_id).limit(1))
    parking_lot = parking_lot_result.scalar_one_or_none()
    if parking_lot is None:
        raise NotFoundException("Assigned parking lot not found")
    return parking_lot


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


def _decode_driver_check_in_token(token: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(token, SECRET_KEY.get_secret_value(), algorithms=[ALGORITHM])
    except JWTError as exc:
        raise BadRequestException("Invalid QR code. Please try again.") from exc

    if payload.get("purpose") != "driver_check_in":
        raise BadRequestException("Invalid QR code. Please try again.")

    driver_id = payload.get("driver_id")
    vehicle_id = payload.get("vehicle_id")
    if not isinstance(driver_id, int) or not isinstance(vehicle_id, int):
        raise BadRequestException("Invalid QR code. Please try again.")

    return payload


def _normalize_walk_in_vehicle_type(vehicle_type: str) -> str:
    normalized = vehicle_type.strip().upper()
    allowed = {member.value for member in VehicleType}
    if normalized not in allowed:
        raise BadRequestException("Unsupported vehicle type for walk-in check-in")
    return normalized


def _build_walk_in_license_plate() -> str:
    return f"WALK-IN-{token_urlsafe(4).replace('-', '').replace('_', '').upper()}"


async def _store_walk_in_image(upload: UploadFile) -> str:
    content_type = upload.content_type or ""
    if not content_type.startswith("image/"):
        raise BadRequestException("Walk-in photo upload must be an image")

    payload = await upload.read()
    if not payload:
        raise BadRequestException("Walk-in plate photo is required")

    suffix = Path(upload.filename or "walk-in.jpg").suffix or ".jpg"
    WALK_IN_IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    stored_name = f"{datetime.now(UTC).strftime('%Y%m%d%H%M%S')}-{token_urlsafe(6)}{suffix}"
    stored_path = WALK_IN_IMAGE_DIR / stored_name
    stored_path.write_bytes(payload)
    return stored_path.relative_to(Path(__file__).resolve().parents[2]).as_posix()


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


@router.post("/sessions/attendant-check-in", response_model=AttendantCheckInRead, status_code=201)
async def attendant_check_in_with_driver_qr(
    request: Request,
    payload: AttendantCheckInCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> AttendantCheckInRead:
    attendant = await _get_attendant_for_user(db, current_user)
    parking_lot = await _get_attendant_lot(db, attendant)
    token_payload = _decode_driver_check_in_token(payload.token)

    vehicle_result = await db.execute(select(Vehicle).where(Vehicle.id == token_payload["vehicle_id"]).limit(1))
    vehicle = vehicle_result.scalar_one_or_none()
    if vehicle is None or vehicle.driver_id != token_payload["driver_id"]:
        raise BadRequestException("Invalid QR code. Please try again.")

    active_session_result = await db.execute(
        select(ParkingSession)
        .where(
            ParkingSession.driver_id == token_payload["driver_id"],
            ParkingSession.status == SessionStatus.CHECKED_IN.value,
        )
        .limit(1)
    )
    active_session = active_session_result.scalar_one_or_none()
    if active_session is not None:
        if active_session.parking_lot_id == parking_lot.id:
            raise BadRequestException("Driver already has an active session at this lot")

        other_lot_result = await db.execute(
            select(ParkingLot).where(ParkingLot.id == active_session.parking_lot_id).limit(1)
        )
        other_lot = other_lot_result.scalar_one_or_none()
        other_lot_name = other_lot.name if other_lot is not None else "another lot"
        raise BadRequestException(f"Driver has an active session at {other_lot_name}")

    if parking_lot.current_available <= 0:
        raise BadRequestException("Lot is full - no available spots.")

    created_session = ParkingSession(
        parking_lot_id=parking_lot.id,
        license_plate=vehicle.license_plate,
        driver_id=token_payload["driver_id"],
        attendant_checkin_id=attendant.id,
        vehicle_type=vehicle.vehicle_type,
    )
    parking_lot.current_available -= 1
    db.add(created_session)
    await db.commit()
    await db.refresh(created_session)

    return AttendantCheckInRead(
        session_id=created_session.id,
        parking_lot_id=parking_lot.id,
        current_available=parking_lot.current_available,
        license_plate=created_session.license_plate,
        vehicle_type=created_session.vehicle_type,
        checked_in_at=created_session.checkin_time,
    )


@router.post("/sessions/attendant-walk-in-check-in", response_model=AttendantCheckInRead, status_code=201)
async def attendant_check_in_walk_in_vehicle(
    request: Request,
    vehicle_type: Annotated[str, Form(...)],
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
    plate_image: Annotated[UploadFile | None, File(...)] = None,
    overview_image: Annotated[UploadFile | None, File()] = None,
) -> AttendantCheckInRead:
    attendant = await _get_attendant_for_user(db, current_user)
    parking_lot = await _get_attendant_lot(db, attendant)

    if plate_image is None:
      raise BadRequestException("A plate photo is required for walk-in check-in")

    normalized_vehicle_type = _normalize_walk_in_vehicle_type(vehicle_type)
    plate_image_path = await _store_walk_in_image(plate_image)
    if overview_image is not None:
        content_type = overview_image.content_type or ""
        if not content_type.startswith("image/"):
            raise BadRequestException("Walk-in photo upload must be an image")

    if parking_lot.current_available <= 0:
        raise BadRequestException("Lot is full - no available spots.")

    created_session = ParkingSession(
        parking_lot_id=parking_lot.id,
        license_plate=_build_walk_in_license_plate(),
        attendant_checkin_id=attendant.id,
        vehicle_type=normalized_vehicle_type,
        checkin_image=plate_image_path,
    )
    parking_lot.current_available -= 1
    db.add(created_session)
    await db.commit()
    await db.refresh(created_session)

    return AttendantCheckInRead(
        session_id=created_session.id,
        parking_lot_id=parking_lot.id,
        current_available=parking_lot.current_available,
        license_plate=created_session.license_plate,
        vehicle_type=created_session.vehicle_type,
        checked_in_at=created_session.checkin_time,
    )
