from src.app.api.dependencies import get_current_superuser
from src.app.core.exceptions.http_exceptions import ForbiddenException

import pytest


class TestGetCurrentSuperuser:
    @pytest.mark.asyncio
    async def test_accepts_true_superuser(self):
        current_user = {"id": 1, "role": "DRIVER", "is_superuser": True}

        result = await get_current_superuser(current_user)

        assert result == current_user

    @pytest.mark.asyncio
    async def test_accepts_admin_role_without_superuser_flag(self):
        current_user = {"id": 2, "role": "ADMIN", "is_superuser": False}

        result = await get_current_superuser(current_user)

        assert result == current_user

    @pytest.mark.asyncio
    async def test_rejects_non_admin_non_superuser(self):
        current_user = {"id": 3, "role": "DRIVER", "is_superuser": False}

        with pytest.raises(ForbiddenException, match="enough privileges"):
            await get_current_superuser(current_user)