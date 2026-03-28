"""Regression tests for Story 5.4 lot-availability event publication."""

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, Mock, patch

import pytest
from jose import jwt

from src.app.api.v1.lots import patch_operator_parking_lot
from src.app.api.v1.sessions import (
    attendant_check_in_with_driver_qr,
    attendant_check_out_finalize,
)
from src.app.core.security import ALGORITHM, SECRET_KEY
from src.app.models.enums import PaymentMethod, PricingMode
from src.app.models.leases import LotLease
from src.app.models.parking import ParkingLot, Pricing
from src.app.models.sessions import ParkingSession
from src.app.models.users import Attendant, Manager
from src.app.schemas.parking_lot import OperatorManagedParkingLotUpdate
from src.app.schemas.session import AttendantCheckInCreate, AttendantCheckOutFinalizeCreate


def _attendant_user(user_id: int = 51) -> dict:
    return {
        "id": user_id,
        "username": "attendant_user",
        "email": "attendant@test.com",
        "role": "ATTENDANT",
    }


def _operator_user(user_id: int = 88) -> dict:
    return {
        "id": user_id,
        "username": "operator_user",
        "email": "operator@test.com",
        "role": "MANAGER",
        "is_superuser": False,
    }


def _make_attendant(attendant_id: int = 7, parking_lot_id: int = 13) -> Attendant:
    attendant = MagicMock(spec=Attendant)
    attendant.id = attendant_id
    attendant.user_id = 51
    attendant.parking_lot_id = parking_lot_id
    return attendant


def _make_manager(manager_id: int = 5, user_id: int = 88) -> Manager:
    manager = MagicMock(spec=Manager)
    manager.id = manager_id
    manager.user_id = user_id
    return manager


def _make_lot(
    lot_id: int = 13,
    current_available: int = 7,
    name: str = "Bai xe Quan 1",
) -> ParkingLot:
    lot = MagicMock(spec=ParkingLot)
    lot.id = lot_id
    lot.name = name
    lot.current_available = current_available
    lot.status = "APPROVED"
    lot.updated_at = None
    return lot


def _make_vehicle(vehicle_id: int = 22, driver_id: int = 9):
    vehicle = MagicMock()
    vehicle.id = vehicle_id
    vehicle.driver_id = driver_id
    vehicle.license_plate = "59A-12345"
    vehicle.vehicle_type = "MOTORBIKE"
    return vehicle


def _make_session(session_id: int = 88, parking_lot_id: int = 13) -> ParkingSession:
    session = MagicMock(spec=ParkingSession)
    session.id = session_id
    session.parking_lot_id = parking_lot_id
    session.driver_id = 9
    session.license_plate = "30A-99999"
    session.vehicle_type = "CAR"
    session.status = "CHECKED_IN"
    session.checkin_time = datetime.now(UTC)
    session.checkout_time = None
    session.attendant_checkout_id = None
    return session


def _build_driver_token(*, driver_id: int = 9, vehicle_id: int = 22) -> str:
    now = datetime.now(UTC)
    payload = {
        "purpose": "driver_check_in",
        "driver_id": driver_id,
        "vehicle_id": vehicle_id,
        "license_plate": "59A-12345",
        "vehicle_type": "MOTORBIKE",
        "jti": "story-5-4-driver-token",
        "iat": now.replace(tzinfo=None),
        "exp": (now + timedelta(minutes=5)).replace(tzinfo=None),
    }
    return jwt.encode(payload, SECRET_KEY.get_secret_value(), algorithm=ALGORITHM)


def _make_pricing(*, pricing_mode: str = "HOURLY", price_amount: float = 15000) -> Pricing:
    pricing = MagicMock(spec=Pricing)
    pricing.pricing_mode = pricing_mode
    pricing.price_amount = price_amount
    pricing.vehicle_type = "CAR"
    return pricing


