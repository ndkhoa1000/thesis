"""Unit tests for Story 6.2 operator announcement management."""

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.lots import (
    create_operator_lot_announcement,
    patch_operator_lot_announcement,
    read_operator_lot_announcements,
)
from src.app.core.exceptions.http_exceptions import NotFoundException
from src.app.models.enums import AnnouncementType, LeaseStatus, UserRole
from src.app.models.leases import LotLease
from src.app.models.notifications import ParkingLotAnnouncement
from src.app.models.users import Manager
from src.app.schemas.parking_lot import (
    OperatorManagedAnnouncementCreate,
    OperatorManagedAnnouncementUpdate,
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


def _announcement(announcement_id: int = 51, parking_lot_id: int = 13) -> ParkingLotAnnouncement:
    announcement = MagicMock(spec=ParkingLotAnnouncement)
    announcement.id = announcement_id
    announcement.parking_lot_id = parking_lot_id
    announcement.posted_by = 8
    announcement.title = "Loi vao tam dong"
    announcement.content = "Su dung cong phu o duong ben hong."
    announcement.announcement_type = AnnouncementType.TRAFFIC_ALERT.value
    announcement.visible_from = datetime.now(UTC)
    announcement.visible_until = datetime.now(UTC) + timedelta(days=1)
    announcement.created_at = datetime.now(UTC)
    return announcement


class TestOperatorAnnouncements:
    @pytest.mark.asyncio
    async def test_read_operator_lot_announcements_returns_managed_lot_entries(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.scalar_one_or_none.return_value = _active_lease()
        announcements_result = MagicMock()
        announcements_result.scalars.return_value.all.return_value = [
            _announcement(),
            _announcement(announcement_id=52),
        ]
        mock_db.execute = AsyncMock(
            side_effect=[manager_result, lease_result, announcements_result]
        )

        result = await read_operator_lot_announcements(
            Mock(),
            13,
            _manager_user(),
            mock_db,
        )

        assert len(result) == 2
        assert result[0].title == "Loi vao tam dong"
        assert result[0].announcement_type == AnnouncementType.TRAFFIC_ALERT

    @pytest.mark.asyncio
    async def test_create_operator_lot_announcement_persists_for_managed_lot(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.scalar_one_or_none.return_value = _active_lease()
        mock_db.execute = AsyncMock(side_effect=[manager_result, lease_result])
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()

        async def _refresh(instance):
            instance.id = 77
            instance.created_at = datetime.now(UTC)

        mock_db.refresh = AsyncMock(side_effect=_refresh)

        payload = OperatorManagedAnnouncementCreate(
            title="Bao tri thang may xe",
            content="Tang ham B dong tu 20h den 23h.",
            announcement_type=AnnouncementType.EVENT,
            visible_from=datetime.now(UTC),
            visible_until=datetime.now(UTC) + timedelta(days=2),
        )

        result = await create_operator_lot_announcement(
            Mock(),
            13,
            payload,
            _manager_user(),
            mock_db,
        )

        persisted = mock_db.add.call_args.args[0]
        assert persisted.parking_lot_id == 13
        assert persisted.posted_by == 8
        assert persisted.title == payload.title
        assert persisted.announcement_type == AnnouncementType.EVENT.value
        mock_db.commit.assert_awaited_once()
        assert result.id == 77
        assert result.title == payload.title

    @pytest.mark.asyncio
    async def test_patch_operator_lot_announcement_updates_visibility_window(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.scalar_one_or_none.return_value = _active_lease()
        announcement_result = MagicMock()
        announcement = _announcement()
        announcement_result.scalar_one_or_none.return_value = announcement
        mock_db.execute = AsyncMock(
            side_effect=[manager_result, lease_result, announcement_result]
        )
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        updated_visible_until = datetime.now(UTC) + timedelta(days=5)
        result = await patch_operator_lot_announcement(
            Mock(),
            13,
            51,
            OperatorManagedAnnouncementUpdate(
                title="Cap nhat loi vao moi",
                content="Su dung cong so 2 trong khung gio cao diem.",
                announcement_type=AnnouncementType.GENERAL,
                visible_from=datetime.now(UTC),
                visible_until=updated_visible_until,
            ),
            _manager_user(),
            mock_db,
        )

        assert announcement.title == "Cap nhat loi vao moi"
        assert announcement.announcement_type == AnnouncementType.GENERAL.value
        assert announcement.visible_until == updated_visible_until
        mock_db.commit.assert_awaited_once()
        assert result.title == "Cap nhat loi vao moi"

    @pytest.mark.asyncio
    async def test_operator_announcement_routes_reject_unmanaged_lot(self, mock_db):
        manager_result = MagicMock()
        manager_result.scalar_one_or_none.return_value = _manager_profile()
        lease_result = MagicMock()
        lease_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(side_effect=[manager_result, lease_result])

        with pytest.raises(NotFoundException, match="Managed parking lot not found"):
            await read_operator_lot_announcements(
                Mock(),
                13,
                _manager_user(),
                mock_db,
            )