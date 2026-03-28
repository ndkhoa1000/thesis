"""Parking session endpoints, driver token issuance, and attendant gate flows."""

from datetime import UTC, datetime, timedelta
from math import ceil
from pathlib import Path
from secrets import token_urlsafe
from typing import Annotated, Any

from fastapi import APIRouter, Depends, File, Form, Request, UploadFile
from jose import JWTError, jwt
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from ...api.dependencies import get_current_user
from ...core.db.database import async_get_db
from ...core.exceptions.http_exceptions import BadRequestException, ForbiddenException, NotFoundException
from ...core.security import ALGORITHM, SECRET_KEY
from ...models.financials import Payment
from ...models.parking import ParkingLot, Pricing
from ...models.enums import (
    PayableType,
    PaymentMethod,
    PaymentStatus,
    PricingMode,
    SessionStatus,
    UserRole,
    VehicleType,
    VehicleTypeAll,
)
from ...models.sessions import ParkingSession
from ...models.users import Attendant, Driver
from ...models.vehicles import Vehicle
from ...schemas.session import (
    AttendantCheckInCreate,
    AttendantCheckInRead,
    AttendantCheckOutFinalizeCreate,
    AttendantCheckOutFinalizeRead,
    AttendantCheckOutUndoCreate,
    AttendantCheckOutUndoRead,
    AttendantCheckOutPreviewCreate,
    AttendantCheckOutPreviewRead,
    DriverActiveSessionRead,
    DriverCheckInTokenCreate,
    DriverCheckInTokenRead,
    DriverCheckOutTokenRead,
)
from ...schemas.vehicle import VehicleRead

router = APIRouter(tags=["sessions"])
DRIVER_CHECK_IN_TOKEN_TTL = timedelta(minutes=5)
DRIVER_CHECK_OUT_TOKEN_TTL = timedelta(minutes=5)
CHECK_OUT_UNDO_WINDOW = timedelta(seconds=3)
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


