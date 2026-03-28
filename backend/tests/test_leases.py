"""Unit tests for Epic 8 lease contract lifecycle."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.leases import accept_operator_lease_contract, create_owner_lease_contract, list_operator_lease_contracts
from src.app.core.exceptions.http_exceptions import BadRequestException, NotFoundException
from src.app.models.enums import LeaseContractStatus, LeaseStatus, ParkingLotStatus
from src.app.models.leases import LeaseContract, LotLease
from src.app.models.parking import ParkingLot
from src.app.models.user import User
from src.app.models.users import LotOwner, Manager
from src.app.schemas.lease_contract import LeaseContractCreate


def _public_user(user_id: int = 1, role: str = "LOT_OWNER") -> dict:
    return {
        "id": user_id,
        "username": "owner_user",
        "email": "owner@test.com",
        "role": role,
        "is_superuser": False,
    }


def _lot_owner_profile(profile_id: int = 3, user_id: int = 1) -> LotOwner:
    profile = MagicMock(spec=LotOwner)
    profile.id = profile_id
    profile.user_id = user_id
    return profile


def _manager_profile(profile_id: int = 4, user_id: int = 9) -> Manager:
    profile = MagicMock(spec=Manager)
    profile.id = profile_id
    profile.user_id = user_id
    return profile


def _user(user_id: int, name: str, email: str) -> User:
    user = MagicMock(spec=User)
    user.id = user_id
    user.name = name
    user.email = email
    user.is_deleted = False
    user.is_active = True
    return user


def _parking_lot(lot_id: int = 7, lot_owner_id: int = 3, status: str = ParkingLotStatus.APPROVED.value) -> ParkingLot:
    parking_lot = MagicMock(spec=ParkingLot)
    parking_lot.id = lot_id
    parking_lot.lot_owner_id = lot_owner_id
    parking_lot.name = "Bai xe Nguyen Hue"
    parking_lot.status = status
    return parking_lot


def _lease(lease_id: int = 18, parking_lot_id: int = 7, manager_id: int = 4, status: str = LeaseStatus.PENDING.value) -> LotLease:
    lease = MagicMock(spec=LotLease)
    lease.id = lease_id
    lease.parking_lot_id = parking_lot_id
    lease.manager_id = manager_id
    lease.monthly_fee = 15000000
    lease.revenue_share_percentage = 35
    lease.term_months = 6
    lease.status = status
    lease.start_date = None
    lease.end_date = None
    lease.created_at = datetime.now(UTC)
    lease.approved_by = None
    return lease


def _contract(contract_id: int = 41, lease_id: int = 18, status: str = LeaseContractStatus.DRAFT.value) -> LeaseContract:
    contract = MagicMock(spec=LeaseContract)
    contract.id = contract_id
    contract.lease_id = lease_id
    contract.contract_number = "LC-7-18-20260328120000"
    contract.content = "<h1>Lease Contract</h1>"
    contract.generated_at = datetime.now(UTC)
    contract.status = status
    return contract


class TestLeaseContracts:
    @pytest.mark.asyncio
    async def test_create_owner_lease_contract_success(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = _parking_lot()
        open_lease_result = MagicMock()
        open_lease_result.scalar_one_or_none.return_value = None
        manager_result = MagicMock()
        manager_result.one_or_none.return_value = (_manager_profile(), _user(9, "Tran Thi B", "operator@test.com"))
        owner_user_result = MagicMock()
        owner_user_result.scalar_one_or_none.return_value = _user(1, "Nguyen Van A", "owner@test.com")

        mock_db.execute = AsyncMock(
            side_effect=[owner_result, parking_lot_result, open_lease_result, manager_result, owner_user_result]
        )
        mock_db.add = Mock()
        mock_db.flush = AsyncMock(side_effect=lambda: None)
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock(
            side_effect=lambda entity: setattr(entity, "id", 18 if isinstance(entity, LotLease) else 41)
        )

        payload = LeaseContractCreate(
            manager_user_id=9,
            monthly_fee=15000000,
            revenue_share_percentage=35,
            term_months=6,
            additional_terms="Operator manages the lot under owner oversight.",
        )

        result = await create_owner_lease_contract(Mock(), 7, payload, _public_user(), mock_db)

        assert result.lease_status == LeaseStatus.PENDING.value
        assert result.contract_status == LeaseContractStatus.DRAFT.value
        assert result.revenue_share_percentage == 35
        assert result.term_months == 6
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_create_owner_lease_contract_rejects_existing_open_lease(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = _parking_lot()
        open_lease_result = MagicMock()
        open_lease_result.scalar_one_or_none.return_value = _lease(status=LeaseStatus.ACTIVE.value)
        mock_db.execute = AsyncMock(side_effect=[owner_result, parking_lot_result, open_lease_result])

        payload = LeaseContractCreate(
            manager_user_id=9,
            monthly_fee=15000000,
            revenue_share_percentage=35,
            term_months=6,
        )

        with pytest.raises(BadRequestException, match="open lease workflow"):
            await create_owner_lease_contract(Mock(), 7, payload, _public_user(), mock_db)

    @pytest.mark.asyncio
    async def test_accept_operator_lease_contract_success(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        bundle_result = MagicMock()
        bundle_result.one_or_none.return_value = (
            _lease(),
            _contract(),
            _parking_lot(),
            _user(9, "Tran Thi B", "operator@test.com"),
            _user(1, "Nguyen Van A", "owner@test.com"),
        )
        competing_result = MagicMock()
        competing_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(side_effect=[manager_result, bundle_result, competing_result])
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        result = await accept_operator_lease_contract(Mock(), 18, _public_user(role="MANAGER", user_id=9), mock_db)

        assert result.lease_status == LeaseStatus.ACTIVE.value
        assert result.contract_status == LeaseContractStatus.ACTIVE.value
        assert result.start_date is not None
        assert result.end_date is not None

    @pytest.mark.asyncio
    async def test_accept_operator_lease_contract_rejects_missing_contract(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        bundle_result = MagicMock()
        bundle_result.one_or_none.return_value = None
        mock_db.execute = AsyncMock(side_effect=[manager_result, bundle_result])

        with pytest.raises(NotFoundException, match="Lease contract not found"):
            await accept_operator_lease_contract(Mock(), 404, _public_user(role="MANAGER", user_id=9), mock_db)

    @pytest.mark.asyncio
    async def test_list_operator_lease_contracts_returns_pending_and_active_contracts(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        contracts_result = MagicMock()
        contracts_result.all.return_value = [
            (
                _lease(status=LeaseStatus.PENDING.value),
                _contract(status=LeaseContractStatus.DRAFT.value),
                _parking_lot(),
                _user(9, "Tran Thi B", "operator@test.com"),
                _user(1, "Nguyen Van A", "owner@test.com"),
            )
        ]
        mock_db.execute = AsyncMock(side_effect=[manager_result, contracts_result])

        result = await list_operator_lease_contracts(Mock(), _public_user(role="MANAGER", user_id=9), mock_db)

        assert len(result) == 1
        assert result[0].lease_status == LeaseStatus.PENDING.value
        assert result[0].operator_name == "Tran Thi B"