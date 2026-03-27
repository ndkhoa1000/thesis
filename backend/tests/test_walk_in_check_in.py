"""Unit tests for attendant walk-in check-in flow (Story 4.3)."""

from io import BytesIO
from unittest.mock import AsyncMock, MagicMock, Mock, patch

import pytest
from fastapi import UploadFile
from starlette.datastructures import Headers

from src.app.api.v1.sessions import attendant_check_in_walk_in_vehicle
from src.app.core.exceptions.http_exceptions import BadRequestException, ForbiddenException
from src.app.models.parking import ParkingLot
from src.app.models.sessions import ParkingSession
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


def _make_lot(lot_id: int = 13, current_available: int = 12) -> ParkingLot:
    lot = MagicMock(spec=ParkingLot)
    lot.id = lot_id
    lot.current_available = current_available
    lot.name = 'Bai xe Quan 1'
    return lot


def _make_upload(
    *,
    filename: str = 'plate.jpg',
    content_type: str = 'image/jpeg',
) -> UploadFile:
    return UploadFile(
        file=BytesIO(b'fake-image-bytes'),
        filename=filename,
        headers=Headers({'content-type': content_type}),
    )


class TestAttendantWalkInCheckIn:
    @pytest.mark.asyncio
    async def test_creates_walk_in_session_and_updates_availability(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot = _make_lot(current_available=5)
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = lot

        mock_db.execute = AsyncMock(side_effect=[attendant_result, lot_result])
        created_sessions = []
        mock_db.add = Mock(side_effect=lambda instance: created_sessions.append(instance))
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock(side_effect=lambda instance: setattr(instance, 'id', 201))

        with patch(
            'src.app.api.v1.sessions._store_walk_in_image',
            return_value='walk-in://plate.jpg',
        ):
            result = await attendant_check_in_walk_in_vehicle(
                Mock(),
                vehicle_type='CAR',
                overview_image=_make_upload(filename='overview.jpg'),
                plate_image=_make_upload(filename='plate.jpg'),
                current_user=_attendant_user(),
                db=mock_db,
            )

        assert result.parking_lot_id == 13
        assert result.current_available == 4
        assert result.vehicle_type == 'CAR'
        assert result.license_plate.startswith('WALK-IN-')
        assert len(created_sessions) == 1
        assert created_sessions[0].driver_id is None
        assert created_sessions[0].checkin_image == 'walk-in://plate.jpg'
        assert lot.current_available == 4
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_rejects_missing_plate_photo(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        mock_db.execute = AsyncMock(side_effect=[attendant_result, lot_result])

        with pytest.raises(BadRequestException, match='plate photo'):
            await attendant_check_in_walk_in_vehicle(
                Mock(),
                vehicle_type='MOTORBIKE',
                overview_image=None,
                plate_image=None,
                current_user=_attendant_user(),
                db=mock_db,
            )

    @pytest.mark.asyncio
    async def test_rejects_non_image_upload(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot()

        mock_db.execute = AsyncMock(side_effect=[attendant_result, lot_result])

        with pytest.raises(BadRequestException, match='image'):
            await attendant_check_in_walk_in_vehicle(
                Mock(),
                vehicle_type='MOTORBIKE',
                overview_image=None,
                plate_image=_make_upload(content_type='text/plain'),
                current_user=_attendant_user(),
                db=mock_db,
            )

    @pytest.mark.asyncio
    async def test_rejects_when_lot_is_full(self, mock_db):
        attendant_result = MagicMock()
        attendant_result.scalar_one_or_none.return_value = _make_attendant()

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _make_lot(current_available=0)

        mock_db.execute = AsyncMock(side_effect=[attendant_result, lot_result])

        with pytest.raises(BadRequestException, match='Lot is full'):
            await attendant_check_in_walk_in_vehicle(
                Mock(),
                vehicle_type='MOTORBIKE',
                overview_image=None,
                plate_image=_make_upload(),
                current_user=_attendant_user(),
                db=mock_db,
            )

    @pytest.mark.asyncio
    async def test_rejects_non_attendant_account(self, mock_db):
        with pytest.raises(ForbiddenException, match='Only attendant accounts'):
            await attendant_check_in_walk_in_vehicle(
                Mock(),
                vehicle_type='MOTORBIKE',
                overview_image=None,
                plate_image=_make_upload(),
                current_user={'id': 1, 'role': 'DRIVER'},
                db=mock_db,
            )