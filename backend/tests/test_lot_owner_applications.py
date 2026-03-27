"""Unit tests for lot owner capability applications (Story 1-4)."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.users import (
    create_my_lot_owner_application,
    read_my_lot_owner_application,
    read_lot_owner_applications,
    review_lot_owner_application,
)
from src.app.core.exceptions.http_exceptions import (
    BadRequestException,
    DuplicateValueException,
    ForbiddenException,
    NotFoundException,
)
from src.app.models.enums import CapabilityApplicationStatus
from src.app.models.users import LotOwner, LotOwnerApplication
from src.app.schemas.lot_owner_application import (
    LotOwnerApplicationCreate,
    LotOwnerApplicationReview,
)


def _public_user(user_id: int = 1, role: str = "DRIVER") -> dict:
    return {
        "id": user_id,
        "username": "driver_user",
        "email": "driver@test.com",
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


def _application(
    application_id: int = 10,
    user_id: int = 1,
    status: str = CapabilityApplicationStatus.PENDING.value,
) -> LotOwnerApplication:
    application = MagicMock(spec=LotOwnerApplication)
    application.id = application_id
    application.user_id = user_id
    application.full_name = "Nguyen Van A"
    application.phone_number = "0909123456"
    application.business_license = "BL-001"
    application.document_reference = "https://example.com/doc.pdf"
    application.notes = "Need review"
    application.status = status
    application.rejection_reason = None
    application.reviewed_by_user_id = None
    application.reviewed_at = None
    application.created_at = datetime.now(UTC)
    application.updated_at = None
    return application


def _lot_owner(user_id: int = 1) -> LotOwner:
    lot_owner = MagicMock(spec=LotOwner)
    lot_owner.user_id = user_id
    lot_owner.business_license = "BL-001"
    lot_owner.verified_at = None
    return lot_owner


class TestReadMyLotOwnerApplication:
    @pytest.mark.asyncio
    async def test_returns_current_application(self, mock_db):
        application = _application()
        app_result = MagicMock()
        app_result.scalar_one_or_none.return_value = application
        mock_db.execute = AsyncMock(return_value=app_result)

        result = await read_my_lot_owner_application(Mock(), _public_user(), mock_db)

        assert result == application

    @pytest.mark.asyncio
    async def test_attendant_cannot_read_application(self, mock_db):
        with pytest.raises(ForbiddenException):
            await read_my_lot_owner_application(
                Mock(),
                _public_user(role="ATTENDANT"),
                mock_db,
            )


class TestCreateMyLotOwnerApplication:
    @pytest.mark.asyncio
    async def test_create_application_success(self, mock_db):
        no_capability = MagicMock()
        no_capability.scalar_one_or_none.return_value = None
        no_application = MagicMock()
        no_application.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(side_effect=[no_capability, no_application])
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        payload = LotOwnerApplicationCreate(
            full_name="Nguyen Van A",
            phone_number="0909123456",
            business_license="BL-001",
            document_reference="https://example.com/doc.pdf",
            notes="Please review",
        )

        result = await create_my_lot_owner_application(
            Mock(),
            payload,
            _public_user(),
            mock_db,
        )

        assert result.user_id == 1
        assert result.status == CapabilityApplicationStatus.PENDING.value
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_pending_application_raises_duplicate(self, mock_db):
        no_capability = MagicMock()
        no_capability.scalar_one_or_none.return_value = None
        existing_application = MagicMock()
        existing_application.scalar_one_or_none.return_value = _application(
            status=CapabilityApplicationStatus.PENDING.value,
        )
        mock_db.execute = AsyncMock(side_effect=[no_capability, existing_application])

        payload = LotOwnerApplicationCreate(
            full_name="Nguyen Van A",
            phone_number="0909123456",
            business_license="BL-001",
            document_reference="https://example.com/doc.pdf",
            notes=None,
        )

        with pytest.raises(DuplicateValueException, match="pending review"):
            await create_my_lot_owner_application(
                Mock(),
                payload,
                _public_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_rejected_application_can_be_resubmitted(self, mock_db):
        no_capability = MagicMock()
        no_capability.scalar_one_or_none.return_value = None
        existing_record = _application(status=CapabilityApplicationStatus.REJECTED.value)
        existing_record.rejection_reason = "Missing document"
        existing_application = MagicMock()
        existing_application.scalar_one_or_none.return_value = existing_record
        mock_db.execute = AsyncMock(side_effect=[no_capability, existing_application])
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        payload = LotOwnerApplicationCreate(
            full_name="Tran Thi B",
            phone_number="0911222333",
            business_license="BL-002",
            document_reference="https://example.com/new.pdf",
            notes="Updated doc",
        )

        result = await create_my_lot_owner_application(
            Mock(),
            payload,
            _public_user(),
            mock_db,
        )

        assert result.full_name == "Tran Thi B"
        assert result.status == CapabilityApplicationStatus.PENDING.value
        assert result.rejection_reason is None


class TestAdminLotOwnerApplications:
    @pytest.mark.asyncio
    async def test_read_admin_application_list(self, mock_db):
        applications = [_application(application_id=10), _application(application_id=11, user_id=2)]
        apps_result = MagicMock()
        apps_result.scalars.return_value.all.return_value = applications
        mock_db.execute = AsyncMock(return_value=apps_result)

        result = await read_lot_owner_applications(Mock(), _admin_user(), mock_db)

        assert result == applications

    @pytest.mark.asyncio
    async def test_approve_application_creates_lot_owner_capability(self, mock_db):
        application = _application(status=CapabilityApplicationStatus.PENDING.value)
        app_result = MagicMock()
        app_result.scalar_one_or_none.return_value = application

        user = MagicMock()
        user.id = 1
        user.role = "DRIVER"
        user_result = MagicMock()
        user_result.scalar_one_or_none.return_value = user

        no_lot_owner_result = MagicMock()
        no_lot_owner_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(
            side_effect=[app_result, user_result, no_lot_owner_result],
        )
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        payload = LotOwnerApplicationReview(decision=CapabilityApplicationStatus.APPROVED)
        result = await review_lot_owner_application(
            Mock(),
            10,
            payload,
            _admin_user(),
            mock_db,
        )

        assert result.status == CapabilityApplicationStatus.APPROVED.value
        assert application.reviewed_by_user_id == 99
        assert user.role == "LOT_OWNER"
        mock_db.add.assert_called_once()
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_reject_application_requires_reason(self, mock_db):
        app_result = MagicMock()
        app_result.scalar_one_or_none.return_value = _application()
        mock_db.execute = AsyncMock(return_value=app_result)

        payload = LotOwnerApplicationReview(
            decision=CapabilityApplicationStatus.REJECTED,
            rejection_reason=None,
        )

        with pytest.raises(BadRequestException, match="Rejection reason"):
            await review_lot_owner_application(
                Mock(),
                10,
                payload,
                _admin_user(),
                mock_db,
            )

    @pytest.mark.asyncio
    async def test_review_missing_application_raises_not_found(self, mock_db):
        app_result = MagicMock()
        app_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=app_result)

        payload = LotOwnerApplicationReview(decision=CapabilityApplicationStatus.APPROVED)

        with pytest.raises(NotFoundException, match="Lot owner application not found"):
            await review_lot_owner_application(
                Mock(),
                999,
                payload,
                _admin_user(),
                mock_db,
            )