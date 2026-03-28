"""Shift handover and day-end close-out service helpers."""

from datetime import UTC, datetime, timedelta

from jose import ExpiredSignatureError, JWTError, jwt
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.exceptions.http_exceptions import BadRequestException
from ..core.security import ALGORITHM, SECRET_KEY
from ..models.enums import (
    LeaseStatus,
    NotificationType,
    PayableType,
    PaymentMethod,
    PaymentStatus,
    ReferenceType,
    SessionStatus,
    ShiftCloseOutStatus,
    ShiftStatus,
    VehicleTypeAll,
)
from ..models.financials import Payment
from ..models.leases import LotLease
from ..models.notifications import Notification
from ..models.parking import ParkingLot, ParkingLotConfig
from ..models.sessions import ParkingSession
from ..models.shifts import Shift, ShiftCloseOut
from ..models.user import User
from ..models.users import Attendant, Manager

SHIFT_HANDOVER_TOKEN_TTL = timedelta(minutes=5)


def _utcnow() -> datetime:
    return datetime.now(UTC)


async def get_open_shift(
    db: AsyncSession,
    attendant_id: int,
    *,
    for_update: bool = False,
) -> Shift | None:
    query = (
        select(Shift)
        .where(
            Shift.attendant_id == attendant_id,
            Shift.status == ShiftStatus.OPEN.value,
        )
        .order_by(Shift.started_at.desc(), Shift.id.desc())
        .limit(1)
    )
    if for_update:
        query = query.with_for_update()
    result = await db.execute(query)
    return result.scalar_one_or_none()


async def get_current_shift(
    db: AsyncSession,
    attendant_id: int,
    *,
    for_update: bool = False,
) -> Shift | None:
    query = (
        select(Shift)
        .where(
            Shift.attendant_id == attendant_id,
            Shift.status.in_([ShiftStatus.OPEN.value, ShiftStatus.HANDOVER_PENDING.value]),
        )
        .order_by(Shift.started_at.desc(), Shift.id.desc())
        .limit(1)
    )
    if for_update:
        query = query.with_for_update()
    result = await db.execute(query)
    return result.scalar_one_or_none()


async def get_or_create_open_shift(
    db: AsyncSession,
    attendant: Attendant,
    *,
    started_at: datetime | None = None,
) -> Shift:
    shift = await get_current_shift(db, attendant.id, for_update=True)
    if shift is not None:
        if shift.status == ShiftStatus.HANDOVER_PENDING.value:
            raise BadRequestException("Current shift is already pending handover.")
        return shift

    shift = Shift(
        parking_lot_id=attendant.parking_lot_id,
        attendant_id=attendant.id,
        started_at=started_at or _utcnow(),
        status=ShiftStatus.OPEN.value,
    )
    db.add(shift)
    return shift


async def calculate_expected_cash(
    db: AsyncSession,
    shift: Shift,
    attendant_user_id: int,
) -> float:
    ended_at = shift.ended_at or _utcnow()
    result = await db.execute(
        select(func.coalesce(func.sum(Payment.final_amount), 0))
        .select_from(Payment)
        .join(ParkingSession, ParkingSession.id == Payment.payable_id)
        .where(
            Payment.payable_type == PayableType.SESSION.value,
            Payment.payment_method == PaymentMethod.CASH.value,
            Payment.payment_status == PaymentStatus.COMPLETED.value,
            Payment.processed_by == attendant_user_id,
            Payment.created_at >= shift.started_at,
            Payment.created_at <= ended_at,
            ParkingSession.parking_lot_id == shift.parking_lot_id,
            ParkingSession.attendant_checkout_id == shift.attendant_id,
        )
    )
    return float(result.scalar_one() or 0)


def build_shift_handover_token(
    *,
    shift: Shift,
    outgoing_attendant_user_id: int,
    expected_cash: float,
    expires_at: datetime,
) -> str:
    payload = {
        "purpose": "shift_handover",
        "shift_id": shift.id,
        "parking_lot_id": shift.parking_lot_id,
        "outgoing_attendant_id": shift.attendant_id,
        "outgoing_attendant_user_id": outgoing_attendant_user_id,
        "expected_cash": expected_cash,
        "exp": expires_at.replace(tzinfo=None),
    }
    return jwt.encode(payload, SECRET_KEY.get_secret_value(), algorithm=ALGORITHM)


def decode_shift_handover_token(token: str) -> dict[str, int | float]:
    try:
        payload = jwt.decode(
            token,
            SECRET_KEY.get_secret_value(),
            algorithms=[ALGORITHM],
        )
    except ExpiredSignatureError as exc:
        raise BadRequestException("Shift handover QR has expired. Please generate a new one.") from exc
    except JWTError as exc:
        raise BadRequestException("Invalid shift handover QR. Please generate a new one.") from exc

    if payload.get("purpose") != "shift_handover":
        raise BadRequestException("Invalid shift handover QR. Please generate a new one.")

    shift_id = payload.get("shift_id")
    parking_lot_id = payload.get("parking_lot_id")
    outgoing_attendant_id = payload.get("outgoing_attendant_id")
    outgoing_attendant_user_id = payload.get("outgoing_attendant_user_id")
    expected_cash = payload.get("expected_cash")
    if (
        not isinstance(shift_id, int)
        or not isinstance(parking_lot_id, int)
        or not isinstance(outgoing_attendant_id, int)
        or not isinstance(outgoing_attendant_user_id, int)
    ):
        raise BadRequestException("Invalid shift handover QR. Please generate a new one.")
    if not isinstance(expected_cash, (int, float)):
        raise BadRequestException("Invalid shift handover QR. Please generate a new one.")

    return {
        "shift_id": shift_id,
        "parking_lot_id": parking_lot_id,
        "outgoing_attendant_id": outgoing_attendant_id,
        "outgoing_attendant_user_id": outgoing_attendant_user_id,
        "expected_cash": float(expected_cash),
    }


