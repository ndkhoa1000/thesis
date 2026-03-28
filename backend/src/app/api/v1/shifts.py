"""Shift handover endpoints for attendants and operators."""

from datetime import UTC, datetime
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ...api.dependencies import get_current_user
from ...core.db.database import async_get_db
from ...core.exceptions.http_exceptions import BadRequestException, ForbiddenException, NotFoundException
from ...models.enums import (
    NotificationType,
    ReferenceType,
    ShiftCloseOutStatus,
    ShiftStatus,
    UserRole,
)
from ...models.notifications import Notification
from ...models.parking import ParkingLot
from ...models.shifts import Shift, ShiftCloseOut, ShiftHandover
from ...models.user import User
from ...models.users import Attendant, Manager
from ...schemas.shift import (
    AttendantFinalShiftCloseOutRead,
    AttendantShiftHandoverFinalizeCreate,
    AttendantShiftHandoverFinalizeRead,
    AttendantShiftHandoverStartRead,
    OperatorFinalShiftCloseOutRead,
    OperatorShiftAlertRead,
)
from ...services.shift_service import (
    SHIFT_HANDOVER_TOKEN_TTL,
    build_final_shift_close_out_notification,
    build_shift_discrepancy_notification,
    build_shift_handover_token,
    calculate_expected_cash,
    decode_shift_handover_token,
    get_current_shift,
    get_operator_recipients_for_lot,
    get_shift_close_out_by_id,
    get_shift_close_out_by_shift,
    validate_lot_empty_for_final_close_out,
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


async def _require_manager_for_lot(
    db: AsyncSession,
    current_user: dict[str, Any],
    parking_lot_id: int,
) -> Manager:
    manager = await _require_manager_profile(db, current_user)
    operator_rows = await get_operator_recipients_for_lot(db, parking_lot_id)
    if not any(existing_manager.id == manager.id for _, existing_manager, _ in operator_rows):
        raise ForbiddenException("Operator does not manage this parking lot")
    return manager


async def _build_final_shift_close_out_read(
    db: AsyncSession,
    close_out: ShiftCloseOut,
) -> OperatorFinalShiftCloseOutRead:
    lot_result = await db.execute(select(ParkingLot).where(ParkingLot.id == close_out.parking_lot_id).limit(1))
    parking_lot = lot_result.scalar_one_or_none()
    if parking_lot is None:
        raise NotFoundException("Assigned parking lot not found")

    attendant_result = await db.execute(
        select(Attendant, User)
        .join(User, User.id == Attendant.user_id)
        .where(Attendant.id == close_out.attendant_id)
        .limit(1)
    )
    attendant_pair = attendant_result.one_or_none()
    if attendant_pair is None:
        raise NotFoundException("Attendant profile not found for final shift close-out")
    attendant, attendant_user = attendant_pair
    attendant_name = attendant_user.name or attendant_user.username

    return OperatorFinalShiftCloseOutRead(
        close_out_id=close_out.id,
        shift_id=close_out.shift_id,
        parking_lot_id=close_out.parking_lot_id,
        parking_lot_name=parking_lot.name,
        attendant_id=attendant.id,
        attendant_name=attendant_name,
        expected_cash=float(close_out.expected_cash),
        current_available=close_out.current_available,
        active_session_count=close_out.active_session_count,
        status=close_out.status,
        requested_at=close_out.requested_at,
        completed_at=close_out.completed_at,
    )


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


@router.post(
    "/shifts/attendant-final-close-out/request",
    response_model=AttendantFinalShiftCloseOutRead,
    status_code=200,
)
async def request_attendant_final_shift_close_out(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> AttendantFinalShiftCloseOutRead:
    attendant = await _get_attendant_for_user(db, current_user)
    lot = await _get_attendant_lot(db, attendant, for_update=True)

    shift = await get_current_shift(db, attendant.id, for_update=True)
    if shift is None:
        raise BadRequestException("No active shift found to close for the day.")
    if shift.status != ShiftStatus.OPEN.value:
        raise BadRequestException("Current shift is not eligible for final day close-out.")

    existing_close_out = await get_shift_close_out_by_shift(db, shift.id, for_update=True)
    if existing_close_out is not None:
        if existing_close_out.status == ShiftCloseOutStatus.COMPLETED.value:
            raise BadRequestException("Final shift close-out has already been completed for this shift.")
        raise BadRequestException("Final shift close-out has already been requested for this shift.")

    active_session_count = await validate_lot_empty_for_final_close_out(db, lot)
    shift.ended_at = shift.ended_at or _utcnow()
    expected_cash = await calculate_expected_cash(db, shift, attendant.user_id)
    shift.status = ShiftStatus.LOCKED.value

    close_out = ShiftCloseOut(
        shift_id=shift.id,
        parking_lot_id=lot.id,
        attendant_id=attendant.id,
        expected_cash=expected_cash,
        current_available=lot.current_available,
        active_session_count=active_session_count,
        status=ShiftCloseOutStatus.REQUESTED.value,
        requested_at=_utcnow(),
    )
    db.add(close_out)
    await db.flush()

    notification_ids: list[int] = []
    for _, _, operator_user in await get_operator_recipients_for_lot(db, lot.id):
        notification = build_final_shift_close_out_notification(
            user_id=operator_user.id,
            sender_id=current_user["id"],
            close_out_id=close_out.id,
            lot_name=lot.name,
            attendant_name=current_user.get("name") or current_user.get("username") or "Attendant",
            expected_cash=expected_cash,
        )
        db.add(notification)
        await db.flush()
        notification_ids.append(notification.id)
    close_out.operator_notification_id = notification_ids[0] if notification_ids else None

    await db.commit()
    await db.refresh(close_out)

    return AttendantFinalShiftCloseOutRead(
        close_out_id=close_out.id,
        shift_id=close_out.shift_id,
        parking_lot_id=close_out.parking_lot_id,
        expected_cash=float(close_out.expected_cash),
        current_available=close_out.current_available,
        active_session_count=close_out.active_session_count,
        status=close_out.status,
        requested_at=close_out.requested_at,
    )


@router.get(
    "/shifts/operator-final-close-outs/{close_out_id}",
    response_model=OperatorFinalShiftCloseOutRead,
    status_code=200,
)
async def read_operator_final_shift_close_out(
    request: Request,
    close_out_id: int,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> OperatorFinalShiftCloseOutRead:
    close_out = await get_shift_close_out_by_id(db, close_out_id)
    if close_out is None:
        raise NotFoundException("Final shift close-out not found")
    await _require_manager_for_lot(db, current_user, close_out.parking_lot_id)
    return await _build_final_shift_close_out_read(db, close_out)


@router.post(
    "/shifts/operator-final-close-outs/{close_out_id}/complete",
    response_model=OperatorFinalShiftCloseOutRead,
    status_code=200,
)
async def complete_operator_final_shift_close_out(
    request: Request,
    close_out_id: int,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> OperatorFinalShiftCloseOutRead:
    close_out = await get_shift_close_out_by_id(db, close_out_id, for_update=True)
    if close_out is None:
        raise NotFoundException("Final shift close-out not found")

    manager = await _require_manager_for_lot(db, current_user, close_out.parking_lot_id)
    if close_out.status == ShiftCloseOutStatus.COMPLETED.value:
        raise BadRequestException("Final shift close-out has already been completed.")

    close_out.status = ShiftCloseOutStatus.COMPLETED.value
    close_out.completed_by_manager_id = manager.id
    close_out.completed_at = _utcnow()
    await db.commit()
    await db.refresh(close_out)
    return await _build_final_shift_close_out_read(db, close_out)


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
            Notification.notification_type.in_(
                [
                    NotificationType.SHIFT_HANDOVER_DISCREPANCY.value,
                    NotificationType.FINAL_SHIFT_CLOSE_OUT_READY.value,
                ]
            ),
            Notification.reference_type.in_(
                [
                    ReferenceType.SHIFT_HANDOVER.value,
                    ReferenceType.SHIFT_CLOSE_OUT.value,
                ]
            ),
        )
        .order_by(Notification.created_at.desc(), Notification.id.desc())
    )
    notifications = list(result.scalars().all())
    return [OperatorShiftAlertRead.model_validate(notification) for notification in notifications]
