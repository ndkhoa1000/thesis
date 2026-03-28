"""Unit tests for driver booking lifecycle endpoints (Story 7.1)."""

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, Mock, patch

import pytest
from jose import jwt

from src.app.api.v1.bookings import cancel_driver_booking, create_driver_booking, get_driver_active_booking
from src.app.core.exceptions.http_exceptions import BadRequestException, NotFoundException
from src.app.core.security import ALGORITHM, SECRET_KEY
from src.app.models.financials import Payment
from src.app.models.parking import ParkingLot, Pricing
from src.app.models.sessions import Booking
from src.app.models.users import Driver
from src.app.models.vehicles import Vehicle
from src.app.schemas.booking import DriverBookingCreate


def _driver_user(user_id: int = 11) -> dict:
    return {
        "id": user_id,
        "username": "driver_user",
        "email": "driver@test.com",
        "role": "DRIVER",
    }


def _make_driver(driver_id: int = 3, user_id: int = 11) -> Driver:
    driver = MagicMock(spec=Driver)
    driver.id = driver_id
    driver.user_id = user_id
    return driver


def _make_lot(lot_id: int = 14, current_available: int = 5, name: str = "Bai xe Le Loi") -> ParkingLot:
    lot = MagicMock(spec=ParkingLot)
    lot.id = lot_id
    lot.name = name
    lot.current_available = current_available
    lot.status = "APPROVED"
    return lot


def _make_vehicle(vehicle_id: int = 7, driver_id: int = 3) -> Vehicle:
    vehicle = MagicMock(spec=Vehicle)
    vehicle.id = vehicle_id
    vehicle.driver_id = driver_id
    vehicle.license_plate = "59A-12345"
    vehicle.vehicle_type = "MOTORBIKE"
    return vehicle


def _make_pricing(price_amount: float = 8000) -> Pricing:
    pricing = MagicMock(spec=Pricing)
    pricing.id = 21
    pricing.price_amount = price_amount
    pricing.pricing_mode = "SESSION"
    pricing.vehicle_type = "MOTORBIKE"
    return pricing


def _make_booking(
    booking_id: int = 31,
    driver_id: int = 3,
    parking_lot_id: int = 14,
    vehicle_id: int = 7,
    *,
    status: str = "CONFIRMED",
    expires_in_minutes: int = 30,
) -> Booking:
    booking = MagicMock(spec=Booking)
    booking.id = booking_id
    booking.driver_id = driver_id
    booking.parking_lot_id = parking_lot_id
    booking.vehicle_id = vehicle_id
    booking.status = status
    booking.booking_time = datetime.now(UTC)
    booking.expected_arrival = booking.booking_time + timedelta(minutes=30)
    booking.expiration_time = datetime.now(UTC) + timedelta(minutes=expires_in_minutes)
    return booking


def _make_payment(payment_id: int = 77, amount: float = 8000) -> Payment:
    payment = MagicMock(spec=Payment)
    payment.id = payment_id
    payment.amount = amount
    payment.final_amount = amount
    payment.payment_method = "ONLINE"
    payment.payment_status = "COMPLETED"
    return payment


