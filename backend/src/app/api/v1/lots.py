"""Parking lot endpoints for registration, admin review, operator management, and availability streaming."""

import asyncio
from collections.abc import Sequence
from datetime import UTC, date, datetime, timedelta
from typing import Annotated, Any

from fastapi import (
    APIRouter,
    Depends,
    Request,
    WebSocket,
    WebSocketDisconnect,
    status,
)
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from ...api.dependencies import get_current_superuser, get_current_user
from ...core.db.database import async_get_db, local_session
from ...core.exceptions.http_exceptions import (
    BadRequestException,
    DuplicateValueException,
    ForbiddenException,
    NotFoundException,
)
from ...core.lot_availability import (
    lot_availability_hub,
    publish_lot_availability_update,
)
from ...core.security import TokenType, get_password_hash, verify_token
from ...crud.crud_users import crud_users
from ...models.enums import (
    LeaseContractStatus,
    LeaseStatus,
    ParkingLotStatus,
    SessionStatus,
    UserRole,
    VehicleTypeAll,
)
from ...models.leases import LeaseContract, LotLease
from ...models.notifications import ParkingLotAnnouncement
from ...models.parking import (
    ParkingLot,
    ParkingLotConfig,
    ParkingLotFeature,
    ParkingLotTag,
    Pricing,
)
from ...models.sessions import ParkingSession
from ...models.user import User
from ...models.users import Attendant, LotOwner, Manager
from ...schemas.parking_lot import (
    AvailableOperatorRead,
    OperatorManagedAnnouncementCreate,
    OperatorManagedAnnouncementUpdate,
    OperatorManagedAttendantCreate,
    OperatorManagedAttendantRead,
    OperatorManagedParkingLotRead,
    OperatorManagedParkingLotUpdate,
    ParkingLotAdminRead,
    ParkingLotAnnouncementRead,
    ParkingLotCreate,
    ParkingLotDriverDetailRead,
    ParkingLotLeaseBootstrapCreate,
    ParkingLotLeaseBootstrapRead,
    ParkingLotPeakHourPointRead,
    ParkingLotPeakHoursRead,
    ParkingLotRead,
    ParkingLotReview,
    ParkingLotStatusUpdate,
)
from ...schemas.user import UserCreateInternal

router = APIRouter(tags=["lots"])


def _utcnow() -> datetime:
    return datetime.now(UTC)


async def _expire_lease_and_contract_if_needed(db: AsyncSession, lease: LotLease) -> LotLease:
    lease_end = lease.end_date.date() if isinstance(lease.end_date, datetime) else lease.end_date
    if (
        lease.status != LeaseStatus.ACTIVE.value
        or not isinstance(lease_end, date)
        or lease_end >= _utcnow().date()
    ):
        return lease

    lease.status = LeaseStatus.EXPIRED.value
    contract_result = await db.execute(select(LeaseContract).where(LeaseContract.lease_id == lease.id).limit(1))
    contract = contract_result.scalar_one_or_none()
    if contract is not None and contract.status == LeaseContractStatus.ACTIVE.value:
        contract.status = LeaseContractStatus.EXPIRED.value
    await db.commit()
    return lease


def _ensure_public_account(current_user: dict[str, Any]) -> None:
    if current_user.get("role") in {UserRole.ATTENDANT.value, UserRole.ADMIN.value} or current_user.get("is_superuser"):
        raise ForbiddenException("Only public accounts can manage parking lots")


def _extract_bearer_token(authorization_header: str | None) -> str | None:
    if not authorization_header:
        return None

    token_type, _, token_value = authorization_header.partition(" ")
    if token_type.lower() != "bearer" or not token_value:
        return None
    return token_value


async def _authenticate_availability_websocket(websocket: WebSocket) -> dict[str, Any] | None:
    token = _extract_bearer_token(websocket.headers.get("authorization"))
    if token is None:
        return None

    async with local_session() as db:
        token_data = await verify_token(token, TokenType.ACCESS, db)
        if token_data is None:
            return None

        if "@" in token_data.username_or_email:
            user = await crud_users.get(
                db=db,
                email=token_data.username_or_email,
                is_deleted=False,
            )
        else:
            user = await crud_users.get(
                db=db,
                username=token_data.username_or_email,
                is_deleted=False,
            )

        if user is None or not user.get("is_active", True):
            return None

        return user


async def _get_lot_owner_profile(db: AsyncSession, user_id: int) -> LotOwner | None:
    lot_owner_result = await db.execute(select(LotOwner).where(LotOwner.user_id == user_id).limit(1))
    return lot_owner_result.scalar_one_or_none()


async def _require_lot_owner_profile(db: AsyncSession, current_user: dict[str, Any]) -> LotOwner:
    _ensure_public_account(current_user)
    lot_owner = await _get_lot_owner_profile(db, current_user["id"])
    if lot_owner is None:
        raise ForbiddenException("Lot owner capability is required to register parking lots")
    return lot_owner


