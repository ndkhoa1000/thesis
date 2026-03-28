from datetime import UTC, date, datetime

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.lot_availability import publish_lot_availability_update
from ..models.enums import BookingStatus, VehicleTypeAll
from ..models.parking import ParkingLot, ParkingLotConfig
from ..models.sessions import Booking


def utcnow() -> datetime:
    return datetime.now(UTC)


async def get_latest_lot_capacity_config(
    db: AsyncSession,
    parking_lot_id: int,
) -> ParkingLotConfig | None:
    config_result = await db.execute(
        select(ParkingLotConfig)
        .where(
            ParkingLotConfig.parking_lot_id == parking_lot_id,
            ParkingLotConfig.vehicle_type == VehicleTypeAll.ALL.value,
            or_(ParkingLotConfig.effective_from.is_(None), ParkingLotConfig.effective_from <= date.today()),
            or_(ParkingLotConfig.effective_to.is_(None), ParkingLotConfig.effective_to >= date.today()),
        )
        .order_by(ParkingLotConfig.created_at.desc(), ParkingLotConfig.id.desc())
        .limit(1)
    )
    return config_result.scalar_one_or_none()


async def restore_booking_capacity(
    db: AsyncSession,
    parking_lot: ParkingLot,
) -> None:
    latest_config = await get_latest_lot_capacity_config(db, parking_lot.id)
    if latest_config is None:
        parking_lot.current_available += 1
        return

    parking_lot.current_available = min(
        parking_lot.current_available + 1,
        max(latest_config.total_capacity, 0),
    )


async def mark_booking_expired(
    db: AsyncSession,
    booking: Booking,
    parking_lot: ParkingLot,
) -> int:
    previous_current_available = parking_lot.current_available
    booking.status = BookingStatus.EXPIRED.value
    await restore_booking_capacity(db, parking_lot)
    return previous_current_available


async def expire_stale_bookings(
    db: AsyncSession,
    *,
    now: datetime | None = None,
    batch_limit: int = 200,
) -> int:
    current_time = now or utcnow()
    expiration_result = await db.execute(
        select(Booking, ParkingLot)
        .join(ParkingLot, ParkingLot.id == Booking.parking_lot_id)
        .where(
            Booking.status == BookingStatus.CONFIRMED.value,
            Booking.expiration_time.is_not(None),
            Booking.expiration_time <= current_time,
        )
        .order_by(Booking.expiration_time.asc(), Booking.id.asc())
        .limit(batch_limit)
        .with_for_update(skip_locked=True)
    )
    rows = expiration_result.all()
    if not rows:
        return 0

    changed_lots: dict[int, tuple[ParkingLot, int]] = {}
    expired_count = 0
    for booking, parking_lot in rows:
        if booking.status != BookingStatus.CONFIRMED.value:
            continue

        if parking_lot.id not in changed_lots:
            changed_lots[parking_lot.id] = (parking_lot, parking_lot.current_available)
        await mark_booking_expired(db, booking, parking_lot)
        expired_count += 1

    if expired_count == 0:
        return 0

    try:
        await db.commit()
    except Exception:
        await db.rollback()
        raise

    for parking_lot, previous_current_available in changed_lots.values():
        publish_lot_availability_update(
            parking_lot,
            previous_current_available=previous_current_available,
            source="booking_expiration_job",
        )

    return expired_count