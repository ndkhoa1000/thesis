"""Unit tests for Story 3-1 and 3-2 operator lot configuration flows."""

from datetime import UTC, datetime, time
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.lots import _get_latest_parking_lot_config, patch_operator_parking_lot, read_operator_parking_lots
from src.app.core.exceptions.http_exceptions import BadRequestException, NotFoundException
from src.app.models.enums import LeaseStatus, ParkingLotStatus, PricingMode, UserRole, VehicleTypeAll
from src.app.models.leases import LotLease
from src.app.models.parking import ParkingLot, ParkingLotConfig, Pricing
from src.app.models.users import Manager
from src.app.schemas.parking_lot import (
    OperatorManagedParkingLotUpdate,
    OperatorManagedParkingLotRead,
)


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
    manager.business_license = "OP-001"
    manager.verified_at = datetime.now(UTC)
    return manager


def _active_lease(lease_id: int = 4, parking_lot_id: int = 13, manager_id: int = 8) -> LotLease:
    lease = MagicMock(spec=LotLease)
    lease.id = lease_id
    lease.parking_lot_id = parking_lot_id
    lease.manager_id = manager_id
    lease.status = LeaseStatus.ACTIVE.value
    lease.created_at = datetime.now(UTC)
    return lease


def _parking_lot(parking_lot_id: int = 13, status: str = ParkingLotStatus.APPROVED.value) -> ParkingLot:
    parking_lot = MagicMock(spec=ParkingLot)
    parking_lot.id = parking_lot_id
    parking_lot.lot_owner_id = 3
    parking_lot.name = "Bai xe Nguyen Du"
    parking_lot.address = "5 Nguyen Du, Quan 1"
    parking_lot.latitude = 10.7751
    parking_lot.longitude = 106.7001
    parking_lot.current_available = 7
    parking_lot.status = status
    parking_lot.description = "Gan trung tam"
    parking_lot.cover_image = None
    parking_lot.created_at = datetime.now(UTC)
    parking_lot.updated_at = None
    return parking_lot


def _parking_lot_config(total_capacity: int = 10) -> ParkingLotConfig:
    config = MagicMock(spec=ParkingLotConfig)
    config.total_capacity = total_capacity
    config.opening_time = time(hour=6, minute=0)
    config.closing_time = time(hour=22, minute=0)
    config.created_at = datetime.now(UTC)
    return config


def _pricing(mode: str = PricingMode.HOURLY.value, price_amount: float = 15000) -> Pricing:
    pricing = MagicMock(spec=Pricing)
    pricing.pricing_mode = mode
    pricing.price_amount = price_amount
    pricing.created_at = datetime.now(UTC)
    return pricing


