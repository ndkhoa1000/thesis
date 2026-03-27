"""Unit tests for Story 3-3 operator attendant account provisioning flows."""

from datetime import UTC, date, datetime
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.lots import (
    create_operator_lot_attendant,
    read_operator_lot_attendants,
    remove_operator_lot_attendant,
)
from src.app.core.exceptions.http_exceptions import DuplicateValueException, NotFoundException
from src.app.models.enums import LeaseStatus, UserRole
from src.app.models.leases import LotLease
from src.app.models.user import User
from src.app.models.users import Attendant, Manager
from src.app.schemas.parking_lot import OperatorManagedAttendantCreate


def _manager_user(user_id: int = 21) -> dict:
    return {
        "id": user_id,
        "username": "operator",
        "email": "operator@test.com",
        "role": UserRole.MANAGER.value,
        "is_superuser": False,
    }


def _manager_profile(manager_id: int = 8, user_id: int = 21) -> Manager:
    manager = MagicMock(spec=Manager)
    manager.id = manager_id
    manager.user_id = user_id
    return manager


def _active_lease(lease_id: int = 4, parking_lot_id: int = 13, manager_id: int = 8) -> LotLease:
    lease = MagicMock(spec=LotLease)
    lease.id = lease_id
    lease.parking_lot_id = parking_lot_id
    lease.manager_id = manager_id
    lease.status = LeaseStatus.ACTIVE.value
    lease.created_at = datetime.now(UTC)
    return lease


def _attendant_user(user_id: int = 31) -> User:
    user = MagicMock(spec=User)
    user.id = user_id
    user.name = "Le Thi Truc"
    user.username = "lethitruc"
    user.email = "truc@example.com"
    user.phone = "0909123456"
    user.is_active = True
    user.created_at = datetime.now(UTC)
    return user


def _attendant_profile(attendant_id: int = 41, parking_lot_id: int = 13, user_id: int = 31) -> Attendant:
    attendant = MagicMock(spec=Attendant)
    attendant.id = attendant_id
    attendant.user_id = user_id
    attendant.parking_lot_id = parking_lot_id
    attendant.hired_at = date(2026, 3, 27)
    return attendant


class TestOperatorAttendantManagement:
    @pytest.mark.asyncio
    async def test_read_operator_lot_attendants_returns_active_lot_staff(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.scalar_one_or_none.return_value = _active_lease()
        attendants_result = MagicMock()
        attendants_result.all.return_value = [(_attendant_profile(), _attendant_user())]
        mock_db.execute = AsyncMock(
            side_effect=[manager_result, lease_result, attendants_result]
        )

        result = await read_operator_lot_attendants(Mock(), 13, _manager_user(), mock_db)

        assert len(result) == 1
        assert result[0].email == "truc@example.com"
        assert result[0].parking_lot_id == 13

    @pytest.mark.asyncio
    async def test_create_operator_lot_attendant_provisions_dedicated_credentials(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.scalar_one_or_none.return_value = _active_lease()
        created_user = _attendant_user()
        mock_db.execute = AsyncMock(side_effect=[manager_result, lease_result])
        mock_db.add = Mock(side_effect=lambda instance: None)
        mock_db.commit = AsyncMock()

        async def refresh_side_effect(instance):
            if isinstance(instance, Attendant):
                instance.id = 41

        mock_db.refresh = AsyncMock(side_effect=refresh_side_effect)

        with pytest.MonkeyPatch.context() as monkeypatch:
            monkeypatch.setattr(
                "src.app.api.v1.lots.crud_users.exists",
                AsyncMock(side_effect=[False, False]),
            )
            monkeypatch.setattr(
                "src.app.api.v1.lots.crud_users.create",
                AsyncMock(return_value=created_user),
            )
            monkeypatch.setattr(
                "src.app.api.v1.lots.get_password_hash",
                Mock(return_value="hashed-password"),
            )

            payload = OperatorManagedAttendantCreate(
                name="Le Thi Truc",
                username="lethitruc",
                email="truc@example.com",
                password="Str1ngst!123",
                phone="0909123456",
            )
            result = await create_operator_lot_attendant(
                Mock(),
                13,
                payload,
                _manager_user(),
                mock_db,
            )

        assert result.username == payload.username
        assert result.email == payload.email
        assert result.is_active is True
        assert mock_db.add.call_count == 1
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_create_operator_lot_attendant_rejects_duplicate_email(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.scalar_one_or_none.return_value = _active_lease()
        mock_db.execute = AsyncMock(side_effect=[manager_result, lease_result])

        with pytest.MonkeyPatch.context() as monkeypatch:
            monkeypatch.setattr(
                "src.app.api.v1.lots.crud_users.exists",
                AsyncMock(return_value=True),
            )

            with pytest.raises(DuplicateValueException, match="Email is already registered"):
                await create_operator_lot_attendant(
                    Mock(),
                    13,
                    OperatorManagedAttendantCreate(
                        name="Le Thi Truc",
                        username="lethitruc",
                        email="truc@example.com",
                        password="Str1ngst!123",
                        phone="0909123456",
                    ),
                    _manager_user(),
                    mock_db,
                )

    @pytest.mark.asyncio
    async def test_remove_operator_lot_attendant_deactivates_credentials(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.scalar_one_or_none.return_value = _active_lease()
        attendant_result = MagicMock()
        user = _attendant_user()
        attendant_result.one_or_none.return_value = (_attendant_profile(), user)
        mock_db.execute = AsyncMock(
            side_effect=[manager_result, lease_result, attendant_result]
        )
        mock_db.commit = AsyncMock()

        result = await remove_operator_lot_attendant(
            Mock(),
            13,
            41,
            _manager_user(),
            mock_db,
        )

        assert result == {"message": "Attendant removed"}
        assert user.is_active is False
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_remove_operator_lot_attendant_rejects_unknown_attendant(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.scalar_one_or_none.return_value = _active_lease()
        attendant_result = MagicMock()
        attendant_result.one_or_none.return_value = None
        mock_db.execute = AsyncMock(
            side_effect=[manager_result, lease_result, attendant_result]
        )

        with pytest.raises(NotFoundException, match="Attendant not found"):
            await remove_operator_lot_attendant(
                Mock(),
                13,
                999,
                _manager_user(),
                mock_db,
            )