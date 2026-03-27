import re
from datetime import timedelta
from typing import Any

from fastapi import APIRouter, Depends, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ...api.dependencies import get_current_user
from ...core.db.database import async_get_db
from ...core.exceptions.http_exceptions import DuplicateValueException
from ...core.schemas import Token
from ...core.security import ACCESS_TOKEN_EXPIRE_MINUTES, create_access_token, create_refresh_token, get_password_hash
from ...crud.crud_users import crud_users
from ...models.enums import UserRole
from ...models.users import Attendant, Driver, LotOwner, Manager
from ...schemas.user import UserCreateInternal, UserRegister

router = APIRouter(prefix="/auth", tags=["auth"])


def _value(source: Any, key: str) -> Any:
    if isinstance(source, dict):
        return source.get(key)
    return getattr(source, key)


def _fallback_capabilities(user: Any) -> dict[str, bool]:
    role = _value(user, "role")
    is_superuser = bool(_value(user, "is_superuser") or role == UserRole.ADMIN.value)
    driver = role == UserRole.DRIVER.value
    lot_owner = role == UserRole.LOT_OWNER.value
    operator = role == UserRole.MANAGER.value
    attendant = role == UserRole.ATTENDANT.value
    admin = is_superuser or role == UserRole.ADMIN.value
    return {
        "driver": driver,
        "lot_owner": lot_owner,
        "operator": operator,
        "attendant": attendant,
        "admin": admin,
        "public_account": driver or lot_owner or operator,
    }


async def _linked_profile_exists(db: AsyncSession, model: type[Driver | LotOwner | Manager | Attendant], user_id: int) -> bool:
    result = await db.execute(select(model.id).where(model.user_id == user_id).limit(1))
    return result.scalar_one_or_none() is not None


async def resolve_auth_capabilities(user: Any, db: AsyncSession | None = None) -> dict[str, bool]:
    user_id = _value(user, "id")
    if db is None or user_id is None:
        return _fallback_capabilities(user)

    role = _value(user, "role")
    is_superuser = bool(_value(user, "is_superuser") or role == UserRole.ADMIN.value)
    driver = await _linked_profile_exists(db, Driver, user_id)
    lot_owner = await _linked_profile_exists(db, LotOwner, user_id)
    operator = await _linked_profile_exists(db, Manager, user_id)
    attendant = await _linked_profile_exists(db, Attendant, user_id) or role == UserRole.ATTENDANT.value
    admin = is_superuser or role == UserRole.ADMIN.value
    return {
        "driver": driver,
        "lot_owner": lot_owner,
        "operator": operator,
        "attendant": attendant,
        "admin": admin,
        "public_account": driver or lot_owner or operator,
    }


def build_auth_response(
    user: Any,
    access_token: str,
    refresh_token: str,
    *,
    capabilities: dict[str, bool] | None = None,
) -> dict[str, Any]:
    user_payload = build_auth_user_payload(user, capabilities=capabilities)

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": user_payload,
    }


def build_auth_user_payload(
    user: Any,
    *,
    capabilities: dict[str, bool] | None = None,
) -> dict[str, Any]:
    user_payload = {
        "id": _value(user, "id"),
        "name": _value(user, "name"),
        "username": _value(user, "username"),
        "email": _value(user, "email"),
        "role": _value(user, "role"),
        "is_active": _value(user, "is_active"),
        "capabilities": capabilities or _fallback_capabilities(user),
    }
    return {key: value for key, value in user_payload.items() if value is not None}


def _derive_name_from_email(email: str) -> str:
    local_part = email.split("@", 1)[0]
    pieces = [piece for piece in re.split(r"[._-]+", local_part) if piece]
    if not pieces:
        return "New User"
    return " ".join(piece.capitalize() for piece in pieces)[:30]


async def _generate_unique_username(email: str, db: AsyncSession) -> str:
    base = re.sub(r"[^a-z0-9]", "", email.split("@", 1)[0].lower())
    if len(base) < 2:
        base = "driver"
    candidate = base[:20]
    suffix = 1

    while await crud_users.exists(db=db, username=candidate):
        suffix_str = str(suffix)
        candidate = f"{base[: max(2, 20 - len(suffix_str))]}{suffix_str}"
        suffix += 1

    return candidate


@router.post("/register", response_model=Token, status_code=201)
async def register_user(
    payload: UserRegister,
    db: AsyncSession = Depends(async_get_db),
) -> dict[str, Any]:
    existing_email = await crud_users.exists(db=db, email=payload.email)
    if existing_email:
        raise DuplicateValueException("Email is already registered")

    username = await _generate_unique_username(payload.email, db)
    user_internal = UserCreateInternal(
        name=_derive_name_from_email(payload.email),
        username=username,
        email=payload.email,
        hashed_password=get_password_hash(payload.password),
        role=UserRole.DRIVER.value,
        is_active=True,
    )

    created_user = await crud_users.create(db=db, object=user_internal, commit=False)
    db.add(Driver(user_id=created_user.id))
    await db.commit()
    await db.refresh(created_user)

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = await create_access_token(data={"sub": created_user.username}, expires_delta=access_token_expires)
    refresh_token = await create_refresh_token(data={"sub": created_user.username})

    return build_auth_response(
        created_user,
        access_token,
        refresh_token,
        capabilities={
            "driver": True,
            "lot_owner": False,
            "operator": False,
            "attendant": False,
            "admin": False,
            "public_account": True,
        },
    )


@router.get("/me")
async def read_auth_me(
    current_user: dict[str, Any] = Depends(get_current_user),
    db: AsyncSession = Depends(async_get_db),
) -> dict[str, Any]:
    capabilities = await resolve_auth_capabilities(current_user, db)
    return {"user": build_auth_user_payload(current_user, capabilities=capabilities)}