async def get_operator_recipients_for_lot(
    db: AsyncSession,
    parking_lot_id: int,
) -> list[tuple[LotLease, Manager, User]]:
    result = await db.execute(
        select(LotLease, Manager, User)
        .join(Manager, Manager.id == LotLease.manager_id)
        .join(User, User.id == Manager.user_id)
        .where(
            LotLease.parking_lot_id == parking_lot_id,
            LotLease.status == LeaseStatus.ACTIVE.value,
        )
        .order_by(LotLease.created_at.desc(), LotLease.id.desc())
    )
    return [(lease, manager, user) for lease, manager, user in result.all()]


async def get_shift_close_out_by_shift(
    db: AsyncSession,
    shift_id: int,
    *,
    for_update: bool = False,
) -> ShiftCloseOut | None:
    query = select(ShiftCloseOut).where(ShiftCloseOut.shift_id == shift_id).limit(1)
    if for_update:
        query = query.with_for_update()
    result = await db.execute(query)
    return result.scalar_one_or_none()


async def get_shift_close_out_by_id(
    db: AsyncSession,
    close_out_id: int,
    *,
    for_update: bool = False,
) -> ShiftCloseOut | None:
    query = select(ShiftCloseOut).where(ShiftCloseOut.id == close_out_id).limit(1)
    if for_update:
        query = query.with_for_update()
    result = await db.execute(query)
    return result.scalar_one_or_none()


async def count_active_sessions_for_lot(db: AsyncSession, parking_lot_id: int) -> int:
    result = await db.execute(
        select(func.count(ParkingSession.id)).where(
            ParkingSession.parking_lot_id == parking_lot_id,
            ParkingSession.status == SessionStatus.CHECKED_IN.value,
        )
    )
    return int(result.scalar_one() or 0)


async def get_latest_total_capacity(
    db: AsyncSession,
    parking_lot_id: int,
) -> int | None:
    result = await db.execute(
        select(ParkingLotConfig)
        .where(
            ParkingLotConfig.parking_lot_id == parking_lot_id,
            ParkingLotConfig.vehicle_type == VehicleTypeAll.ALL.value,
        )
        .order_by(ParkingLotConfig.created_at.desc(), ParkingLotConfig.id.desc())
        .limit(1)
    )
    config = result.scalar_one_or_none()
    if config is None:
        return None
    return max(config.total_capacity, 0)


async def validate_lot_empty_for_final_close_out(
    db: AsyncSession,
    parking_lot: ParkingLot,
) -> int:
    active_session_count = await count_active_sessions_for_lot(db, parking_lot.id)
    if active_session_count > 0:
        raise BadRequestException(
            f"Lot still has {active_session_count} active session(s). Resolve them before final shift close-out."
        )

    total_capacity = await get_latest_total_capacity(db, parking_lot.id)
    if total_capacity is not None and parking_lot.current_available != total_capacity:
        raise BadRequestException(
            "Lot occupancy is out of sync. Reconcile capacity before requesting final shift close-out."
        )
    return active_session_count


async def ensure_no_pending_final_shift_close_out(
    db: AsyncSession,
    parking_lot_id: int,
) -> None:
    result = await db.execute(
        select(ShiftCloseOut)
        .where(
            ShiftCloseOut.parking_lot_id == parking_lot_id,
            ShiftCloseOut.status == ShiftCloseOutStatus.REQUESTED.value,
        )
        .order_by(ShiftCloseOut.requested_at.desc(), ShiftCloseOut.id.desc())
        .limit(1)
    )
    pending = result.scalar_one_or_none()
    if pending is not None:
        raise BadRequestException(
            "Final shift close-out is pending operator confirmation. "
            "Gate operations stay locked until the operator completes it."
        )


def build_shift_discrepancy_notification(
    *,
    user_id: int,
    sender_id: int,
    shift_id: int,
    lot_name: str,
    expected_cash: float,
    actual_cash: float,
    discrepancy_reason: str,
) -> Notification:
    difference = actual_cash - expected_cash
    difference_label = f"{difference:,.0f}".replace(",", ".")
    expected_label = f"{expected_cash:,.0f}".replace(",", ".")
    actual_label = f"{actual_cash:,.0f}".replace(",", ".")
    return Notification(
        user_id=user_id,
        sender_id=sender_id,
        title=f"Chenh lech giao ca tai {lot_name}",
        message=(
            f"Expected {expected_label} VND, counted {actual_label} VND, delta {difference_label} VND. "
            f"Ly do: {discrepancy_reason}"
        ),
        notification_type=NotificationType.SHIFT_HANDOVER_DISCREPANCY.value,
        reference_type=ReferenceType.SHIFT_HANDOVER.value,
        reference_id=shift_id,
        is_read=False,
    )


def build_final_shift_close_out_notification(
    *,
    user_id: int,
    sender_id: int,
    close_out_id: int,
    lot_name: str,
    attendant_name: str,
    expected_cash: float,
) -> Notification:
    expected_label = f"{expected_cash:,.0f}".replace(",", ".")
    return Notification(
        user_id=user_id,
        sender_id=sender_id,
        title=f"Dong ca cuoi ngay tai {lot_name}",
        message=(
            f"{attendant_name} da gui dong ca cuoi ngay. "
            f"Tien mat doi chieu: {expected_label} VND. "
            "Operator can xac nhan ket thuc ngay van hanh."
        ),
        notification_type=NotificationType.FINAL_SHIFT_CLOSE_OUT_READY.value,
        reference_type=ReferenceType.SHIFT_CLOSE_OUT.value,
        reference_id=close_out_id,
        is_read=False,
    )
