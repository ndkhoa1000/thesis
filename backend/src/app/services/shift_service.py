"""Shift handover service helpers."""

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
    ShiftStatus,
)
from ..models.financials import Payment
from ..models.leases import LotLease
from ..models.notifications import Notification
from ..models.sessions import ParkingSession
from ..models.shifts import Shift
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
    shift = await get_open_shift(db, attendant.id, for_update=True)
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
    expected_cash: float,
    expires_at: datetime,
) -> str:
    payload = {
        "purpose": "shift_handover",
        "shift_id": shift.id,
        "parking_lot_id": shift.parking_lot_id,
        "outgoing_attendant_id": shift.attendant_id,
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
    expected_cash = payload.get("expected_cash")
    if (
        not isinstance(shift_id, int)
        or not isinstance(parking_lot_id, int)
        or not isinstance(outgoing_attendant_id, int)
    ):
        raise BadRequestException("Invalid shift handover QR. Please generate a new one.")
    if not isinstance(expected_cash, (int, float)):
        raise BadRequestException("Invalid shift handover QR. Please generate a new one.")

    return {
        "shift_id": shift_id,
        "parking_lot_id": parking_lot_id,
        "outgoing_attendant_id": outgoing_attendant_id,
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
