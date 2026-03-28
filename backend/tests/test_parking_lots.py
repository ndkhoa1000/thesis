"""Unit tests for parking lot registration and admin review flows (Story 2-1)."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.lots import (
    bootstrap_parking_lot_lease,
    create_my_parking_lot,
    list_available_operators,
    list_lots,
    read_my_parking_lots,
    read_parking_lot_applications,
    review_parking_lot,
)
from src.app.core.exceptions.http_exceptions import BadRequestException, ForbiddenException, NotFoundException
from src.app.models.enums import LeaseStatus, ParkingLotStatus
from src.app.models.leases import LotLease
from src.app.models.parking import ParkingLot
from src.app.models.user import User
from src.app.models.users import LotOwner, Manager
from src.app.schemas.parking_lot import ParkingLotLeaseBootstrapCreate
from src.app.schemas.parking_lot import ParkingLotAdminRead, ParkingLotCreate, ParkingLotRead, ParkingLotReview


def _public_user(user_id: int = 1, role: str = "LOT_OWNER") -> dict:
    return {
        "id": user_id,
        "username": "lot_owner",
        "email": "owner@test.com",
        "role": role,
        "is_superuser": False,
    }


def _admin_user(user_id: int = 99) -> dict:
    return {
        "id": user_id,
        "username": "admin",
        "email": "admin@test.com",
        "role": "ADMIN",
        "is_superuser": True,
    }


def _lot_owner_profile(profile_id: int = 3, user_id: int = 1) -> LotOwner:
    profile = MagicMock(spec=LotOwner)
    profile.id = profile_id
    profile.user_id = user_id
    profile.business_license = "BL-001"
    profile.verified_at = datetime.now(UTC)
    return profile


def _manager_profile(profile_id: int = 4, user_id: int = 9) -> Manager:
    profile = MagicMock(spec=Manager)
    profile.id = profile_id
    profile.user_id = user_id
    profile.business_license = "OP-001"
    profile.verified_at = datetime.now(UTC)
    return profile


def _manager_user(user_id: int = 9, name: str = "Tran Thi B") -> User:
    user = MagicMock(spec=User)
    user.id = user_id
    user.name = name
    user.email = "operator@test.com"
    user.phone = "0909555666"
    user.is_active = True
    user.is_deleted = False
    return user


def _parking_lot(
    lot_id: int = 7,
    lot_owner_id: int = 3,
    status: str = ParkingLotStatus.PENDING.value,
) -> ParkingLot:
    parking_lot = MagicMock(spec=ParkingLot)
    parking_lot.id = lot_id
    parking_lot.lot_owner_id = lot_owner_id
    parking_lot.name = "Bai xe Nguyen Hue"
    parking_lot.address = "1 Nguyen Hue, Quan 1"
    parking_lot.latitude = 10.7732
    parking_lot.longitude = 106.7041
    parking_lot.current_available = 0
    parking_lot.status = status
    parking_lot.description = "Gan trung tam"
    parking_lot.cover_image = None
    parking_lot.created_at = datetime.now(UTC)
    parking_lot.updated_at = None
    return parking_lot


def _lease(lease_id: int = 21, parking_lot_id: int = 7, manager_id: int = 4) -> LotLease:
    lease = MagicMock(spec=LotLease)
    lease.id = lease_id
    lease.parking_lot_id = parking_lot_id
    lease.manager_id = manager_id
    lease.monthly_fee = 0
    lease.status = LeaseStatus.ACTIVE.value
    lease.start_date = datetime.now(UTC).date()
    lease.end_date = None
    lease.created_at = datetime.now(UTC)
    return lease


class TestPublicParkingLots:
    def test_read_schema_supports_orm_objects(self):
        parking_lot = _parking_lot(status=ParkingLotStatus.APPROVED.value)

        result = ParkingLotRead.model_validate(parking_lot)

        assert result.id == parking_lot.id
        assert result.status == parking_lot.status

    @pytest.mark.asyncio
    async def test_list_public_lots_returns_only_approved_records(self, mock_db):
        approved_lot = _parking_lot(status=ParkingLotStatus.APPROVED.value)
        lots_result = MagicMock()
        lots_result.scalars.return_value.all.return_value = [approved_lot]
        mock_db.execute = AsyncMock(return_value=lots_result)

        result = await list_lots(Mock(), mock_db)

        assert result == [approved_lot]

    @pytest.mark.asyncio
    async def test_list_public_lots_exposes_marker_summary_fields(self, mock_db):
        approved_lot = _parking_lot(status=ParkingLotStatus.APPROVED.value)
        approved_lot.current_available = 12
        lots_result = MagicMock()
        lots_result.scalars.return_value.all.return_value = [approved_lot]
        mock_db.execute = AsyncMock(return_value=lots_result)

        result = await list_lots(Mock(), mock_db)
        marker_summary = ParkingLotRead.model_validate(result[0])

        assert marker_summary.id == approved_lot.id
        assert marker_summary.name == approved_lot.name
        assert marker_summary.latitude == approved_lot.latitude
        assert marker_summary.longitude == approved_lot.longitude
        assert marker_summary.current_available == 12
        assert marker_summary.status == ParkingLotStatus.APPROVED.value


class TestLotOwnerParkingLots:
    @pytest.mark.asyncio
    async def test_read_my_parking_lots_returns_owned_lots(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        lots_result = MagicMock()
        lots_result.scalars.return_value.all.return_value = [_parking_lot()]
        active_lease_result = MagicMock()
        active_lease_result.one_or_none.return_value = None
        mock_db.execute = AsyncMock(side_effect=[owner_result, lots_result, active_lease_result])

        result = await read_my_parking_lots(Mock(), _public_user(), mock_db)

        assert len(result) == 1
        assert result[0].name == "Bai xe Nguyen Hue"

    @pytest.mark.asyncio
    async def test_create_my_parking_lot_success(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        mock_db.execute = AsyncMock(return_value=owner_result)
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock(side_effect=lambda parking_lot: setattr(parking_lot, "id", 17))

        payload = ParkingLotCreate(
            name="Bai xe Ben Thanh",
            address="45 Le Loi, Quan 1",
            latitude=10.7729,
            longitude=106.6983,
            description="Co camera va che mua",
            cover_image=None,
        )

        result = await create_my_parking_lot(Mock(), payload, _public_user(), mock_db)

        assert result.lot_owner_id == 3
        assert result.status == ParkingLotStatus.PENDING.value
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_create_requires_lot_owner_capability(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=owner_result)

        payload = ParkingLotCreate(
            name="Bai xe Ben Thanh",
            address="45 Le Loi, Quan 1",
            latitude=10.7729,
            longitude=106.6983,
        )

        with pytest.raises(ForbiddenException, match="Lot owner capability"):
            await create_my_parking_lot(Mock(), payload, _public_user(), mock_db)

    @pytest.mark.asyncio
    async def test_list_available_operators_returns_verified_profiles(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        operators_result = MagicMock()
        operators_result.all.return_value = [(_manager_profile(), _manager_user())]
        mock_db.execute = AsyncMock(side_effect=[owner_result, operators_result])

        result = await list_available_operators(Mock(), _public_user(), mock_db)

        assert len(result) == 1
        assert result[0].user_id == 9
        assert result[0].name == "Tran Thi B"

    @pytest.mark.asyncio
    async def test_bootstrap_parking_lot_lease_success(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _parking_lot(
            status=ParkingLotStatus.APPROVED.value,
        )
        existing_lease_result = MagicMock()
        existing_lease_result.one_or_none.return_value = None
        manager_result = MagicMock()
        manager_result.one_or_none.return_value = (_manager_profile(), _manager_user())
        mock_db.execute = AsyncMock(
            side_effect=[
                owner_result,
                lot_result,
                existing_lease_result,
                manager_result,
            ]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock(side_effect=lambda lease: setattr(lease, "id", 21))

        payload = ParkingLotLeaseBootstrapCreate(manager_user_id=9, monthly_fee=0)

        result = await bootstrap_parking_lot_lease(Mock(), 7, payload, _public_user(), mock_db)

        assert result.status == LeaseStatus.ACTIVE.value
        assert result.operator_name == "Tran Thi B"
        mock_db.add.assert_called_once()
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_bootstrap_parking_lot_lease_requires_approved_lot(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _parking_lot(
            status=ParkingLotStatus.PENDING.value,
        )
        mock_db.execute = AsyncMock(side_effect=[owner_result, lot_result])

        payload = ParkingLotLeaseBootstrapCreate(manager_user_id=9, monthly_fee=0)

        with pytest.raises(BadRequestException, match="Only approved parking lots"):
            await bootstrap_parking_lot_lease(Mock(), 7, payload, _public_user(), mock_db)


class TestAdminParkingLotApprovals:
    def test_admin_read_schema_supports_marshaled_records(self):
        parking_lot = _parking_lot()

        result = ParkingLotAdminRead.model_validate(
            {
                "id": parking_lot.id,
                "lot_owner_id": parking_lot.lot_owner_id,
                "name": parking_lot.name,
                "address": parking_lot.address,
                "latitude": parking_lot.latitude,
                "longitude": parking_lot.longitude,
                "current_available": parking_lot.current_available,
                "status": parking_lot.status,
                "description": parking_lot.description,
                "cover_image": parking_lot.cover_image,
                "created_at": parking_lot.created_at,
                "updated_at": parking_lot.updated_at,
                "owner_name": "Nguyen Van A",
                "owner_phone": "0909123456",
                "owner_business_license": "BL-001",
            }
        )

        assert result.owner_name == "Nguyen Van A"

    @pytest.mark.asyncio
    async def test_read_admin_parking_lot_list(self, mock_db):
        lots_result = MagicMock()
        lots_result.all.return_value = [
            (_parking_lot(), "Nguyen Van A", "0909123456", "BL-001"),
        ]
        mock_db.execute = AsyncMock(return_value=lots_result)

        result = await read_parking_lot_applications(Mock(), _admin_user(), mock_db)

        assert len(result) == 1
        assert result[0].owner_name == "Nguyen Van A"

    @pytest.mark.asyncio
    async def test_approve_pending_parking_lot(self, mock_db):
        parking_lot = _parking_lot(status=ParkingLotStatus.PENDING.value)
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = parking_lot
        mock_db.execute = AsyncMock(return_value=parking_lot_result)
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        payload = ParkingLotReview(decision=ParkingLotStatus.APPROVED)
        result = await review_parking_lot(Mock(), 7, payload, _admin_user(), mock_db)

        assert result.status == ParkingLotStatus.APPROVED.value
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_reject_parking_lot_requires_reason(self, mock_db):
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = _parking_lot()
        mock_db.execute = AsyncMock(return_value=parking_lot_result)

        payload = ParkingLotReview(
            decision=ParkingLotStatus.REJECTED,
            rejection_reason=None,
        )

        with pytest.raises(BadRequestException, match="Rejection reason"):
            await review_parking_lot(Mock(), 7, payload, _admin_user(), mock_db)

    @pytest.mark.asyncio
    async def test_review_non_pending_parking_lot_raises_bad_request(self, mock_db):
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = _parking_lot(
            status=ParkingLotStatus.APPROVED.value,
        )
        mock_db.execute = AsyncMock(return_value=parking_lot_result)

        payload = ParkingLotReview(
            decision=ParkingLotStatus.REJECTED,
            rejection_reason="Sai thong tin",
        )

        with pytest.raises(BadRequestException, match="Only pending"):
            await review_parking_lot(Mock(), 7, payload, _admin_user(), mock_db)

    @pytest.mark.asyncio
    async def test_review_missing_parking_lot_raises_not_found(self, mock_db):
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=parking_lot_result)

        payload = ParkingLotReview(decision=ParkingLotStatus.APPROVED)

        with pytest.raises(NotFoundException, match="Parking lot not found"):
            await review_parking_lot(Mock(), 7, payload, _admin_user(), mock_db)