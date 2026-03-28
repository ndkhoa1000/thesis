"""Shift handover endpoints for attendants and operators."""

from datetime import UTC, datetime
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ...api.dependencies import get_current_user
from ...core.db.database import async_get_db
from ...core.exceptions.http_exceptions import BadRequestException, ForbiddenException, NotFoundException
from ...models.enums import NotificationType, ReferenceType, ShiftStatus, UserRole
from ...models.notifications import Notification
from ...models.parking import ParkingLot
from ...models.shifts import Shift, ShiftHandover
from ...models.users import Attendant, Manager
from ...schemas.shift import (
    AttendantShiftHandoverFinalizeCreate,
    AttendantShiftHandoverFinalizeRead,
    AttendantShiftHandoverStartRead,
    OperatorShiftAlertRead,
)
from ...services.shift_service import (
    SHIFT_HANDOVER_TOKEN_TTL,
    build_shift_discrepancy_notification,
    build_shift_handover_token,
    calculate_expected_cash,
    decode_shift_handover_token,
    get_current_shift,
    get_operator_recipients_for_lot,
)

router = APIRouter(tags=["shifts"])


def _utcnow() -> datetime:
    return datetime.now(UTC)


async def _get_attendant_for_user(db: AsyncSession, current_user: dict[str, Any]) -> Attendant:
    if current_user.get("role") != UserRole.ATTENDANT.value:
        raise ForbiddenException("Only attendant accounts can perform shift handover")

    result = await db.execute(select(Attendant).where(Attendant.user_id == current_user["id"]).limit(1))
    attendant = result.scalar_one_or_none()
    if attendant is None:
        raise ForbiddenException("Attendant profile not found for current account")
    return attendant


async def _get_attendant_lot(
    db: AsyncSession,
    attendant: Attendant,
    *,
    for_update: bool = False,
) -> ParkingLot:
    query = select(ParkingLot).where(ParkingLot.id == attendant.parking_lot_id).limit(1)
    if for_update:
        query = query.with_for_update()
    result = await db.execute(query)
    lot = result.scalar_one_or_none()
    if lot is None:
        raise NotFoundException("Assigned parking lot not found")
    return lot


async def _require_manager_profile(db: AsyncSession, current_user: dict[str, Any]) -> Manager:
    if current_user.get("role") != UserRole.MANAGER.value:
        raise ForbiddenException("Operator capability is required to review shift discrepancy alerts")

    result = await db.execute(select(Manager).where(Manager.user_id == current_user["id"]).limit(1))
    manager = result.scalar_one_or_none()
    if manager is None:
        raise ForbiddenException("Operator capability is required to review shift discrepancy alerts")
    return manager