async def _get_manager_profile(db: AsyncSession, user_id: int) -> Manager | None:
    manager_result = await db.execute(select(Manager).where(Manager.user_id == user_id).limit(1))
    return manager_result.scalar_one_or_none()


async def _require_manager_profile(db: AsyncSession, current_user: dict[str, Any]) -> Manager:
    _ensure_public_account(current_user)
    manager = await _get_manager_profile(db, current_user["id"])
    if manager is None:
        raise ForbiddenException("Operator capability is required to manage leased parking lots")
    return manager


async def _get_parking_lot(db: AsyncSession, parking_lot_id: int) -> ParkingLot | None:
    parking_lot_result = await db.execute(select(ParkingLot).where(ParkingLot.id == parking_lot_id).limit(1))
    return parking_lot_result.scalar_one_or_none()


async def _get_parking_lot_owner_snapshot(
    db: AsyncSession,
    lot_owner_id: int,
) -> tuple[str | None, str | None, str | None]:
    owner_result = await db.execute(
        select(User.name, User.phone, LotOwner.business_license)
        .join(User, LotOwner.user_id == User.id)
        .where(LotOwner.id == lot_owner_id)
        .limit(1)
    )
    owner_snapshot = owner_result.one_or_none()
    if owner_snapshot is None:
        return None, None, None
    return tuple(owner_snapshot)


async def _get_latest_parking_lot_config(
    db: AsyncSession,
    parking_lot_id: int,
) -> ParkingLotConfig | None:
    today = _utcnow().date()
    config_result = await db.execute(
        select(ParkingLotConfig)
        .where(
            ParkingLotConfig.parking_lot_id == parking_lot_id,
            ParkingLotConfig.vehicle_type == VehicleTypeAll.ALL.value,
            or_(
                ParkingLotConfig.effective_from.is_(None),
                ParkingLotConfig.effective_from <= today,
            ),
            or_(
                ParkingLotConfig.effective_to.is_(None),
                ParkingLotConfig.effective_to >= today,
            ),
        )
        .order_by(ParkingLotConfig.created_at.desc(), ParkingLotConfig.id.desc())
        .limit(1)
    )
    return config_result.scalar_one_or_none()


async def _count_active_sessions(db: AsyncSession, parking_lot_id: int) -> int:
    active_sessions_result = await db.execute(
        select(func.count(ParkingSession.id)).where(
            ParkingSession.parking_lot_id == parking_lot_id,
            ParkingSession.status == SessionStatus.CHECKED_IN.value,
        )
    )
    return int(active_sessions_result.scalar_one() or 0)


async def _get_active_lease_for_manager(
    db: AsyncSession,
    manager_id: int,
    parking_lot_id: int,
) -> LotLease | None:
    lease_result = await db.execute(
        select(LotLease)
        .where(
            LotLease.manager_id == manager_id,
            LotLease.parking_lot_id == parking_lot_id,
            LotLease.status == LeaseStatus.ACTIVE.value,
        )
        .order_by(LotLease.created_at.desc(), LotLease.id.desc())
        .limit(1)
    )
    lease = lease_result.scalar_one_or_none()
    if lease is None:
        return None
    lease = await _expire_lease_and_contract_if_needed(db, lease)
    if lease.status != LeaseStatus.ACTIVE.value:
        return None
    return lease


async def _get_operator_lot_announcement(
    db: AsyncSession,
    parking_lot_id: int,
    announcement_id: int,
) -> ParkingLotAnnouncement | None:
    announcement_result = await db.execute(
        select(ParkingLotAnnouncement)
        .where(
            ParkingLotAnnouncement.id == announcement_id,
            ParkingLotAnnouncement.parking_lot_id == parking_lot_id,
        )
        .limit(1)
    )
    return announcement_result.scalar_one_or_none()


async def _get_operator_lot_announcements(
    db: AsyncSession,
    parking_lot_id: int,
) -> list[ParkingLotAnnouncement]:
    announcement_result = await db.execute(
        select(ParkingLotAnnouncement)
        .where(ParkingLotAnnouncement.parking_lot_id == parking_lot_id)
        .order_by(
            ParkingLotAnnouncement.visible_from.desc(),
            ParkingLotAnnouncement.id.desc(),
        )
    )
    return list(announcement_result.scalars().all())


async def _get_driver_visible_announcements(
    db: AsyncSession,
    parking_lot_id: int,
) -> list[ParkingLotAnnouncement]:
    now = _utcnow()
    announcement_result = await db.execute(
        select(ParkingLotAnnouncement)
        .where(
            ParkingLotAnnouncement.parking_lot_id == parking_lot_id,
            ParkingLotAnnouncement.visible_from <= now,
            or_(
                ParkingLotAnnouncement.visible_until.is_(None),
                ParkingLotAnnouncement.visible_until >= now,
            ),
        )
        .order_by(
            ParkingLotAnnouncement.visible_from.desc(),
            ParkingLotAnnouncement.id.desc(),
        )
    )
    return list(announcement_result.scalars().all())


