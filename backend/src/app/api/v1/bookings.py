"""Driver booking lifecycle endpoints."""

from datetime import UTC, datetime, timedelta
from secrets import token_urlsafe
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Query, Request
from jose import JWTError, jwt
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from ...api.dependencies import get_current_user
from ...core.db.database import async_get_db
from ...core.exceptions.http_exceptions import BadRequestException, ForbiddenException, NotFoundException
from ...core.lot_availability import publish_lot_availability_update
from ...core.security import ALGORITHM, SECRET_KEY
from ...models.enums import (
    BookingStatus,
    PayableType,
    PaymentMethod,
    PaymentStatus,
    PricingMode,
    UserRole,
    VehicleTypeAll,
)
from ...models.financials import Payment
from ...models.parking import ParkingLot, Pricing
from ...models.sessions import Booking
from ...models.users import Driver
from ...models.vehicles import Vehicle
from ...schemas.booking import BookingPaymentRead, DriverBookingCancelRead, DriverBookingCreate, DriverBookingRead
from ...schemas.vehicle import VehicleRead
from ...services.booking_service import get_latest_lot_capacity_config, mark_booking_expired

router = APIRouter(tags=["bookings"])
BOOKING_HOLD_TTL = timedelta(minutes=30)


def _utcnow() -> datetime:
    return datetime.now(UTC)


async def _get_driver_for_user(db: AsyncSession, current_user: dict[str, Any]) -> Driver:
    is_public_capable = current_user.get("role") in {
        UserRole.DRIVER.value,
        UserRole.LOT_OWNER.value,
        UserRole.MANAGER.value,
    }
    if not is_public_capable:
        raise ForbiddenException("Only driver-capable public accounts can manage bookings")

    driver_result = await db.execute(select(Driver).where(Driver.user_id == current_user["id"]).limit(1))
    driver = driver_result.scalar_one_or_none()
    if driver is None:
        raise ForbiddenException("Driver profile not found for current account")
    return driver


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


def _calculate_booking_fee(pricing: Pricing) -> float:
    amount = float(pricing.price_amount)
    if pricing.pricing_mode == PricingMode.HOURLY.value:
        return amount
    return amount


def _build_booking_token(
    booking: Booking,
    parking_lot: ParkingLot,
    vehicle: Vehicle,
    expires_at: datetime,
) -> str:
    issued_at = _utcnow()
    payload = {
        "purpose": "booking_check_in",
        "booking_id": booking.id,
        "driver_id": booking.driver_id,
        "parking_lot_id": parking_lot.id,
        "vehicle_id": vehicle.id,
        "license_plate": vehicle.license_plate,
        "vehicle_type": vehicle.vehicle_type,
        "jti": token_urlsafe(18),
        "iat": issued_at.replace(tzinfo=None),
        "exp": expires_at.replace(tzinfo=None),
    }
    return jwt.encode(payload, SECRET_KEY.get_secret_value(), algorithm=ALGORITHM)


def decode_booking_token(token: str, *, allow_expired: bool = False) -> dict[str, Any]:
    try:
        payload = jwt.decode(
            token,
            SECRET_KEY.get_secret_value(),
            algorithms=[ALGORITHM],
            options={"verify_exp": not allow_expired},
        )
    except JWTError as exc:
        raise BadRequestException("Invalid booking confirmation. Please refresh and try again.") from exc

    if payload.get("purpose") != "booking_check_in":
        raise BadRequestException("Invalid booking confirmation. Please refresh and try again.")

    booking_id = payload.get("booking_id")
    driver_id = payload.get("driver_id")
    parking_lot_id = payload.get("parking_lot_id")
    vehicle_id = payload.get("vehicle_id")
    if not all(isinstance(value, int) for value in (booking_id, driver_id, parking_lot_id, vehicle_id)):
        raise BadRequestException("Invalid booking confirmation. Please refresh and try again.")

    return payload


async def _get_booking_payment(db: AsyncSession, booking_id: int) -> Payment | None:
    payment_result = await db.execute(
        select(Payment)
        .where(
            Payment.payable_type == PayableType.BOOKING.value,
            Payment.payable_id == booking_id,
        )
        .order_by(Payment.id.desc())
        .limit(1)
    )
    return payment_result.scalar_one_or_none()


