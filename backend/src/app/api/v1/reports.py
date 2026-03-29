from datetime import UTC, date, datetime, time, timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ...api.dependencies import get_current_user
from ...core.db.database import async_get_db
from ...core.exceptions.http_exceptions import NotFoundException
from ...models.enums import LeaseStatus, PayableType, PaymentStatus, SessionStatus
from ...models.financials import Payment
from ...models.leases import LotLease
from ...models.parking import ParkingLot
from ...models.sessions import ParkingSession
from ...models.user import User
from ...models.users import LotOwner, Manager
from ...schemas.report import (
    OperatorRevenueSummaryRead,
    OperatorRevenueVehicleBreakdownRead,
    OwnerRevenuePeriod,
    OwnerRevenueSummaryRead,
)
from .lots import (
    _expire_lease_and_contract_if_needed,
    _get_latest_parking_lot_config,
    _get_parking_lot,
    _require_lot_owner_profile,
    _require_manager_profile,
    _utcnow,
)

router = APIRouter(tags=["reports"])


def _as_date(value: datetime | date | None) -> date | None:
    if isinstance(value, datetime):
        return value.date()
    return value


def _at_start_of_day(value: date) -> datetime:
    return datetime.combine(value, time.min, tzinfo=UTC)


def _build_period_window(now: datetime, period: OwnerRevenuePeriod) -> tuple[date, date, datetime, datetime]:
    current_date = now.date()
    if period == OwnerRevenuePeriod.DAY:
        start_date = current_date
        end_date = current_date
    elif period == OwnerRevenuePeriod.WEEK:
        start_date = current_date - timedelta(days=current_date.weekday())
        end_date = start_date + timedelta(days=6)
    else:
        start_date = current_date.replace(day=1)
        if start_date.month == 12:
            next_month = date(start_date.year + 1, 1, 1)
        else:
            next_month = date(start_date.year, start_date.month + 1, 1)
        end_date = next_month - timedelta(days=1)

    start_at = _at_start_of_day(start_date)
    end_before = _at_start_of_day(end_date + timedelta(days=1))
    return start_date, end_date, start_at, end_before


async def _get_latest_lease_status(db: AsyncSession, parking_lot_id: int) -> str | None:
    latest_lease_result = await db.execute(
        select(LotLease.status)
        .where(LotLease.parking_lot_id == parking_lot_id)
        .order_by(LotLease.created_at.desc(), LotLease.id.desc())
        .limit(1)
    )
    return latest_lease_result.scalar_one_or_none()


async def _get_latest_accepted_lease(db: AsyncSession, parking_lot_id: int) -> tuple[LotLease, User] | None:
    lease_result = await db.execute(
        select(LotLease, User)
        .join(Manager, LotLease.manager_id == Manager.id)
        .join(User, Manager.user_id == User.id)
        .where(
            LotLease.parking_lot_id == parking_lot_id,
            LotLease.start_date.is_not(None),
            User.is_deleted.is_(False),
        )
        .order_by(LotLease.created_at.desc(), LotLease.id.desc())
        .limit(1)
    )
    snapshot = lease_result.one_or_none()
    return tuple(snapshot) if snapshot is not None else None


async def _get_operator_historical_lease(
    db: AsyncSession,
    parking_lot_id: int,
    manager_id: int,
) -> tuple[LotLease, ParkingLot, User] | None:
    lease_result = await db.execute(
        select(LotLease, ParkingLot, User)
        .join(ParkingLot, ParkingLot.id == LotLease.parking_lot_id)
        .join(LotOwner, LotOwner.id == ParkingLot.lot_owner_id)
        .join(User, LotOwner.user_id == User.id)
        .where(
            LotLease.parking_lot_id == parking_lot_id,
            LotLease.manager_id == manager_id,
            LotLease.start_date.is_not(None),
            User.is_deleted.is_(False),
        )
        .order_by(LotLease.created_at.desc(), LotLease.id.desc())
        .limit(1)
    )
    snapshot = lease_result.one_or_none()
    return tuple(snapshot) if snapshot is not None else None