class TestOperatorManagedLots:
    @pytest.mark.asyncio
    async def test_get_latest_parking_lot_config_filters_to_lot_wide_rows(self, mock_db):
        config_result = MagicMock()
        config_result.scalar_one_or_none.return_value = _parking_lot_config(total_capacity=20)
        mock_db.execute = AsyncMock(return_value=config_result)

        await _get_latest_parking_lot_config(mock_db, 13)

        await_args = mock_db.execute.await_args
        assert await_args is not None
        query = await_args.args[0]
        compiled = query.compile()
        assert compiled.params["parking_lot_id_1"] == 13
        assert compiled.params["vehicle_type_1"] == VehicleTypeAll.ALL.value

    def test_operator_managed_lot_schema_supports_nullable_capacity(self):
        parking_lot = _parking_lot()
        lease = _active_lease(parking_lot_id=parking_lot.id)

        result = OperatorManagedParkingLotRead.model_validate(
            {
                "id": parking_lot.id,
                "lease_id": lease.id,
                "lot_owner_id": parking_lot.lot_owner_id,
                "name": parking_lot.name,
                "address": parking_lot.address,
                "latitude": parking_lot.latitude,
                "longitude": parking_lot.longitude,
                "current_available": parking_lot.current_available,
                "status": parking_lot.status,
                "description": parking_lot.description,
                "cover_image": parking_lot.cover_image,
                "created_at": parking_lot.created_at,
                "updated_at": parking_lot.updated_at,
                "total_capacity": None,
                "occupied_count": 3,
                "opening_time": None,
                "closing_time": None,
                "pricing_mode": None,
                "price_amount": None,
            }
        )

        assert result.total_capacity is None
        assert result.occupied_count == 3

    @pytest.mark.asyncio
    async def test_read_operator_parking_lots_returns_active_leased_lots(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        leases_result = MagicMock()
        leases_result.all.return_value = [(_active_lease(), _parking_lot())]
        config_result = MagicMock()
        config_result.scalar_one_or_none.return_value = _parking_lot_config(total_capacity=20)
        pricing_result = MagicMock()
        pricing_result.scalar_one_or_none.return_value = _pricing()
        active_sessions_result = MagicMock()
        active_sessions_result.scalar_one.return_value = 6
        mock_db.execute = AsyncMock(
            side_effect=[
                manager_result,
                leases_result,
                config_result,
                pricing_result,
                active_sessions_result,
            ]
        )

        result = await read_operator_parking_lots(Mock(), _manager_user(), mock_db)

        assert len(result) == 1
        assert result[0].total_capacity == 20
        assert result[0].occupied_count == 6
        assert result[0].opening_time == time(hour=6, minute=0)
        assert result[0].closing_time == time(hour=22, minute=0)
        assert result[0].pricing_mode == PricingMode.HOURLY
        assert result[0].price_amount == 15000

    @pytest.mark.asyncio
    async def test_patch_operator_parking_lot_updates_details_and_capacity(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.scalar_one_or_none.return_value = _active_lease()
        parking_lot = _parking_lot()
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = parking_lot
        active_sessions_result = MagicMock()
        active_sessions_result.scalar_one.return_value = 4
        mock_db.execute = AsyncMock(
            side_effect=[
                manager_result,
                lease_result,
                parking_lot_result,
                active_sessions_result,
            ]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        payload = OperatorManagedParkingLotUpdate(
            name="Bai xe Nguyen Du Mo Rong",
            address="7 Nguyen Du, Quan 1",
            total_capacity=30,
            opening_time=time(hour=5, minute=30),
            closing_time=time(hour=23, minute=0),
            pricing_mode=PricingMode.HOURLY,
            price_amount=18000,
            description="Mo rong suc chua cho gio cao diem",
            cover_image="https://example.com/lot.jpg",
        )
        result = await patch_operator_parking_lot(
            Mock(),
            parking_lot.id,
            payload,
            _manager_user(),
            mock_db,
        )

        assert result.name == payload.name
        assert result.total_capacity == 30
        assert result.current_available == 26
        assert result.opening_time == time(hour=5, minute=30)
        assert result.closing_time == time(hour=23, minute=0)
        assert result.pricing_mode == PricingMode.HOURLY
        assert result.price_amount == 18000
        assert mock_db.add.call_count == 2
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_patch_operator_parking_lot_clamps_current_available_to_zero(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.scalar_one_or_none.return_value = _active_lease()
        parking_lot = _parking_lot()
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = parking_lot
        active_sessions_result = MagicMock()
        active_sessions_result.scalar_one.return_value = 12
        mock_db.execute = AsyncMock(
            side_effect=[
                manager_result,
                lease_result,
                parking_lot_result,
                active_sessions_result,
            ]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        result = await patch_operator_parking_lot(
            Mock(),
            parking_lot.id,
            OperatorManagedParkingLotUpdate(
                name="Bai xe Nguyen Du Toi Gian",
                address="5 Nguyen Du, Quan 1",
                total_capacity=10,
                opening_time=time(hour=6, minute=0),
                closing_time=time(hour=22, minute=0),
                pricing_mode=PricingMode.HOURLY,
                price_amount=12000,
                description=None,
                cover_image=None,
            ),
            _manager_user(),
            mock_db,
        )

        assert result.total_capacity == 10
        assert result.occupied_count == 12
        assert result.current_available == 0

    @pytest.mark.asyncio
    async def test_patch_operator_parking_lot_raises_not_found_without_active_lease(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(side_effect=[manager_result, lease_result])

        with pytest.raises(NotFoundException, match="Managed parking lot not found"):
            await patch_operator_parking_lot(
                Mock(),
                999,
                OperatorManagedParkingLotUpdate(
                    name="Bai xe A",
                    address="1 Le Loi, Quan 1",
                    total_capacity=10,
                    opening_time=time(hour=6, minute=0),
                    closing_time=time(hour=22, minute=0),
                    pricing_mode=PricingMode.HOURLY,
                    price_amount=15000,
                    description=None,
                    cover_image=None,
                ),
                _manager_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_patch_operator_parking_lot_rejects_pending_lot(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.scalar_one_or_none.return_value = _active_lease()
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = _parking_lot(
            status=ParkingLotStatus.PENDING.value
        )
        mock_db.execute = AsyncMock(
            side_effect=[manager_result, lease_result, parking_lot_result]
        )

        with pytest.raises(BadRequestException, match="approved or suspended"):
            await patch_operator_parking_lot(
                Mock(),
                13,
                OperatorManagedParkingLotUpdate(
                    name="Bai xe A",
                    address="1 Le Loi, Quan 1",
                    total_capacity=10,
                    opening_time=time(hour=6, minute=0),
                    closing_time=time(hour=22, minute=0),
                    pricing_mode=PricingMode.HOURLY,
                    price_amount=15000,
                    description=None,
                    cover_image=None,
                ),
                _manager_user(),
                mock_db,
            )