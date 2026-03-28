"""Unit tests for attendant QR check-in flow (Story 4.2)."""

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest
from jose import jwt

from src.app.api.v1.sessions import attendant_check_in_with_driver_qr
from src.app.core.exceptions.http_exceptions import BadRequestException, ForbiddenException
from src.app.core.security import ALGORITHM, SECRET_KEY
from src.app.models.parking import ParkingLot
from src.app.models.sessions import ParkingSession
from src.app.models.users import Attendant
from src.app.models.vehicles import Vehicle
from src.app.schemas.session import AttendantCheckInCreate


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


def _make_lot(lot_id: int = 13, current_available: int = 12, name: str = 'Bai xe Quan 1') -> ParkingLot:
    lot = MagicMock(spec=ParkingLot)
    lot.id = lot_id
    lot.current_available = current_available
    lot.name = name
    return lot


def _make_vehicle(vehicle_id: int = 22, driver_id: int = 9) -> Vehicle:
    vehicle = MagicMock(spec=Vehicle)
    vehicle.id = vehicle_id
    vehicle.driver_id = driver_id
    vehicle.license_plate = '59A-12345'
    vehicle.vehicle_type = 'MOTORBIKE'
    return vehicle


def _make_active_session(session_id: int = 91, parking_lot_id: int = 13) -> ParkingSession:
    session = MagicMock(spec=ParkingSession)
    session.id = session_id
    session.parking_lot_id = parking_lot_id
    return session


def _build_driver_token(*, driver_id: int = 9, vehicle_id: int = 22, expires_in_minutes: int = 5) -> str:
    now = datetime.now(UTC)
    payload = {
        'purpose': 'driver_check_in',
        'driver_id': driver_id,
        'vehicle_id': vehicle_id,
        'license_plate': '59A-12345',
        'vehicle_type': 'MOTORBIKE',
        'jti': 'story-4-2-token',
        'iat': now.replace(tzinfo=None),
        'exp': (now + timedelta(minutes=expires_in_minutes)).replace(tzinfo=None),
    }
    return jwt.encode(payload, SECRET_KEY.get_secret_value(), algorithm=ALGORITHM)


def _no_pending_close_out_result() -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = None
    return result


class TestAttendantCheckInWithDriverQr:
    @pytest.mark.asyncio
    async def test_creates_session_and_updates_availability(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot = _make_lot(current_available=5)
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = lot

        vehicle = _make_vehicle()
        vehicle_result = MagicMock()
        vehicle_result.scalar_one_or_none.return_value = vehicle

        active_session_result = MagicMock()
        active_session_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(
            side_effect=[
                attendant_result,
                lot_result,
                _no_pending_close_out_result(),
                vehicle_result,
                active_session_result,
            ]
        )
        created_sessions = []
        mock_db.add = Mock(side_effect=lambda instance: created_sessions.append(instance))
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock(side_effect=lambda instance: setattr(instance, 'id', 101))

        result = await attendant_check_in_with_driver_qr(
            Mock(),
            AttendantCheckInCreate(token=_build_driver_token()),
            _attendant_user(),
            mock_db,
        )

        assert result.parking_lot_id == 13
        assert result.current_available == 4
        assert result.license_plate == '59A-12345'
        assert len(created_sessions) == 1
        assert created_sessions[0].attendant_checkin_id == 7
        assert lot.current_available == 4
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_rejects_when_driver_already_checked_in(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant(parking_lot_id=13)

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot(lot_id=13)

        vehicle_result = MagicMock()
        vehicle_result.scalar_one_or_none.return_value = _make_vehicle(driver_id=9)

        active_session_result = MagicMock()
        active_session_result.scalar_one_or_none.return_value = _make_active_session(parking_lot_id=18)

        other_lot_result = MagicMock()
        other_lot_result.scalar_one_or_none.return_value = _make_lot(lot_id=18, name='Bai xe District 3')

        mock_db.execute = AsyncMock(
            side_effect=[
                attendant_result,
                lot_result,
                _no_pending_close_out_result(),
                vehicle_result,
                active_session_result,
                other_lot_result,
            ]
        )

        with pytest.raises(BadRequestException, match='active session'):
            await attendant_check_in_with_driver_qr(
                Mock(),
                AttendantCheckInCreate(token=_build_driver_token()),
                _attendant_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_rejects_malformed_token(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, _no_pending_close_out_result()]
        )

        with pytest.raises(BadRequestException, match='Invalid QR code'):
            await attendant_check_in_with_driver_qr(
                Mock(),
                AttendantCheckInCreate(token='not-a-valid-token'),
                _attendant_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_rejects_non_attendant_account(self, mock_db):
        with pytest.raises(ForbiddenException, match='Only attendant accounts'):
            await attendant_check_in_with_driver_qr(
                Mock(),
                AttendantCheckInCreate(token=_build_driver_token()),
                {'id': 1, 'role': 'DRIVER'},
                mock_db,
            )