from collections.abc import Sequence
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request
from fastcrud import PaginatedListResponse, compute_offset, paginated_response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ...api.dependencies import get_current_superuser, get_current_user
from ...core.db.database import async_get_db
from ...core.exceptions.http_exceptions import BadRequestException, DuplicateValueException, ForbiddenException, NotFoundException
from ...core.security import blacklist_token, get_password_hash, oauth2_scheme
from ...crud.crud_rate_limit import crud_rate_limits
from ...crud.crud_tier import crud_tiers
from ...crud.crud_users import crud_users
from ...models.enums import UserRole, VehicleType
from ...models.users import Driver
from ...models.vehicles import Vehicle
from ...schemas.tier import TierRead
from ...schemas.user import UserCreate, UserCreateInternal, UserRead, UserTierUpdate, UserUpdate
from ...schemas.vehicle import VehicleCreate, VehicleRead

router = APIRouter(tags=["users"])


def normalize_license_plate(license_plate: str) -> str:
    normalized = " ".join(license_plate.strip().upper().split())
    if not normalized:
        raise BadRequestException("License plate is required")
    return normalized


async def _get_driver_for_user(db: AsyncSession, current_user: dict[str, Any]) -> Driver:
    is_public_capable = current_user.get("role") in {
        UserRole.DRIVER.value,
        UserRole.LOT_OWNER.value,
        UserRole.MANAGER.value,
    }
    if not is_public_capable:
        raise ForbiddenException("Only driver-capable public accounts can manage vehicles")

    driver_result = await db.execute(select(Driver).where(Driver.user_id == current_user["id"]).limit(1))
    driver = driver_result.scalar_one_or_none()
    if driver is None:
        raise ForbiddenException("Driver profile not found for current account")
    return driver


