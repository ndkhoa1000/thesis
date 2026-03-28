"""Unit tests for Story 6.5 final shift close-out."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.sessions import attendant_check_in_with_driver_qr
from src.app.api.v1.shifts import (
    complete_operator_final_shift_close_out,
    request_attendant_final_shift_close_out,
)
from src.app.core.exceptions.http_exceptions import BadRequestException
from src.app.models.enums import LeaseStatus, ShiftCloseOutStatus, ShiftStatus, UserRole
from src.app.models.leases import LotLease
from src.app.models.parking import ParkingLot, ParkingLotConfig
from src.app.models.shifts import Shift, ShiftCloseOut
from src.app.models.user import User
from src.app.models.users import Attendant, Manager
from src.app.schemas.session import AttendantCheckInCreate

NOW = datetime(2026, 3, 28, 21, 0, tzinfo=UTC)


def _attendant_user(user_id: int = 51) -> dict:
    return {
        "id": user_id,
        "username": "attendant_user",
        "email": "attendant@test.com",
        "role": UserRole.ATTENDANT.value,
        "is_superuser": False,
    }


def _manager_user(user_id: int = 21) -> dict:
    return {
        "id": user_id,
        "username": "operator",
        "email": "operator@test.com",
        "role": UserRole.MANAGER.value,
        "is_superuser": False,
    }


def _make_attendant(attendant_id: int = 7, user_id: int = 51, parking_lot_id: int = 13) -> Attendant:
    attendant = MagicMock(spec=Attendant)
    attendant.id = attendant_id
    attendant.user_id = user_id
    attendant.parking_lot_id = parking_lot_id
    return attendant


def _make_manager(manager_id: int = 8, user_id: int = 21) -> Manager:
    manager = MagicMock(spec=Manager)
    manager.id = manager_id
    manager.user_id = user_id
    return manager


def _make_lot(lot_id: int = 13, current_available: int = 10) -> ParkingLot:
    lot = MagicMock(spec=ParkingLot)
    lot.id = lot_id
    lot.name = "Bai xe Nguyen Du"
    lot.current_available = current_available
    return lot


def _make_capacity_config(total_capacity: int = 10) -> ParkingLotConfig:
    config = MagicMock(spec=ParkingLotConfig)
    config.total_capacity = total_capacity
    config.id = 3
    config.created_at = NOW
    return config


def _make_shift(
    *,
    shift_id: int = 17,
    parking_lot_id: int = 13,
    attendant_id: int = 7,
    started_at: datetime = NOW,
    ended_at: datetime | None = None,
    status: str = ShiftStatus.OPEN.value,
) -> Shift:
    shift = MagicMock(spec=Shift)
    shift.id = shift_id
    shift.parking_lot_id = parking_lot_id
    shift.attendant_id = attendant_id
    shift.started_at = started_at
    shift.ended_at = ended_at
    shift.status = status
    shift.created_at = NOW
    return shift


def _make_close_out(
    *,
    close_out_id: int = 31,
    shift_id: int = 17,
    parking_lot_id: int = 13,
    attendant_id: int = 7,
    status: str = ShiftCloseOutStatus.REQUESTED.value,
) -> ShiftCloseOut:
    close_out = MagicMock(spec=ShiftCloseOut)
    close_out.id = close_out_id
    close_out.shift_id = shift_id
    close_out.parking_lot_id = parking_lot_id
    close_out.attendant_id = attendant_id
    close_out.expected_cash = 85000
    close_out.current_available = 10
    close_out.active_session_count = 0
    close_out.status = status
    close_out.requested_at = NOW
    close_out.completed_at = None
    close_out.completed_by_manager_id = None
    return close_out


def _make_active_lease(
    *,
    lease_id: int = 4,
    parking_lot_id: int = 13,
    manager_id: int = 8,
) -> LotLease:
    lease = MagicMock(spec=LotLease)
    lease.id = lease_id
    lease.parking_lot_id = parking_lot_id
    lease.manager_id = manager_id
    lease.status = LeaseStatus.ACTIVE.value
    lease.created_at = NOW
    return lease


def _make_user(*, user_id: int = 21, name: str = "Operator A") -> User:
    user = MagicMock(spec=User)
    user.id = user_id
    user.name = name
    user.username = "operator"
    user.email = "operator@test.com"
    return user


class TestAttendantFinalShiftCloseOutRequest:
    @pytest.mark.asyncio
    async def test_requests_final_close_out_when_lot_is_empty(self, mock_db, monkeypatch):
        monkeypatch.setattr("src.app.api.v1.shifts._utcnow", lambda: NOW)

        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot(current_available=10)
        shift_result = MagicMock()
        shift_result.scalar_one_or_none.return_value = _make_shift(
            started_at=datetime(2026, 3, 28, 13, 0, tzinfo=UTC)
        )
        existing_close_out_result = MagicMock()
        existing_close_out_result.scalar_one_or_none.return_value = None
        active_sessions_result = MagicMock()
        active_sessions_result.scalar_one.return_value = 0
        capacity_result = MagicMock()
        capacity_result.scalar_one_or_none.return_value = _make_capacity_config()
        expected_cash_result = MagicMock()
        expected_cash_result.scalar_one.return_value = 85000
        operator_rows_result = MagicMock()
        operator_rows_result.all.return_value = [(_make_active_lease(), _make_manager(), _make_user())]

        created_records: list[object] = []

        def track_add(record):
            created_records.append(record)

        async def assign_ids():
            for record in created_records:
                if isinstance(record, ShiftCloseOut) and getattr(record, "id", None) is None:
                    record.id = 31
                notification_type = getattr(record, "notification_type", None)
                if notification_type is not None and getattr(record, "id", None) is None:
                    record.id = 71

        mock_db.execute = AsyncMock(
            side_effect=[
                attendant_result,
                lot_result,
                shift_result,
                existing_close_out_result,
                active_sessions_result,
                capacity_result,
                expected_cash_result,
                operator_rows_result,
            ]
        )
        mock_db.add = Mock(side_effect=track_add)
        mock_db.flush = AsyncMock(side_effect=assign_ids)
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        result = await request_attendant_final_shift_close_out(
            Mock(),
            _attendant_user(),
            mock_db,
        )

        created_close_out = next(item for item in created_records if isinstance(item, ShiftCloseOut))
        created_notification = next(
            item for item in created_records if getattr(item, "notification_type", None) is not None
        )

        assert created_close_out.shift_id == 17
        assert created_close_out.status == ShiftCloseOutStatus.REQUESTED.value
        assert created_close_out.operator_notification_id == 71
        assert created_notification.reference_id == 31
        assert created_notification.reference_type == "SHIFT_CLOSE_OUT"
        assert result.close_out_id == 31
        assert result.expected_cash == 85000
        assert result.current_available == 10
        assert result.active_session_count == 0
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_blocks_final_close_out_when_active_sessions_remain(self, mock_db, monkeypatch):
        monkeypatch.setattr("src.app.api.v1.shifts._utcnow", lambda: NOW)

        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot(current_available=8)
        shift_result = MagicMock()
        shift_result.scalar_one_or_none.return_value = _make_shift()
        existing_close_out_result = MagicMock()
        existing_close_out_result.scalar_one_or_none.return_value = None
        active_sessions_result = MagicMock()
        active_sessions_result.scalar_one.return_value = 2

        mock_db.execute = AsyncMock(
            side_effect=[
                attendant_result,
                lot_result,
                shift_result,
                existing_close_out_result,
                active_sessions_result,
            ]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()

        with pytest.raises(BadRequestException, match="Lot still has 2 active session\(s\)"):
            await request_attendant_final_shift_close_out(Mock(), _attendant_user(), mock_db)

        mock_db.add.assert_not_called()
        mock_db.commit.assert_not_awaited()


class TestOperatorFinalShiftCloseOut:
    @pytest.mark.asyncio
    async def test_operator_completes_requested_close_out(self, mock_db, monkeypatch):
        monkeypatch.setattr("src.app.api.v1.shifts._utcnow", lambda: NOW)

        close_out_result = MagicMock()
        close_out_result.scalar_one_or_none.return_value = _make_close_out()
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _make_manager()
        operator_rows_result = MagicMock()
        operator_rows_result.all.return_value = [(_make_active_lease(), _make_manager(), _make_user())]
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()
        attendant_pair_result = MagicMock()
        attendant_pair_result.one_or_none.return_value = (_make_attendant(), _make_user(user_id=51, name="Attendant A"))

        mock_db.execute = AsyncMock(
            side_effect=[
                close_out_result,
                manager_result,
                operator_rows_result,
                lot_result,
                attendant_pair_result,
            ]
        )
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        result = await complete_operator_final_shift_close_out(
            Mock(),
            31,
            _manager_user(),
            mock_db,
        )

        assert result.close_out_id == 31
        assert result.status == ShiftCloseOutStatus.COMPLETED.value
        assert result.completed_at == NOW
        mock_db.commit.assert_awaited_once()


class TestPendingFinalShiftCloseOutGateLock:
    @pytest.mark.asyncio
    async def test_blocks_attendant_check_in_while_close_out_is_pending(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot(current_available=10)
        pending_close_out_result = MagicMock()
        pending_close_out_result.scalar_one_or_none.return_value = _make_close_out()

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, pending_close_out_result]
        )

        with pytest.raises(
            BadRequestException,
            match="Final shift close-out is pending operator confirmation",
        ):
            await attendant_check_in_with_driver_qr(
                Mock(),
                AttendantCheckInCreate(token="driver-token"),
                _attendant_user(),
                mock_db,
            )