def _serialize_driver_booking(
    booking: Booking,
    parking_lot: ParkingLot,
    vehicle: Vehicle,
    payment: Payment,
) -> DriverBookingRead:
    expires_at = booking.expiration_time or booking.expected_arrival or booking.booking_time
    can_present_qr = booking.status == BookingStatus.CONFIRMED.value and expires_at > _utcnow()
    expires_in_seconds = max(int((expires_at - _utcnow()).total_seconds()), 0)
    return DriverBookingRead(
        booking_id=booking.id,
        parking_lot_id=parking_lot.id,
        parking_lot_name=parking_lot.name,
        status=booking.status,
        booking_time=booking.booking_time,
        expected_arrival=booking.expected_arrival,
        expiration_time=booking.expiration_time,
        expires_in_seconds=expires_in_seconds,
        current_available=max(int(parking_lot.current_available), 0),
        token=_build_booking_token(booking, parking_lot, vehicle, expires_at) if can_present_qr else "",
        vehicle=VehicleRead.model_validate(vehicle),
        payment=BookingPaymentRead(
            payment_id=payment.id,
            amount=float(payment.amount),
            final_amount=float(payment.final_amount),
            payment_method=payment.payment_method,
            payment_status=payment.payment_status,
        ),
    )


async def _commit_and_publish_if_changed(
    db: AsyncSession,
    parking_lot: ParkingLot,
    *,
    previous_current_available: int,
    source: str,
) -> None:
    try:
        await db.commit()
    except Exception:
        await db.rollback()
        raise

    publish_lot_availability_update(
        parking_lot,
        previous_current_available=previous_current_available,
        source=source,
    )


@router.get("/bookings/driver-active", response_model=DriverBookingRead, status_code=200)
async def get_driver_active_booking(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
    parking_lot_id: Annotated[int, Query(gt=0)],
) -> DriverBookingRead:
    driver = await _get_driver_for_user(db, current_user)
    booking_result = await db.execute(
        select(Booking, ParkingLot, Vehicle)
        .join(ParkingLot, ParkingLot.id == Booking.parking_lot_id)
        .join(Vehicle, Vehicle.id == Booking.vehicle_id)
        .where(
            Booking.driver_id == driver.id,
            Booking.parking_lot_id == parking_lot_id,
            Booking.status.in_([BookingStatus.CONFIRMED.value, BookingStatus.EXPIRED.value]),
        )
        .order_by(Booking.id.desc())
        .limit(1)
        .with_for_update()
    )
    row = booking_result.first()
    if row is None:
        raise NotFoundException("No active booking found")

    booking, parking_lot, vehicle = row
    if (
        booking.status == BookingStatus.CONFIRMED.value
        and booking.expiration_time is not None
        and booking.expiration_time <= _utcnow()
    ):
        previous_current_available = await mark_booking_expired(db, booking, parking_lot)
        await _commit_and_publish_if_changed(
            db,
            parking_lot,
            previous_current_available=previous_current_available,
            source="driver_booking_expired_on_read",
        )

    payment = await _get_booking_payment(db, booking.id)
    if payment is None:
        raise NotFoundException("Booking payment not found")

    return _serialize_driver_booking(booking, parking_lot, vehicle, payment)


