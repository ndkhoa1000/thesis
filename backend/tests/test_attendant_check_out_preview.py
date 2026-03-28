"""Unit tests for attendant checkout preview flow (Story 4.5)."""

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest
from jose import jwt

from src.app.api.v1.sessions import attendant_check_out_preview
from src.app.core.exceptions.http_exceptions import BadRequestException, NotFoundException
from src.app.core.security import ALGORITHM, SECRET_KEY
from src.app.models.parking import ParkingLot, Pricing
from src.app.models.sessions import ParkingSession
from src.app.models.users import Attendant
from src.app.schemas.session import AttendantCheckOutPreviewCreate


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


def _make_lot(lot_id: int = 13, name: str = "Bai xe Quan 1") -> ParkingLot:
    lot = MagicMock(spec=ParkingLot)
    lot.id = lot_id
    lot.name = name
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
) -> ParkingSession:
    session = MagicMock(spec=ParkingSession)
    session.id = session_id
    session.parking_lot_id = parking_lot_id
    session.driver_id = driver_id
    session.license_plate = license_plate
    session.vehicle_type = vehicle_type
    session.status = status
    session.checkin_time = checkin_time or datetime.now(UTC) - timedelta(minutes=125)
    return session


def _make_pricing(*, pricing_mode: str = "HOURLY", price_amount: float = 15000) -> Pricing:
    pricing = MagicMock(spec=Pricing)
    pricing.pricing_mode = pricing_mode
    pricing.price_amount = price_amount
    pricing.vehicle_type = "CAR"
    return pricing


def _build_checkout_token(
    *,
    session_id: int = 88,
    driver_id: int = 9,
    parking_lot_id: int = 13,
    expires_in_minutes: int = 5,
) -> str:
    now = datetime.now(UTC)
    payload = {
        "purpose": "driver_check_out",
        "session_id": session_id,
        "driver_id": driver_id,
        "parking_lot_id": parking_lot_id,
        "license_plate": "30A-99999",
        "vehicle_type": "CAR",
        "jti": "story-4-5-token",
        "iat": now.replace(tzinfo=None),
        "exp": (now + timedelta(minutes=expires_in_minutes)).replace(tzinfo=None),
    }
    return jwt.encode(payload, SECRET_KEY.get_secret_value(), algorithm=ALGORITHM)


class TestAttendantCheckOutPreview:
    @pytest.mark.asyncio
    async def test_returns_checkout_preview_without_mutating_state(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        active_session = _make_session()
        active_session_result = MagicMock()
        active_session_result.scalars.return_value.all.return_value = [active_session]

        pricing_result = MagicMock()
        pricing_result.scalars.return_value.all.return_value = [_make_pricing()]

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, active_session_result, pricing_result]
        )
        mock_db.commit = AsyncMock()
        mock_db.add = Mock()

        result = await attendant_check_out_preview(
            Mock(),
            AttendantCheckOutPreviewCreate(token=_build_checkout_token()),
            _attendant_user(),
            mock_db,
        )

        assert result.session_id == 88
        assert result.parking_lot_id == 13
        assert result.parking_lot_name == "Bai xe Quan 1"
        assert result.license_plate == "30A-99999"
        assert result.elapsed_minutes >= 125
        assert result.final_fee == 45000
        assert result.pricing_mode == "HOURLY"
        mock_db.add.assert_not_called()
        mock_db.commit.assert_not_awaited()

    @pytest.mark.asyncio
    async def test_rejects_when_session_belongs_to_different_lot(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant(parking_lot_id=13)

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot(lot_id=13)

        active_session_result = MagicMock()
        active_session_result.scalars.return_value.all.return_value = [_make_session(parking_lot_id=18)]

        mock_db.execute = AsyncMock(side_effect=[attendant_result, lot_result, active_session_result])

        with pytest.raises(BadRequestException, match="different parking lot"):
            await attendant_check_out_preview(
                Mock(),
                AttendantCheckOutPreviewCreate(token=_build_checkout_token(parking_lot_id=18)),
                _attendant_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_rejects_when_active_pricing_is_missing(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        active_session_result = MagicMock()
        active_session_result.scalars.return_value.all.return_value = [_make_session()]

        pricing_result = MagicMock()
        pricing_result.scalars.return_value.all.return_value = []

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, active_session_result, pricing_result]
        )

        with pytest.raises(BadRequestException, match="No active pricing"):
            await attendant_check_out_preview(
                Mock(),
                AttendantCheckOutPreviewCreate(token=_build_checkout_token()),
                _attendant_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_rejects_when_session_already_checked_out(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        active_session_result = MagicMock()
        active_session_result.scalars.return_value.all.return_value = []

        session_lookup_result = MagicMock()
        session_lookup_result.scalar_one_or_none.return_value = _make_session(status="CHECKED_OUT")

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, active_session_result, session_lookup_result]
        )

        with pytest.raises(BadRequestException, match="already checked out"):
            await attendant_check_out_preview(
                Mock(),
                AttendantCheckOutPreviewCreate(token=_build_checkout_token()),
                _attendant_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_rejects_when_no_active_session_exists(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        active_session_result = MagicMock()
        active_session_result.scalars.return_value.all.return_value = []

        session_lookup_result = MagicMock()
        session_lookup_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(
            side_effect=[attendant_result, lot_result, active_session_result, session_lookup_result]
        )

        with pytest.raises(NotFoundException, match="No active parking session"):
            await attendant_check_out_preview(
                Mock(),
                AttendantCheckOutPreviewCreate(token=_build_checkout_token()),
                _attendant_user(),
                mock_db,
            )