@router.post(
    "/shifts/attendant-handover/start",
    response_model=AttendantShiftHandoverStartRead,
    status_code=200,
)
async def create_attendant_shift_handover(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> AttendantShiftHandoverStartRead:
    attendant = await _get_attendant_for_user(db, current_user)
    await _get_attendant_lot(db, attendant, for_update=True)

    shift = await get_current_shift(db, attendant.id, for_update=True)
    if shift is None:
        raise BadRequestException(
            "No active shift found to hand over. Use the daily close-out flow if this is the last shift of the day."
        )

    if shift.status == ShiftStatus.LOCKED.value:
        raise BadRequestException("Current shift is already locked")

    if shift.status == ShiftStatus.OPEN.value:
        shift.ended_at = _utcnow()
        shift.status = ShiftStatus.HANDOVER_PENDING.value
    elif shift.ended_at is None:
        shift.ended_at = _utcnow()

    expected_cash = await calculate_expected_cash(db, shift, attendant.user_id)
    expires_at = _utcnow() + SHIFT_HANDOVER_TOKEN_TTL
    token = build_shift_handover_token(
        shift=shift,
        outgoing_attendant_user_id=attendant.user_id,
        expected_cash=expected_cash,
        expires_at=expires_at,
    )
    await db.commit()

    return AttendantShiftHandoverStartRead(
        shift_id=shift.id,
        parking_lot_id=shift.parking_lot_id,
        expected_cash=expected_cash,
        token=token,
        expires_at=expires_at,
        expires_in_seconds=int(SHIFT_HANDOVER_TOKEN_TTL.total_seconds()),
    )


@router.post(
    "/shifts/attendant-handover/finalize",
    response_model=AttendantShiftHandoverFinalizeRead,
    status_code=200,
)
async def finalize_attendant_shift_handover(
    request: Request,
    payload: AttendantShiftHandoverFinalizeCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> AttendantShiftHandoverFinalizeRead:
    incoming_attendant = await _get_attendant_for_user(db, current_user)
    lot = await _get_attendant_lot(db, incoming_attendant)
    token_payload = decode_shift_handover_token(payload.token)

    outgoing_shift_result = await db.execute(
        select(Shift).where(Shift.id == token_payload["shift_id"]).limit(1).with_for_update()
    )
    outgoing_shift = outgoing_shift_result.scalar_one_or_none()
    if outgoing_shift is None:
        raise NotFoundException("Outgoing shift not found")

    if outgoing_shift.parking_lot_id != lot.id:
        raise BadRequestException("This shift belongs to a different parking lot")
    if outgoing_shift.attendant_id == incoming_attendant.id:
        raise BadRequestException("Shift handover requires a different incoming attendant")
    if outgoing_shift.status != ShiftStatus.HANDOVER_PENDING.value:
        raise BadRequestException("Outgoing shift is not pending handover")

    expected_cash = await calculate_expected_cash(
        db,
        outgoing_shift,
        int(token_payload["outgoing_attendant_user_id"]),
    )
    discrepancy_flagged = abs(payload.actual_cash - expected_cash) > 0.009
    discrepancy_reason = (payload.discrepancy_reason or "").strip() or None
    if discrepancy_flagged and not discrepancy_reason:
        raise BadRequestException("Discrepancy reason is required before completing handover.")

    incoming_shift = await get_current_shift(db, incoming_attendant.id, for_update=True)
    if incoming_shift is None:
        incoming_shift = Shift(
            parking_lot_id=lot.id,
            attendant_id=incoming_attendant.id,
            started_at=_utcnow(),
            status=ShiftStatus.OPEN.value,
        )
        db.add(incoming_shift)
        await db.flush()
    elif incoming_shift.status != ShiftStatus.OPEN.value:
        raise BadRequestException(
            "Incoming attendant already has a shift pending handover and must close it before receiving a new shift."
        )

    outgoing_shift.status = ShiftStatus.LOCKED.value
    if outgoing_shift.ended_at is None:
        outgoing_shift.ended_at = _utcnow()

    notification_ids: list[int] = []
    for _, _, operator_user in await get_operator_recipients_for_lot(db, lot.id):
        if discrepancy_flagged:
            notification = build_shift_discrepancy_notification(
                user_id=operator_user.id,
                sender_id=current_user["id"],
                shift_id=outgoing_shift.id,
                lot_name=lot.name,
                expected_cash=expected_cash,
                actual_cash=payload.actual_cash,
                discrepancy_reason=discrepancy_reason or "",
            )
            db.add(notification)
            await db.flush()
            notification_ids.append(notification.id)

    handover = ShiftHandover(
        outgoing_shift_id=outgoing_shift.id,
        incoming_shift_id=incoming_shift.id,
        incoming_attendant_id=incoming_attendant.id,
        expected_cash=expected_cash,
        actual_cash=payload.actual_cash,
        discrepancy_reason=discrepancy_reason,
        operator_notification_id=notification_ids[0] if notification_ids else None,
        completed_at=_utcnow(),
    )
    db.add(handover)
    await db.commit()
    await db.refresh(handover)

    handover_id = getattr(handover, "id", None)
    if handover_id is None:
        handover_id = 0
    incoming_shift_id = getattr(handover, "incoming_shift_id", None)
    if incoming_shift_id is None:
        incoming_shift_id = incoming_shift.id

    return AttendantShiftHandoverFinalizeRead(
        handover_id=handover_id,
        outgoing_shift_id=handover.outgoing_shift_id,
        incoming_shift_id=incoming_shift_id,
        expected_cash=float(handover.expected_cash),
        actual_cash=float(handover.actual_cash),
        discrepancy_flagged=discrepancy_flagged,
        completed_at=handover.completed_at,
    )


@router.get(
    "/shifts/operator-alerts",
    response_model=list[OperatorShiftAlertRead],
    status_code=200,
)
async def read_operator_shift_handover_alerts(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> list[OperatorShiftAlertRead]:
    await _require_manager_profile(db, current_user)
    result = await db.execute(
        select(Notification)
        .where(
            Notification.user_id == current_user["id"],
            Notification.notification_type == NotificationType.SHIFT_HANDOVER_DISCREPANCY.value,
            Notification.reference_type == ReferenceType.SHIFT_HANDOVER.value,
        )
        .order_by(Notification.created_at.desc(), Notification.id.desc())
    )
    notifications = list(result.scalars().all())
    return [OperatorShiftAlertRead.model_validate(notification) for notification in notifications]
