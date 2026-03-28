"""Unit tests for Story 6.3 attendant timeout management."""

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.sessions import (
    attendant_force_close_timeout,
    get_attendant_active_sessions,
)
from src.app.core.exceptions.http_exceptions import BadRequestException, ForbiddenException
from src.app.models.enums import SessionStatus
from src.app.models.parking import ParkingLot, ParkingLotConfig
from src.app.models.sessions import ParkingSession, SessionEdit
from src.app.models.users import Attendant
from src.app.schemas.session import AttendantForceCloseTimeoutCreate


def _attendant_user(user_id: int = 51) -> dict:
    return {
        "id": user_id,
        "username": "attendant_user",
        "email": "attendant@test.com",
        "role": "ATTENDANT",
    }


def _make_attendant(attendant_id: int = 7, parking_lot_id: int = 13) -> Attendant:
    attendant = MagicMock(spec=Attendant)
    attendant.id = attendant_id
    attendant.user_id = 51
    attendant.parking_lot_id = parking_lot_id
    return attendant


def _make_lot(lot_id: int = 13, current_available: int = 7) -> ParkingLot:
    lot = MagicMock(spec=ParkingLot)
    lot.id = lot_id
    lot.name = "Bai xe Quan 1"
    lot.current_available = current_available
    return lot


def _make_config(total_capacity: int = 12) -> ParkingLotConfig:
    config = MagicMock(spec=ParkingLotConfig)
    config.total_capacity = total_capacity
    config.created_at = datetime.now(UTC)
    return config


def _make_session(
    *,
    session_id: int = 88,
    parking_lot_id: int = 13,
    status: str = SessionStatus.CHECKED_IN.value,
    license_plate: str = "30A-99999",
    vehicle_type: str = "CAR",
    current_minutes: int = 125,
) -> ParkingSession:
    session = MagicMock(spec=ParkingSession)
    session.id = session_id
    session.parking_lot_id = parking_lot_id
    session.license_plate = license_plate
    session.vehicle_type = vehicle_type
    session.status = status
    session.checkin_time = datetime.now(UTC) - timedelta(minutes=current_minutes)
    session.checkout_time = None
    session.attendant_checkout_id = None
    return session


class TestAttendantActiveSessions:
    @pytest.mark.asyncio
    async def test_returns_lot_scoped_active_sessions(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        active_sessions_result = MagicMock()
        active_sessions_result.scalars.return_value.all.return_value = [
            _make_session(session_id=81, license_plate="59A-12345", vehicle_type="MOTORBIKE", current_minutes=30),
            _make_session(session_id=82, license_plate="30A-99999", vehicle_type="CAR", current_minutes=125),
        ]

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, active_sessions_result]
        )

        result = await get_attendant_active_sessions(Mock(), _attendant_user(), mock_db)

        assert len(result) == 2
        assert result[0].license_plate == "59A-12345"
        assert result[1].vehicle_type == "CAR"
        assert result[0].elapsed_minutes >= 30

    @pytest.mark.asyncio
    async def test_rejects_non_attendant_accounts(self, mock_db):
        with pytest.raises(ForbiddenException, match="Only attendant accounts"):
            await get_attendant_active_sessions(
                Mock(),
                {"id": 1, "role": "DRIVER"},
                mock_db,
            )


class TestAttendantForceCloseTimeout:
    @pytest.mark.asyncio
    async def test_force_closes_session_to_timeout_and_records_audit(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot = _make_lot(current_available=7)
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = lot

        config_result = MagicMock()
        config_result.scalar_one_or_none.return_value = _make_config(total_capacity=12)

        session = _make_session()
        session_result = MagicMock()
        session_result.scalar_one_or_none.return_value = session

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, config_result, session_result]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()
        mock_db.rollback = AsyncMock()

        result = await attendant_force_close_timeout(
            Mock(),
            AttendantForceCloseTimeoutCreate(
                session_id=88,
                reason="Xe da roi bai nhung checkout khong thanh cong.",
            ),
            _attendant_user(),
            mock_db,
        )

        added_edit = mock_db.add.call_args.args[0]
        assert isinstance(added_edit, SessionEdit)
        assert added_edit.session_id == 88
        assert added_edit.edited_by == 7
        assert added_edit.old_value == SessionStatus.CHECKED_IN.value
        assert added_edit.new_value == SessionStatus.TIMEOUT.value
        assert session.status == SessionStatus.TIMEOUT.value
        assert session.attendant_checkout_id == 7
        assert session.checkout_time is not None
        assert lot.current_available == 8
        mock_db.commit.assert_awaited_once()
        mock_db.rollback.assert_not_awaited()
        assert result.status == SessionStatus.TIMEOUT.value
        assert result.current_available == 8

    @pytest.mark.asyncio
    async def test_rejects_duplicate_timeout_transition(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        config_result = MagicMock()
        config_result.scalar_one_or_none.return_value = _make_config(total_capacity=12)

        session_result = MagicMock()
        session_result.scalar_one_or_none.return_value = _make_session(
            status=SessionStatus.TIMEOUT.value,
        )

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, config_result, session_result]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()

        with pytest.raises(BadRequestException, match="already been force-closed"):
            await attendant_force_close_timeout(
                Mock(),
                AttendantForceCloseTimeoutCreate(
                    session_id=88,
                    reason="Session da duoc xu ly truoc do.",
                ),
                _attendant_user(),
                mock_db,
            )

        mock_db.add.assert_not_called()
        mock_db.commit.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_clamps_availability_to_capacity_when_releasing_timeout(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot = _make_lot(current_available=12)
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = lot

        config_result = MagicMock()
        config_result.scalar_one_or_none.return_value = _make_config(total_capacity=12)

        session_result = MagicMock()
        session_result.scalar_one_or_none.return_value = _make_session()

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, config_result, session_result]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()

        result = await attendant_force_close_timeout(
            Mock(),
            AttendantForceCloseTimeoutCreate(
                session_id=88,
                reason="Ban ghi ket thuc bi ket nhung cho da duoc trong san.",
            ),
            _attendant_user(),
            mock_db,
        )

        assert lot.current_available == 12
        assert result.current_available == 12