def _make_lease(lease_id: int = 12, parking_lot_id: int = 13, manager_id: int = 5) -> LotLease:
    lease = MagicMock(spec=LotLease)
    lease.id = lease_id
    lease.parking_lot_id = parking_lot_id
    lease.manager_id = manager_id
    lease.status = "ACTIVE"
    lease.created_at = datetime.now(UTC)
    return lease


@pytest.mark.asyncio
async def test_attendant_check_in_publishes_availability_event(mock_db):
    attendant_result = MagicMock()
    attendant_result.scalar_one_or_none.return_value = _make_attendant()

    lot = _make_lot(current_available=5)
    lot_result = MagicMock()
    lot_result.scalar_one_or_none.return_value = lot

    vehicle_result = MagicMock()
    vehicle_result.scalar_one_or_none.return_value = _make_vehicle()

    active_session_result = MagicMock()
    active_session_result.scalar_one_or_none.return_value = None

    mock_db.execute = AsyncMock(
        side_effect=[attendant_result, lot_result, vehicle_result, active_session_result]
    )
    mock_db.add = Mock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock(side_effect=lambda instance: setattr(instance, "id", 101))

    with patch("src.app.api.v1.sessions.publish_lot_availability_update") as publish_mock:
        await attendant_check_in_with_driver_qr(
            Mock(),
            AttendantCheckInCreate(token=_build_driver_token()),
            _attendant_user(),
            mock_db,
        )

    publish_mock.assert_called_once_with(
        lot,
        previous_current_available=5,
        source="attendant_check_in",
    )


@pytest.mark.asyncio
async def test_attendant_check_out_finalize_publishes_availability_event(mock_db):
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
    mock_db.rollback = AsyncMock()

    with patch("src.app.api.v1.sessions.publish_lot_availability_update") as publish_mock:
        await attendant_check_out_finalize(
            Mock(),
            AttendantCheckOutFinalizeCreate(
                session_id=88,
                payment_method=PaymentMethod.CASH.value,
                quoted_final_fee=15000,
            ),
            _attendant_user(),
            mock_db,
        )

    publish_mock.assert_called_once_with(
        lot,
        previous_current_available=7,
        source="attendant_check_out_finalize",
    )


@pytest.mark.asyncio
async def test_operator_lot_patch_publishes_availability_event(mock_db):
    manager_result = MagicMock()
    manager_result.scalar_one_or_none.return_value = _make_manager()

    lease_result = MagicMock()
    lease_result.scalar_one_or_none.return_value = _make_lease()

    lot = _make_lot(current_available=2)
    parking_lot_result = MagicMock()
    parking_lot_result.scalar_one_or_none.return_value = lot

    latest_config_result = MagicMock()
    latest_config_result.scalar_one_or_none.return_value = None

    latest_pricing_result = MagicMock()
    latest_pricing_result.scalar_one_or_none.return_value = None

    occupied_result = MagicMock()
    occupied_result.scalar_one.return_value = 4

    mock_db.execute = AsyncMock(
        side_effect=[
            manager_result,
            lease_result,
            parking_lot_result,
            latest_config_result,
            latest_pricing_result,
            occupied_result,
        ]
    )
    mock_db.add = Mock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

    payload = OperatorManagedParkingLotUpdate(
        name="Bai xe Quan 1",
        address="1 Nguyen Hue, Quan 1",
        total_capacity=10,
        opening_time="07:00",
        closing_time="22:00",
        pricing_mode=PricingMode.HOURLY,
        price_amount=5000,
        description="Gan trung tam",
        cover_image=None,
    )

    with patch("src.app.api.v1.lots.publish_lot_availability_update") as publish_mock:
        await patch_operator_parking_lot(
            Mock(),
            13,
            payload,
            _operator_user(),
            mock_db,
        )

    publish_mock.assert_called_once_with(
        lot,
        previous_current_available=2,
        source="operator_parking_lot_update",
    )