class TestDriverBookings:
    @pytest.mark.asyncio
    async def test_create_booking_holds_capacity_records_payment_and_returns_signed_token(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver()

        lot = _make_lot(current_available=4)
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = lot

        vehicle = _make_vehicle()
        vehicle_result = MagicMock()
        vehicle_result.scalar_one_or_none.return_value = vehicle

        existing_booking_result = MagicMock()
        existing_booking_result.scalar_one_or_none.return_value = None

        pricing_result = MagicMock()
        pricing_result.scalars.return_value.all.return_value = [_make_pricing()]

        mock_db.execute = AsyncMock(
            side_effect=[
                driver_result,
                lot_result,
                vehicle_result,
                existing_booking_result,
                pricing_result,
            ]
        )
        mock_db.commit = AsyncMock()
        mock_db.rollback = AsyncMock()
        mock_db.flush = AsyncMock()

        def _refresh(instance):
            if getattr(instance, "id", None) is None:
                if isinstance(instance, MagicMock) and instance._spec_class is Booking:
                    instance.id = 301
                else:
                    instance.id = 901

        mock_db.refresh = AsyncMock(side_effect=_refresh)

        with patch("src.app.api.v1.bookings.publish_lot_availability_update") as publish_mock:
            response = await create_driver_booking(
                Mock(),
                DriverBookingCreate(parking_lot_id=14, vehicle_id=7),
                _driver_user(),
                mock_db,
            )

        assert response.parking_lot_id == 14
        assert response.vehicle.id == 7
        assert response.payment.payment_status == "COMPLETED"
        assert response.current_available == 3
        assert lot.current_available == 3
        payload = jwt.decode(
            response.token,
            SECRET_KEY.get_secret_value(),
            algorithms=[ALGORITHM],
        )
        assert payload["purpose"] == "booking_check_in"
        assert payload["parking_lot_id"] == 14
        assert payload["vehicle_id"] == 7
        publish_mock.assert_called_once_with(
            lot,
            previous_current_available=4,
            source="driver_booking_create",
        )

    @pytest.mark.asyncio
    async def test_rejects_duplicate_active_booking_at_same_lot(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot(current_available=2)

        vehicle_result = MagicMock()
        vehicle_result.scalar_one_or_none.return_value = _make_vehicle()

        existing_booking_result = MagicMock()
        existing_booking_result.scalar_one_or_none.return_value = _make_booking()

        mock_db.execute = AsyncMock(
            side_effect=[
                driver_result,
                lot_result,
                vehicle_result,
                existing_booking_result,
            ]
        )

        with pytest.raises(BadRequestException, match="active booking"):
            await create_driver_booking(
                Mock(),
                DriverBookingCreate(parking_lot_id=14, vehicle_id=7),
                _driver_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_rejects_booking_when_lot_is_full(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot(current_available=0)

        vehicle_result = MagicMock()
        vehicle_result.scalar_one_or_none.return_value = _make_vehicle()

        existing_booking_result = MagicMock()
        existing_booking_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(
            side_effect=[
                driver_result,
                lot_result,
                vehicle_result,
                existing_booking_result,
            ]
        )

        with pytest.raises(BadRequestException, match="Lot is full"):
            await create_driver_booking(
                Mock(),
                DriverBookingCreate(parking_lot_id=14, vehicle_id=7),
                _driver_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_reads_active_booking_for_current_lot(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver()

        lot = _make_lot(current_available=3)
        vehicle = _make_vehicle()
        booking = _make_booking()

        booking_result = MagicMock()
        booking_result.first.return_value = (booking, lot, vehicle)

        payment_result = MagicMock()
        payment_result.scalar_one_or_none.return_value = _make_payment()

        mock_db.execute = AsyncMock(side_effect=[driver_result, booking_result, payment_result])

        response = await get_driver_active_booking(Mock(), _driver_user(), mock_db, 14)

        assert response.booking_id == 31
        assert response.parking_lot_name == "Bai xe Le Loi"
        assert response.vehicle.license_plate == "59A-12345"

    @pytest.mark.asyncio
    async def test_reads_expired_booking_state_and_releases_capacity_when_latest_booking_times_out(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver()

        lot = _make_lot(current_available=1)
        vehicle = _make_vehicle()
        booking = _make_booking(expires_in_minutes=-1)

        booking_result = MagicMock()
        booking_result.first.return_value = (booking, lot, vehicle)

        latest_config_result = MagicMock()
        latest_config_result.scalar_one_or_none.return_value = None

        payment_result = MagicMock()
        payment_result.scalar_one_or_none.return_value = _make_payment()

        mock_db.execute = AsyncMock(
            side_effect=[driver_result, booking_result, latest_config_result, payment_result]
        )
        mock_db.commit = AsyncMock()
        mock_db.rollback = AsyncMock()

        with patch("src.app.api.v1.bookings.publish_lot_availability_update") as publish_mock:
            response = await get_driver_active_booking(Mock(), _driver_user(), mock_db, 14)

        assert response.status == "EXPIRED"
        assert response.expires_in_seconds == 0
        assert response.token == ""
        assert response.current_available == 2
        assert booking.status == "EXPIRED"
        assert lot.current_available == 2
        publish_mock.assert_called_once_with(
            lot,
            previous_current_available=1,
            source="driver_booking_expired_on_read",
        )

    @pytest.mark.asyncio
    async def test_does_not_surface_older_expired_booking_when_latest_booking_is_cancelled(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver()

        latest_booking = _make_booking(booking_id=99, status="CANCELLED")
        lot = _make_lot(current_available=4)
        vehicle = _make_vehicle()

        booking_result = MagicMock()
        booking_result.first.return_value = (latest_booking, lot, vehicle)

        mock_db.execute = AsyncMock(side_effect=[driver_result, booking_result])

        with pytest.raises(NotFoundException, match="No active booking found"):
            await get_driver_active_booking(Mock(), _driver_user(), mock_db, 14)

    @pytest.mark.asyncio
    async def test_cancel_booking_restores_capacity_exactly_once(self, mock_db):
        driver_result = MagicMock()
        driver_result.scalar_one_or_none.return_value = _make_driver()

        booking = _make_booking(expires_in_minutes=15)
        booking_result = MagicMock()
        booking_result.scalar_one_or_none.return_value = booking

        lot = _make_lot(current_available=2)
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = lot

        latest_config_result = MagicMock()
        latest_config_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(
            side_effect=[
                driver_result,
                booking_result,
                lot_result,
                latest_config_result,
            ]
        )
        mock_db.commit = AsyncMock()
        mock_db.rollback = AsyncMock()

        with patch("src.app.api.v1.bookings.publish_lot_availability_update") as publish_mock:
            response = await cancel_driver_booking(Mock(), 31, _driver_user(), mock_db)

        assert response.booking_id == 31
        assert response.status == "CANCELLED"
        assert response.current_available == 3
        assert lot.current_available == 3
        publish_mock.assert_called_once_with(
            lot,
            previous_current_available=2,
            source="driver_booking_cancel",
        )