def _build_admin_read(
    parking_lot: ParkingLot,
    owner_name: str | None,
    owner_phone: str | None,
    owner_business_license: str | None,
) -> ParkingLotAdminRead:
    return ParkingLotAdminRead.model_validate(
        {
            "id": parking_lot.id,
            "lot_owner_id": parking_lot.lot_owner_id,
            "name": parking_lot.name,
            "address": parking_lot.address,
            "latitude": float(parking_lot.latitude),
            "longitude": float(parking_lot.longitude),
            "current_available": parking_lot.current_available,
            "status": parking_lot.status,
            "description": parking_lot.description,
            "cover_image": parking_lot.cover_image,
            "created_at": parking_lot.created_at,
            "updated_at": parking_lot.updated_at,
            "owner_name": owner_name,
            "owner_phone": owner_phone,
            "owner_business_license": owner_business_license,
        }
    )


def _build_parking_lot_read(
    parking_lot: ParkingLot,
    active_lease_id: int | None = None,
    active_lease_status: str | None = None,
    active_operator_user_id: int | None = None,
    active_operator_name: str | None = None,
) -> ParkingLotRead:
    return ParkingLotRead.model_validate(
        {
            "id": parking_lot.id,
            "lot_owner_id": parking_lot.lot_owner_id,
            "name": parking_lot.name,
            "address": parking_lot.address,
            "latitude": float(parking_lot.latitude),
            "longitude": float(parking_lot.longitude),
            "current_available": parking_lot.current_available,
            "status": parking_lot.status,
            "description": parking_lot.description,
            "cover_image": parking_lot.cover_image,
            "active_lease_id": active_lease_id,
            "active_lease_status": active_lease_status,
            "active_operator_user_id": active_operator_user_id,
            "active_operator_name": active_operator_name,
            "created_at": parking_lot.created_at,
            "updated_at": parking_lot.updated_at,
        }
    )


def _build_operator_read(
    parking_lot: ParkingLot,
    lease: LotLease,
    total_capacity: int | None,
    occupied_count: int,
    opening_time=None,
    closing_time=None,
    pricing_mode: str | None = None,
    price_amount: float | None = None,
) -> OperatorManagedParkingLotRead:
    return OperatorManagedParkingLotRead.model_validate(
        {
            "id": parking_lot.id,
            "lease_id": lease.id,
            "lot_owner_id": parking_lot.lot_owner_id,
            "name": parking_lot.name,
            "address": parking_lot.address,
            "latitude": float(parking_lot.latitude),
            "longitude": float(parking_lot.longitude),
            "current_available": parking_lot.current_available,
            "status": parking_lot.status,
            "description": parking_lot.description,
            "cover_image": parking_lot.cover_image,
            "created_at": parking_lot.created_at,
            "updated_at": parking_lot.updated_at,
            "total_capacity": total_capacity,
            "occupied_count": occupied_count,
            "opening_time": opening_time,
            "closing_time": closing_time,
            "pricing_mode": pricing_mode,
            "price_amount": price_amount,
        }
    )


def _build_attendant_read(user: User, attendant: Attendant) -> OperatorManagedAttendantRead:
    hired_at = attendant.hired_at.date() if isinstance(attendant.hired_at, datetime) else attendant.hired_at
    return OperatorManagedAttendantRead.model_validate(
        {
            "id": attendant.id,
            "user_id": user.id,
            "parking_lot_id": attendant.parking_lot_id,
            "name": user.name,
            "username": user.username,
            "email": user.email,
            "phone": user.phone,
            "is_active": user.is_active,
            "hired_at": hired_at,
        }
    )


def _build_available_operator_read(manager: Manager, user: User) -> AvailableOperatorRead:
    return AvailableOperatorRead.model_validate(
        {
            "manager_id": manager.id,
            "user_id": user.id,
            "name": user.name,
            "email": user.email,
            "phone": user.phone,
            "business_license": manager.business_license,
            "verified_at": manager.verified_at,
        }
    )


def _build_lease_bootstrap_read(lease: LotLease, user: User) -> ParkingLotLeaseBootstrapRead:
    start_date = lease.start_date.date() if isinstance(lease.start_date, datetime) else lease.start_date
    end_date = lease.end_date.date() if isinstance(lease.end_date, datetime) else lease.end_date
    return ParkingLotLeaseBootstrapRead.model_validate(
        {
            "lease_id": lease.id,
            "parking_lot_id": lease.parking_lot_id,
            "manager_id": lease.manager_id,
            "manager_user_id": user.id,
            "operator_name": user.name,
            "status": lease.status,
            "monthly_fee": float(lease.monthly_fee),
            "start_date": start_date,
            "end_date": end_date,
        }
    )


async def _get_latest_pricing(db: AsyncSession, parking_lot_id: int) -> Pricing | None:
    today = _utcnow().date()
    pricing_result = await db.execute(
        select(Pricing)
        .where(
            Pricing.parking_lot_id == parking_lot_id,
            Pricing.vehicle_type == VehicleTypeAll.ALL.value,
            or_(Pricing.effective_from.is_(None), Pricing.effective_from <= today),
            or_(Pricing.effective_to.is_(None), Pricing.effective_to >= today),
        )
        .order_by(Pricing.effective_from.desc(), Pricing.id.desc())
        .limit(1)
    )
    return pricing_result.scalar_one_or_none()


