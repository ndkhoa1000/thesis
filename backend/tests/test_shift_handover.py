"""Unit tests for Story 6.4 zero-trust shift handover."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.shifts import (
    create_attendant_shift_handover,
    finalize_attendant_shift_handover,
    read_operator_shift_handover_alerts,
)
from src.app.core.exceptions.http_exceptions import BadRequestException, ForbiddenException
from src.app.models.enums import LeaseStatus, NotificationType, ReferenceType, ShiftStatus, UserRole
from src.app.models.leases import LotLease
from src.app.models.notifications import Notification
from src.app.models.parking import ParkingLot
from src.app.models.shifts import Shift, ShiftHandover
from src.app.models.user import User
from src.app.models.users import Attendant, Manager
from src.app.schemas.shift import AttendantShiftHandoverFinalizeCreate
from src.app.services.shift_service import build_shift_handover_token


NOW = datetime(2026, 3, 28, 9, 0, tzinfo=UTC)


def _attendant_user(user_id: int = 51) -> dict:
    return {
        "id": user_id,
        "username": "attendant_user",
        "email": "attendant@test.com",
        "role": UserRole.ATTENDANT.value,
        "is_superuser": False,
    }


def _manager_user(user_id: int = 21) -> dict:
    return {
        "id": user_id,
        "username": "operator",
        "email": "operator@test.com",
        "role": UserRole.MANAGER.value,
        "is_superuser": False,
    }


def _make_attendant(attendant_id: int = 7, user_id: int = 51, parking_lot_id: int = 13) -> Attendant:
    attendant = MagicMock(spec=Attendant)
    attendant.id = attendant_id
    attendant.user_id = user_id
    attendant.parking_lot_id = parking_lot_id
    return attendant


def _make_manager(manager_id: int = 8, user_id: int = 21) -> Manager:
    manager = MagicMock(spec=Manager)
    manager.id = manager_id
    manager.user_id = user_id
    return manager


def _make_lot(lot_id: int = 13) -> ParkingLot:
    lot = MagicMock(spec=ParkingLot)
    lot.id = lot_id
    lot.name = 'Bai xe Nguyen Du'
    return lot


def _make_shift(
    *,
    shift_id: int = 17,
    parking_lot_id: int = 13,
    attendant_id: int = 7,
    started_at: datetime = NOW,
    ended_at: datetime | None = None,
    status: str = ShiftStatus.OPEN.value,
) -> Shift:
    shift = MagicMock(spec=Shift)
    shift.id = shift_id
    shift.parking_lot_id = parking_lot_id
    shift.attendant_id = attendant_id
    shift.started_at = started_at
    shift.ended_at = ended_at
    shift.status = status
    shift.created_at = NOW
    return shift


def _make_active_lease(
    *,
    lease_id: int = 4,
    parking_lot_id: int = 13,
    manager_id: int = 8,
) -> LotLease:
    lease = MagicMock(spec=LotLease)
    lease.id = lease_id
    lease.parking_lot_id = parking_lot_id
    lease.manager_id = manager_id
    lease.status = LeaseStatus.ACTIVE.value
    lease.created_at = NOW
    return lease


def _make_user(*, user_id: int = 21, name: str = 'Operator A') -> User:
    user = MagicMock(spec=User)
    user.id = user_id
    user.name = name
    user.username = 'operator'
    user.email = 'operator@test.com'
    return user


class TestAttendantShiftHandoverStart:
    @pytest.mark.asyncio
    async def test_prepares_qr_payload_from_open_shift_cash_total(self, mock_db, monkeypatch):
        monkeypatch.setattr('src.app.api.v1.shifts._utcnow', lambda: NOW)

        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()
        open_shift = _make_shift(started_at=datetime(2026, 3, 28, 6, 0, tzinfo=UTC))
        shift_result = MagicMock()
        shift_result.scalar_one_or_none.return_value = open_shift
        expected_cash_result = MagicMock()
        expected_cash_result.scalar_one.return_value = 85000

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, shift_result, expected_cash_result]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()

        result = await create_attendant_shift_handover(Mock(), _attendant_user(), mock_db)

        assert result.shift_id == 17
        assert result.parking_lot_id == 13
        assert result.expected_cash == 85000
        assert result.expires_in_seconds > 0
        assert isinstance(result.token, str)
        assert open_shift.status == ShiftStatus.HANDOVER_PENDING.value
        assert open_shift.ended_at == NOW
        mock_db.add.assert_not_called()
        mock_db.commit.assert_awaited_once()

        aggregation_query = mock_db.execute.await_args_list[3].args[0]
        compiled = aggregation_query.compile()
        assert compiled.params['payment_method_1'] == 'CASH'
        assert compiled.params['payment_status_1'] == 'COMPLETED'


class TestAttendantShiftHandoverFinalize:
    @pytest.mark.asyncio
    async def test_blocks_mismatch_without_reason(self, mock_db, monkeypatch):
        monkeypatch.setattr('src.app.api.v1.shifts._utcnow', lambda: NOW)

        incoming_attendant_result = MagicMock()
        incoming_attendant_result.scalar_one_or_none.return_value = _make_attendant(attendant_id=9, user_id=61)
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()
        outgoing_shift = _make_shift(
            shift_id=17,
            attendant_id=7,
            started_at=datetime(2026, 3, 28, 6, 0, tzinfo=UTC),
            ended_at=datetime(2026, 3, 28, 9, 0, tzinfo=UTC),
            status=ShiftStatus.HANDOVER_PENDING.value,
        )
        shift_result = MagicMock()
        shift_result.scalar_one_or_none.return_value = outgoing_shift
        expected_cash_result = MagicMock()
        expected_cash_result.scalar_one.return_value = 85000

        token = build_shift_handover_token(
            shift=outgoing_shift,
            expected_cash=85000,
            expires_at=datetime(2026, 3, 28, 9, 5, tzinfo=UTC),
        )

        mock_db.execute = AsyncMock(
            side_effect=[incoming_attendant_result, lot_result, shift_result, expected_cash_result]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()

        with pytest.raises(BadRequestException, match='Discrepancy reason is required'):
            await finalize_attendant_shift_handover(
                Mock(),
                AttendantShiftHandoverFinalizeCreate(token=token, actual_cash=80000, discrepancy_reason=None),
                _attendant_user(user_id=61),
                mock_db,
            )

        mock_db.add.assert_not_called()
        mock_db.commit.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_locks_shift_and_creates_operator_alert_on_discrepancy(self, mock_db, monkeypatch):
        monkeypatch.setattr('src.app.api.v1.shifts._utcnow', lambda: NOW)

        incoming_attendant_result = MagicMock()
        incoming_attendant_result.scalar_one_or_none.return_value = _make_attendant(attendant_id=9, user_id=61)
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()
        outgoing_shift = _make_shift(
            shift_id=17,
            attendant_id=7,
            started_at=datetime(2026, 3, 28, 6, 0, tzinfo=UTC),
            ended_at=datetime(2026, 3, 28, 8, 45, tzinfo=UTC),
            status=ShiftStatus.HANDOVER_PENDING.value,
        )
        outgoing_shift_result = MagicMock()
        outgoing_shift_result.scalar_one_or_none.return_value = outgoing_shift
        expected_cash_result = MagicMock()
        expected_cash_result.scalar_one.return_value = 85000
        incoming_shift_result = MagicMock()
        incoming_shift_result.scalar_one_or_none.return_value = None
        operator_rows_result = MagicMock()
        operator_rows_result.all.return_value = [(_make_active_lease(), _make_manager(), _make_user())]

        token = build_shift_handover_token(
            shift=outgoing_shift,
            expected_cash=85000,
            expires_at=datetime(2026, 3, 28, 9, 5, tzinfo=UTC),
        )

        mock_db.execute = AsyncMock(
            side_effect=[
                incoming_attendant_result,
                lot_result,
                outgoing_shift_result,
                expected_cash_result,
                incoming_shift_result,
                operator_rows_result,
            ]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        result = await finalize_attendant_shift_handover(
            Mock(),
            AttendantShiftHandoverFinalizeCreate(
                token=token,
                actual_cash=80000,
                discrepancy_reason='Thieu 5.000 VND sau khi doi ca.',
            ),
            _attendant_user(user_id=61),
            mock_db,
        )

        added = [call.args[0] for call in mock_db.add.call_args_list]
        created_incoming_shift = next(item for item in added if isinstance(item, Shift))
        created_handover = next(item for item in added if isinstance(item, ShiftHandover))
        created_notification = next(item for item in added if isinstance(item, Notification))

        assert created_incoming_shift.attendant_id == 9
        assert created_handover.outgoing_shift_id == 17
        assert created_handover.expected_cash == 85000
        assert created_handover.actual_cash == 80000
        assert created_handover.discrepancy_reason == 'Thieu 5.000 VND sau khi doi ca.'
        assert created_notification.user_id == 21
        assert created_notification.notification_type == NotificationType.SHIFT_HANDOVER_DISCREPANCY.value
        assert created_notification.reference_type == ReferenceType.SHIFT_HANDOVER.value
        assert outgoing_shift.status == ShiftStatus.LOCKED.value
        mock_db.commit.assert_awaited_once()
        assert result.discrepancy_flagged is True
        assert result.expected_cash == 85000
        assert result.actual_cash == 80000


class TestOperatorShiftAlerts:
    @pytest.mark.asyncio
    async def test_reads_shift_handover_alerts_for_current_operator(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _make_manager()

        notification = MagicMock(spec=Notification)
        notification.id = 41
        notification.user_id = 21
        notification.title = 'Chenh lech giao ca tai Bai xe Nguyen Du'
        notification.message = 'Lech 5.000 VND. Ly do: Thieu tien mat.'
        notification.notification_type = NotificationType.SHIFT_HANDOVER_DISCREPANCY.value
        notification.reference_type = ReferenceType.SHIFT_HANDOVER.value
        notification.reference_id = 17
        notification.is_read = False
        notification.created_at = NOW

        notification_result = MagicMock()
        notification_result.scalars.return_value.all.return_value = [notification]

        mock_db.execute = AsyncMock(side_effect=[manager_result, notification_result])

        result = await read_operator_shift_handover_alerts(Mock(), _manager_user(), mock_db)

        assert len(result) == 1
        assert result[0].id == 41
        assert result[0].reference_id == 17
        assert result[0].notification_type == NotificationType.SHIFT_HANDOVER_DISCREPANCY.value

    @pytest.mark.asyncio
    async def test_rejects_non_operator_accounts(self, mock_db):
        with pytest.raises(ForbiddenException, match='Operator capability is required'):
            await read_operator_shift_handover_alerts(
                Mock(),
                _attendant_user(),
                mock_db,
            )
