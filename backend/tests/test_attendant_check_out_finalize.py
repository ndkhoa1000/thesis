"""Unit tests for attendant checkout finalization flow (Story 4.6)."""

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.sessions import attendant_check_out_finalize, attendant_check_out_undo
from src.app.core.exceptions.http_exceptions import BadRequestException
from src.app.models.enums import PaymentMethod, PaymentStatus, SessionStatus
from src.app.models.financials import Payment
from src.app.models.parking import ParkingLot, Pricing
from src.app.models.sessions import ParkingSession
from src.app.models.users import Attendant
from src.app.schemas.session import AttendantCheckOutFinalizeCreate, AttendantCheckOutUndoCreate


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


def _make_lot(
    lot_id: int = 13,
    name: str = "Bai xe Quan 1",
    current_available: int = 7,
) -> ParkingLot:
    lot = MagicMock(spec=ParkingLot)
    lot.id = lot_id
    lot.name = name
    lot.current_available = current_available
    return lot


def _make_session(
    *,
    session_id: int = 88,
    parking_lot_id: int = 13,
    driver_id: int = 9,
    license_plate: str = "30A-99999",
    vehicle_type: str = "CAR",
    status: str = "CHECKED_IN",
    checkin_time: datetime | None = None,
    checkout_time: datetime | None = None,
    attendant_checkout_id: int | None = None,
) -> ParkingSession:
    session = MagicMock(spec=ParkingSession)
    session.id = session_id
    session.parking_lot_id = parking_lot_id
    session.driver_id = driver_id
    session.license_plate = license_plate
    session.vehicle_type = vehicle_type
    session.status = status
    session.checkin_time = checkin_time or datetime.now(UTC) - timedelta(minutes=125)
    session.checkout_time = checkout_time
    session.attendant_checkout_id = attendant_checkout_id
    return session


def _make_pricing(*, pricing_mode: str = "HOURLY", price_amount: float = 15000) -> Pricing:
    pricing = MagicMock(spec=Pricing)
    pricing.pricing_mode = pricing_mode
    pricing.price_amount = price_amount
    pricing.vehicle_type = "CAR"
    return pricing


def _existing_payment(
    *,
    payable_id: int = 88,
    payment_status: str = PaymentStatus.COMPLETED.value,
) -> Payment:
    payment = MagicMock(spec=Payment)
    payment.id = 991
    payment.payable_id = payable_id
    payment.payment_status = payment_status
    payment.payment_method = PaymentMethod.CASH.value
    return payment