async def _get_active_attendant_pairs(
    db: AsyncSession,
    parking_lot_id: int,
) -> list[tuple[Attendant, User]]:
    attendants_result = await db.execute(
        select(Attendant, User)
        .join(User, Attendant.user_id == User.id)
        .where(
            Attendant.parking_lot_id == parking_lot_id,
            User.is_deleted.is_(False),
            User.is_active.is_(True),
        )
        .order_by(User.created_at.desc(), User.id.desc())
    )
    return [tuple(row) for row in attendants_result.all()]


async def _get_attendant_pair_for_lot(
    db: AsyncSession,
    parking_lot_id: int,
    attendant_id: int,
) -> tuple[Attendant, User] | None:
    attendant_result = await db.execute(
        select(Attendant, User)
        .join(User, Attendant.user_id == User.id)
        .where(
            Attendant.id == attendant_id,
            Attendant.parking_lot_id == parking_lot_id,
            User.is_deleted.is_(False),
        )
        .limit(1)
    )
    attendant_pair = attendant_result.one_or_none()
    if attendant_pair is None:
        return None
    return tuple(attendant_pair)


async def _get_manager_user(db: AsyncSession, manager_user_id: int) -> tuple[Manager, User] | None:
    manager_result = await db.execute(
        select(Manager, User)
        .join(User, Manager.user_id == User.id)
        .where(
            Manager.user_id == manager_user_id,
            Manager.verified_at.is_not(None),
            User.is_deleted.is_(False),
            User.is_active.is_(True),
        )
        .limit(1)
    )
    manager_pair = manager_result.one_or_none()
    if manager_pair is None:
        return None
    return tuple(manager_pair)


async def _get_parking_lot_tags(db: AsyncSession, parking_lot_id: int) -> list[ParkingLotTag]:
    tags_result = await db.execute(
        select(ParkingLotTag)
        .where(ParkingLotTag.parking_lot_id == parking_lot_id)
        .order_by(ParkingLotTag.id.asc())
    )
    return list(tags_result.scalars().all())


async def _get_enabled_parking_lot_features(
    db: AsyncSession,
    parking_lot_id: int,
) -> list[ParkingLotFeature]:
    features_result = await db.execute(
        select(ParkingLotFeature)
        .where(
            ParkingLotFeature.parking_lot_id == parking_lot_id,
            ParkingLotFeature.enabled.is_(True),
        )
        .order_by(ParkingLotFeature.id.asc())
    )
    return list(features_result.scalars().all())


async def _get_peak_hour_rows(
    db: AsyncSession,
    parking_lot_id: int,
    lookback_days: int = 30,
) -> list[tuple[int, int]]:
    cutoff = _utcnow() - timedelta(days=lookback_days)
    hour_bucket = func.extract("hour", ParkingSession.checkin_time)
    peak_hours_result = await db.execute(
        select(hour_bucket, func.count(ParkingSession.id))
        .where(
            ParkingSession.parking_lot_id == parking_lot_id,
            ParkingSession.checkin_time >= cutoff,
        )
        .group_by(hour_bucket)
        .order_by(hour_bucket.asc())
    )
    return [(int(hour), int(count)) for hour, count in peak_hours_result.all()]


def _build_peak_hours_read(
    peak_hour_rows: list[tuple[int, int]],
    lookback_days: int = 30,
) -> ParkingLotPeakHoursRead:
    total_sessions = sum(count for _, count in peak_hour_rows)
    status = "READY" if total_sessions >= 3 else "INSUFFICIENT_DATA"
    points = [
        ParkingLotPeakHourPointRead(hour=hour, session_count=count)
        for hour, count in peak_hour_rows
    ]
    if status != "READY":
        points = []
    return ParkingLotPeakHoursRead(
        status=status,
        lookback_days=lookback_days,
        total_sessions=total_sessions,
        points=points,
    )


def _build_driver_detail_read(
    parking_lot: ParkingLot,
    latest_config: ParkingLotConfig | None,
    latest_pricing: Pricing | None,
    features: list[ParkingLotFeature],
    tags: list[ParkingLotTag],
    announcements: list[ParkingLotAnnouncement],
    peak_hours: ParkingLotPeakHoursRead,
) -> ParkingLotDriverDetailRead:
    return ParkingLotDriverDetailRead.model_validate(
        {
            "id": parking_lot.id,
            "name": parking_lot.name,
            "address": parking_lot.address,
            "latitude": float(parking_lot.latitude),
            "longitude": float(parking_lot.longitude),
            "current_available": parking_lot.current_available,
            "status": parking_lot.status,
            "description": parking_lot.description,
            "cover_image": parking_lot.cover_image,
            "total_capacity": latest_config.total_capacity if latest_config else None,
            "opening_time": latest_config.opening_time if latest_config else None,
            "closing_time": latest_config.closing_time if latest_config else None,
            "pricing_mode": latest_pricing.pricing_mode if latest_pricing else None,
            "price_amount": float(latest_pricing.price_amount) if latest_pricing else None,
            "feature_labels": [feature.feature_type for feature in features],
            "tag_labels": [tag.tag_name for tag in tags],
            "announcements": announcements,
            "peak_hours": peak_hours,
        }
    )


