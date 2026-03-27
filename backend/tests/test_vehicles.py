"""Unit tests for vehicle management endpoints (Story 1-3)."""

from unittest.mock import AsyncMock, MagicMock, Mock, patch

import pytest

from src.app.api.v1.users import (
    create_my_vehicle,
    erase_my_vehicle,
    normalize_license_plate,
    read_my_vehicles,
)
from src.app.core.exceptions.http_exceptions import (
    BadRequestException,
    DuplicateValueException,
    ForbiddenException,
    NotFoundException,
)
from src.app.models.enums import VehicleType
from src.app.models.users import Driver
from src.app.models.vehicles import Vehicle
from src.app.schemas.vehicle import VehicleCreate


# ─── helpers ──────────────────────────────────────────────────────────────────


def _make_driver(driver_id: int = 1) -> Driver:
    driver = MagicMock(spec=Driver)
    driver.id = driver_id
    return driver


def _make_vehicle(
    vid: int = 10,
    driver_id: int = 1,
    plate: str = "59A-12345",
    vtype: str = VehicleType.MOTORBIKE.value,
) -> Vehicle:
    v = MagicMock(spec=Vehicle)
    v.id = vid
    v.driver_id = driver_id
    v.license_plate = plate
    v.vehicle_type = vtype
    return v


def _driver_user(user_id: int = 1) -> dict:
    return {
        "id": user_id,
        "username": "driver_user",
        "email": "driver@test.com",
        "role": "DRIVER",
    }


def _mock_db_select_driver(mock_db: AsyncMock, driver: Driver | None) -> None:
    """Configure mock_db.execute to return driver for the first call."""
    result_mock = MagicMock()
    result_mock.scalar_one_or_none.return_value = driver
    mock_db.execute = AsyncMock(return_value=result_mock)


# ─── normalize_license_plate ──────────────────────────────────────────────────


class TestNormalizeLicensePlate:
    """Unit tests for the plate normalisation helper."""

    def test_strips_whitespace(self):
        assert normalize_license_plate("  59A-12345  ") == "59A-12345"

    def test_uppercases(self):
        assert normalize_license_plate("59a-12345") == "59A-12345"

    def test_collapses_internal_spaces(self):
        assert normalize_license_plate("59A  12345") == "59A 12345"

    def test_empty_string_raises(self):
        with pytest.raises(BadRequestException, match="required"):
            normalize_license_plate("   ")


# ─── read_my_vehicles ─────────────────────────────────────────────────────────


class TestReadMyVehicles:
    """Tests for GET /user/me/vehicles."""

    @pytest.mark.asyncio
    async def test_returns_vehicle_list(self, mock_db):
        driver = _make_driver()
        vehicles = [_make_vehicle(10), _make_vehicle(11, plate="30A-99999")]

        # First call: driver lookup; second call: vehicles query
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = driver

        vehicles_result = MagicMock()
        vehicles_result.scalars.return_value.all.return_value = vehicles

        mock_db.execute = AsyncMock(
            side_effect=[driver_result, vehicles_result]
        )

        result = await read_my_vehicles(Mock(), _driver_user(), mock_db)
        assert result == vehicles

    @pytest.mark.asyncio
    async def test_non_driver_role_raises_forbidden(self, mock_db):
        current_user = {"id": 5, "username": "admin_u", "role": "ADMIN"}
        with pytest.raises(ForbiddenException):
            await read_my_vehicles(Mock(), current_user, mock_db)

    @pytest.mark.asyncio
    async def test_missing_driver_profile_raises_forbidden(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=driver_result)

        with pytest.raises(ForbiddenException, match="Driver profile not found"):
            await read_my_vehicles(Mock(), _driver_user(), mock_db)


# ─── create_my_vehicle ────────────────────────────────────────────────────────


