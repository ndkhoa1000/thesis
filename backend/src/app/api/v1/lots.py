"""Parking lot endpoints for Story 2-1 and admin approvals."""

from collections.abc import Sequence
from datetime import UTC, datetime
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ...api.dependencies import get_current_superuser, get_current_user
from ...core.db.database import async_get_db
from ...core.exceptions.http_exceptions import BadRequestException, ForbiddenException, NotFoundException
from ...models.enums import ParkingLotStatus, UserRole
from ...models.parking import ParkingLot
from ...models.user import User
from ...models.users import LotOwner
from ...schemas.parking_lot import ParkingLotAdminRead, ParkingLotCreate, ParkingLotRead, ParkingLotReview

router = APIRouter(tags=["lots"])


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _ensure_public_account(current_user: dict[str, Any]) -> None:
    if current_user.get("role") in {UserRole.ATTENDANT.value, UserRole.ADMIN.value} or current_user.get("is_superuser"):
        raise ForbiddenException("Only public accounts can manage parking lots")


async def _get_lot_owner_profile(db: AsyncSession, user_id: int) -> LotOwner | None:
    lot_owner_result = await db.execute(select(LotOwner).where(LotOwner.user_id == user_id).limit(1))
    return lot_owner_result.scalar_one_or_none()


async def _require_lot_owner_profile(db: AsyncSession, current_user: dict[str, Any]) -> LotOwner:
    _ensure_public_account(current_user)
    lot_owner = await _get_lot_owner_profile(db, current_user["id"])
    if lot_owner is None:
        raise ForbiddenException("Lot owner capability is required to register parking lots")
    return lot_owner


async def _get_parking_lot(db: AsyncSession, parking_lot_id: int) -> ParkingLot | None:
    parking_lot_result = await db.execute(select(ParkingLot).where(ParkingLot.id == parking_lot_id).limit(1))
    return parking_lot_result.scalar_one_or_none()


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


@router.get("/user/me/parking-lots", response_model=list[ParkingLotRead])
async def read_my_parking_lots(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> Sequence[ParkingLot]:
    lot_owner = await _require_lot_owner_profile(db, current_user)
    lots_result = await db.execute(
        select(ParkingLot)
        .where(ParkingLot.lot_owner_id == lot_owner.id)
        .order_by(ParkingLot.created_at.desc(), ParkingLot.id.desc())
    )
    return list(lots_result.scalars().all())


@router.post("/user/me/parking-lots", response_model=ParkingLotRead, status_code=201)
async def create_my_parking_lot(
    request: Request,
    payload: ParkingLotCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> ParkingLot:
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
    return parking_lot


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