async def _get_latest_lease_snapshot(
    db: AsyncSession,
    parking_lot_id: int,
) -> tuple[LotLease, User] | None:
    lease_result = await db.execute(
        select(LotLease, User)
        .join(Manager, LotLease.manager_id == Manager.id)
        .join(User, Manager.user_id == User.id)
        .where(
            LotLease.parking_lot_id == parking_lot_id,
            User.is_deleted.is_(False),
        )
        .order_by(LotLease.created_at.desc(), LotLease.id.desc())
        .limit(1)
    )
    lease_snapshot = lease_result.one_or_none()
    if lease_snapshot is None:
        return None
    lease, operator_user = tuple(lease_snapshot)
    lease = await _expire_lease_and_contract_if_needed(db, lease)
    return lease, operator_user


@router.get("/lots", response_model=list[ParkingLotRead])
async def list_lots(
    request: Request,
    db: Annotated[AsyncSession, Depends(async_get_db)],
)-> Sequence[ParkingLot]:
    lots_result = await db.execute(
        select(ParkingLot)
        .where(ParkingLot.status == ParkingLotStatus.APPROVED.value)
        .order_by(ParkingLot.created_at.desc(), ParkingLot.id.desc())
    )
    return list(lots_result.scalars().all())


@router.websocket("/lots/availability/stream")
async def stream_lot_availability(websocket: WebSocket) -> None:
    current_user = await _authenticate_availability_websocket(websocket)
    if current_user is None:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await websocket.accept()
    subscription = lot_availability_hub.subscribe()
    try:
        while True:
            event = await asyncio.to_thread(subscription.get)
            await websocket.send_json(event.model_dump(mode="json"))
    except WebSocketDisconnect:
        return
    finally:
        lot_availability_hub.unsubscribe(subscription)


