"""Unit tests for driver active-session and check-out QR flow (Story 4.4)."""

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest
from jose import jwt

from src.app.api.v1.sessions import create_driver_check_out_token, get_driver_active_session
from src.app.core.exceptions.http_exceptions import BadRequestException, ForbiddenException, NotFoundException
from src.app.core.security import ALGORITHM, SECRET_KEY
from src.app.models.parking import ParkingLot, Pricing
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


def _make_active_session(
    *,
    session_id: int = 88,
    parking_lot_id: int = 13,
    driver_id: int = 5,
    license_plate: str = '30A-99999',
    vehicle_type: str = 'CAR',
    checkin_time: datetime | None = None,
) -> ParkingSession:
    session = MagicMock(spec=ParkingSession)
    session.id = session_id
    session.parking_lot_id = parking_lot_id
    session.driver_id = driver_id
    session.license_plate = license_plate
    session.vehicle_type = vehicle_type
    session.checkin_time = checkin_time or datetime.now(UTC) - timedelta(minutes=95)
    session.status = 'CHECKED_IN'
    return session


def _make_lot(lot_id: int = 13, name: str = 'Bai xe Le Loi') -> ParkingLot:
    lot = MagicMock(spec=ParkingLot)
    lot.id = lot_id
    lot.name = name
    lot.address = '12 Le Loi, Quan 1'
    return lot


def _make_pricing(*, pricing_mode: str = 'HOURLY', price_amount: float = 15000) -> Pricing:
    pricing = MagicMock(spec=Pricing)
    pricing.pricing_mode = pricing_mode
    pricing.price_amount = price_amount
    return pricing


class TestDriverActiveSession:
    @pytest.mark.asyncio
    async def test_returns_active_session_summary_with_estimated_cost(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver()

        active_session = _make_active_session(
            checkin_time=datetime.now(UTC) - timedelta(minutes=95),
        )
        active_session_result = MagicMock()
        active_session_result.scalars.return_value.all.return_value = [active_session]

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        pricing_result = MagicMock()
        default_pricing = _make_pricing()
        default_pricing.vehicle_type = 'ALL'
        pricing_result.scalars.return_value.all.return_value = [default_pricing]

        mock_db.execute = AsyncMock(
            side_effect=[driver_result, active_session_result, lot_result, pricing_result]
        )

        result = await get_driver_active_session(Mock(), _driver_user(), mock_db)

        assert result.session_id == 88
        assert result.parking_lot_id == 13
        assert result.parking_lot_name == 'Bai xe Le Loi'
        assert result.license_plate == '30A-99999'
        assert result.elapsed_minutes >= 95
        assert result.estimated_cost == 30000
        assert result.pricing_mode == 'HOURLY'

    @pytest.mark.asyncio
    async def test_raises_not_found_when_driver_has_no_active_session(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver()

        active_session_result = MagicMock()
        active_session_result.scalars.return_value.all.return_value = []

        mock_db.execute = AsyncMock(side_effect=[driver_result, active_session_result])

        with pytest.raises(NotFoundException, match='No active parking session'):
            await get_driver_active_session(Mock(), _driver_user(), mock_db)

    @pytest.mark.asyncio
    async def test_rejects_duplicate_active_sessions(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver()

        active_session_result = MagicMock()
        active_session_result.scalars.return_value.all.return_value = [
            _make_active_session(session_id=88),
            _make_active_session(session_id=87),
        ]

        mock_db.execute = AsyncMock(side_effect=[driver_result, active_session_result])

        with pytest.raises(BadRequestException, match='Multiple active parking sessions'):
            await get_driver_active_session(Mock(), _driver_user(), mock_db)

    @pytest.mark.asyncio
    async def test_rejects_non_driver_account(self, mock_db):
        with pytest.raises(ForbiddenException, match='Only driver-capable public accounts'):
            await get_driver_active_session(Mock(), _driver_user(role='ATTENDANT'), mock_db)


class TestDriverCheckOutToken:
    @pytest.mark.asyncio
    async def test_issues_checkout_token_for_active_session(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver(driver_id=9)

        active_session = _make_active_session(session_id=120, driver_id=9)
        active_session_result = MagicMock()
        active_session_result.scalars.return_value.all.return_value = [active_session]

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot(lot_id=13, name='Bai xe Ben Thanh')

        mock_db.execute = AsyncMock(side_effect=[driver_result, active_session_result, lot_result])

        result = await create_driver_check_out_token(Mock(), _driver_user(), mock_db)

        payload = jwt.decode(
            result.token,
            SECRET_KEY.get_secret_value(),
            algorithms=[ALGORITHM],
        )

        assert payload['purpose'] == 'driver_check_out'
        assert payload['session_id'] == 120
        assert payload['driver_id'] == 9
        assert payload['parking_lot_id'] == 13
        assert result.session_id == 120
        assert result.license_plate == '30A-99999'
        assert result.expires_in_seconds > 0

    @pytest.mark.asyncio
    async def test_rejects_checkout_token_request_without_active_session(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver()

        active_session_result = MagicMock()
        active_session_result.scalars.return_value.all.return_value = []

        mock_db.execute = AsyncMock(side_effect=[driver_result, active_session_result])

        with pytest.raises(NotFoundException, match='No active parking session'):
            await create_driver_check_out_token(Mock(), _driver_user(), mock_db)

    @pytest.mark.asyncio
    async def test_prefers_vehicle_specific_active_pricing(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver()

        active_session = _make_active_session(vehicle_type='CAR')
        active_session_result = MagicMock()
        active_session_result.scalars.return_value.all.return_value = [active_session]

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        lot_wide_pricing = _make_pricing(pricing_mode='HOURLY', price_amount=10000)
        lot_wide_pricing.vehicle_type = 'ALL'
        vehicle_specific_pricing = _make_pricing(pricing_mode='SESSION', price_amount=25000)
        vehicle_specific_pricing.vehicle_type = 'CAR'
        pricing_result = MagicMock()
        pricing_result.scalars.return_value.all.return_value = [lot_wide_pricing, vehicle_specific_pricing]

        mock_db.execute = AsyncMock(
            side_effect=[driver_result, active_session_result, lot_result, pricing_result]
        )

        result = await get_driver_active_session(Mock(), _driver_user(), mock_db)

        assert result.pricing_mode == 'SESSION'
        assert result.estimated_cost == 25000