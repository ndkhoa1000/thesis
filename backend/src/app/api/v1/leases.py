import calendar
from datetime import UTC, date, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from ...api.dependencies import get_current_user
from ...core.db.database import async_get_db
from ...core.exceptions.http_exceptions import BadRequestException, NotFoundException
from ...models.enums import LeaseContractStatus, LeaseStatus, ParkingLotStatus
from ...models.leases import LeaseContract, LotLease
from ...models.parking import ParkingLot
from ...models.user import User
from ...models.users import LotOwner, Manager
from ...schemas.lease_contract import LeaseContractCreate, LeaseContractRead
from .lots import _get_manager_user, _get_parking_lot, _require_lot_owner_profile, _require_manager_profile, _utcnow

router = APIRouter(tags=["leases"])

OperatorUser = aliased(User)
OwnerUser = aliased(User)


def _add_months(start_date: date, months: int) -> date:
    year = start_date.year + (start_date.month - 1 + months) // 12
    month = (start_date.month - 1 + months) % 12 + 1
    day = min(start_date.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)


def _build_contract_number(parking_lot_id: int, lease_id: int) -> str:
    timestamp = _utcnow().strftime("%Y%m%d%H%M%S")
    return f"LC-{parking_lot_id}-{lease_id}-{timestamp}"


def _build_contract_content(
    parking_lot: ParkingLot,
    owner_user: User,
    operator_user: User,
    lease: LotLease,
    additional_terms: str | None,
) -> str:
    terms_block = additional_terms or "No additional terms were provided for this thesis MVP contract."
    return (
        f"<h1>Lease Contract</h1>"
        f"<p>Parking lot: {parking_lot.name}</p>"
        f"<p>Owner: {owner_user.name}</p>"
        f"<p>Operator: {operator_user.name}</p>"
        f"<p>Monthly fee: {float(lease.monthly_fee):.2f}</p>"
        f"<p>Revenue split (owner share): {float(lease.revenue_share_percentage):.2f}%</p>"
        f"<p>Contract term: {lease.term_months} month(s)</p>"
        f"<p>Terms: {terms_block}</p>"
    )


def _build_contract_read(
    lease: LotLease,
    contract: LeaseContract,
    parking_lot: ParkingLot,
    owner_user: User,
    operator_user: User,
) -> LeaseContractRead:
    start_date = _as_date(lease.start_date)
    end_date = _as_date(lease.end_date)
    return LeaseContractRead.model_validate(
        {
            "contract_id": contract.id,
            "lease_id": lease.id,
            "parking_lot_id": parking_lot.id,
            "parking_lot_name": parking_lot.name,
            "manager_id": lease.manager_id,
            "manager_user_id": operator_user.id,
            "operator_name": operator_user.name,
            "operator_email": operator_user.email,
            "owner_name": owner_user.name,
            "owner_email": owner_user.email,
            "lease_status": lease.status,
            "contract_status": contract.status,
            "monthly_fee": float(lease.monthly_fee),
            "revenue_share_percentage": float(lease.revenue_share_percentage),
            "term_months": lease.term_months,
            "contract_number": contract.contract_number,
            "content": contract.content,
            "generated_at": contract.generated_at,
            "start_date": start_date,
            "end_date": end_date,
        }
    )


def _as_date(value: datetime | date | None) -> date | None:
    if isinstance(value, datetime):
        return value.date()
    return value


def _as_utc_datetime(value: date) -> datetime:
    return datetime(value.year, value.month, value.day, tzinfo=UTC)


async def _get_owner_user(db: AsyncSession, lot_owner_id: int) -> User | None:
    owner_result = await db.execute(
        select(User)
        .join(LotOwner, LotOwner.user_id == User.id)
        .where(LotOwner.id == lot_owner_id, User.is_deleted.is_(False))
        .limit(1)
    )
    return owner_result.scalar_one_or_none()


async def _expire_lease_if_needed(db: AsyncSession, lease: LotLease, contract: LeaseContract) -> None:
    if lease.status != LeaseStatus.ACTIVE.value or lease.end_date is None:
        return
    today = _utcnow().date()
    lease_end = lease.end_date.date() if hasattr(lease.end_date, "date") else lease.end_date
    if lease_end is None or lease_end >= today:
        return

    lease.status = LeaseStatus.EXPIRED.value
    if contract.status == LeaseContractStatus.ACTIVE.value:
        contract.status = LeaseContractStatus.EXPIRED.value
    await db.commit()
    await db.refresh(lease)
    await db.refresh(contract)


async def _get_contract_bundle_for_operator(
    db: AsyncSession,
    lease_id: int,
    manager_id: int,
) -> tuple[LotLease, LeaseContract, ParkingLot, User, User] | None:
    contract_result = await db.execute(
        select(LotLease, LeaseContract, ParkingLot, OperatorUser, OwnerUser)
        .join(LeaseContract, LeaseContract.lease_id == LotLease.id)
        .join(ParkingLot, ParkingLot.id == LotLease.parking_lot_id)
        .join(Manager, Manager.id == LotLease.manager_id)
        .join(OperatorUser, Manager.user_id == OperatorUser.id)
        .join(LotOwner, LotOwner.id == ParkingLot.lot_owner_id)
        .join(OwnerUser, LotOwner.user_id == OwnerUser.id)
        .where(
            LotLease.id == lease_id,
            LotLease.manager_id == manager_id,
            OperatorUser.is_deleted.is_(False),
            OwnerUser.is_deleted.is_(False),
        )
        .limit(1)
    )
    row = contract_result.one_or_none()
    return tuple(row) if row is not None else None