@router.get("/lots/{parking_lot_id}", response_model=ParkingLotDriverDetailRead)
async def read_public_lot_detail(
    request: Request,
    parking_lot_id: int,
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> ParkingLotDriverDetailRead:
    parking_lot = await _get_parking_lot(db, parking_lot_id)
    if parking_lot is None or parking_lot.status != ParkingLotStatus.APPROVED.value:
        raise NotFoundException("Parking lot not found")

    latest_config = await _get_latest_parking_lot_config(db, parking_lot_id)
    latest_pricing = await _get_latest_pricing(db, parking_lot_id)
    tags = await _get_parking_lot_tags(db, parking_lot_id)
    features = await _get_enabled_parking_lot_features(db, parking_lot_id)
    announcements = await _get_driver_visible_announcements(db, parking_lot_id)
    peak_hours = _build_peak_hours_read(await _get_peak_hour_rows(db, parking_lot_id))

    return _build_driver_detail_read(
        parking_lot,
        latest_config,
        latest_pricing,
        features,
        tags,
        announcements,
        peak_hours,
    )


@router.get("/user/me/parking-lots", response_model=list[ParkingLotRead])
async def read_my_parking_lots(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> list[ParkingLotRead]:
    lot_owner = await _require_lot_owner_profile(db, current_user)
    lots_result = await db.execute(
        select(ParkingLot)
        .where(ParkingLot.lot_owner_id == lot_owner.id)
        .order_by(ParkingLot.created_at.desc(), ParkingLot.id.desc())
    )
    parking_lots = list(lots_result.scalars().all())
    results: list[ParkingLotRead] = []
    for parking_lot in parking_lots:
        latest_lease = await _get_latest_lease_snapshot(db, parking_lot.id)
        if latest_lease is None:
            results.append(_build_parking_lot_read(parking_lot))
            continue
        lease, operator_user = latest_lease
        results.append(
            _build_parking_lot_read(
                parking_lot,
                active_lease_id=lease.id,
                active_lease_status=lease.status,
                active_operator_user_id=operator_user.id,
                active_operator_name=operator_user.name,
            )
        )
    return results


@router.get("/user/me/operators", response_model=list[AvailableOperatorRead])
async def list_available_operators(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> list[AvailableOperatorRead]:
    await _require_lot_owner_profile(db, current_user)
    operators_result = await db.execute(
        select(Manager, User)
        .join(User, Manager.user_id == User.id)
        .where(
            Manager.verified_at.is_not(None),
            User.is_deleted.is_(False),
            User.is_active.is_(True),
        )
        .order_by(Manager.verified_at.desc(), Manager.id.desc())
    )
    return [_build_available_operator_read(manager, user) for manager, user in operators_result.all()]


@router.post(
    "/user/me/parking-lots/{parking_lot_id}/lease-bootstrap",
    response_model=ParkingLotLeaseBootstrapRead,
    status_code=201,
)
async def bootstrap_parking_lot_lease(
    request: Request,
    parking_lot_id: int,
    payload: ParkingLotLeaseBootstrapCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> ParkingLotLeaseBootstrapRead:
    lot_owner = await _require_lot_owner_profile(db, current_user)
    parking_lot = await _get_parking_lot(db, parking_lot_id)
    if parking_lot is None or parking_lot.lot_owner_id != lot_owner.id:
        raise NotFoundException("Parking lot not found")

    if parking_lot.status != ParkingLotStatus.APPROVED.value:
        raise BadRequestException("Only approved parking lots can bootstrap operator access")

    existing_lease = await _get_latest_lease_snapshot(db, parking_lot_id)
    if existing_lease is not None and existing_lease[0].status in {
        LeaseStatus.PENDING.value,
        LeaseStatus.ACTIVE.value,
    }:
        raise BadRequestException("Parking lot already has an active operator lease")

    manager_pair = await _get_manager_user(db, payload.manager_user_id)
    if manager_pair is None:
        raise NotFoundException("Operator not found")

    manager, operator_user = manager_pair
    lease = LotLease(
        parking_lot_id=parking_lot.id,
        manager_id=manager.id,
        monthly_fee=payload.monthly_fee,
        start_date=_utcnow(),
        status=LeaseStatus.ACTIVE.value,
        approved_by=current_user["id"],
    )
    db.add(lease)
    await db.commit()
    await db.refresh(lease)
    return _build_lease_bootstrap_read(lease, operator_user)


@router.get("/operator/parking-lots", response_model=list[OperatorManagedParkingLotRead])
async def read_operator_parking_lots(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> list[OperatorManagedParkingLotRead]:
    manager = await _require_manager_profile(db, current_user)
    leases_result = await db.execute(
        select(LotLease, ParkingLot)
        .join(ParkingLot, LotLease.parking_lot_id == ParkingLot.id)
        .where(
            LotLease.manager_id == manager.id,
            LotLease.status == LeaseStatus.ACTIVE.value,
        )
        .order_by(LotLease.created_at.desc(), LotLease.id.desc())
    )

    managed_lots: list[OperatorManagedParkingLotRead] = []
    for lease, parking_lot in leases_result.all():
        latest_config = await _get_latest_parking_lot_config(db, parking_lot.id)
        latest_pricing = await _get_latest_pricing(db, parking_lot.id)
        occupied_count = await _count_active_sessions(db, parking_lot.id)
        managed_lots.append(
            _build_operator_read(
                parking_lot,
                lease,
                latest_config.total_capacity if latest_config else None,
                occupied_count,
                latest_config.opening_time if latest_config else None,
                latest_config.closing_time if latest_config else None,
                latest_pricing.pricing_mode if latest_pricing else None,
                float(latest_pricing.price_amount) if latest_pricing else None,
            )
        )
    return managed_lots


@router.patch("/operator/parking-lots/{parking_lot_id}", response_model=OperatorManagedParkingLotRead)
async def patch_operator_parking_lot(
    request: Request,
    parking_lot_id: int,
    payload: OperatorManagedParkingLotUpdate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> OperatorManagedParkingLotRead:
    manager = await _require_manager_profile(db, current_user)
    lease = await _get_active_lease_for_manager(db, manager.id, parking_lot_id)
    if lease is None:
        raise NotFoundException("Managed parking lot not found")

    parking_lot = await _get_parking_lot(db, parking_lot_id)
    if parking_lot is None:
        raise NotFoundException("Parking lot not found")

    if parking_lot.status not in {ParkingLotStatus.APPROVED.value, ParkingLotStatus.CLOSED.value}:
        raise BadRequestException("Only approved or suspended parking lots can be configured")

    effective_today = _utcnow().date()
    previous_current_available = parking_lot.current_available
    latest_config = await _get_latest_parking_lot_config(db, parking_lot.id)
    latest_pricing = await _get_latest_pricing(db, parking_lot.id)
    occupied_count = await _count_active_sessions(db, parking_lot.id)
    parking_lot.name = payload.name
    parking_lot.address = payload.address
    parking_lot.description = payload.description
    parking_lot.cover_image = payload.cover_image
    parking_lot.current_available = max(payload.total_capacity - occupied_count, 0)
    if (
        parking_lot.status == ParkingLotStatus.CLOSED.value
        and latest_config is None
        and latest_pricing is None
    ):
        parking_lot.status = ParkingLotStatus.APPROVED.value
    parking_lot.updated_at = _utcnow()

    parking_lot_config = ParkingLotConfig(
        parking_lot_id=parking_lot.id,
        set_by=manager.id,
        total_capacity=payload.total_capacity,
        vehicle_type=VehicleTypeAll.ALL.value,
        opening_time=payload.opening_time,
        closing_time=payload.closing_time,
        effective_from=effective_today,
    )
    pricing = Pricing(
        parking_lot_id=parking_lot.id,
        price_amount=payload.price_amount,
        pricing_mode=payload.pricing_mode.value,
        vehicle_type=VehicleTypeAll.ALL.value,
        effective_from=effective_today,
    )
    db.add(parking_lot_config)
    db.add(pricing)

    await db.commit()
    await db.refresh(parking_lot)
    publish_lot_availability_update(
        parking_lot,
        previous_current_available=previous_current_available,
        source="operator_parking_lot_update",
    )

    return _build_operator_read(
        parking_lot,
        lease,
        parking_lot_config.total_capacity,
        occupied_count,
        parking_lot_config.opening_time,
        parking_lot_config.closing_time,
        pricing.pricing_mode,
        float(pricing.price_amount),
    )


@router.get(
    "/operator/parking-lots/{parking_lot_id}/announcements",
    response_model=list[ParkingLotAnnouncementRead],
)
async def read_operator_lot_announcements(
    request: Request,
    parking_lot_id: int,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> list[ParkingLotAnnouncementRead]:
    manager = await _require_manager_profile(db, current_user)
    lease = await _get_active_lease_for_manager(db, manager.id, parking_lot_id)
    if lease is None:
        raise NotFoundException("Managed parking lot not found")

    return [
        ParkingLotAnnouncementRead.model_validate(announcement)
        for announcement in await _get_operator_lot_announcements(db, parking_lot_id)
    ]


@router.post(
    "/operator/parking-lots/{parking_lot_id}/announcements",
    response_model=ParkingLotAnnouncementRead,
    status_code=201,
)
async def create_operator_lot_announcement(
    request: Request,
    parking_lot_id: int,
    payload: OperatorManagedAnnouncementCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> ParkingLotAnnouncementRead:
    manager = await _require_manager_profile(db, current_user)
    lease = await _get_active_lease_for_manager(db, manager.id, parking_lot_id)
    if lease is None:
        raise NotFoundException("Managed parking lot not found")

    announcement = ParkingLotAnnouncement(
        parking_lot_id=parking_lot_id,
        posted_by=manager.id,
        title=payload.title,
        content=payload.content,
        announcement_type=payload.announcement_type.value,
        visible_from=payload.visible_from,
        visible_until=payload.visible_until,
    )
    db.add(announcement)
    await db.commit()
    await db.refresh(announcement)
    return ParkingLotAnnouncementRead.model_validate(announcement)


@router.patch(
    "/operator/parking-lots/{parking_lot_id}/announcements/{announcement_id}",
    response_model=ParkingLotAnnouncementRead,
)
async def patch_operator_lot_announcement(
    request: Request,
    parking_lot_id: int,
    announcement_id: int,
    payload: OperatorManagedAnnouncementUpdate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> ParkingLotAnnouncementRead:
    manager = await _require_manager_profile(db, current_user)
    lease = await _get_active_lease_for_manager(db, manager.id, parking_lot_id)
    if lease is None:
        raise NotFoundException("Managed parking lot not found")

    announcement = await _get_operator_lot_announcement(db, parking_lot_id, announcement_id)
    if announcement is None:
        raise NotFoundException("Announcement not found")

    announcement.title = payload.title
    announcement.content = payload.content
    announcement.announcement_type = payload.announcement_type.value
    announcement.visible_from = payload.visible_from
    announcement.visible_until = payload.visible_until
    await db.commit()
    await db.refresh(announcement)
    return ParkingLotAnnouncementRead.model_validate(announcement)


@router.get(
    "/operator/parking-lots/{parking_lot_id}/attendants",
    response_model=list[OperatorManagedAttendantRead],
)
async def read_operator_lot_attendants(
    request: Request,
    parking_lot_id: int,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> list[OperatorManagedAttendantRead]:
    manager = await _require_manager_profile(db, current_user)
    lease = await _get_active_lease_for_manager(db, manager.id, parking_lot_id)
    if lease is None:
        raise NotFoundException("Managed parking lot not found")

    attendants = await _get_active_attendant_pairs(db, parking_lot_id)
    return [_build_attendant_read(user, attendant) for attendant, user in attendants]


@router.post(
    "/operator/parking-lots/{parking_lot_id}/attendants",
    response_model=OperatorManagedAttendantRead,
    status_code=201,
)
async def create_operator_lot_attendant(
    request: Request,
    parking_lot_id: int,
    payload: OperatorManagedAttendantCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> OperatorManagedAttendantRead:
    manager = await _require_manager_profile(db, current_user)
    lease = await _get_active_lease_for_manager(db, manager.id, parking_lot_id)
    if lease is None:
        raise NotFoundException("Managed parking lot not found")

    email_exists = await crud_users.exists(db=db, email=payload.email)
    if email_exists:
        raise DuplicateValueException("Email is already registered")

    username_exists = await crud_users.exists(db=db, username=payload.username)
    if username_exists:
        raise DuplicateValueException("Username not available")

    created_user = await crud_users.create(
        db=db,
        object=UserCreateInternal(
            name=payload.name,
            username=payload.username,
            email=payload.email,
            phone=payload.phone,
            hashed_password=get_password_hash(payload.password),
            role=UserRole.ATTENDANT.value,
            is_active=True,
        ),
        commit=False,
    )
    attendant = Attendant(
        user_id=created_user.id,
        parking_lot_id=parking_lot_id,
        hired_at=_utcnow(),
    )
    db.add(attendant)
    await db.commit()
    await db.refresh(created_user)
    await db.refresh(attendant)
    return _build_attendant_read(created_user, attendant)


@router.delete("/operator/parking-lots/{parking_lot_id}/attendants/{attendant_id}")
async def remove_operator_lot_attendant(
    request: Request,
    parking_lot_id: int,
    attendant_id: int,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> dict[str, str]:
    manager = await _require_manager_profile(db, current_user)
    lease = await _get_active_lease_for_manager(db, manager.id, parking_lot_id)
    if lease is None:
        raise NotFoundException("Managed parking lot not found")

    attendant_pair = await _get_attendant_pair_for_lot(db, parking_lot_id, attendant_id)
    if attendant_pair is None:
        raise NotFoundException("Attendant not found")

    _, user = attendant_pair
    user.is_active = False
    user.updated_at = _utcnow()
    await db.commit()
    return {"message": "Attendant removed"}


@router.post("/user/me/parking-lots", response_model=ParkingLotRead, status_code=201)
async def create_my_parking_lot(
    request: Request,
    payload: ParkingLotCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> ParkingLotRead:
    lot_owner = await _require_lot_owner_profile(db, current_user)

    parking_lot = ParkingLot(
        lot_owner_id=lot_owner.id,
        name=payload.name,
        address=payload.address,
        latitude=payload.latitude,
        longitude=payload.longitude,
        description=payload.description,
        cover_image=payload.cover_image,
        current_available=0,
        status=ParkingLotStatus.PENDING.value,
    )
    db.add(parking_lot)
    await db.commit()
    await db.refresh(parking_lot)
    return _build_parking_lot_read(parking_lot)


@router.get("/admin/parking-lots", response_model=list[ParkingLotAdminRead])
async def read_parking_lot_applications(
    request: Request,
    current_superuser: Annotated[dict, Depends(get_current_superuser)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> list[ParkingLotAdminRead]:
    lots_result = await db.execute(
        select(ParkingLot, User.name, User.phone, LotOwner.business_license)
        .join(LotOwner, ParkingLot.lot_owner_id == LotOwner.id)
        .join(User, LotOwner.user_id == User.id)
        .order_by(ParkingLot.created_at.desc(), ParkingLot.id.desc())
    )
    return [
        _build_admin_read(parking_lot, owner_name, owner_phone, owner_business_license)
        for parking_lot, owner_name, owner_phone, owner_business_license in lots_result.all()
    ]


@router.post("/admin/parking-lots/{parking_lot_id}/review", response_model=ParkingLotRead)
async def review_parking_lot(
    request: Request,
    parking_lot_id: int,
    payload: ParkingLotReview,
    current_superuser: Annotated[dict, Depends(get_current_superuser)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> ParkingLot:
    parking_lot = await _get_parking_lot(db, parking_lot_id)
    if parking_lot is None:
        raise NotFoundException("Parking lot not found")

    if parking_lot.status != ParkingLotStatus.PENDING.value:
        raise BadRequestException("Only pending parking lots can be reviewed")

    if payload.decision == ParkingLotStatus.REJECTED and not payload.rejection_reason:
        raise BadRequestException("Rejection reason is required when rejecting a parking lot")

    parking_lot.status = payload.decision.value
    parking_lot.updated_at = _utcnow()
    await db.commit()
    await db.refresh(parking_lot)
    return parking_lot


@router.patch("/admin/parking-lots/{parking_lot_id}/status", response_model=ParkingLotAdminRead)
async def patch_parking_lot_status(
    request: Request,
    parking_lot_id: int,
    payload: ParkingLotStatusUpdate,
    current_superuser: Annotated[dict, Depends(get_current_superuser)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> ParkingLotAdminRead:
    parking_lot = await _get_parking_lot(db, parking_lot_id)
    if parking_lot is None:
        raise NotFoundException("Parking lot not found")

    if payload.status == ParkingLotStatus.CLOSED and parking_lot.status != ParkingLotStatus.APPROVED.value:
        raise BadRequestException("Only approved parking lots can be suspended")

    if payload.status == ParkingLotStatus.APPROVED and parking_lot.status != ParkingLotStatus.CLOSED.value:
        raise BadRequestException("Only suspended parking lots can be reopened")

    parking_lot.status = payload.status.value
    parking_lot.updated_at = _utcnow()
    await db.commit()
    await db.refresh(parking_lot)

    owner_name, owner_phone, owner_business_license = await _get_parking_lot_owner_snapshot(
        db,
        parking_lot.lot_owner_id,
    )
    return _build_admin_read(parking_lot, owner_name, owner_phone, owner_business_license)
