"""Unit tests for operator capability applications (Story 1-5)."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest

from src.app.api.v1.users import (
    create_my_operator_application,
    read_my_operator_application,
    read_operator_applications,
    review_operator_application,
)
from src.app.core.exceptions.http_exceptions import BadRequestException, DuplicateValueException, ForbiddenException, NotFoundException
from src.app.models.enums import CapabilityApplicationStatus
from src.app.models.users import Manager, OperatorApplication
from src.app.schemas.operator_application import OperatorApplicationCreate, OperatorApplicationRead, OperatorApplicationReview


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
) -> OperatorApplication:
    application = MagicMock(spec=OperatorApplication)
    application.id = application_id
    application.user_id = user_id
    application.full_name = "Nguyen Van B"
    application.phone_number = "0909123456"
    application.business_license = "OP-001"
    application.document_reference = "https://example.com/operator.pdf"
    application.notes = "Need review"
    application.status = status
    application.rejection_reason = None
    application.reviewed_by_user_id = None
    application.reviewed_at = None
    application.created_at = datetime.now(UTC)
    application.updated_at = None
    return application


class TestReadMyOperatorApplication:
    def test_read_schema_supports_orm_objects(self):
        application = _application()

        result = OperatorApplicationRead.model_validate(application)

        assert result.id == application.id
        assert result.status == application.status

    @pytest.mark.asyncio
    async def test_returns_current_application(self, mock_db):
        application = _application()
        app_result = MagicMock()
        app_result.scalar_one_or_none.return_value = application
        mock_db.execute = AsyncMock(return_value=app_result)

        result = await read_my_operator_application(Mock(), _public_user(), mock_db)

        assert result == application

    @pytest.mark.asyncio
    async def test_attendant_cannot_read_application(self, mock_db):
        with pytest.raises(ForbiddenException):
            await read_my_operator_application(Mock(), _public_user(role="ATTENDANT"), mock_db)


class TestCreateMyOperatorApplication:
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

        payload = OperatorApplicationCreate(
            full_name="Nguyen Van B",
            phone_number="0909123456",
            business_license="OP-001",
            document_reference="https://example.com/operator.pdf",
            notes="Please review",
        )

        result = await create_my_operator_application(Mock(), payload, _public_user(), mock_db)

        assert result.user_id == 1
        assert result.status == CapabilityApplicationStatus.PENDING.value
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_pending_application_raises_duplicate(self, mock_db):
        no_capability = MagicMock()
        no_capability.scalar_one_or_none.return_value = None
        existing_application = MagicMock()
        existing_application.scalar_one_or_none.return_value = _application(status=CapabilityApplicationStatus.PENDING.value)
        mock_db.execute = AsyncMock(side_effect=[no_capability, existing_application])

        payload = OperatorApplicationCreate(
            full_name="Nguyen Van B",
            phone_number="0909123456",
            business_license="OP-001",
            document_reference="https://example.com/operator.pdf",
            notes=None,
        )

        with pytest.raises(DuplicateValueException, match="pending review"):
            await create_my_operator_application(Mock(), payload, _public_user(), mock_db)

    @pytest.mark.asyncio
    async def test_rejected_application_can_be_resubmitted(self, mock_db):
        no_capability = MagicMock()
        no_capability.scalar_one_or_none.return_value = None
        existing_record = _application(status=CapabilityApplicationStatus.REJECTED.value)
        existing_record.rejection_reason = "Missing document"
        existing_application = MagicMock()
        existing_application.scalar_one_or_none.return_value = existing_record
        mock_db.execute = AsyncMock(side_effect=[no_capability, existing_application])
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        payload = OperatorApplicationCreate(
            full_name="Tran Thi C",
            phone_number="0911222333",
            business_license="OP-002",
            document_reference="https://example.com/new.pdf",
            notes="Updated doc",
        )

        result = await create_my_operator_application(Mock(), payload, _public_user(), mock_db)

        mock_db.add.assert_called_once()
        assert result is not existing_record
        assert result.full_name == "Tran Thi C"
        assert result.status == CapabilityApplicationStatus.PENDING.value
        assert result.rejection_reason is None


class TestAdminOperatorApplications:
    @pytest.mark.asyncio
    async def test_read_admin_application_list(self, mock_db):
        applications = [_application(application_id=10), _application(application_id=11, user_id=2)]
        apps_result = MagicMock()
        apps_result.scalars.return_value.all.return_value = applications
        mock_db.execute = AsyncMock(return_value=apps_result)

        result = await read_operator_applications(Mock(), _admin_user(), mock_db)

        assert result == applications

    @pytest.mark.asyncio
    async def test_approve_application_creates_operator_capability(self, mock_db):
        application = _application(status=CapabilityApplicationStatus.PENDING.value)
        app_result = MagicMock()
        app_result.scalar_one_or_none.return_value = application

        user = MagicMock()
        user.id = 1
        user.role = "DRIVER"
        user_result = MagicMock()
        user_result.scalar_one_or_none.return_value = user

        no_manager_result = MagicMock()
        no_manager_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(side_effect=[app_result, user_result, no_manager_result])
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        payload = OperatorApplicationReview(decision=CapabilityApplicationStatus.APPROVED)
        result = await review_operator_application(Mock(), 10, payload, _admin_user(), mock_db)

        assert result.status == CapabilityApplicationStatus.APPROVED.value
        assert application.reviewed_by_user_id == 99
        assert user.role == "MANAGER"
        mock_db.add.assert_called_once()
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_approve_application_promotes_lot_owner_workspace_to_manager(self, mock_db):
        application = _application(status=CapabilityApplicationStatus.PENDING.value)
        app_result = MagicMock()
        app_result.scalar_one_or_none.return_value = application

        user = MagicMock()
        user.id = 1
        user.role = "LOT_OWNER"
        user_result = MagicMock()
        user_result.scalar_one_or_none.return_value = user

        no_manager_result = MagicMock()
        no_manager_result.scalar_one_or_none.return_value = None

        mock_db.execute = AsyncMock(side_effect=[app_result, user_result, no_manager_result])
        mock_db.add = Mock()
        mock_db.commit = AsyncMock()
        mock_db.refresh = AsyncMock()

        payload = OperatorApplicationReview(decision=CapabilityApplicationStatus.APPROVED)
        result = await review_operator_application(Mock(), 10, payload, _admin_user(), mock_db)

        assert result.status == CapabilityApplicationStatus.APPROVED.value
        assert user.role == "MANAGER"
        mock_db.add.assert_called_once()
        mock_db.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_reject_application_requires_reason(self, mock_db):
        app_result = MagicMock()
        app_result.scalar_one_or_none.return_value = _application()
        mock_db.execute = AsyncMock(return_value=app_result)

        payload = OperatorApplicationReview(decision=CapabilityApplicationStatus.REJECTED, rejection_reason=None)

        with pytest.raises(BadRequestException, match="Rejection reason"):
            await review_operator_application(Mock(), 10, payload, _admin_user(), mock_db)

    @pytest.mark.asyncio
    async def test_review_non_pending_application_raises_bad_request(self, mock_db):
        app_result = MagicMock()
        app_result.scalar_one_or_none.return_value = _application(status=CapabilityApplicationStatus.APPROVED.value)
        mock_db.execute = AsyncMock(return_value=app_result)

        payload = OperatorApplicationReview(decision=CapabilityApplicationStatus.REJECTED, rejection_reason="late")

        with pytest.raises(BadRequestException, match="Only pending"):
            await review_operator_application(Mock(), 10, payload, _admin_user(), mock_db)

    @pytest.mark.asyncio
    async def test_review_missing_application_raises_not_found(self, mock_db):
        app_result = MagicMock()
        app_result.scalar_one_or_none.return_value = None
        mock_db.execute = AsyncMock(return_value=app_result)

        payload = OperatorApplicationReview(decision=CapabilityApplicationStatus.APPROVED)

        with pytest.raises(NotFoundException, match="Operator application not found"):
            await review_operator_application(Mock(), 999, payload, _admin_user(), mock_db)