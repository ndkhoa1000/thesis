from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from src.app.services.booking_service import expire_stale_bookings


def _make_lot(lot_id: int = 13, current_available: int = 1):
    lot = MagicMock()
    lot.id = lot_id
    lot.current_available = current_available
    lot.name = f"Lot {lot_id}"
    return lot


def _make_booking(booking_id: int, lot_id: int = 13, status: str = "CONFIRMED"):
    booking = MagicMock()
    booking.id = booking_id
    booking.parking_lot_id = lot_id
    booking.status = status
    booking.expiration_time = datetime.now(UTC) - timedelta(minutes=1)
    return booking


class TestBookingExpirationJob:
    @pytest.mark.asyncio
    async def test_expires_batch_and_publishes_once_per_lot_after_commit(self, mock_db):
        lot = _make_lot(current_available=1)
        first_booking = _make_booking(41)
        second_booking = _make_booking(42)

        batch_result = MagicMock()
        batch_result.all.return_value = [
            (first_booking, lot),
            (second_booking, lot),
        ]

        config_result_one = MagicMock()
        config_result_one.scalar_one_or_none.return_value = None
        config_result_two = MagicMock()
        config_result_two.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(
            side_effect=[batch_result, config_result_one, config_result_two]
        )
        events: list[str] = []
        mock_db.commit = AsyncMock(side_effect=lambda: events.append("commit"))
        mock_db.rollback = AsyncMock()

        with patch(
            "src.app.services.booking_service.publish_lot_availability_update",
            side_effect=lambda *_args, **_kwargs: events.append("publish"),
        ) as publish_mock:
            expired_count = await expire_stale_bookings(mock_db)

        assert expired_count == 2
        assert first_booking.status == "EXPIRED"
        assert second_booking.status == "EXPIRED"
        assert lot.current_available == 3
        assert events == ["commit", "publish"]
        publish_mock.assert_called_once_with(
            lot,
            previous_current_available=1,
            source="booking_expiration_job",
        )

    @pytest.mark.asyncio
    async def test_skips_defensively_non_confirmed_rows_without_releasing_capacity(self, mock_db):
        lot = _make_lot(current_available=2)
        consumed_booking = _make_booking(55, status="CONSUMED")

        batch_result = MagicMock()
        batch_result.all.return_value = [(consumed_booking, lot)]

        mock_db.execute = AsyncMock(return_value=batch_result)
        mock_db.commit = AsyncMock()
        mock_db.rollback = AsyncMock()

        with patch("src.app.services.booking_service.publish_lot_availability_update") as publish_mock:
            expired_count = await expire_stale_bookings(mock_db)

        assert expired_count == 0
        assert consumed_booking.status == "CONSUMED"
        assert lot.current_available == 2
        mock_db.commit.assert_not_awaited()
        publish_mock.assert_not_called()