def _build_empty_summary(
    parking_lot: ParkingLot,
    period: OwnerRevenuePeriod,
    range_start: date,
    range_end: date,
    lease_status: str | None,
    empty_reason: str,
    empty_message: str,
    operator_name: str | None = None,
    revenue_share_percentage: float | None = None,
    lease_start_date: date | None = None,
    lease_end_date: date | None = None,
) -> OwnerRevenueSummaryRead:
    return OwnerRevenueSummaryRead(
        parking_lot_id=parking_lot.id,
        parking_lot_name=parking_lot.name,
        period=period,
        range_start=range_start,
        range_end=range_end,
        lease_status=lease_status,
        operator_name=operator_name,
        revenue_share_percentage=revenue_share_percentage,
        lease_start_date=lease_start_date,
        lease_end_date=lease_end_date,
        completed_payment_count=0,
        completed_session_count=0,
        has_data=False,
        gross_revenue=None,
        owner_share=None,
        operator_share=None,
        empty_reason=empty_reason,
        empty_message=empty_message,
    )


def _build_operator_empty_summary(
    parking_lot: ParkingLot,
    period: OwnerRevenuePeriod,
    range_start: date,
    range_end: date,
    lease_status: str | None,
    empty_reason: str,
    empty_message: str,
    owner_name: str | None = None,
    revenue_share_percentage: float | None = None,
    lease_start_date: date | None = None,
    lease_end_date: date | None = None,
    total_capacity: int | None = None,
) -> OperatorRevenueSummaryRead:
    return OperatorRevenueSummaryRead(
        parking_lot_id=parking_lot.id,
        parking_lot_name=parking_lot.name,
        period=period,
        range_start=range_start,
        range_end=range_end,
        lease_status=lease_status,
        owner_name=owner_name,
        revenue_share_percentage=revenue_share_percentage,
        lease_start_date=lease_start_date,
        lease_end_date=lease_end_date,
        total_capacity=total_capacity,
        occupancy_rate_percentage=None,
        completed_payment_count=0,
        completed_session_count=0,
        has_data=False,
        gross_revenue=None,
        owner_share=None,
        operator_share=None,
        vehicle_type_breakdown=[],
        empty_reason=empty_reason,
        empty_message=empty_message,
    )