def _build_driver_check_out_token(session: ParkingSession, parking_lot: ParkingLot, expires_at: datetime) -> str:
    issued_at = _utcnow()
    payload = {
        "purpose": "driver_check_out",
        "session_id": session.id,
        "driver_id": session.driver_id,
        "parking_lot_id": parking_lot.id,
        "license_plate": session.license_plate,
        "vehicle_type": session.vehicle_type,
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


def _decode_driver_check_out_token(token: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(token, SECRET_KEY.get_secret_value(), algorithms=[ALGORITHM])
    except JWTError as exc:
        raise BadRequestException("Invalid QR code. Please try again.") from exc

    if payload.get("purpose") != "driver_check_out":
        raise BadRequestException("Invalid QR code. Please try again.")

    session_id = payload.get("session_id")
    driver_id = payload.get("driver_id")
    parking_lot_id = payload.get("parking_lot_id")
    if not isinstance(session_id, int) or not isinstance(driver_id, int) or not isinstance(parking_lot_id, int):
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


async def _get_active_session_for_driver(db: AsyncSession, driver_id: int) -> ParkingSession | None:
    active_session_result = await db.execute(
        select(ParkingSession)
        .where(
            ParkingSession.driver_id == driver_id,
            ParkingSession.status == SessionStatus.CHECKED_IN.value,
        )
        .order_by(ParkingSession.id.desc())
        .limit(2)
    )
    active_sessions = list(active_session_result.scalars().all())
    if len(active_sessions) > 1:
        raise BadRequestException("Multiple active parking sessions found for this driver")
    return active_sessions[0] if active_sessions else None


async def _get_latest_pricing(
    db: AsyncSession,
    parking_lot_id: int,
    vehicle_type: str,
) -> Pricing | None:
    today = _utcnow().date()
    pricing_result = await db.execute(
        select(Pricing)
        .where(
            Pricing.parking_lot_id == parking_lot_id,
            Pricing.vehicle_type.in_([vehicle_type, VehicleTypeAll.ALL.value]),
            or_(Pricing.effective_from.is_(None), Pricing.effective_from <= today),
            or_(Pricing.effective_to.is_(None), Pricing.effective_to >= today),
        )
        .order_by(Pricing.id.desc())
    )
    pricing_rows = list(pricing_result.scalars().all())
    for pricing in pricing_rows:
        if pricing.vehicle_type == vehicle_type:
            return pricing
    for pricing in pricing_rows:
        if pricing.vehicle_type == VehicleTypeAll.ALL.value:
            return pricing
    return None


async def _get_completed_payments_for_session(db: AsyncSession, session_id: int) -> list[Payment]:
    payment_result = await db.execute(
        select(Payment)
        .where(
            Payment.payable_type == PayableType.SESSION.value,
            Payment.payable_id == session_id,
            Payment.payment_status == PaymentStatus.COMPLETED.value,
        )
        .order_by(Payment.id.desc())
    )
    return list(payment_result.scalars().all())


def _calculate_estimated_cost(session: ParkingSession, pricing: Pricing | None) -> float:
    if pricing is None:
        return 0.0

    amount = float(pricing.price_amount)
    if pricing.pricing_mode == PricingMode.SESSION.value:
        return amount

    elapsed_seconds = max((_utcnow() - session.checkin_time).total_seconds(), 0)
    elapsed_hours = max(1, ceil(elapsed_seconds / 3600))
    if pricing.pricing_mode == PricingMode.HOURLY.value:
        return float(elapsed_hours * amount)

    return amount


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


@router.get("/sessions/driver-active-session", response_model=DriverActiveSessionRead, status_code=200)
async def get_driver_active_session(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> DriverActiveSessionRead:
    driver = await _get_driver_for_user(db, current_user)
    active_session = await _get_active_session_for_driver(db, driver.id)
    if active_session is None:
        raise NotFoundException("No active parking session found")

    parking_lot_result = await db.execute(
        select(ParkingLot).where(ParkingLot.id == active_session.parking_lot_id).limit(1)
    )
    parking_lot = parking_lot_result.scalar_one_or_none()
    if parking_lot is None:
        raise NotFoundException("Assigned parking lot not found")

    pricing = await _get_latest_pricing(db, parking_lot.id, active_session.vehicle_type)
    elapsed_minutes = max(int((_utcnow() - active_session.checkin_time).total_seconds() // 60), 0)

    return DriverActiveSessionRead(
        session_id=active_session.id,
        parking_lot_id=parking_lot.id,
        parking_lot_name=parking_lot.name,
        license_plate=active_session.license_plate,
        vehicle_type=active_session.vehicle_type,
        checked_in_at=active_session.checkin_time,
        elapsed_minutes=elapsed_minutes,
        estimated_cost=_calculate_estimated_cost(active_session, pricing),
        pricing_mode=pricing.pricing_mode if pricing is not None else None,
    )


@router.post("/sessions/driver-check-out-token", response_model=DriverCheckOutTokenRead, status_code=201)
async def create_driver_check_out_token(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> DriverCheckOutTokenRead:
    driver = await _get_driver_for_user(db, current_user)
    active_session = await _get_active_session_for_driver(db, driver.id)
    if active_session is None:
        raise NotFoundException("No active parking session found")

    parking_lot_result = await db.execute(
        select(ParkingLot).where(ParkingLot.id == active_session.parking_lot_id).limit(1)
    )
    parking_lot = parking_lot_result.scalar_one_or_none()
    if parking_lot is None:
        raise NotFoundException("Assigned parking lot not found")

    expires_at = _utcnow() + DRIVER_CHECK_OUT_TOKEN_TTL
    token = _build_driver_check_out_token(active_session, parking_lot, expires_at)
    return DriverCheckOutTokenRead(
        token=token,
        expires_at=expires_at,
        expires_in_seconds=int(DRIVER_CHECK_OUT_TOKEN_TTL.total_seconds()),
        session_id=active_session.id,
        license_plate=active_session.license_plate,
    )


@router.post("/sessions/attendant-check-out-preview", response_model=AttendantCheckOutPreviewRead, status_code=200)
async def attendant_check_out_preview(
    request: Request,
    payload: AttendantCheckOutPreviewCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> AttendantCheckOutPreviewRead:
    attendant = await _get_attendant_for_user(db, current_user)
    parking_lot = await _get_attendant_lot(db, attendant)
    token_payload = _decode_driver_check_out_token(payload.token)

    active_session = await _get_active_session_for_driver(db, token_payload["driver_id"])
    if active_session is None:
        session_result = await db.execute(
            select(ParkingSession).where(ParkingSession.id == token_payload["session_id"]).limit(1)
        )
        session = session_result.scalar_one_or_none()
        if session is not None and session.status == SessionStatus.CHECKED_OUT.value:
            raise BadRequestException("Session already checked out.")
        raise NotFoundException("No active parking session found")

    if active_session.id != token_payload["session_id"] or active_session.driver_id != token_payload["driver_id"]:
        raise BadRequestException("Invalid QR code. Please try again.")

    if active_session.parking_lot_id != token_payload["parking_lot_id"]:
        raise BadRequestException("Invalid QR code. Please try again.")

    if active_session.parking_lot_id != parking_lot.id:
        raise BadRequestException("This session belongs to a different parking lot")

    pricing = await _get_latest_pricing(db, parking_lot.id, active_session.vehicle_type)
    if pricing is None:
        raise BadRequestException("No active pricing found for this parking session.")

    elapsed_minutes = max(int((_utcnow() - active_session.checkin_time).total_seconds() // 60), 0)
    final_fee = _calculate_estimated_cost(active_session, pricing)

    return AttendantCheckOutPreviewRead(
        session_id=active_session.id,
        parking_lot_id=parking_lot.id,
        parking_lot_name=parking_lot.name,
        license_plate=active_session.license_plate,
        vehicle_type=active_session.vehicle_type,
        checked_in_at=active_session.checkin_time,
        elapsed_minutes=elapsed_minutes,
        final_fee=final_fee,
        pricing_mode=pricing.pricing_mode,
    )


@router.post("/sessions/attendant-check-out-finalize", response_model=AttendantCheckOutFinalizeRead, status_code=200)
async def attendant_check_out_finalize(
    request: Request,
    payload: AttendantCheckOutFinalizeCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> AttendantCheckOutFinalizeRead:
    attendant = await _get_attendant_for_user(db, current_user)
    parking_lot = await _get_attendant_lot(db, attendant)

    session_result = await db.execute(
        select(ParkingSession).where(ParkingSession.id == payload.session_id).limit(1)
    )
    session = session_result.scalar_one_or_none()
    if session is None:
        raise NotFoundException("Parking session not found")

    if session.parking_lot_id != parking_lot.id:
        raise BadRequestException("This session belongs to a different parking lot")

    if session.status != SessionStatus.CHECKED_IN.value:
        raise BadRequestException("Session already checked out.")

    if session.driver_id is None:
        raise BadRequestException("This parking session cannot be finalized through QR checkout yet.")

    existing_payments = await _get_completed_payments_for_session(db, session.id)
    if existing_payments:
        raise BadRequestException("This parking session has already been finalized.")

    pricing = await _get_latest_pricing(db, parking_lot.id, session.vehicle_type)
    if pricing is None:
        raise BadRequestException("No active pricing found for this parking session.")

    final_fee = _calculate_estimated_cost(session, pricing)
    if payload.quoted_final_fee is not None and abs(payload.quoted_final_fee - final_fee) > 0.009:
        raise BadRequestException("Checkout preview is stale. Please rescan and confirm again.")

    checked_out_at = _utcnow()
    previous_status = session.status
    previous_checkout_time = session.checkout_time
    previous_attendant_checkout_id = session.attendant_checkout_id
    previous_current_available = parking_lot.current_available

    payment = Payment(
        payable_id=session.id,
        payable_type=PayableType.SESSION.value,
        driver_id=session.driver_id,
        amount=final_fee,
        final_amount=final_fee,
        payment_method=payload.payment_method,
        payment_status=PaymentStatus.COMPLETED.value,
        processed_by=current_user["id"],
    )

    session.attendant_checkout_id = attendant.id
    session.checkout_time = checked_out_at
    session.status = SessionStatus.CHECKED_OUT.value
    parking_lot.current_available += 1
    db.add(payment)

    try:
        await db.commit()
    except Exception:
        await db.rollback()
        session.status = previous_status
        session.checkout_time = previous_checkout_time
        session.attendant_checkout_id = previous_attendant_checkout_id
        parking_lot.current_available = previous_current_available
        raise

    return AttendantCheckOutFinalizeRead(
        session_id=session.id,
        parking_lot_id=parking_lot.id,
        parking_lot_name=parking_lot.name,
        license_plate=session.license_plate,
        vehicle_type=session.vehicle_type,
        final_fee=final_fee,
        payment_method=payload.payment_method,
        checked_out_at=checked_out_at,
        current_available=parking_lot.current_available,
    )


@router.post("/sessions/attendant-check-out-undo", response_model=AttendantCheckOutUndoRead, status_code=200)
async def attendant_check_out_undo(
    request: Request,
    payload: AttendantCheckOutUndoCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> AttendantCheckOutUndoRead:
    attendant = await _get_attendant_for_user(db, current_user)
    parking_lot = await _get_attendant_lot(db, attendant)

    session_result = await db.execute(
        select(ParkingSession).where(ParkingSession.id == payload.session_id).limit(1)
    )
    session = session_result.scalar_one_or_none()
    if session is None:
        raise NotFoundException("Parking session not found")

    if session.parking_lot_id != parking_lot.id:
        raise BadRequestException("This session belongs to a different parking lot")

    if (
        session.status != SessionStatus.CHECKED_OUT.value
        or session.attendant_checkout_id != attendant.id
        or session.checkout_time is None
    ):
        raise BadRequestException("This parking session is not eligible for undo.")

    if _utcnow() - session.checkout_time > CHECK_OUT_UNDO_WINDOW:
        raise BadRequestException("Undo window has expired for this parking session.")

    completed_payments = await _get_completed_payments_for_session(db, session.id)
    if len(completed_payments) != 1:
        raise BadRequestException("This parking session is not eligible for undo.")

    payment = completed_payments[0]
    previous_status = session.status
    previous_checkout_time = session.checkout_time
    previous_attendant_checkout_id = session.attendant_checkout_id
    previous_current_available = parking_lot.current_available
    previous_payment_status = payment.payment_status
    previous_payment_note = payment.note

    session.status = SessionStatus.CHECKED_IN.value
    session.checkout_time = None
    session.attendant_checkout_id = None
    parking_lot.current_available = max(parking_lot.current_available - 1, 0)
    payment.payment_status = PaymentStatus.FAILED.value
    payment.note = "Settlement undone within recovery window."

    try:
        await db.commit()
    except Exception:
        await db.rollback()
        session.status = previous_status
        session.checkout_time = previous_checkout_time
        session.attendant_checkout_id = previous_attendant_checkout_id
        parking_lot.current_available = previous_current_available
        payment.payment_status = previous_payment_status
        payment.note = previous_payment_note
        raise

    return AttendantCheckOutUndoRead(
        session_id=session.id,
        parking_lot_id=parking_lot.id,
        current_available=parking_lot.current_available,
        status=session.status,
    )


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

    active_session = await _get_active_session_for_driver(db, driver.id)
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