class TestAttendantCheckOutFinalize:
    @pytest.mark.asyncio
    async def test_finalizes_checkout_and_creates_payment_atomically(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot = _make_lot(current_available=7)
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = lot

        session = _make_session()
        session_result = MagicMock()
        session_result.scalar_one_or_none.return_value = session

        payment_lookup_result = MagicMock()
        payment_lookup_result.scalars.return_value.all.return_value = []

        pricing_result = MagicMock()
        pricing_result.scalars.return_value.all.return_value = [_make_pricing()]

        open_shift_result = MagicMock()
        open_shift_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(
            side_effect=[
                attendant_result,
                lot_result,
                session_result,
                payment_lookup_result,
                pricing_result,
                open_shift_result,
            ]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()
        mock_db.rollback = AsyncMock()

        result = await attendant_check_out_finalize(
            Mock(),
            AttendantCheckOutFinalizeCreate(
                session_id=88,
                payment_method=PaymentMethod.CASH.value,
                quoted_final_fee=45000,
            ),
            _attendant_user(),
            mock_db,
        )

        created_payment = mock_db.add.call_args.args[0]
        assert isinstance(created_payment, Payment)
        assert created_payment.payable_id == 88
        assert created_payment.amount == 45000
        assert created_payment.final_amount == 45000
        assert created_payment.payment_method == PaymentMethod.CASH.value
        assert created_payment.payment_status == PaymentStatus.COMPLETED.value
        assert created_payment.processed_by == 51
        assert session.status == SessionStatus.CHECKED_OUT.value
        assert session.attendant_checkout_id == 7
        assert session.checkout_time is not None
        assert lot.current_available == 8
        mock_db.commit.assert_awaited_once()
        mock_db.rollback.assert_not_awaited()
        assert result.session_id == 88
        assert result.final_fee == 45000
        assert result.payment_method == PaymentMethod.CASH.value
        assert result.current_available == 8

    @pytest.mark.asyncio
    async def test_rejects_duplicate_finalization_when_completed_payment_exists(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        session_result = MagicMock()
        session_result.scalar_one_or_none.return_value = _make_session()

        payment_lookup_result = MagicMock()
        payment_lookup_result.scalars.return_value.all.return_value = [_existing_payment()]

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, session_result, payment_lookup_result]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()

        with pytest.raises(BadRequestException, match="already been finalized"):
            await attendant_check_out_finalize(
                Mock(),
                AttendantCheckOutFinalizeCreate(
                    session_id=88,
                    payment_method=PaymentMethod.CASH.value,
                    quoted_final_fee=45000,
                ),
                _attendant_user(),
                mock_db,
            )

        mock_db.add.assert_not_called()
        mock_db.commit.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_rejects_stale_preview_when_authoritative_fee_changes(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        session_result = MagicMock()
        session_result.scalar_one_or_none.return_value = _make_session()

        payment_lookup_result = MagicMock()
        payment_lookup_result.scalars.return_value.all.return_value = []

        pricing_result = MagicMock()
        pricing_result.scalars.return_value.all.return_value = [_make_pricing(price_amount=20000)]

        mock_db.execute = AsyncMock(
            side_effect=[
                attendant_result,
                lot_result,
                session_result,
                payment_lookup_result,
                pricing_result,
            ]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()

        with pytest.raises(BadRequestException, match="preview is stale"):
            await attendant_check_out_finalize(
                Mock(),
                AttendantCheckOutFinalizeCreate(
                    session_id=88,
                    payment_method=PaymentMethod.ONLINE.value,
                    quoted_final_fee=45000,
                ),
                _attendant_user(),
                mock_db,
            )

        mock_db.add.assert_not_called()
        mock_db.commit.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_rolls_back_local_mutations_when_commit_fails(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot = _make_lot(current_available=7)
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = lot

        session = _make_session()
        session_result = MagicMock()
        session_result.scalar_one_or_none.return_value = session

        payment_lookup_result = MagicMock()
        payment_lookup_result.scalars.return_value.all.return_value = []

        pricing_result = MagicMock()
        pricing_result.scalars.return_value.all.return_value = [_make_pricing()]

        open_shift_result = MagicMock()
        open_shift_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(
            side_effect=[
                attendant_result,
                lot_result,
                session_result,
                payment_lookup_result,
                pricing_result,
                open_shift_result,
            ]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock(side_effect=RuntimeError("commit failed"))
        mock_db.rollback = AsyncMock()

        with pytest.raises(RuntimeError, match="commit failed"):
            await attendant_check_out_finalize(
                Mock(),
                AttendantCheckOutFinalizeCreate(
                    session_id=88,
                    payment_method=PaymentMethod.CASH.value,
                    quoted_final_fee=45000,
                ),
                _attendant_user(),
                mock_db,
            )

        mock_db.rollback.assert_awaited_once()
        assert session.status == SessionStatus.CHECKED_IN.value
        assert session.attendant_checkout_id is None
        assert session.checkout_time is None
        assert lot.current_available == 7

    @pytest.mark.asyncio
    async def test_undo_reopens_recent_checkout_within_recovery_window(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot = _make_lot(current_available=8)
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = lot

        session = _make_session(
            status=SessionStatus.CHECKED_OUT.value,
            checkout_time=datetime.now(UTC) - timedelta(seconds=2),
            attendant_checkout_id=7,
        )
        session_result = MagicMock()
        session_result.scalar_one_or_none.return_value = session

        payment_lookup_result = MagicMock()
        payment_lookup_result.scalars.return_value.all.return_value = [_existing_payment()]

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, session_result, payment_lookup_result]
        )
        mock_db.commit = AsyncMock()
        mock_db.rollback = AsyncMock()

        result = await attendant_check_out_undo(
            Mock(),
            AttendantCheckOutUndoCreate(session_id=88),
            _attendant_user(),
            mock_db,
        )

        assert session.status == SessionStatus.CHECKED_IN.value
        assert session.checkout_time is None
        assert session.attendant_checkout_id is None
        assert lot.current_available == 7
        assert result.status == SessionStatus.CHECKED_IN.value
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_rejects_undo_after_recovery_window_expires(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot(current_available=8)

        session_result = MagicMock()
        session_result.scalar_one_or_none.return_value = _make_session(
            status=SessionStatus.CHECKED_OUT.value,
            checkout_time=datetime.now(UTC) - timedelta(seconds=5),
            attendant_checkout_id=7,
        )

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, session_result]
        )
        mock_db.commit = AsyncMock()

        with pytest.raises(BadRequestException, match="Undo window has expired"):
            await attendant_check_out_undo(
                Mock(),
                AttendantCheckOutUndoCreate(session_id=88),
                _attendant_user(),
                mock_db,
            )

        mock_db.commit.assert_not_awaited()