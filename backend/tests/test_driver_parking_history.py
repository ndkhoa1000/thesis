"""Unit tests for driver parking history flow (Story 5.3)."""

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.sessions import list_driver_parking_history
from src.app.core.exceptions.http_exceptions import ForbiddenException
from src.app.models.financials import Payment
from src.app.models.enums import SessionStatus
from src.app.models.parking import ParkingLot
from src.app.models.sessions import ParkingSession
from src.app.models.users import Driver


def _driver_user(user_id: int = 17, role: str = 'DRIVER') -> dict:
    return {
        'id': user_id,
        'username': 'driver_user',
        'email': 'driver@test.com',
        'role': role,
    }


def _make_driver(driver_id: int = 5, user_id: int = 17) -> Driver:
    driver = MagicMock(spec=Driver)
    driver.id = driver_id
    driver.user_id = user_id
    return driver


def _make_lot(lot_id: int, name: str) -> ParkingLot:
    lot = MagicMock(spec=ParkingLot)
    lot.id = lot_id
    lot.name = name
    return lot


def _make_session(
    *,
    session_id: int,
    parking_lot_id: int,
    driver_id: int,
    checked_out_at: datetime,
    license_plate: str = '59A-88888',
    vehicle_type: str = 'CAR',
    duration_minutes: int = 90,
    status: str = SessionStatus.CHECKED_OUT.value,
) -> ParkingSession:
    session = MagicMock(spec=ParkingSession)
    session.id = session_id
    session.parking_lot_id = parking_lot_id
    session.driver_id = driver_id
    session.license_plate = license_plate
    session.vehicle_type = vehicle_type
    session.checkin_time = checked_out_at - timedelta(minutes=duration_minutes)
    session.checkout_time = checked_out_at
    session.status = status
    return session


def _make_payment(*, final_amount: float, payment_method: str = 'CASH') -> Payment:
    payment = MagicMock(spec=Payment)
    payment.final_amount = final_amount
    payment.payment_method = payment_method
    return payment


class TestDriverParkingHistory:
    @pytest.mark.asyncio
    async def test_returns_driver_completed_sessions_in_reverse_chronological_order(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver(driver_id=9)

        newer_checkout = datetime.now(UTC) - timedelta(hours=2)
        older_checkout = datetime.now(UTC) - timedelta(days=1)
        history_result = MagicMock()
        history_result.all.return_value = [
            (
                _make_session(
                    session_id=101,
                    parking_lot_id=13,
                    driver_id=9,
                    checked_out_at=newer_checkout,
                    duration_minutes=75,
                ),
                _make_lot(13, 'Bai xe Nguyen Hue'),
                _make_payment(final_amount=25000, payment_method='CASH'),
            ),
            (
                _make_session(
                    session_id=99,
                    parking_lot_id=11,
                    driver_id=9,
                    checked_out_at=older_checkout,
                    duration_minutes=120,
                    license_plate='59A-77777',
                ),
                _make_lot(11, 'Bai xe Le Loi'),
                _make_payment(final_amount=40000, payment_method='ONLINE'),
            ),
        ]

        mock_db.execute = AsyncMock(side_effect=[driver_result, history_result])

        result = await list_driver_parking_history(Mock(), _driver_user(), mock_db)

        assert [item.session_id for item in result] == [101, 99]
        assert result[0].parking_lot_name == 'Bai xe Nguyen Hue'
        assert result[0].amount_paid == 25000
        assert result[0].payment_method == 'CASH'
        assert result[0].duration_minutes == 75
        assert result[1].amount_paid == 40000
        assert result[1].payment_method == 'ONLINE'

    @pytest.mark.asyncio
    async def test_returns_empty_list_when_driver_has_no_completed_sessions(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver(driver_id=9)
        history_result = MagicMock()
        history_result.all.return_value = []

        mock_db.execute = AsyncMock(side_effect=[driver_result, history_result])

        result = await list_driver_parking_history(Mock(), _driver_user(), mock_db)

        assert result == []

    @pytest.mark.asyncio
    async def test_includes_timeout_sessions_in_driver_history(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver(driver_id=9)
        timeout_at = datetime.now(UTC) - timedelta(hours=3)
        history_result = MagicMock()
        history_result.all.return_value = [
            (
                _make_session(
                    session_id=111,
                    parking_lot_id=15,
                    driver_id=9,
                    checked_out_at=timeout_at,
                    duration_minutes=45,
                    status=SessionStatus.TIMEOUT.value,
                ),
                _make_lot(15, 'Bai xe Le Thanh Ton'),
                None,
            ),
        ]

        mock_db.execute = AsyncMock(side_effect=[driver_result, history_result])

        result = await list_driver_parking_history(Mock(), _driver_user(), mock_db)

        assert len(result) == 1
        assert result[0].session_id == 111
        assert result[0].amount_paid is None
        assert result[0].payment_method is None

    @pytest.mark.asyncio
    async def test_rejects_non_driver_account(self, mock_db):
        with pytest.raises(ForbiddenException, match='Only driver-capable public accounts'):
            await list_driver_parking_history(Mock(), _driver_user(role='ATTENDANT'), mock_db)