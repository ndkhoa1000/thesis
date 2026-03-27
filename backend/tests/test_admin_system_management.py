"""Unit tests for Story 2-3 admin user management and lot suspension flows."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.lots import patch_parking_lot_status
from src.app.api.v1.users import patch_admin_user_activation, read_admin_users
from src.app.core.exceptions.http_exceptions import BadRequestException, NotFoundException
from src.app.models.enums import ParkingLotStatus, UserRole
from src.app.models.parking import ParkingLot
from src.app.models.user import User
from src.app.schemas.parking_lot import ParkingLotStatusUpdate
from src.app.schemas.user import AdminUserActivationUpdate, AdminUserRead


def _admin_user(user_id: int = 99) -> dict:
    return {
        "id": user_id,
        "username": "admin",
        "email": "admin@test.com",
        "role": "ADMIN",
        "is_superuser": True,
    }


def _managed_user(user_id: int = 10, is_active: bool = True) -> User:
    user = MagicMock(spec=User)
    user.id = user_id
    user.name = "Nguyen Van A"
    user.username = "nguyenvana"
    user.email = "nguyenvana@example.com"
    user.phone = "0909123456"
    user.role = UserRole.DRIVER.value
    user.is_active = is_active
    user.is_superuser = False
    user.created_at = datetime.now(UTC)
    user.updated_at = None
    return user


def _parking_lot(
    lot_id: int = 7,
    lot_owner_id: int = 3,
    status: str = ParkingLotStatus.APPROVED.value,
) -> ParkingLot:
    parking_lot = MagicMock(spec=ParkingLot)
    parking_lot.id = lot_id
    parking_lot.lot_owner_id = lot_owner_id
    parking_lot.name = "Bai xe Nguyen Hue"
    parking_lot.address = "1 Nguyen Hue, Quan 1"
    parking_lot.latitude = 10.7732
    parking_lot.longitude = 106.7041
    parking_lot.current_available = 12
    parking_lot.status = status
    parking_lot.description = "Gan trung tam"
    parking_lot.cover_image = None
    parking_lot.created_at = datetime.now(UTC)
    parking_lot.updated_at = None
    return parking_lot


class TestAdminUsers:
    def test_admin_user_schema_supports_orm_objects(self):
        result = AdminUserRead.model_validate(_managed_user())

        assert result.username == "nguyenvana"
        assert result.is_active is True

    @pytest.mark.asyncio
    async def test_read_admin_users_returns_records(self, mock_db):
        users_result = MagicMock()
        users_result.scalars.return_value.all.return_value = [_managed_user()]
        mock_db.execute = AsyncMock(return_value=users_result)

        result = await read_admin_users(Mock(), _admin_user(), mock_db)

        assert len(result) == 1
        assert result[0].email == "nguyenvana@example.com"

    @pytest.mark.asyncio
    async def test_patch_admin_user_activation_deactivates_account(self, mock_db):
        user = _managed_user(is_active=True)
        user_result = MagicMock()
        user_result.scalar_one_or_none.return_value = user
        mock_db.execute = AsyncMock(return_value=user_result)
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        payload = AdminUserActivationUpdate(is_active=False)
        result = await patch_admin_user_activation(Mock(), user.id, payload, _admin_user(), mock_db)

        assert result.is_active is False
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_patch_admin_user_activation_rejects_self_deactivation(self, mock_db):
        user = _managed_user(user_id=99, is_active=True)
        user_result = MagicMock()
        user_result.scalar_one_or_none.return_value = user
        mock_db.execute = AsyncMock(return_value=user_result)

        with pytest.raises(BadRequestException, match="current account"):
            await patch_admin_user_activation(
                Mock(),
                user.id,
                AdminUserActivationUpdate(is_active=False),
                _admin_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_patch_admin_user_activation_raises_not_found(self, mock_db):
        user_result = MagicMock()
        user_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=user_result)

        with pytest.raises(NotFoundException, match="User not found"):
            await patch_admin_user_activation(
                Mock(),
                404,
                AdminUserActivationUpdate(is_active=True),
                _admin_user(),
                mock_db,
            )


class TestAdminParkingLotManagement:
    @pytest.mark.asyncio
    async def test_patch_parking_lot_status_suspends_approved_lot(self, mock_db):
        parking_lot = _parking_lot(status=ParkingLotStatus.APPROVED.value)
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = parking_lot
        owner_result = MagicMock()
        owner_result.one_or_none.return_value = ("Nguyen Van A", "0909123456", "BL-001")
        mock_db.execute = AsyncMock(side_effect=[parking_lot_result, owner_result])
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        result = await patch_parking_lot_status(
            Mock(),
            parking_lot.id,
            ParkingLotStatusUpdate(status=ParkingLotStatus.CLOSED),
            _admin_user(),
            mock_db,
        )

        assert result.status == ParkingLotStatus.CLOSED.value
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_patch_parking_lot_status_reopens_suspended_lot(self, mock_db):
        parking_lot = _parking_lot(status=ParkingLotStatus.CLOSED.value)
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = parking_lot
        owner_result = MagicMock()
        owner_result.one_or_none.return_value = ("Nguyen Van A", "0909123456", "BL-001")
        mock_db.execute = AsyncMock(side_effect=[parking_lot_result, owner_result])
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        result = await patch_parking_lot_status(
            Mock(),
            parking_lot.id,
            ParkingLotStatusUpdate(status=ParkingLotStatus.APPROVED),
            _admin_user(),
            mock_db,
        )

        assert result.status == ParkingLotStatus.APPROVED.value

    @pytest.mark.asyncio
    async def test_patch_parking_lot_status_rejects_non_approved_suspension(self, mock_db):
        parking_lot = _parking_lot(status=ParkingLotStatus.PENDING.value)
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = parking_lot
        mock_db.execute = AsyncMock(return_value=parking_lot_result)

        with pytest.raises(BadRequestException, match="approved parking lots"):
            await patch_parking_lot_status(
                Mock(),
                parking_lot.id,
                ParkingLotStatusUpdate(status=ParkingLotStatus.CLOSED),
                _admin_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_patch_parking_lot_status_raises_not_found(self, mock_db):
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=parking_lot_result)

        with pytest.raises(NotFoundException, match="Parking lot not found"):
            await patch_parking_lot_status(
                Mock(),
                404,
                ParkingLotStatusUpdate(status=ParkingLotStatus.CLOSED),
                _admin_user(),
                mock_db,
            )