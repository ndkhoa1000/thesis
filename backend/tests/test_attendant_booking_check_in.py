"""Unit tests for attendant booking conversion flow (Story 7.2)."""

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, Mock, patch

import pytest
from jose import jwt

from src.app.api.v1.sessions import attendant_check_in_with_driver_qr
from src.app.core.exceptions.http_exceptions import BadRequestException
from src.app.core.security import ALGORITHM, SECRET_KEY
from src.app.models.parking import ParkingLot
from src.app.models.sessions import Booking, ParkingSession
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


def _make_lot(lot_id: int = 13, current_available: int = 5, name: str = "Bai xe Quan 1") -> ParkingLot:
    lot = MagicMock(spec=ParkingLot)
    lot.id = lot_id
    lot.current_available = current_available
    lot.name = name
    return lot


def _make_vehicle(vehicle_id: int = 22, driver_id: int = 9) -> Vehicle:
    vehicle = MagicMock(spec=Vehicle)
    vehicle.id = vehicle_id
    vehicle.driver_id = driver_id
    vehicle.license_plate = "59A-12345"
    vehicle.vehicle_type = "MOTORBIKE"
    return vehicle


def _make_booking(
    booking_id: int = 45,
    parking_lot_id: int = 13,
    driver_id: int = 9,
    vehicle_id: int = 22,
    *,
    status: str = "CONFIRMED",
    expires_in_minutes: int = 20,
) -> Booking:
    booking = MagicMock(spec=Booking)
    booking.id = booking_id
    booking.parking_lot_id = parking_lot_id
    booking.driver_id = driver_id
    booking.vehicle_id = vehicle_id
    booking.status = status
    booking.booking_time = datetime.now(UTC)
    booking.expected_arrival = booking.booking_time + timedelta(minutes=30)
    booking.expiration_time = datetime.now(UTC) + timedelta(minutes=expires_in_minutes)
    return booking


def _make_active_session(session_id: int = 91, parking_lot_id: int = 13) -> ParkingSession:
    session = MagicMock(spec=ParkingSession)
    session.id = session_id
    session.parking_lot_id = parking_lot_id
    return session


def _build_booking_token(
    *,
    booking_id: int = 45,
    driver_id: int = 9,
    parking_lot_id: int = 13,
    vehicle_id: int = 22,
    expires_in_minutes: int = 20,
) -> str:
    now = datetime.now(UTC)
    payload = {
        "purpose": "booking_check_in",
        "booking_id": booking_id,
        "driver_id": driver_id,
        "parking_lot_id": parking_lot_id,
        "vehicle_id": vehicle_id,
        "license_plate": "59A-12345",
        "vehicle_type": "MOTORBIKE",
        "jti": "story-7-2-booking-token",
        "iat": now.replace(tzinfo=None),
        "exp": (now + timedelta(minutes=expires_in_minutes)).replace(tzinfo=None),
    }
    return jwt.encode(payload, SECRET_KEY.get_secret_value(), algorithm=ALGORITHM)


def _no_pending_close_out_result() -> MagicMock:
    result = MagicMock()
    result.scalar_one_or_none.return_value = None
    return result


class TestAttendantBookingCheckIn:
    @pytest.mark.asyncio
    async def test_converts_booking_to_session_without_decrementing_availability(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot = _make_lot(current_available=5)
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = lot

        booking = _make_booking()
        booking_result = MagicMock()
        booking_result.scalar_one_or_none.return_value = booking

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
                booking_result,
                vehicle_result,
                active_session_result,
            ]
        )
        created_sessions = []
        mock_db.add = Mock(side_effect=lambda instance: created_sessions.append(instance))
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock(side_effect=lambda instance: setattr(instance, "id", 101))

        with patch("src.app.api.v1.sessions.publish_lot_availability_update") as publish_mock:
            result = await attendant_check_in_with_driver_qr(
                Mock(),
                AttendantCheckInCreate(token=_build_booking_token()),
                _attendant_user(),
                mock_db,
            )

        assert result.parking_lot_id == 13
        assert result.current_available == 5
        assert result.license_plate == "59A-12345"
        assert booking.status == "CONSUMED"
        assert len(created_sessions) == 1
        assert created_sessions[0].booking_id == 45
        assert lot.current_available == 5
        publish_mock.assert_not_called()

    @pytest.mark.asyncio
    async def test_rejects_booking_from_different_lot(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant(parking_lot_id=13)

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot(lot_id=13)

        booking_result = MagicMock()
        booking_result.scalar_one_or_none.return_value = _make_booking(parking_lot_id=99)

        mock_db.execute = AsyncMock(
            side_effect=[
                attendant_result,
                lot_result,
                _no_pending_close_out_result(),
                booking_result,
            ]
        )

        with pytest.raises(BadRequestException, match="different parking lot"):
            await attendant_check_in_with_driver_qr(
                Mock(),
                AttendantCheckInCreate(token=_build_booking_token(parking_lot_id=99)),
                _attendant_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_rejects_expired_booking_with_regular_check_in_guidance(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        booking_result = MagicMock()
        booking_result.scalar_one_or_none.return_value = _make_booking(expires_in_minutes=-1)

        mock_db.execute = AsyncMock(
            side_effect=[
                attendant_result,
                lot_result,
                _no_pending_close_out_result(),
                booking_result,
            ]
        )

        with pytest.raises(BadRequestException, match="regular check-in"):
            await attendant_check_in_with_driver_qr(
                Mock(),
                AttendantCheckInCreate(token=_build_booking_token(expires_in_minutes=-1)),
                _attendant_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_rejects_booking_that_has_already_been_consumed(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        booking_result = MagicMock()
        booking_result.scalar_one_or_none.return_value = _make_booking(status="CONSUMED")

        mock_db.execute = AsyncMock(
            side_effect=[
                attendant_result,
                lot_result,
                _no_pending_close_out_result(),
                booking_result,
            ]
        )

        with pytest.raises(BadRequestException, match="already been used"):
            await attendant_check_in_with_driver_qr(
                Mock(),
                AttendantCheckInCreate(token=_build_booking_token()),
                _attendant_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_rechecks_expiration_before_commit_to_block_just_expired_booking(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        booking = _make_booking(expires_in_minutes=1)
        booking_result = MagicMock()
        booking_result.scalar_one_or_none.return_value = booking

        vehicle_result = MagicMock()
        vehicle_result.scalar_one_or_none.return_value = _make_vehicle()

        active_session_result = MagicMock()
        active_session_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(
            side_effect=[
                attendant_result,
                lot_result,
                _no_pending_close_out_result(),
                booking_result,
                vehicle_result,
                active_session_result,
            ]
        )

        first_now = datetime.now(UTC)
        second_now = booking.expiration_time + timedelta(seconds=1)

        with patch("src.app.api.v1.sessions._utcnow", side_effect=[first_now, second_now]):
            with pytest.raises(BadRequestException, match="regular check-in"):
                await attendant_check_in_with_driver_qr(
                    Mock(),
                    AttendantCheckInCreate(token=_build_booking_token(expires_in_minutes=5)),
                    _attendant_user(),
                    mock_db,
                )