class TestCreateMyVehicle:
    """Tests for POST /user/me/vehicles."""

    @pytest.mark.asyncio
    async def test_create_vehicle_success(self, mock_db):
        driver = _make_driver()

        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = driver

        no_dup_result = MagicMock()
        no_dup_result.scalar_one_or_none.return_value = None  # no duplicate

        mock_db.execute = AsyncMock(
            side_effect=[driver_result, no_dup_result]
        )

        added_vehicles: list = []
        mock_db.add = Mock(side_effect=lambda v: added_vehicles.append(v))
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        payload = VehicleCreate(license_plate="59A-12345", vehicle_type=VehicleType.MOTORBIKE)

        result = await create_my_vehicle(Mock(), payload, _driver_user(), mock_db)

        assert len(added_vehicles) == 1
        v = added_vehicles[0]
        assert v.license_plate == "59A-12345"
        assert v.driver_id == driver.id
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_create_vehicle_normalizes_plate(self, mock_db):
        """License plate is trimmed and uppercased before duplicate check."""
        driver = _make_driver()

        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = driver

        no_dup_result = MagicMock()
        no_dup_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(side_effect=[driver_result, no_dup_result])

        added_vehicles: list = []
        mock_db.add = Mock(side_effect=lambda v: added_vehicles.append(v))
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        payload = VehicleCreate(
            license_plate="  59a-12345  ", vehicle_type=VehicleType.CAR
        )

        await create_my_vehicle(Mock(), payload, _driver_user(), mock_db)

        assert len(added_vehicles) == 1
        assert added_vehicles[0].license_plate == "59A-12345"

    @pytest.mark.asyncio
    async def test_duplicate_plate_raises(self, mock_db):
        driver = _make_driver()

        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = driver

        dup_result = MagicMock()
        dup_result.scalar_one_or_none.return_value = 99  # existing vehicle id

        mock_db.execute = AsyncMock(side_effect=[driver_result, dup_result])

        payload = VehicleCreate(
            license_plate="59A-12345", vehicle_type=VehicleType.MOTORBIKE
        )

        with pytest.raises(DuplicateValueException, match="already registered"):
            await create_my_vehicle(Mock(), payload, _driver_user(), mock_db)

    @pytest.mark.asyncio
    async def test_blank_plate_raises_bad_request(self, mock_db):
        driver = _make_driver()

        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = driver

        mock_db.execute = AsyncMock(side_effect=[driver_result])

        payload = VehicleCreate(
            license_plate="   ", vehicle_type=VehicleType.MOTORBIKE
        )

        with pytest.raises(BadRequestException, match="required"):
            await create_my_vehicle(Mock(), payload, _driver_user(), mock_db)

    @pytest.mark.asyncio
    async def test_non_driver_role_raises_forbidden(self, mock_db):
        payload = VehicleCreate(
            license_plate="59A-00000", vehicle_type=VehicleType.MOTORBIKE
        )
        current_user = {"id": 1, "username": "su", "role": "SUPER_ADMIN"}

        with pytest.raises(ForbiddenException):
            await create_my_vehicle(Mock(), payload, current_user, mock_db)


# ─── erase_my_vehicle ─────────────────────────────────────────────────────────


class TestEraseMyVehicle:
    """Tests for DELETE /user/me/vehicles/{id}."""

    @pytest.mark.asyncio
    async def test_delete_vehicle_success(self, mock_db):
        driver = _make_driver(driver_id=1)
        vehicle = _make_vehicle(vid=10, driver_id=1)

        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = driver

        vehicle_result = MagicMock()
        vehicle_result.scalar_one_or_none.return_value = vehicle

        mock_db.execute = AsyncMock(side_effect=[driver_result, vehicle_result])
        mock_db.delete = AsyncMock()
        mock_db.commit = AsyncMock()

        result = await erase_my_vehicle(Mock(), 10, _driver_user(), mock_db)

        assert result == {"message": "Vehicle deleted"}
        mock_db.delete.assert_awaited_once_with(vehicle)
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_delete_vehicle_not_found(self, mock_db):
        driver = _make_driver()

        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = driver

        no_vehicle_result = MagicMock()
        no_vehicle_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(
            side_effect=[driver_result, no_vehicle_result]
        )

        with pytest.raises(NotFoundException, match="Vehicle not found"):
            await erase_my_vehicle(Mock(), 999, _driver_user(), mock_db)

    @pytest.mark.asyncio
    async def test_delete_vehicle_wrong_owner(self, mock_db):
        """Driver cannot delete a vehicle belonging to another driver."""
        driver = _make_driver(driver_id=1)
        other_vehicle = _make_vehicle(vid=55, driver_id=2)  # different driver

        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = driver

        vehicle_result = MagicMock()
        vehicle_result.scalar_one_or_none.return_value = other_vehicle

        mock_db.execute = AsyncMock(side_effect=[driver_result, vehicle_result])

        with pytest.raises(ForbiddenException, match="does not belong"):
            await erase_my_vehicle(Mock(), 55, _driver_user(), mock_db)

    @pytest.mark.asyncio
    async def test_non_driver_role_raises_forbidden(self, mock_db):
        current_user = {"id": 1, "username": "att", "role": "ATTENDANT"}

        with pytest.raises(ForbiddenException):
            await erase_my_vehicle(Mock(), 10, current_user, mock_db)
