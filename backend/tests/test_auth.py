from unittest.mock import AsyncMock, Mock, patch

import pytest

from src.app.core.exceptions.http_exceptions import DuplicateValueException, UnauthorizedException


class TestRegisterUser:
    @pytest.mark.asyncio
    async def test_register_user_success(self, mock_db):
        from src.app.api.v1.auth import register_user
        from src.app.schemas.user import UserRegister

        payload = UserRegister(email="new.user@example.com", password="Str1ngst!123")
        created_user = Mock(
            id=10,
            name="New User",
            username="newuser",
            email="new.user@example.com",
            role="DRIVER",
            is_active=True,
        )

        with patch("src.app.api.v1.auth.crud_users") as mock_crud:
            mock_crud.exists = AsyncMock(side_effect=[False, False])
            mock_crud.create = AsyncMock(return_value=created_user)

            with patch("src.app.api.v1.auth.get_password_hash", return_value="hashed-password"):
                with patch("src.app.api.v1.auth.create_access_token", new=AsyncMock(return_value="access-token")):
                    with patch("src.app.api.v1.auth.create_refresh_token", new=AsyncMock(return_value="refresh-token")):
                        result = await register_user(Mock(), payload, mock_db)

        assert result["access_token"] == "access-token"
        assert result["refresh_token"] == "refresh-token"
        assert result["token_type"] == "bearer"
        assert result["user"]["email"] == payload.email
        assert result["user"]["role"] == "DRIVER"
        mock_crud.create.assert_awaited_once()
        assert mock_db.add.call_count == 1

    @pytest.mark.asyncio
    async def test_register_user_duplicate_email(self, mock_db):
        from src.app.api.v1.auth import register_user
        from src.app.schemas.user import UserRegister

        payload = UserRegister(email="duplicate@example.com", password="Str1ngst!123")

        with patch("src.app.api.v1.auth.crud_users") as mock_crud:
            mock_crud.exists = AsyncMock(return_value=True)

            with pytest.raises(DuplicateValueException, match="Email is already registered"):
                await register_user(Mock(), payload, mock_db)

    @pytest.mark.asyncio
    async def test_register_user_generates_unique_username(self, mock_db):
        from src.app.api.v1.auth import register_user
        from src.app.schemas.user import UserRegister

        payload = UserRegister(email="new.user@example.com", password="Str1ngst!123")
        created_user = Mock(
            id=10,
            name="New User",
            username="newuser1",
            email="new.user@example.com",
            role="DRIVER",
            is_active=True,
        )

        with patch("src.app.api.v1.auth.crud_users") as mock_crud:
            mock_crud.exists = AsyncMock(side_effect=[False, True, False])
            mock_crud.create = AsyncMock(return_value=created_user)

            with patch("src.app.api.v1.auth.get_password_hash", return_value="hashed-password"):
                with patch("src.app.api.v1.auth.create_access_token", new=AsyncMock(return_value="access-token")):
                    with patch("src.app.api.v1.auth.create_refresh_token", new=AsyncMock(return_value="refresh-token")):
                        result = await register_user(Mock(), payload, mock_db)

        assert result["user"]["username"] == "newuser1"
        mock_crud.exists.assert_any_await(db=mock_db, username="newuser")
        mock_crud.exists.assert_any_await(db=mock_db, username="newuser1")


class TestAuthTokenFlows:
    @pytest.mark.asyncio
    async def test_login_returns_refresh_token_in_body(self, mock_db):
        from src.app.api.v1.login import login_for_access_token

        form_data = Mock(username="tester", password="Str1ngst!123")
        user = {"username": "tester"}

        with patch("src.app.api.v1.login.authenticate_user", new=AsyncMock(return_value=user)):
            with patch("src.app.api.v1.login.create_access_token", new=AsyncMock(return_value="access-token")):
                with patch("src.app.api.v1.login.create_refresh_token", new=AsyncMock(return_value="refresh-token")):
                    result = await login_for_access_token(Mock(), form_data, mock_db)

        assert result == {
            "access_token": "access-token",
            "refresh_token": "refresh-token",
            "token_type": "bearer",
            "user": {"username": "tester"},
        }

    @pytest.mark.asyncio
    async def test_refresh_uses_request_body_token(self, mock_db):
        from src.app.api.v1.login import refresh_access_token
        from src.app.core.schemas import RefreshTokenRequest

        payload = RefreshTokenRequest(refresh_token="refresh-token")

        with patch("src.app.api.v1.login.verify_token", new=AsyncMock(return_value=Mock(username_or_email="tester"))):
            with patch("src.app.api.v1.login.create_access_token", new=AsyncMock(return_value="new-access-token")):
                result = await refresh_access_token(Mock(), payload, mock_db)

        assert result == {"access_token": "new-access-token", "token_type": "bearer"}

    @pytest.mark.asyncio
    async def test_refresh_requires_token(self, mock_db):
        from src.app.api.v1.login import refresh_access_token

        request = Mock()
        request.cookies.get.return_value = None

        with pytest.raises(UnauthorizedException, match="Refresh token missing"):
            await refresh_access_token(request, None, mock_db)