async def _get_existing_open_lease(db: AsyncSession, parking_lot_id: int) -> LotLease | None:
    existing_lease_result = await db.execute(
        select(LotLease)
        .where(
            LotLease.parking_lot_id == parking_lot_id,
            LotLease.status.in_([LeaseStatus.PENDING.value, LeaseStatus.ACTIVE.value]),
        )
        .order_by(LotLease.created_at.desc(), LotLease.id.desc())
        .limit(1)
    )
    return existing_lease_result.scalar_one_or_none()


@router.post(
    "/leases/owner/parking-lots/{parking_lot_id}/contracts",
    response_model=LeaseContractRead,
    status_code=201,
)
async def create_owner_lease_contract(
    request: Request,
    parking_lot_id: int,
    payload: LeaseContractCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> LeaseContractRead:
    lot_owner = await _require_lot_owner_profile(db, current_user)
    parking_lot = await _get_parking_lot(db, parking_lot_id)
    if parking_lot is None or parking_lot.lot_owner_id != lot_owner.id:
        raise NotFoundException("Parking lot not found")
    if parking_lot.status != ParkingLotStatus.APPROVED.value:
        raise BadRequestException("Only approved parking lots can create lease contracts")

    existing_lease = await _get_existing_open_lease(db, parking_lot.id)
    if existing_lease is not None:
        raise BadRequestException("Parking lot already has an open lease workflow")

    manager_pair = await _get_manager_user(db, payload.manager_user_id)
    if manager_pair is None:
        raise NotFoundException("Operator not found")

    manager, operator_user = manager_pair
    owner_user = await _get_owner_user(db, lot_owner.id)
    if owner_user is None:
        raise NotFoundException("Lot owner not found")

    lease = LotLease(
        parking_lot_id=parking_lot.id,
        manager_id=manager.id,
        monthly_fee=payload.monthly_fee,
        revenue_share_percentage=payload.revenue_share_percentage,
        term_months=payload.term_months,
        status=LeaseStatus.PENDING.value,
    )
    db.add(lease)
    await db.flush()

    contract = LeaseContract(
        lease_id=lease.id,
        contract_number=_build_contract_number(parking_lot.id, lease.id),
        content=_build_contract_content(parking_lot, owner_user, operator_user, lease, payload.additional_terms),
        generated_by=current_user["id"],
        status=LeaseContractStatus.DRAFT.value,
    )
    db.add(contract)
    await db.commit()
    await db.refresh(lease)
    await db.refresh(contract)
    return _build_contract_read(lease, contract, parking_lot, owner_user, operator_user)


@router.get(
    "/leases/operator/contracts",
    response_model=list[LeaseContractRead],
)
async def list_operator_lease_contracts(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> list[LeaseContractRead]:
    manager = await _require_manager_profile(db, current_user)
    contracts_result = await db.execute(
        select(LotLease, LeaseContract, ParkingLot, OperatorUser, OwnerUser)
        .join(LeaseContract, LeaseContract.lease_id == LotLease.id)
        .join(ParkingLot, ParkingLot.id == LotLease.parking_lot_id)
        .join(Manager, Manager.id == LotLease.manager_id)
        .join(OperatorUser, Manager.user_id == OperatorUser.id)
        .join(LotOwner, LotOwner.id == ParkingLot.lot_owner_id)
        .join(OwnerUser, LotOwner.user_id == OwnerUser.id)
        .where(LotLease.manager_id == manager.id)
        .order_by(LotLease.created_at.desc(), LotLease.id.desc())
    )

    results: list[LeaseContractRead] = []
    for lease, contract, parking_lot, operator_user, owner_user in contracts_result.all():
        await _expire_lease_if_needed(db, lease, contract)
        results.append(_build_contract_read(lease, contract, parking_lot, owner_user, operator_user))
    return results


@router.post(
    "/leases/operator/contracts/{lease_id}/accept",
    response_model=LeaseContractRead,
)
async def accept_operator_lease_contract(
    request: Request,
    lease_id: int,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> LeaseContractRead:
    manager = await _require_manager_profile(db, current_user)
    bundle = await _get_contract_bundle_for_operator(db, lease_id, manager.id)
    if bundle is None:
        raise NotFoundException("Lease contract not found")

    lease, contract, parking_lot, operator_user, owner_user = bundle
    await _expire_lease_if_needed(db, lease, contract)
    if lease.status != LeaseStatus.PENDING.value or contract.status != LeaseContractStatus.DRAFT.value:
        raise BadRequestException("Lease contract is no longer pending acceptance")

    competing_lease = await db.execute(
        select(LotLease)
        .where(
            LotLease.parking_lot_id == parking_lot.id,
            LotLease.status == LeaseStatus.ACTIVE.value,
            LotLease.id != lease.id,
        )
        .limit(1)
    )
    if competing_lease.scalar_one_or_none() is not None:
        raise BadRequestException("Parking lot already has an active operator lease")

    start_date = _utcnow().date()
    lease.start_date = _as_utc_datetime(start_date)
    lease.end_date = _as_utc_datetime(_add_months(start_date, lease.term_months))
    lease.status = LeaseStatus.ACTIVE.value
    lease.approved_by = current_user["id"]
    contract.status = LeaseContractStatus.ACTIVE.value
    await db.commit()
    await db.refresh(lease)
    await db.refresh(contract)
    return _build_contract_read(lease, contract, parking_lot, owner_user, operator_user)
