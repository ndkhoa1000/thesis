"""Unit tests for Story 8.2 owner revenue reporting."""

from datetime import UTC, date, datetime
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1 import reports
from src.app.api.v1.reports import _build_period_window, get_owner_revenue_summary
from src.app.core.exceptions.http_exceptions import NotFoundException
from src.app.models.enums import LeaseContractStatus, LeaseStatus, ParkingLotStatus
from src.app.models.leases import LeaseContract, LotLease
from src.app.models.parking import ParkingLot
from src.app.models.user import User
from src.app.models.users import LotOwner
from src.app.schemas.report import OwnerRevenuePeriod


def _owner_user(user_id: int = 1) -> dict:
    return {
        "id": user_id,
        "username": "owner_user",
        "email": "owner@test.com",
        "role": "LOT_OWNER",
        "is_superuser": False,
    }


def _lot_owner_profile(profile_id: int = 3, user_id: int = 1) -> LotOwner:
    profile = MagicMock(spec=LotOwner)
    profile.id = profile_id
    profile.user_id = user_id
    return profile


def _parking_lot(lot_owner_id: int = 3) -> ParkingLot:
    parking_lot = MagicMock(spec=ParkingLot)
    parking_lot.id = 7
    parking_lot.lot_owner_id = lot_owner_id
    parking_lot.name = "Bai xe Nguyen Hue"
    parking_lot.status = ParkingLotStatus.APPROVED.value
    return parking_lot


