"""Unit tests for Story 8.3 operator revenue reporting."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1 import reports
from src.app.api.v1.reports import get_operator_revenue_summary
from src.app.core.exceptions.http_exceptions import NotFoundException
from src.app.models.enums import LeaseContractStatus, LeaseStatus, ParkingLotStatus
from src.app.models.leases import LeaseContract, LotLease
from src.app.models.parking import ParkingLot, ParkingLotConfig
from src.app.models.sessions import ParkingSession
from src.app.models.user import User
from src.app.models.users import Manager
from src.app.schemas.report import OwnerRevenuePeriod


def _manager_user(user_id: int = 9) -> dict:
    return {
        "id": user_id,
        "username": "operator",
        "email": "operator@test.com",
        "role": "MANAGER",
        "is_superuser": False,
    }


def _manager_profile(profile_id: int = 4, user_id: int = 9) -> Manager:
    profile = MagicMock(spec=Manager)
    profile.id = profile_id
    profile.user_id = user_id
    return profile


def _parking_lot() -> ParkingLot:
    parking_lot = MagicMock(spec=ParkingLot)
    parking_lot.id = 7
    parking_lot.lot_owner_id = 3
    parking_lot.name = "Bai xe Nguyen Hue"
    parking_lot.status = ParkingLotStatus.APPROVED.value
    return parking_lot


def _owner_user() -> User:
    user = MagicMock(spec=User)
    user.id = 1
    user.name = "Nguyen Van A"
    user.email = "owner@test.com"
    user.is_deleted = False
    return user


def _contract(status: str = LeaseContractStatus.ACTIVE.value) -> LeaseContract:
    contract = MagicMock(spec=LeaseContract)
    contract.id = 22
    contract.lease_id = 18
    contract.status = status
    return contract


def _lease(
    status: str = LeaseStatus.ACTIVE.value,
    end_date: datetime | None = datetime(2026, 3, 31, tzinfo=UTC),
) -> LotLease:
    lease = MagicMock(spec=LotLease)
    lease.id = 18
    lease.parking_lot_id = 7
    lease.manager_id = 4
    lease.monthly_fee = 15000000
    lease.revenue_share_percentage = 35
    lease.term_months = 6
    lease.status = status
    lease.start_date = datetime(2026, 3, 1, tzinfo=UTC)
    lease.end_date = end_date
    lease.created_at = datetime(2026, 3, 28, tzinfo=UTC)
    return lease


def _capacity_config(total_capacity: int = 20) -> ParkingLotConfig:
    config = MagicMock(spec=ParkingLotConfig)
    config.total_capacity = total_capacity
    return config


def _session(
    vehicle_type: str,
    checkin_time: datetime,
    checkout_time: datetime,
) -> ParkingSession:
    session = MagicMock(spec=ParkingSession)
    session.id = hash((vehicle_type, checkin_time.isoformat(), checkout_time.isoformat()))
    session.vehicle_type = vehicle_type
    session.checkin_time = checkin_time
    session.checkout_time = checkout_time
    return session


class TestOperatorRevenueReports:
    @pytest.mark.asyncio
    async def test_returns_operator_revenue_summary_with_breakdown_and_occupancy(self, mock_db, monkeypatch):
        monkeypatch.setattr(reports, "_utcnow", lambda: datetime(2026, 3, 29, 10, 30, tzinfo=UTC))

        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.one_or_none.return_value = (_lease(), _parking_lot(), _owner_user())
        config_result = MagicMock()
        config_result.scalar_one_or_none.return_value = _capacity_config(20)
        paid_sessions_result = MagicMock()
        paid_sessions_result.scalars.return_value.all.return_value = [
            _session('CAR', datetime(2026, 3, 29, 8, 0, tzinfo=UTC), datetime(2026, 3, 29, 10, 0, tzinfo=UTC)),
            _session('MOTORBIKE', datetime(2026, 3, 29, 9, 0, tzinfo=UTC), datetime(2026, 3, 29, 11, 0, tzinfo=UTC)),
        ]
        totals_result = MagicMock()
        totals_result.one.return_value = (2, 400000, 2)
        breakdown_result = MagicMock()
        breakdown_result.all.return_value = [('CAR', 1), ('MOTORBIKE', 1)]
        mock_db.execute = AsyncMock(
            side_effect=[manager_result, lease_result, config_result, paid_sessions_result, totals_result, breakdown_result]
        )
        mock_db.commit = AsyncMock()

        result = await get_operator_revenue_summary(
            Mock(),
            7,
            OwnerRevenuePeriod.DAY,
            _manager_user(),
            mock_db,
        )

        assert result.has_data is True
        assert result.gross_revenue == 400000
        assert result.owner_share == 140000
        assert result.operator_share == 260000
        assert result.completed_session_count == 2
        assert result.total_capacity == 20
        assert result.occupancy_rate_percentage == 0.83
        assert [item.vehicle_type for item in result.vehicle_type_breakdown] == ['CAR', 'MOTORBIKE']
        mock_db.commit.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_returns_empty_state_when_selected_period_has_no_paid_sessions(self, mock_db, monkeypatch):
        monkeypatch.setattr(reports, "_utcnow", lambda: datetime(2026, 3, 29, 10, 30, tzinfo=UTC))

        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.one_or_none.return_value = (_lease(), _parking_lot(), _owner_user())
        config_result = MagicMock()
        config_result.scalar_one_or_none.return_value = _capacity_config(20)
        paid_sessions_result = MagicMock()
        paid_sessions_result.scalars.return_value.all.return_value = []
        totals_result = MagicMock()
        totals_result.one.return_value = (0, 0, 0)
        mock_db.execute = AsyncMock(
            side_effect=[manager_result, lease_result, config_result, paid_sessions_result, totals_result]
        )
        mock_db.commit = AsyncMock()

        result = await get_operator_revenue_summary(
            Mock(),
            7,
            OwnerRevenuePeriod.DAY,
            _manager_user(),
            mock_db,
        )

        assert result.has_data is False
        assert result.empty_reason == 'NO_COMPLETED_PAYMENTS'
        assert result.lease_status == LeaseStatus.ACTIVE.value

    @pytest.mark.asyncio
    async def test_preserves_expired_lease_state_for_historical_operator_reads(self, mock_db, monkeypatch):
        monkeypatch.setattr(reports, "_utcnow", lambda: datetime(2026, 3, 29, 10, 30, tzinfo=UTC))

        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.one_or_none.return_value = (
            _lease(end_date=datetime(2026, 3, 28, tzinfo=UTC)),
            _parking_lot(),
            _owner_user(),
        )
        contract_result = MagicMock()
        contract_result.scalar_one_or_none.return_value = _contract()
        config_result = MagicMock()
        config_result.scalar_one_or_none.return_value = _capacity_config(10)
        paid_sessions_result = MagicMock()
        paid_sessions_result.scalars.return_value.all.return_value = [
            _session('CAR', datetime(2026, 3, 28, 8, 0, tzinfo=UTC), datetime(2026, 3, 28, 9, 0, tzinfo=UTC)),
        ]
        totals_result = MagicMock()
        totals_result.one.return_value = (1, 100000, 1)
        breakdown_result = MagicMock()
        breakdown_result.all.return_value = [('CAR', 1)]
        mock_db.execute = AsyncMock(
            side_effect=[manager_result, lease_result, contract_result, config_result, paid_sessions_result, totals_result, breakdown_result]
        )
        mock_db.commit = AsyncMock()

        result = await get_operator_revenue_summary(
            Mock(),
            7,
            OwnerRevenuePeriod.MONTH,
            _manager_user(),
            mock_db,
        )

        assert result.lease_status == LeaseStatus.EXPIRED.value
        assert result.has_data is True
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_rejects_operator_revenue_request_for_unmanaged_lot(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.one_or_none.return_value = None
        mock_db.execute = AsyncMock(side_effect=[manager_result, lease_result])

        with pytest.raises(NotFoundException, match='Parking lot not found'):
            await get_operator_revenue_summary(
                Mock(),
                404,
                OwnerRevenuePeriod.DAY,
                _manager_user(),
                mock_db,
            )