@router.get("/user/me/vehicles", response_model=list[VehicleRead])
async def read_my_vehicles(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> Sequence[Vehicle]:
    driver = await _get_driver_for_user(db, current_user)
    vehicles_result = await db.execute(
        select(Vehicle).where(Vehicle.driver_id == driver.id).order_by(Vehicle.created_at.desc(), Vehicle.id.desc())
    )
    return list(vehicles_result.scalars().all())


@router.post("/user/me/vehicles", response_model=VehicleRead, status_code=201)
async def create_my_vehicle(
    request: Request,
    payload: VehicleCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> Vehicle:
    driver = await _get_driver_for_user(db, current_user)
    normalized_plate = normalize_license_plate(payload.license_plate)

    duplicate_result = await db.execute(select(Vehicle.id).where(Vehicle.license_plate == normalized_plate).limit(1))
    if duplicate_result.scalar_one_or_none() is not None:
        raise DuplicateValueException("License plate is already registered")

    vehicle_type = payload.vehicle_type.value if isinstance(payload.vehicle_type, VehicleType) else str(payload.vehicle_type)
    created_vehicle = Vehicle(driver_id=driver.id, license_plate=normalized_plate, vehicle_type=vehicle_type)
    db.add(created_vehicle)
    await db.commit()
    await db.refresh(created_vehicle)
    return created_vehicle


@router.delete("/user/me/vehicles/{vehicle_id}")
async def erase_my_vehicle(
    request: Request,
    vehicle_id: int,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> dict[str, str]:
    driver = await _get_driver_for_user(db, current_user)
    vehicle_result = await db.execute(select(Vehicle).where(Vehicle.id == vehicle_id).limit(1))
    vehicle = vehicle_result.scalar_one_or_none()

    if vehicle is None:
        raise NotFoundException("Vehicle not found")
    if vehicle.driver_id != driver.id:
        raise ForbiddenException("Vehicle does not belong to current driver")

    await db.delete(vehicle)
    await db.commit()
    return {"message": "Vehicle deleted"}


@router.post("/user", response_model=UserRead, status_code=201)
async def write_user(
    request: Request, user: UserCreate, db: Annotated[AsyncSession, Depends(async_get_db)]
) -> dict[str, Any]:
    email_row = await crud_users.exists(db=db, email=user.email)
    if email_row:
        raise DuplicateValueException("Email is already registered")

    username_row = await crud_users.exists(db=db, username=user.username)
    if username_row:
        raise DuplicateValueException("Username not available")

    user_internal_dict = user.model_dump()
    user_internal_dict["hashed_password"] = get_password_hash(password=user_internal_dict["password"])
    del user_internal_dict["password"]

    user_internal = UserCreateInternal(**user_internal_dict)
    created_user = await crud_users.create(db=db, object=user_internal, schema_to_select=UserRead)

    if created_user is None:
        raise NotFoundException("Failed to create user")

    return created_user


@router.get("/users", response_model=PaginatedListResponse[UserRead])
async def read_users(
    request: Request, db: Annotated[AsyncSession, Depends(async_get_db)], page: int = 1, items_per_page: int = 10
) -> dict:
    users_data = await crud_users.get_multi(
        db=db,
        offset=compute_offset(page, items_per_page),
        limit=items_per_page,
        is_deleted=False,
    )

    response: dict[str, Any] = paginated_response(crud_data=users_data, page=page, items_per_page=items_per_page)
    return response


@router.get("/user/me/", response_model=UserRead)
async def read_users_me(request: Request, current_user: Annotated[dict, Depends(get_current_user)]) -> dict:
    return current_user


@router.get("/user/{username}", response_model=UserRead)
async def read_user(
    request: Request, username: str, db: Annotated[AsyncSession, Depends(async_get_db)]
) -> dict[str, Any]:
    db_user = await crud_users.get(db=db, username=username, is_deleted=False, schema_to_select=UserRead)
    if db_user is None:
        raise NotFoundException("User not found")

    return db_user


@router.patch("/user/{username}")
async def patch_user(
    request: Request,
    values: UserUpdate,
    username: str,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> dict[str, str]:
    db_user = await crud_users.get(db=db, username=username)
    if db_user is None:
        raise NotFoundException("User not found")

    db_username = db_user["username"]
    db_email = db_user["email"]

    if db_username != current_user["username"]:
        raise ForbiddenException()

    if values.email is not None and values.email != db_email:
        if await crud_users.exists(db=db, email=values.email):
            raise DuplicateValueException("Email is already registered")

    if values.username is not None and values.username != db_username:
        if await crud_users.exists(db=db, username=values.username):
            raise DuplicateValueException("Username not available")

    await crud_users.update(db=db, object=values, username=username)
    return {"message": "User updated"}


@router.delete("/user/{username}")
async def erase_user(
    request: Request,
    username: str,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
    token: str = Depends(oauth2_scheme),
) -> dict[str, str]:
    db_user = await crud_users.get(db=db, username=username, schema_to_select=UserRead)
    if not db_user:
        raise NotFoundException("User not found")

    if username != current_user["username"]:
        raise ForbiddenException()

    await crud_users.delete(db=db, username=username)
    await blacklist_token(token=token, db=db)
    return {"message": "User deleted"}


@router.delete("/db_user/{username}", dependencies=[Depends(get_current_superuser)])
async def erase_db_user(
    request: Request,
    username: str,
    db: Annotated[AsyncSession, Depends(async_get_db)],
    token: str = Depends(oauth2_scheme),
) -> dict[str, str]:
    db_user = await crud_users.exists(db=db, username=username)
    if not db_user:
        raise NotFoundException("User not found")

    await crud_users.db_delete(db=db, username=username)
    await blacklist_token(token=token, db=db)
    return {"message": "User deleted from the database"}


@router.get("/user/{username}/rate_limits", dependencies=[Depends(get_current_superuser)])
async def read_user_rate_limits(
    request: Request, username: str, db: Annotated[AsyncSession, Depends(async_get_db)]
) -> dict[str, Any]:
    db_user = await crud_users.get(db=db, username=username, schema_to_select=UserRead)
    if db_user is None:
        raise NotFoundException("User not found")

    user_dict = dict(db_user)
    if db_user["tier_id"] is None:
        user_dict["tier_rate_limits"] = []
        return user_dict

    db_tier = await crud_tiers.get(db=db, id=db_user["tier_id"], schema_to_select=TierRead)
    if db_tier is None:
        raise NotFoundException("Tier not found")

    db_rate_limits = await crud_rate_limits.get_multi(db=db, tier_id=db_tier["id"])

    user_dict["tier_rate_limits"] = db_rate_limits["data"]

    return user_dict


@router.get("/user/{username}/tier")
async def read_user_tier(
    request: Request, username: str, db: Annotated[AsyncSession, Depends(async_get_db)]
) -> dict | None:
    db_user = await crud_users.get(db=db, username=username, schema_to_select=UserRead)
    if db_user is None:
        raise NotFoundException("User not found")

    if db_user["tier_id"] is None:
        return None

    db_tier = await crud_tiers.get(db=db, id=db_user["tier_id"], schema_to_select=TierRead)
    if not db_tier:
        raise NotFoundException("Tier not found")

    user_dict = dict(db_user)
    tier_dict = dict(db_tier)

    for key, value in tier_dict.items():
        user_dict[f"tier_{key}"] = value

    return user_dict


@router.patch("/user/{username}/tier", dependencies=[Depends(get_current_superuser)])
async def patch_user_tier(
    request: Request, username: str, values: UserTierUpdate, db: Annotated[AsyncSession, Depends(async_get_db)]
) -> dict[str, str]:
    db_user = await crud_users.get(db=db, username=username, schema_to_select=UserRead)
    if db_user is None:
        raise NotFoundException("User not found")

    db_tier = await crud_tiers.get(db=db, id=values.tier_id, schema_to_select=TierRead)
    if db_tier is None:
        raise NotFoundException("Tier not found")

    await crud_users.update(db=db, object=values.model_dump(), username=username)
    return {"message": f"User {db_user['name']} Tier updated"}
