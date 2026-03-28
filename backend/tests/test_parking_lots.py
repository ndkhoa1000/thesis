"""Unit tests for parking lot registration and admin review flows."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.lots import (
    bootstrap_parking_lot_lease,
    create_my_parking_lot,
    list_available_operators,
    list_lots,
    read_public_lot_detail,
    read_my_parking_lots,
    read_parking_lot_applications,
    review_parking_lot,
)
from src.app.core.exceptions.http_exceptions import BadRequestException, ForbiddenException, NotFoundException
from src.app.models.enums import LeaseStatus, ParkingLotStatus, PricingMode
from src.app.models.leases import LotLease
from src.app.models.notifications import ParkingLotAnnouncement
from src.app.models.parking import ParkingLot, ParkingLotConfig, ParkingLotFeature, ParkingLotTag, Pricing
from src.app.models.user import User
from src.app.models.users import LotOwner, Manager
from src.app.schemas.parking_lot import ParkingLotLeaseBootstrapCreate
from src.app.schemas.parking_lot import ParkingLotAdminRead, ParkingLotCreate, ParkingLotRead, ParkingLotReview


def _public_user(user_id: int = 1, role: str = "LOT_OWNER") -> dict:
    return {
        "id": user_id,
        "username": "lot_owner",
        "email": "owner@test.com",
        "role": role,
        "is_superuser": False,
    }


def _admin_user(user_id: int = 99) -> dict:
    return {
        "id": user_id,
        "username": "admin",
        "email": "admin@test.com",
        "role": "ADMIN",
        "is_superuser": True,
    }


def _lot_owner_profile(profile_id: int = 3, user_id: int = 1) -> LotOwner:
    profile = MagicMock(spec=LotOwner)
    profile.id = profile_id
    profile.user_id = user_id
    profile.business_license = "BL-001"
    profile.verified_at = datetime.now(UTC)
    return profile


def _manager_profile(profile_id: int = 4, user_id: int = 9) -> Manager:
    profile = MagicMock(spec=Manager)
    profile.id = profile_id
    profile.user_id = user_id
    profile.business_license = "OP-001"
    profile.verified_at = datetime.now(UTC)
    return profile


def _manager_user(user_id: int = 9, name: str = "Tran Thi B") -> User:
    user = MagicMock(spec=User)
    user.id = user_id
    user.name = name
    user.email = "operator@test.com"
    user.phone = "0909555666"
    user.is_active = True
    user.is_deleted = False
    return user


def _parking_lot(
    lot_id: int = 7,
    lot_owner_id: int = 3,
    status: str = ParkingLotStatus.PENDING.value,
) -> ParkingLot:
    parking_lot = MagicMock(spec=ParkingLot)
    parking_lot.id = lot_id
    parking_lot.lot_owner_id = lot_owner_id
    parking_lot.name = "Bai xe Nguyen Hue"
    parking_lot.address = "1 Nguyen Hue, Quan 1"
    parking_lot.latitude = 10.7732
    parking_lot.longitude = 106.7041
    parking_lot.current_available = 0
    parking_lot.status = status
    parking_lot.description = "Gan trung tam"
    parking_lot.cover_image = None
    parking_lot.created_at = datetime.now(UTC)
    parking_lot.updated_at = None
    return parking_lot


def _lease(lease_id: int = 21, parking_lot_id: int = 7, manager_id: int = 4) -> LotLease:
    lease = MagicMock(spec=LotLease)
    lease.id = lease_id
    lease.parking_lot_id = parking_lot_id
    lease.manager_id = manager_id
    lease.monthly_fee = 0
    lease.status = LeaseStatus.ACTIVE.value
    lease.start_date = datetime.now(UTC).date()
    lease.end_date = None
    lease.created_at = datetime.now(UTC)
    return lease


def _parking_lot_config(parking_lot_id: int = 7) -> ParkingLotConfig:
    parking_lot_config = MagicMock(spec=ParkingLotConfig)
    parking_lot_config.id = 11
    parking_lot_config.parking_lot_id = parking_lot_id
    parking_lot_config.total_capacity = 24
    parking_lot_config.opening_time = "07:00:00"
    parking_lot_config.closing_time = "22:00:00"
    parking_lot_config.effective_from = None
    parking_lot_config.effective_to = None
    parking_lot_config.created_at = datetime.now(UTC)
    return parking_lot_config


def _pricing(parking_lot_id: int = 7) -> Pricing:
    pricing = MagicMock(spec=Pricing)
    pricing.id = 17
    pricing.parking_lot_id = parking_lot_id
    pricing.pricing_mode = PricingMode.HOURLY.value
    pricing.price_amount = 5000
    pricing.effective_from = None
    pricing.effective_to = None
    return pricing


def _parking_lot_feature(
    parking_lot_id: int = 7,
    feature_type: str = "CAMERA",
) -> ParkingLotFeature:
    feature = MagicMock(spec=ParkingLotFeature)
    feature.parking_lot_id = parking_lot_id
    feature.feature_type = feature_type
    feature.enabled = True
    return feature


def _parking_lot_tag(parking_lot_id: int = 7, tag_name: str = "co-mai-che") -> ParkingLotTag:
    tag = MagicMock(spec=ParkingLotTag)
    tag.parking_lot_id = parking_lot_id
    tag.tag_name = tag_name
    return tag


def _announcement(
    announcement_id: int = 31,
    parking_lot_id: int = 7,
    title: str = "Thong bao gio cao diem",
) -> ParkingLotAnnouncement:
    announcement = MagicMock(spec=ParkingLotAnnouncement)
    announcement.id = announcement_id
    announcement.parking_lot_id = parking_lot_id
    announcement.posted_by = 4
    announcement.title = title
    announcement.content = "Nen vao bai som hon 15 phut."
    announcement.announcement_type = "TRAFFIC_ALERT"
    announcement.visible_from = datetime.now(UTC)
    announcement.visible_until = None
    announcement.created_at = datetime.now(UTC)
    return announcement


class TestPublicParkingLots:
    def test_read_schema_supports_orm_objects(self):
        parking_lot = _parking_lot(status=ParkingLotStatus.APPROVED.value)

        result = ParkingLotRead.model_validate(parking_lot)

        assert result.id == parking_lot.id
        assert result.status == parking_lot.status

    @pytest.mark.asyncio
    async def test_list_public_lots_returns_only_approved_records(self, mock_db):
        approved_lot = _parking_lot(status=ParkingLotStatus.APPROVED.value)
        lots_result = MagicMock()
        lots_result.scalars.return_value.all.return_value = [approved_lot]
        mock_db.execute = AsyncMock(return_value=lots_result)

        result = await list_lots(Mock(), mock_db)

        assert result == [approved_lot]

    @pytest.mark.asyncio
    async def test_list_public_lots_exposes_marker_summary_fields(self, mock_db):
        approved_lot = _parking_lot(status=ParkingLotStatus.APPROVED.value)
        approved_lot.current_available = 12
        lots_result = MagicMock()
        lots_result.scalars.return_value.all.return_value = [approved_lot]
        mock_db.execute = AsyncMock(return_value=lots_result)

        result = await list_lots(Mock(), mock_db)
        marker_summary = ParkingLotRead.model_validate(result[0])

        assert marker_summary.id == approved_lot.id
        assert marker_summary.name == approved_lot.name
        assert marker_summary.latitude == approved_lot.latitude
        assert marker_summary.longitude == approved_lot.longitude
        assert marker_summary.current_available == 12
        assert marker_summary.status == ParkingLotStatus.APPROVED.value

    @pytest.mark.asyncio
    async def test_read_public_lot_detail_returns_driver_safe_snapshot(self, mock_db):
        approved_lot = _parking_lot(status=ParkingLotStatus.APPROVED.value)
        approved_lot.current_available = 9

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = approved_lot
        config_result = MagicMock()
        config_result.scalar_one_or_none.return_value = _parking_lot_config()
        pricing_result = MagicMock()
        pricing_result.scalar_one_or_none.return_value = _pricing()
        tags_result = MagicMock()
        tags_result.scalars.return_value.all.return_value = [
            _parking_lot_tag(tag_name="trung-tam"),
            _parking_lot_tag(tag_name="co-mai-che"),
        ]
        features_result = MagicMock()
        features_result.scalars.return_value.all.return_value = [
            _parking_lot_feature(feature_type="CAMERA"),
        ]
        announcements_result = MagicMock()
        announcements_result.scalars.return_value.all.return_value = []
        peak_hours_result = MagicMock()
        peak_hours_result.all.return_value = [(8, 3), (18, 5)]
        mock_db.execute = AsyncMock(
            side_effect=[
                lot_result,
                config_result,
                pricing_result,
                tags_result,
                features_result,
                announcements_result,
                peak_hours_result,
            ]
        )

        result = await read_public_lot_detail(Mock(), approved_lot.id, mock_db)

        assert result.id == approved_lot.id
        assert result.current_available == 9
        assert result.total_capacity == 24
        assert result.pricing_mode == PricingMode.HOURLY
        assert result.price_amount == 5000
        assert result.tag_labels == ["trung-tam", "co-mai-che"]
        assert result.feature_labels == ["CAMERA"]
        assert result.announcements == []
        assert result.peak_hours.status == "READY"
        assert result.peak_hours.total_sessions == 8
        assert result.peak_hours.points[0].hour == 8
        assert result.peak_hours.points[1].session_count == 5

    @pytest.mark.asyncio
    async def test_read_public_lot_detail_returns_honest_empty_trend(self, mock_db):
        approved_lot = _parking_lot(status=ParkingLotStatus.APPROVED.value)

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = approved_lot
        config_result = MagicMock()
        config_result.scalar_one_or_none.return_value = None
        pricing_result = MagicMock()
        pricing_result.scalar_one_or_none.return_value = None
        tags_result = MagicMock()
        tags_result.scalars.return_value.all.return_value = []
        features_result = MagicMock()
        features_result.scalars.return_value.all.return_value = []
        announcements_result = MagicMock()
        announcements_result.scalars.return_value.all.return_value = []
        peak_hours_result = MagicMock()
        peak_hours_result.all.return_value = [(9, 1)]
        mock_db.execute = AsyncMock(
            side_effect=[
                lot_result,
                config_result,
                pricing_result,
                tags_result,
                features_result,
                announcements_result,
                peak_hours_result,
            ]
        )

        result = await read_public_lot_detail(Mock(), approved_lot.id, mock_db)

        assert result.peak_hours.status == "INSUFFICIENT_DATA"
        assert result.peak_hours.total_sessions == 1
        assert result.peak_hours.points == []

    @pytest.mark.asyncio
    async def test_read_public_lot_detail_uses_current_effective_config_and_pricing(self, mock_db):
        approved_lot = _parking_lot(status=ParkingLotStatus.APPROVED.value)

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = approved_lot
        config_result = MagicMock()
        current_config = _parking_lot_config()
        current_config.total_capacity = 20
        config_result.scalar_one_or_none.return_value = current_config
        pricing_result = MagicMock()
        current_pricing = _pricing()
        current_pricing.price_amount = 12000
        pricing_result.scalar_one_or_none.return_value = current_pricing
        tags_result = MagicMock()
        tags_result.scalars.return_value.all.return_value = []
        features_result = MagicMock()
        features_result.scalars.return_value.all.return_value = []
        announcements_result = MagicMock()
        announcements_result.scalars.return_value.all.return_value = []
        peak_hours_result = MagicMock()
        peak_hours_result.all.return_value = [(8, 3)]
        mock_db.execute = AsyncMock(
            side_effect=[
                lot_result,
                config_result,
                pricing_result,
                tags_result,
                features_result,
                announcements_result,
                peak_hours_result,
            ]
        )

        result = await read_public_lot_detail(Mock(), approved_lot.id, mock_db)

        config_query = mock_db.execute.await_args_list[1].args[0]
        pricing_query = mock_db.execute.await_args_list[2].args[0]

        assert str(config_query.compile(compile_kwargs={"literal_binds": True}))
        assert "effective_from" in str(config_query)
        assert "effective_to" in str(config_query)
        assert "effective_from" in str(pricing_query)
        assert "effective_to" in str(pricing_query)
        assert result.total_capacity == 20
        assert result.price_amount == 12000

    @pytest.mark.asyncio
    async def test_read_public_lot_detail_returns_only_active_announcements(self, mock_db):
        approved_lot = _parking_lot(status=ParkingLotStatus.APPROVED.value)

        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = approved_lot
        config_result = MagicMock()
        config_result.scalar_one_or_none.return_value = _parking_lot_config()
        pricing_result = MagicMock()
        pricing_result.scalar_one_or_none.return_value = _pricing()
        tags_result = MagicMock()
        tags_result.scalars.return_value.all.return_value = []
        features_result = MagicMock()
        features_result.scalars.return_value.all.return_value = []
        announcements_result = MagicMock()
        announcements_result.scalars.return_value.all.return_value = [
            _announcement(title="Thong bao dang hien thi"),
        ]
        peak_hours_result = MagicMock()
        peak_hours_result.all.return_value = [(8, 3)]
        mock_db.execute = AsyncMock(
            side_effect=[
                lot_result,
                config_result,
                pricing_result,
                tags_result,
                features_result,
                announcements_result,
                peak_hours_result,
            ]
        )

        result = await read_public_lot_detail(Mock(), approved_lot.id, mock_db)

        assert len(result.announcements) == 1
        assert result.announcements[0].title == "Thong bao dang hien thi"

        announcements_query = mock_db.execute.await_args_list[5].args[0]
        query_text = str(announcements_query)
        assert "visible_from" in query_text
        assert "visible_until" in query_text

    @pytest.mark.asyncio
    async def test_read_public_lot_detail_rejects_missing_or_inaccessible_lot(self, mock_db):
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=lot_result)

        with pytest.raises(NotFoundException, match="Parking lot not found"):
            await read_public_lot_detail(Mock(), 999, mock_db)

        hidden_lot_result = MagicMock()
        hidden_lot_result.scalar_one_or_none.return_value = _parking_lot(
            status=ParkingLotStatus.PENDING.value,
        )
        mock_db.execute = AsyncMock(return_value=hidden_lot_result)

        with pytest.raises(NotFoundException, match="Parking lot not found"):
            await read_public_lot_detail(Mock(), 7, mock_db)


class TestLotOwnerParkingLots:
    @pytest.mark.asyncio
    async def test_read_my_parking_lots_returns_owned_lots(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        lots_result = MagicMock()
        lots_result.scalars.return_value.all.return_value = [_parking_lot()]
        active_lease_result = MagicMock()
        active_lease_result.one_or_none.return_value = None
        mock_db.execute = AsyncMock(side_effect=[owner_result, lots_result, active_lease_result])

        result = await read_my_parking_lots(Mock(), _public_user(), mock_db)

        assert len(result) == 1
        assert result[0].name == "Bai xe Nguyen Hue"

    @pytest.mark.asyncio
    async def test_create_my_parking_lot_success(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        mock_db.execute = AsyncMock(return_value=owner_result)
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock(side_effect=lambda parking_lot: setattr(parking_lot, "id", 17))

        payload = ParkingLotCreate(
            name="Bai xe Ben Thanh",
            address="45 Le Loi, Quan 1",
            latitude=10.7729,
            longitude=106.6983,
            description="Co camera va che mua",
            cover_image=None,
        )

        result = await create_my_parking_lot(Mock(), payload, _public_user(), mock_db)

        assert result.lot_owner_id == 3
        assert result.status == ParkingLotStatus.PENDING.value
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_create_requires_lot_owner_capability(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=owner_result)

        payload = ParkingLotCreate(
            name="Bai xe Ben Thanh",
            address="45 Le Loi, Quan 1",
            latitude=10.7729,
            longitude=106.6983,
        )

        with pytest.raises(ForbiddenException, match="Lot owner capability"):
            await create_my_parking_lot(Mock(), payload, _public_user(), mock_db)

    @pytest.mark.asyncio
    async def test_list_available_operators_returns_verified_profiles(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        operators_result = MagicMock()
        operators_result.all.return_value = [(_manager_profile(), _manager_user())]
        mock_db.execute = AsyncMock(side_effect=[owner_result, operators_result])

        result = await list_available_operators(Mock(), _public_user(), mock_db)

        assert len(result) == 1
        assert result[0].user_id == 9
        assert result[0].name == "Tran Thi B"

    @pytest.mark.asyncio
    async def test_bootstrap_parking_lot_lease_success(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _parking_lot(
            status=ParkingLotStatus.APPROVED.value,
        )
        existing_lease_result = MagicMock()
        existing_lease_result.one_or_none.return_value = None
        manager_result = MagicMock()
        manager_result.one_or_none.return_value = (_manager_profile(), _manager_user())
        mock_db.execute = AsyncMock(
            side_effect=[
                owner_result,
                lot_result,
                existing_lease_result,
                manager_result,
            ]
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock(side_effect=lambda lease: setattr(lease, "id", 21))

        payload = ParkingLotLeaseBootstrapCreate(manager_user_id=9, monthly_fee=0)

        result = await bootstrap_parking_lot_lease(Mock(), 7, payload, _public_user(), mock_db)

        assert result.status == LeaseStatus.ACTIVE.value
        assert result.operator_name == "Tran Thi B"
        mock_db.add.assert_called_once()
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_bootstrap_parking_lot_lease_requires_approved_lot(self, mock_db):
        owner_result = MagicMock()
        owner_result.scalar_one_or_none.return_value = _lot_owner_profile()
        lot_result = MagicMock()
        lot_result.scalar_one_or_none.return_value = _parking_lot(
            status=ParkingLotStatus.PENDING.value,
        )
        mock_db.execute = AsyncMock(side_effect=[owner_result, lot_result])

        payload = ParkingLotLeaseBootstrapCreate(manager_user_id=9, monthly_fee=0)

        with pytest.raises(BadRequestException, match="Only approved parking lots"):
            await bootstrap_parking_lot_lease(Mock(), 7, payload, _public_user(), mock_db)


class TestAdminParkingLotApprovals:
    def test_admin_read_schema_supports_marshaled_records(self):
        parking_lot = _parking_lot()

        result = ParkingLotAdminRead.model_validate(
            {
                "id": parking_lot.id,
                "lot_owner_id": parking_lot.lot_owner_id,
                "name": parking_lot.name,
                "address": parking_lot.address,
                "latitude": parking_lot.latitude,
                "longitude": parking_lot.longitude,
                "current_available": parking_lot.current_available,
                "status": parking_lot.status,
                "description": parking_lot.description,
                "cover_image": parking_lot.cover_image,
                "created_at": parking_lot.created_at,
                "updated_at": parking_lot.updated_at,
                "owner_name": "Nguyen Van A",
                "owner_phone": "0909123456",
                "owner_business_license": "BL-001",
            }
        )

        assert result.owner_name == "Nguyen Van A"

    @pytest.mark.asyncio
    async def test_read_admin_parking_lot_list(self, mock_db):
        lots_result = MagicMock()
        lots_result.all.return_value = [
            (_parking_lot(), "Nguyen Van A", "0909123456", "BL-001"),
        ]
        mock_db.execute = AsyncMock(return_value=lots_result)

        result = await read_parking_lot_applications(Mock(), _admin_user(), mock_db)

        assert len(result) == 1
        assert result[0].owner_name == "Nguyen Van A"

    @pytest.mark.asyncio
    async def test_approve_pending_parking_lot(self, mock_db):
        parking_lot = _parking_lot(status=ParkingLotStatus.PENDING.value)
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = parking_lot
        mock_db.execute = AsyncMock(return_value=parking_lot_result)
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        payload = ParkingLotReview(decision=ParkingLotStatus.APPROVED)
        result = await review_parking_lot(Mock(), 7, payload, _admin_user(), mock_db)

        assert result.status == ParkingLotStatus.APPROVED.value
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_reject_parking_lot_requires_reason(self, mock_db):
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = _parking_lot()
        mock_db.execute = AsyncMock(return_value=parking_lot_result)

        payload = ParkingLotReview(
            decision=ParkingLotStatus.REJECTED,
            rejection_reason=None,
        )

        with pytest.raises(BadRequestException, match="Rejection reason"):
            await review_parking_lot(Mock(), 7, payload, _admin_user(), mock_db)

    @pytest.mark.asyncio
    async def test_review_non_pending_parking_lot_raises_bad_request(self, mock_db):
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = _parking_lot(
            status=ParkingLotStatus.APPROVED.value,
        )
        mock_db.execute = AsyncMock(return_value=parking_lot_result)

        payload = ParkingLotReview(
            decision=ParkingLotStatus.REJECTED,
            rejection_reason="Sai thong tin",
        )

        with pytest.raises(BadRequestException, match="Only pending"):
            await review_parking_lot(Mock(), 7, payload, _admin_user(), mock_db)

    @pytest.mark.asyncio
    async def test_review_missing_parking_lot_raises_not_found(self, mock_db):
        parking_lot_result = MagicMock()
        parking_lot_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=parking_lot_result)

        payload = ParkingLotReview(decision=ParkingLotStatus.APPROVED)

        with pytest.raises(NotFoundException, match="Parking lot not found"):
            await review_parking_lot(Mock(), 7, payload, _admin_user(), mock_db)