def _lease(
    status: str = LeaseStatus.ACTIVE.value,
    start_date: datetime | None = datetime(2026, 3, 1, tzinfo=UTC),
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
    lease.start_date = start_date
    lease.end_date = end_date
    lease.created_at = datetime(2026, 3, 28, tzinfo=UTC)
    return lease


def _operator_user() -> User:
    user = MagicMock(spec=User)
    user.id = 9
    user.name = "Tran Thi B"
    user.email = "operator@test.com"
    user.is_deleted = False
    return user


def _contract(status: str = LeaseContractStatus.ACTIVE.value) -> LeaseContract:
    contract = MagicMock(spec=LeaseContract)
    contract.id = 22
    contract.lease_id = 18
    contract.status = status
    return contract


class TestOwnerRevenueReport:
    def test_build_period_window_for_week(self):
        start_date, end_date, start_at, end_before = _build_period_window(
            datetime(2026, 3, 29, 10, 30, tzinfo=UTC),
            OwnerRevenuePeriod.WEEK,
        )

        assert start_date == date(2026, 3, 23)
        assert end_date == date(2026, 3, 29)
        assert start_at == datetime(2026, 3, 23, 0, 0, tzinfo=UTC)
        assert end_before == datetime(2026, 3, 30, 0, 0, tzinfo=UTC)

    @pytest.mark.asyncio
    async def test_returns_owner_revenue_summary_for_completed_payments(self, mock_db, monkeypatch):
        monkeypatch.setattr(reports, "_utcnow", lambda: datetime(2026, 3, 29, 10, 30, tzinfo=UTC))

        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = _parking_lot()
        accepted_lease_result = MagicMock()
        accepted_lease_result.one_or_none.return_value = (_lease(), _operator_user())
        totals_result = MagicMock()
        totals_result.one.return_value = (2, 400000, 2)
        mock_db.execute = AsyncMock(
            side_effect=[owner_result, parking_lot_result, accepted_lease_result, totals_result]
        )
        mock_db.commit = AsyncMock()

        result = await get_owner_revenue_summary(
            Mock(),
            7,
            OwnerRevenuePeriod.MONTH,
            _owner_user(),
            mock_db,
        )

        assert result.has_data is True
        assert result.gross_revenue == 400000
        assert result.owner_share == 140000
        assert result.operator_share == 260000
        assert result.lease_status == LeaseStatus.ACTIVE.value
        assert result.operator_name == "Tran Thi B"
        assert result.completed_payment_count == 2
        assert result.completed_session_count == 2
        mock_db.commit.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_returns_empty_state_when_no_accepted_lease_exists(self, mock_db, monkeypatch):
        monkeypatch.setattr(reports, "_utcnow", lambda: datetime(2026, 3, 29, 10, 30, tzinfo=UTC))

        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = _parking_lot()
        accepted_lease_result = MagicMock()
        accepted_lease_result.one_or_none.return_value = None
        latest_status_result = MagicMock()
        latest_status_result.scalar_one_or_none.return_value = "PENDING"
        mock_db.execute = AsyncMock(
            side_effect=[owner_result, parking_lot_result, accepted_lease_result, latest_status_result]
        )

        result = await get_owner_revenue_summary(
            Mock(),
            7,
            OwnerRevenuePeriod.DAY,
            _owner_user(),
            mock_db,
        )

        assert result.has_data is False
        assert result.empty_reason == "NO_ACCEPTED_LEASE"
        assert result.lease_status == "PENDING"
        assert result.gross_revenue is None

    @pytest.mark.asyncio
    async def test_preserves_historical_revenue_for_expired_lease(self, mock_db, monkeypatch):
        monkeypatch.setattr(reports, "_utcnow", lambda: datetime(2026, 3, 29, 10, 30, tzinfo=UTC))
        expired_lease = _lease(end_date=datetime(2026, 3, 28, tzinfo=UTC))

        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = _parking_lot()
        accepted_lease_result = MagicMock()
        accepted_lease_result.one_or_none.return_value = (expired_lease, _operator_user())
        contract_result = MagicMock()
        contract_result.scalar_one_or_none.return_value = _contract()
        totals_result = MagicMock()
        totals_result.one.return_value = (1, 100000, 1)
        mock_db.execute = AsyncMock(
            side_effect=[owner_result, parking_lot_result, accepted_lease_result, contract_result, totals_result]
        )
        mock_db.commit = AsyncMock()

        result = await get_owner_revenue_summary(
            Mock(),
            7,
            OwnerRevenuePeriod.MONTH,
            _owner_user(),
            mock_db,
        )

        assert result.has_data is True
        assert result.lease_status == LeaseStatus.EXPIRED.value
        assert result.owner_share == 35000
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_owner_revenue_uses_shared_expiry_helper(self, mock_db, monkeypatch):
        monkeypatch.setattr(reports, "_utcnow", lambda: datetime(2026, 3, 29, 10, 30, tzinfo=UTC))
        expired_lease = _lease(end_date=datetime(2026, 3, 28, tzinfo=UTC))

        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = _parking_lot()
        accepted_lease_result = MagicMock()
        accepted_lease_result.one_or_none.return_value = (expired_lease, _operator_user())
        totals_result = MagicMock()
        totals_result.one.return_value = (1, 100000, 1)
        mock_db.execute = AsyncMock(
            side_effect=[owner_result, parking_lot_result, accepted_lease_result, totals_result]
        )
        expiry_helper = AsyncMock(return_value=expired_lease)
        monkeypatch.setattr(reports, "_expire_lease_and_contract_if_needed", expiry_helper)

        await get_owner_revenue_summary(
            Mock(),
            7,
            OwnerRevenuePeriod.MONTH,
            _owner_user(),
            mock_db,
        )

        expiry_helper.assert_awaited_once_with(mock_db, expired_lease)

    @pytest.mark.asyncio
    async def test_rejects_revenue_request_for_foreign_lot(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = _parking_lot(lot_owner_id=99)
        mock_db.execute = AsyncMock(side_effect=[owner_result, parking_lot_result])

        with pytest.raises(NotFoundException, match="Parking lot not found"):
            await get_owner_revenue_summary(
                Mock(),
                7,
                OwnerRevenuePeriod.DAY,
                _owner_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_returns_empty_state_when_selected_period_has_no_completed_payments(self, mock_db, monkeypatch):
        monkeypatch.setattr(reports, "_utcnow", lambda: datetime(2026, 3, 29, 10, 30, tzinfo=UTC))

        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = _parking_lot()
        accepted_lease_result = MagicMock()
        accepted_lease_result.one_or_none.return_value = (_lease(), _operator_user())
        totals_result = MagicMock()
        totals_result.one.return_value = (0, 0, 0)
        mock_db.execute = AsyncMock(
            side_effect=[owner_result, parking_lot_result, accepted_lease_result, totals_result]
        )
        mock_db.commit = AsyncMock()

        result = await get_owner_revenue_summary(
            Mock(),
            7,
            OwnerRevenuePeriod.DAY,
            _owner_user(),
            mock_db,
        )

        assert result.has_data is False
        assert result.empty_reason == "NO_COMPLETED_PAYMENTS"
        assert result.lease_status == LeaseStatus.ACTIVE.value