"""Unit tests for attendant occupancy summary flow (Story 6.1)."""

from datetime import UTC, datetime, time
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.sessions import get_attendant_occupancy_summary
from src.app.core.exceptions.http_exceptions import ForbiddenException
from src.app.models.parking import ParkingLot, ParkingLotConfig
from src.app.models.users import Attendant


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


def _make_lot(lot_id: int = 13, current_available: int = 12, name: str = "Bai xe Quan 1") -> ParkingLot:
    lot = MagicMock(spec=ParkingLot)
    lot.id = lot_id
    lot.current_available = current_available
    lot.name = name
    return lot


def _make_config(total_capacity: int = 20) -> ParkingLotConfig:
    config = MagicMock(spec=ParkingLotConfig)
    config.total_capacity = total_capacity
    config.opening_time = time(hour=6, minute=0)
    config.closing_time = time(hour=22, minute=0)
    config.created_at = datetime.now(UTC)
    return config


class TestAttendantOccupancySummary:
    @pytest.mark.asyncio
    async def test_returns_capacity_counts_and_vehicle_breakdown(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot(current_available=8)

        config_result = MagicMock()
        config_result.scalar_one_or_none.return_value = _make_config(total_capacity=20)

        breakdown_result = MagicMock()
        breakdown_result.all.return_value = [
            ("MOTORBIKE", 9),
            ("CAR", 3),
        ]

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, config_result, breakdown_result]
        )

        result = await get_attendant_occupancy_summary(
            Mock(),
            _attendant_user(),
            mock_db,
        )

        assert result.parking_lot_id == 13
        assert result.parking_lot_name == "Bai xe Quan 1"
        assert result.has_active_capacity_config is True
        assert result.total_capacity == 20
        assert result.free_count == 8
        assert result.occupied_count == 12
        assert [(item.vehicle_type, item.occupied_count) for item in result.vehicle_type_breakdown] == [
            ("MOTORBIKE", 9),
            ("CAR", 3),
        ]

    @pytest.mark.asyncio
    async def test_returns_not_configured_state_without_capacity_math(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot(current_available=8)

        config_result = MagicMock()
        config_result.scalar_one_or_none.return_value = None

        breakdown_result = MagicMock()
        breakdown_result.all.return_value = [("MOTORBIKE", 2)]

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, config_result, breakdown_result]
        )

        result = await get_attendant_occupancy_summary(
            Mock(),
            _attendant_user(),
            mock_db,
        )

        assert result.has_active_capacity_config is False
        assert result.total_capacity is None
        assert result.free_count is None
        assert result.occupied_count is None
        assert result.vehicle_type_breakdown[0].vehicle_type == "MOTORBIKE"
        assert result.vehicle_type_breakdown[0].occupied_count == 2

    @pytest.mark.asyncio
    async def test_rejects_non_attendant_account(self, mock_db):
        with pytest.raises(ForbiddenException, match="Only attendant accounts"):
            await get_attendant_occupancy_summary(
                Mock(),
                {"id": 1, "role": "DRIVER"},
                mock_db,
            )
