"""Unit tests for driver check-in QR token issuance (Story 4.1)."""

from datetime import datetime
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest
from jose import jwt

from src.app.api.v1.sessions import create_driver_check_in_token
from src.app.core.exceptions.http_exceptions import BadRequestException, ForbiddenException, NotFoundException
from src.app.core.security import ALGORITHM, SECRET_KEY
from src.app.models.sessions import ParkingSession
from src.app.models.users import Driver
from src.app.models.vehicles import Vehicle
from src.app.schemas.session import DriverCheckInTokenCreate


def _driver_user(user_id: int = 1) -> dict:
    return {
        "id": user_id,
        "username": "driver_user",
        "email": "driver@test.com",
        "role": "DRIVER",
    }


def _make_driver(driver_id: int = 1) -> Driver:
    driver = MagicMock(spec=Driver)
    driver.id = driver_id
    return driver


def _make_vehicle(vehicle_id: int = 10, driver_id: int = 1) -> Vehicle:
    vehicle = MagicMock(spec=Vehicle)
    vehicle.id = vehicle_id
    vehicle.driver_id = driver_id
    vehicle.license_plate = "59A-12345"
    vehicle.vehicle_type = "MOTORBIKE"
    return vehicle


def _make_active_session() -> ParkingSession:
    session = MagicMock(spec=ParkingSession)
    session.id = 77
    return session


class TestCreateDriverCheckInToken:
    @pytest.mark.asyncio
    async def test_issues_backend_signed_token_for_owned_vehicle(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver(driver_id=3)

        vehicle = _make_vehicle(vehicle_id=11, driver_id=3)
        vehicle_result = MagicMock()
        vehicle_result.scalar_one_or_none.return_value = vehicle

        active_session_result = MagicMock()
        active_session_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(
            side_effect=[driver_result, vehicle_result, active_session_result]
        )

        response = await create_driver_check_in_token(
            Mock(),
            DriverCheckInTokenCreate(vehicle_id=11),
            _driver_user(),
            mock_db,
        )

        assert response.vehicle.id == 11
        assert response.expires_in_seconds == 300
        assert response.expires_at.timestamp() > datetime.utcnow().timestamp()

        payload = jwt.decode(
            response.token,
            SECRET_KEY.get_secret_value(),
            algorithms=[ALGORITHM],
        )
        assert payload["purpose"] == "driver_check_in"
        assert payload["driver_id"] == 3
        assert payload["vehicle_id"] == 11
        assert payload["license_plate"] == "59A-12345"

    @pytest.mark.asyncio
    async def test_rejects_vehicle_that_belongs_to_another_driver(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver(driver_id=1)

        vehicle_result = MagicMock()
        vehicle_result.scalar_one_or_none.return_value = _make_vehicle(vehicle_id=10, driver_id=2)

        mock_db.execute = AsyncMock(side_effect=[driver_result, vehicle_result])

        with pytest.raises(ForbiddenException, match="does not belong"):
            await create_driver_check_in_token(
                Mock(),
                DriverCheckInTokenCreate(vehicle_id=10),
                _driver_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_rejects_when_driver_has_active_session(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver(driver_id=1)

        vehicle_result = MagicMock()
        vehicle_result.scalar_one_or_none.return_value = _make_vehicle(vehicle_id=10, driver_id=1)

        active_session_result = MagicMock()
        active_session_result.scalar_one_or_none.return_value = _make_active_session()

        mock_db.execute = AsyncMock(
            side_effect=[driver_result, vehicle_result, active_session_result]
        )

        with pytest.raises(BadRequestException, match="already in progress"):
            await create_driver_check_in_token(
                Mock(),
                DriverCheckInTokenCreate(vehicle_id=10),
                _driver_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_rejects_missing_vehicle(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver(driver_id=1)

        vehicle_result = MagicMock()
        vehicle_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(side_effect=[driver_result, vehicle_result])

        with pytest.raises(NotFoundException, match="Vehicle not found"):
            await create_driver_check_in_token(
                Mock(),
                DriverCheckInTokenCreate(vehicle_id=999),
                _driver_user(),
                mock_db,
            )