@router.post("/bookings", response_model=DriverBookingRead, status_code=201)
async def create_driver_booking(
    request: Request,
    payload: DriverBookingCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> DriverBookingRead:
    driver = await _get_driver_for_user(db, current_user)
    parking_lot_result = await db.execute(
        select(ParkingLot).where(ParkingLot.id == payload.parking_lot_id).limit(1).with_for_update()
    )
    parking_lot = parking_lot_result.scalar_one_or_none()
    if parking_lot is None:
        raise NotFoundException("Parking lot not found")

    vehicle_result = await db.execute(select(Vehicle).where(Vehicle.id == payload.vehicle_id).limit(1))
    vehicle = vehicle_result.scalar_one_or_none()
    if vehicle is None:
        raise NotFoundException("Vehicle not found")
    if vehicle.driver_id != driver.id:
        raise ForbiddenException("Selected vehicle does not belong to the current driver")

    existing_booking_result = await db.execute(
        select(Booking)
        .where(
            Booking.driver_id == driver.id,
            Booking.parking_lot_id == payload.parking_lot_id,
            Booking.status == BookingStatus.CONFIRMED.value,
        )
        .order_by(Booking.id.desc())
        .limit(1)
        .with_for_update()
    )
    existing_booking = existing_booking_result.scalar_one_or_none()
    previous_current_available = parking_lot.current_available
    if existing_booking is not None:
        if existing_booking.expiration_time is not None and existing_booking.expiration_time <= _utcnow():
            previous_current_available = await mark_booking_expired(db, existing_booking, parking_lot)
        else:
            raise BadRequestException("Driver already has an active booking at this lot")

    if parking_lot.current_available <= 0:
        if existing_booking is not None and existing_booking.status == BookingStatus.EXPIRED.value:
            await _commit_and_publish_if_changed(
                db,
                parking_lot,
                previous_current_available=previous_current_available,
                source="driver_booking_expired_on_create",
            )
        raise BadRequestException("Lot is full - no available spots.")

    pricing = await _get_latest_pricing(db, parking_lot.id, vehicle.vehicle_type)
    if pricing is None:
        if existing_booking is not None and existing_booking.status == BookingStatus.EXPIRED.value:
            await _commit_and_publish_if_changed(
                db,
                parking_lot,
                previous_current_available=previous_current_available,
                source="driver_booking_expired_on_create",
            )
        raise BadRequestException("No active pricing found for this parking lot.")

    expires_at = _utcnow() + BOOKING_HOLD_TTL
    booking = Booking(
        driver_id=driver.id,
        parking_lot_id=parking_lot.id,
        vehicle_id=vehicle.id,
        expected_arrival=expires_at,
        expiration_time=expires_at,
        status=BookingStatus.CONFIRMED.value,
    )
    parking_lot.current_available -= 1
    db.add(booking)
    await db.flush()

    booking_fee = _calculate_booking_fee(pricing)
    payment = Payment(
        payable_id=booking.id,
        payable_type=PayableType.BOOKING.value,
        driver_id=driver.id,
        amount=booking_fee,
        final_amount=booking_fee,
        payment_method=PaymentMethod.ONLINE.value,
        payment_status=PaymentStatus.COMPLETED.value,
        processed_by=current_user["id"],
        note="Booking reservation fee",
    )
    db.add(payment)

    await _commit_and_publish_if_changed(
        db,
        parking_lot,
        previous_current_available=previous_current_available,
        source="driver_booking_create",
    )
    await db.refresh(booking)
    await db.refresh(payment)
    return _serialize_driver_booking(booking, parking_lot, vehicle, payment)


@router.post("/bookings/{booking_id}/cancel", response_model=DriverBookingCancelRead, status_code=200)
async def cancel_driver_booking(
    request: Request,
    booking_id: int,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> DriverBookingCancelRead:
    driver = await _get_driver_for_user(db, current_user)
    booking_result = await db.execute(
        select(Booking).where(Booking.id == booking_id, Booking.driver_id == driver.id).limit(1).with_for_update()
    )
    booking = booking_result.scalar_one_or_none()
    if booking is None:
        raise NotFoundException("Booking not found")

    parking_lot_result = await db.execute(
        select(ParkingLot).where(ParkingLot.id == booking.parking_lot_id).limit(1).with_for_update()
    )
    parking_lot = parking_lot_result.scalar_one_or_none()
    if parking_lot is None:
        raise NotFoundException("Parking lot not found")

    if booking.status == BookingStatus.CANCELLED.value:
        raise BadRequestException("Booking already cancelled")
    if booking.status == BookingStatus.EXPIRED.value:
        raise BadRequestException("Booking already expired")

    if booking.status != BookingStatus.CONFIRMED.value:
        raise BadRequestException("Only confirmed bookings can be cancelled")

    now = _utcnow()
    previous_current_available = parking_lot.current_available
    if booking.expiration_time is not None and booking.expiration_time <= now:
        previous_current_available = await mark_booking_expired(db, booking, parking_lot)
        await _commit_and_publish_if_changed(
            db,
            parking_lot,
            previous_current_available=previous_current_available,
            source="driver_booking_expired_on_cancel",
        )
        raise BadRequestException("Booking already expired")

    latest_config = await get_latest_lot_capacity_config(db, parking_lot.id)
    booking.status = BookingStatus.CANCELLED.value
    if latest_config is None:
        parking_lot.current_available += 1
    else:
        parking_lot.current_available = min(
            parking_lot.current_available + 1,
            max(latest_config.total_capacity, 0),
        )

    await _commit_and_publish_if_changed(
        db,
        parking_lot,
        previous_current_available=previous_current_available,
        source="driver_booking_cancel",
    )
    return DriverBookingCancelRead(
        booking_id=booking.id,
        status=booking.status,
        current_available=max(int(parking_lot.current_available), 0),
    )