def _coerce_datetime(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value


def _calculate_occupancy_rate_percentage(
    sessions: list[ParkingSession],
    window_start: datetime,
    window_end: datetime,
    total_capacity: int | None,
) -> float | None:
    if total_capacity is None or total_capacity <= 0 or window_end <= window_start:
        return None

    occupied_seconds = 0.0
    for session in sessions:
        session_start = _coerce_datetime(session.checkin_time)
        session_end = _coerce_datetime(session.checkout_time)
        if session_start is None or session_end is None:
            continue
        overlap_start = max(session_start, window_start)
        overlap_end = min(session_end, window_end)
        if overlap_end <= overlap_start:
            continue
        occupied_seconds += (overlap_end - overlap_start).total_seconds()

    total_seconds = (window_end - window_start).total_seconds() * total_capacity
    if total_seconds <= 0:
        return None
    return round(min((occupied_seconds / total_seconds) * 100, 100.0), 2)


@router.get(
    "/reports/owner/parking-lots/{parking_lot_id}/revenue",
    response_model=OwnerRevenueSummaryRead,
    status_code=200,
)
async def get_owner_revenue_summary(
    request: Request,
    parking_lot_id: int,
    period: Annotated[OwnerRevenuePeriod, Query()] = OwnerRevenuePeriod.DAY,
    current_user: Annotated[dict, Depends(get_current_user)] = None,
    db: Annotated[AsyncSession, Depends(async_get_db)] = None,
) -> OwnerRevenueSummaryRead:
    lot_owner = await _require_lot_owner_profile(db, current_user)
    parking_lot = await _get_parking_lot(db, parking_lot_id)
    if parking_lot is None or parking_lot.lot_owner_id != lot_owner.id:
        raise NotFoundException("Parking lot not found")

    range_start, range_end, range_start_at, range_end_before = _build_period_window(
        _utcnow(),
        period,
    )
    accepted_lease_snapshot = await _get_latest_accepted_lease(db, parking_lot.id)
    if accepted_lease_snapshot is None:
        latest_lease_status = await _get_latest_lease_status(db, parking_lot.id)
        return _build_empty_summary(
            parking_lot=parking_lot,
            period=period,
            range_start=range_start,
            range_end=range_end,
            lease_status=latest_lease_status,
            empty_reason="NO_ACCEPTED_LEASE",
            empty_message="Bãi xe chưa có hợp đồng đã được operator chấp nhận nên chưa thể tổng hợp doanh thu.",
        )

    lease, operator_user = accepted_lease_snapshot
    lease = await _expire_lease_and_contract_if_needed(db, lease)

    lease_start_date = _as_date(lease.start_date)
    lease_end_date = _as_date(lease.end_date)
    lease_start_at = _at_start_of_day(lease_start_date) if lease_start_date is not None else range_start_at
    lease_end_before = (
        _at_start_of_day(lease_end_date + timedelta(days=1))
        if lease_end_date is not None
        else range_end_before
    )
    query_start = max(range_start_at, lease_start_at)
    query_end = min(range_end_before, lease_end_before)

    share_percentage = float(lease.revenue_share_percentage)
    if query_end <= query_start:
        return _build_empty_summary(
            parking_lot=parking_lot,
            period=period,
            range_start=range_start,
            range_end=range_end,
            lease_status=lease.status,
            operator_name=operator_user.name,
            revenue_share_percentage=share_percentage,
            lease_start_date=lease_start_date,
            lease_end_date=lease_end_date,
            empty_reason="NO_COMPLETED_PAYMENTS",
            empty_message="Không có phiên gửi xe đã thanh toán hoàn tất trong khoảng thời gian đã chọn.",
        )

    totals_result = await db.execute(
        select(
            func.count(Payment.id),
            func.coalesce(func.sum(Payment.final_amount), 0),
            func.count(func.distinct(ParkingSession.id)),
        )
        .join(ParkingSession, Payment.payable_id == ParkingSession.id)
        .where(
            Payment.payable_type == PayableType.SESSION.value,
            Payment.payment_status == PaymentStatus.COMPLETED.value,
            ParkingSession.parking_lot_id == parking_lot.id,
            Payment.created_at >= query_start,
            Payment.created_at < query_end,
        )
    )
    payment_count, gross_value, session_count = totals_result.one()
    gross_revenue = round(float(gross_value or 0), 2)
    if int(payment_count or 0) == 0 or gross_revenue <= 0:
        return _build_empty_summary(
            parking_lot=parking_lot,
            period=period,
            range_start=range_start,
            range_end=range_end,
            lease_status=lease.status,
            operator_name=operator_user.name,
            revenue_share_percentage=share_percentage,
            lease_start_date=lease_start_date,
            lease_end_date=lease_end_date,
            empty_reason="NO_COMPLETED_PAYMENTS",
            empty_message="Không có phiên gửi xe đã thanh toán hoàn tất trong khoảng thời gian đã chọn.",
        )

    owner_share = round(gross_revenue * share_percentage / 100, 2)
    operator_share = round(gross_revenue - owner_share, 2)
    return OwnerRevenueSummaryRead(
        parking_lot_id=parking_lot.id,
        parking_lot_name=parking_lot.name,
        period=period,
        range_start=range_start,
        range_end=range_end,
        lease_status=lease.status,
        operator_name=operator_user.name,
        revenue_share_percentage=share_percentage,
        lease_start_date=lease_start_date,
        lease_end_date=lease_end_date,
        completed_payment_count=int(payment_count or 0),
        completed_session_count=int(session_count or 0),
        has_data=True,
        gross_revenue=gross_revenue,
        owner_share=owner_share,
        operator_share=operator_share,
        empty_reason=None,
        empty_message=None,
    )


@router.get(
    "/reports/operator/parking-lots/{parking_lot_id}/revenue",
    response_model=OperatorRevenueSummaryRead,
    status_code=200,
)
async def get_operator_revenue_summary(
    request: Request,
    parking_lot_id: int,
    period: Annotated[OwnerRevenuePeriod, Query()] = OwnerRevenuePeriod.DAY,
    current_user: Annotated[dict, Depends(get_current_user)] = None,
    db: Annotated[AsyncSession, Depends(async_get_db)] = None,
) -> OperatorRevenueSummaryRead:
    manager = await _require_manager_profile(db, current_user)
    lease_snapshot = await _get_operator_historical_lease(db, parking_lot_id, manager.id)
    if lease_snapshot is None:
        raise NotFoundException("Parking lot not found")

    lease, parking_lot, owner_user = lease_snapshot
    lease = await _expire_lease_and_contract_if_needed(db, lease)

    range_start, range_end, range_start_at, range_end_before = _build_period_window(
        _utcnow(),
        period,
    )
    lease_start_date = _as_date(lease.start_date)
    lease_end_date = _as_date(lease.end_date)
    lease_start_at = _at_start_of_day(lease_start_date) if lease_start_date is not None else range_start_at
    lease_end_before = (
        _at_start_of_day(lease_end_date + timedelta(days=1))
        if lease_end_date is not None
        else range_end_before
    )
    query_start = max(range_start_at, lease_start_at)
    query_end = min(range_end_before, lease_end_before)

    latest_config = await _get_latest_parking_lot_config(db, parking_lot.id)
    total_capacity = latest_config.total_capacity if latest_config is not None else None
    share_percentage = float(lease.revenue_share_percentage)

    if query_end <= query_start:
        return _build_operator_empty_summary(
            parking_lot=parking_lot,
            period=period,
            range_start=range_start,
            range_end=range_end,
            lease_status=lease.status,
            owner_name=owner_user.name,
            revenue_share_percentage=share_percentage,
            lease_start_date=lease_start_date,
            lease_end_date=lease_end_date,
            total_capacity=total_capacity,
            empty_reason="NO_COMPLETED_PAYMENTS",
            empty_message="Không có phiên hoàn tất đã thanh toán trong khoảng thời gian đã chọn.",
        )

    paid_session_rows = await db.execute(
        select(ParkingSession)
        .join(Payment, Payment.payable_id == ParkingSession.id)
        .where(
            Payment.payable_type == PayableType.SESSION.value,
            Payment.payment_status == PaymentStatus.COMPLETED.value,
            ParkingSession.parking_lot_id == parking_lot.id,
            ParkingSession.status.in_([SessionStatus.CHECKED_OUT.value, SessionStatus.TIMEOUT.value]),
            Payment.created_at >= query_start,
            Payment.created_at < query_end,
        )
        .order_by(Payment.created_at.desc(), ParkingSession.id.desc())
    )
    paid_sessions = list(paid_session_rows.scalars().all())

    totals_result = await db.execute(
        select(
            func.count(Payment.id),
            func.coalesce(func.sum(Payment.final_amount), 0),
            func.count(func.distinct(ParkingSession.id)),
        )
        .join(ParkingSession, Payment.payable_id == ParkingSession.id)
        .where(
            Payment.payable_type == PayableType.SESSION.value,
            Payment.payment_status == PaymentStatus.COMPLETED.value,
            ParkingSession.parking_lot_id == parking_lot.id,
            Payment.created_at >= query_start,
            Payment.created_at < query_end,
        )
    )
    payment_count, gross_value, session_count = totals_result.one()
    gross_revenue = round(float(gross_value or 0), 2)
    if int(payment_count or 0) == 0 or int(session_count or 0) == 0:
        return _build_operator_empty_summary(
            parking_lot=parking_lot,
            period=period,
            range_start=range_start,
            range_end=range_end,
            lease_status=lease.status,
            owner_name=owner_user.name,
            revenue_share_percentage=share_percentage,
            lease_start_date=lease_start_date,
            lease_end_date=lease_end_date,
            total_capacity=total_capacity,
            empty_reason="NO_COMPLETED_PAYMENTS",
            empty_message="Không có phiên hoàn tất đã thanh toán trong khoảng thời gian đã chọn.",
        )

    breakdown_rows = await db.execute(
        select(ParkingSession.vehicle_type, func.count(func.distinct(ParkingSession.id)))
        .join(Payment, Payment.payable_id == ParkingSession.id)
        .where(
            Payment.payable_type == PayableType.SESSION.value,
            Payment.payment_status == PaymentStatus.COMPLETED.value,
            ParkingSession.parking_lot_id == parking_lot.id,
            Payment.created_at >= query_start,
            Payment.created_at < query_end,
        )
        .group_by(ParkingSession.vehicle_type)
        .order_by(func.count(func.distinct(ParkingSession.id)).desc(), ParkingSession.vehicle_type.asc())
    )
    breakdown = [
        OperatorRevenueVehicleBreakdownRead(vehicle_type=vehicle_type, session_count=int(session_total))
        for vehicle_type, session_total in breakdown_rows.all()
    ]

    owner_share = round(gross_revenue * share_percentage / 100, 2)
    operator_share = round(gross_revenue - owner_share, 2)
    occupancy_rate_percentage = _calculate_occupancy_rate_percentage(
        paid_sessions,
        query_start,
        query_end,
        total_capacity,
    )
    return OperatorRevenueSummaryRead(
        parking_lot_id=parking_lot.id,
        parking_lot_name=parking_lot.name,
        period=period,
        range_start=range_start,
        range_end=range_end,
        lease_status=lease.status,
        owner_name=owner_user.name,
        revenue_share_percentage=share_percentage,
        lease_start_date=lease_start_date,
        lease_end_date=lease_end_date,
        total_capacity=total_capacity,
        occupancy_rate_percentage=occupancy_rate_percentage,
        completed_payment_count=int(payment_count or 0),
        completed_session_count=int(session_count or 0),
        has_data=True,
        gross_revenue=gross_revenue,
        owner_share=owner_share,
        operator_share=operator_share,
        vehicle_type_breakdown=breakdown,
        empty_reason=None,
        empty_message=None,
    )