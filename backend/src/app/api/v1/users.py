from collections.abc import Sequence
from datetime import UTC, datetime
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Request
from fastcrud import PaginatedListResponse, compute_offset, paginated_response
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from ...api.dependencies import get_current_superuser, get_current_user
from ...core.db.database import async_get_db
from ...core.exceptions.http_exceptions import BadRequestException, DuplicateValueException, ForbiddenException, NotFoundException
from ...core.security import blacklist_token, get_password_hash, oauth2_scheme
from ...crud.crud_rate_limit import crud_rate_limits
from ...crud.crud_tier import crud_tiers
from ...crud.crud_users import crud_users
from ...models.enums import CapabilityApplicationStatus, UserRole, VehicleType
from ...models.user import User
from ...models.users import Driver, LotOwner, LotOwnerApplication, Manager, OperatorApplication
from ...schemas.lot_owner_application import LotOwnerApplicationCreate, LotOwnerApplicationRead, LotOwnerApplicationReview
from ...schemas.operator_application import OperatorApplicationCreate, OperatorApplicationRead, OperatorApplicationReview
from ...models.vehicles import Vehicle
from ...schemas.tier import TierRead
from ...schemas.user import AdminUserActivationUpdate, AdminUserRead, UserCreate, UserCreateInternal, UserRead, UserTierUpdate, UserUpdate
from ...schemas.vehicle import VehicleCreate, VehicleRead

router = APIRouter(tags=["users"])


def _utcnow() -> datetime:
    return datetime.now(UTC)


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


def _ensure_public_account(current_user: dict[str, Any]) -> None:
    if current_user.get("role") in {UserRole.ATTENDANT.value, UserRole.ADMIN.value} or current_user.get("is_superuser"):
        raise ForbiddenException("Only public accounts can manage lot owner applications")


async def _get_lot_owner_application_by_user_id(db: AsyncSession, user_id: int) -> LotOwnerApplication | None:
    application_result = await db.execute(
        select(LotOwnerApplication)
        .where(LotOwnerApplication.user_id == user_id)
        .order_by(LotOwnerApplication.created_at.desc(), LotOwnerApplication.id.desc())
        .limit(1)
    )
    return application_result.scalar_one_or_none()


async def _get_lot_owner_profile(db: AsyncSession, user_id: int) -> LotOwner | None:
    lot_owner_result = await db.execute(select(LotOwner).where(LotOwner.user_id == user_id).limit(1))
    return lot_owner_result.scalar_one_or_none()


async def _get_operator_application_by_user_id(db: AsyncSession, user_id: int) -> OperatorApplication | None:
    application_result = await db.execute(
        select(OperatorApplication)
        .where(OperatorApplication.user_id == user_id)
        .order_by(OperatorApplication.created_at.desc(), OperatorApplication.id.desc())
        .limit(1)
    )
    return application_result.scalar_one_or_none()


async def _get_manager_profile(db: AsyncSession, user_id: int) -> Manager | None:
    manager_result = await db.execute(select(Manager).where(Manager.user_id == user_id).limit(1))
    return manager_result.scalar_one_or_none()


async def _get_user_by_id(db: AsyncSession, user_id: int) -> User | None:
    user_result = await db.execute(select(User).where(User.id == user_id, User.is_deleted.is_(False)).limit(1))
    return user_result.scalar_one_or_none()


@router.get("/user/me/lot-owner-application", response_model=LotOwnerApplicationRead | None)
async def read_my_lot_owner_application(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> LotOwnerApplication | None:
    _ensure_public_account(current_user)
    return await _get_lot_owner_application_by_user_id(db, current_user["id"])


@router.post("/user/me/lot-owner-application", response_model=LotOwnerApplicationRead, status_code=201)
async def create_my_lot_owner_application(
    request: Request,
    payload: LotOwnerApplicationCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> LotOwnerApplication:
    _ensure_public_account(current_user)

    existing_capability = await _get_lot_owner_profile(db, current_user["id"])
    if existing_capability is not None:
        raise DuplicateValueException("Lot owner capability is already active for this account")

    existing_application = await _get_lot_owner_application_by_user_id(db, current_user["id"])
    if existing_application is not None:
        if existing_application.status == CapabilityApplicationStatus.PENDING.value:
            raise DuplicateValueException("Lot owner application is already pending review")
        if existing_application.status == CapabilityApplicationStatus.APPROVED.value:
            raise DuplicateValueException("Lot owner capability is already approved for this account")

    application = LotOwnerApplication(
        user_id=current_user["id"],
        full_name=payload.full_name,
        phone_number=payload.phone_number,
        business_license=payload.business_license,
        document_reference=payload.document_reference,
        notes=payload.notes,
        status=CapabilityApplicationStatus.PENDING.value,
    )
    db.add(application)
    await db.commit()
    await db.refresh(application)
    return application


@router.get("/admin/lot-owner-applications", response_model=list[LotOwnerApplicationRead])
async def read_lot_owner_applications(
    request: Request,
    current_superuser: Annotated[dict, Depends(get_current_superuser)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> Sequence[LotOwnerApplication]:
    applications_result = await db.execute(
        select(LotOwnerApplication).order_by(LotOwnerApplication.created_at.desc(), LotOwnerApplication.id.desc())
    )
    return list(applications_result.scalars().all())


@router.post("/admin/lot-owner-applications/{application_id}/review", response_model=LotOwnerApplicationRead)
async def review_lot_owner_application(
    request: Request,
    application_id: int,
    payload: LotOwnerApplicationReview,
    current_superuser: Annotated[dict, Depends(get_current_superuser)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> LotOwnerApplication:
    application_result = await db.execute(select(LotOwnerApplication).where(LotOwnerApplication.id == application_id).limit(1))
    application = application_result.scalar_one_or_none()
    if application is None:
        raise NotFoundException("Lot owner application not found")

    if application.status != CapabilityApplicationStatus.PENDING.value:
        raise BadRequestException("Only pending lot owner applications can be reviewed")

    if payload.decision == CapabilityApplicationStatus.REJECTED and not payload.rejection_reason:
        raise BadRequestException("Rejection reason is required when rejecting an application")

    reviewed_at = _utcnow()
    application.status = payload.decision.value
    application.rejection_reason = payload.rejection_reason if payload.decision == CapabilityApplicationStatus.REJECTED else None
    application.reviewed_by_user_id = current_superuser["id"]
    application.reviewed_at = reviewed_at
    application.updated_at = reviewed_at

    if payload.decision == CapabilityApplicationStatus.APPROVED:
        user_result = await db.execute(select(User).where(User.id == application.user_id).limit(1))
        user = user_result.scalar_one_or_none()
        if user is None:
            raise NotFoundException("Applicant user not found")

        lot_owner = await _get_lot_owner_profile(db, application.user_id)
        if lot_owner is None:
            db.add(
                LotOwner(
                    user_id=application.user_id,
                    business_license=application.business_license,
                    verified_at=reviewed_at,
                )
            )
        else:
            lot_owner.business_license = application.business_license
            lot_owner.verified_at = reviewed_at

        if user.role in {UserRole.DRIVER.value, UserRole.LOT_OWNER.value}:
            user.role = UserRole.LOT_OWNER.value

    await db.commit()
    await db.refresh(application)
    return application


@router.get("/user/me/operator-application", response_model=OperatorApplicationRead | None)
async def read_my_operator_application(
    request: Request,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> OperatorApplication | None:
    _ensure_public_account(current_user)
    return await _get_operator_application_by_user_id(db, current_user["id"])


@router.post("/user/me/operator-application", response_model=OperatorApplicationRead, status_code=201)
async def create_my_operator_application(
    request: Request,
    payload: OperatorApplicationCreate,
    current_user: Annotated[dict, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> OperatorApplication:
    _ensure_public_account(current_user)

    existing_capability = await _get_manager_profile(db, current_user["id"])
    if existing_capability is not None:
        raise DuplicateValueException("Operator capability is already active for this account")

    existing_application = await _get_operator_application_by_user_id(db, current_user["id"])
    if existing_application is not None:
        if existing_application.status == CapabilityApplicationStatus.PENDING.value:
            raise DuplicateValueException("Operator application is already pending review")
        if existing_application.status == CapabilityApplicationStatus.APPROVED.value:
            raise DuplicateValueException("Operator capability is already approved for this account")

    application = OperatorApplication(
        user_id=current_user["id"],
        full_name=payload.full_name,
        phone_number=payload.phone_number,
        business_license=payload.business_license,
        document_reference=payload.document_reference,
        notes=payload.notes,
        status=CapabilityApplicationStatus.PENDING.value,
    )
    db.add(application)
    await db.commit()
    await db.refresh(application)
    return application


@router.get("/admin/operator-applications", response_model=list[OperatorApplicationRead])
async def read_operator_applications(
    request: Request,
    current_superuser: Annotated[dict, Depends(get_current_superuser)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> Sequence[OperatorApplication]:
    applications_result = await db.execute(
        select(OperatorApplication).order_by(OperatorApplication.created_at.desc(), OperatorApplication.id.desc())
    )
    return list(applications_result.scalars().all())


@router.post("/admin/operator-applications/{application_id}/review", response_model=OperatorApplicationRead)
async def review_operator_application(
    request: Request,
    application_id: int,
    payload: OperatorApplicationReview,
    current_superuser: Annotated[dict, Depends(get_current_superuser)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> OperatorApplication:
    application_result = await db.execute(select(OperatorApplication).where(OperatorApplication.id == application_id).limit(1))
    application = application_result.scalar_one_or_none()
    if application is None:
        raise NotFoundException("Operator application not found")

    if application.status != CapabilityApplicationStatus.PENDING.value:
        raise BadRequestException("Only pending operator applications can be reviewed")

    if payload.decision == CapabilityApplicationStatus.REJECTED and not payload.rejection_reason:
        raise BadRequestException("Rejection reason is required when rejecting an application")

    reviewed_at = _utcnow()
    application.status = payload.decision.value
    application.rejection_reason = payload.rejection_reason if payload.decision == CapabilityApplicationStatus.REJECTED else None
    application.reviewed_by_user_id = current_superuser["id"]
    application.reviewed_at = reviewed_at
    application.updated_at = reviewed_at

    if payload.decision == CapabilityApplicationStatus.APPROVED:
        user_result = await db.execute(select(User).where(User.id == application.user_id).limit(1))
        user = user_result.scalar_one_or_none()
        if user is None:
            raise NotFoundException("Applicant user not found")

        manager = await _get_manager_profile(db, application.user_id)
        if manager is None:
            db.add(
                Manager(
                    user_id=application.user_id,
                    business_license=application.business_license,
                    verified_at=reviewed_at,
                )
            )
        else:
            manager.business_license = application.business_license
            manager.verified_at = reviewed_at

        if user.role in {
            UserRole.DRIVER.value,
            UserRole.LOT_OWNER.value,
            UserRole.MANAGER.value,
        }:
            user.role = UserRole.MANAGER.value

    await db.commit()
    await db.refresh(application)
    return application


@router.get("/admin/users", response_model=list[AdminUserRead])
async def read_admin_users(
    request: Request,
    current_superuser: Annotated[dict, Depends(get_current_superuser)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
    search: str | None = None,
) -> Sequence[User]:
    query = select(User).where(User.is_deleted.is_(False))

    normalized_search = search.strip() if search else None
    if normalized_search:
        search_term = f"%{normalized_search}%"
        query = query.where(
            or_(
                User.name.ilike(search_term),
                User.username.ilike(search_term),
                User.email.ilike(search_term),
            )
        )

    users_result = await db.execute(query.order_by(User.created_at.desc(), User.id.desc()))
    return list(users_result.scalars().all())


@router.patch("/admin/users/{user_id}/activation", response_model=AdminUserRead)
async def patch_admin_user_activation(
    request: Request,
    user_id: int,
    payload: AdminUserActivationUpdate,
    current_superuser: Annotated[dict, Depends(get_current_superuser)],
    db: Annotated[AsyncSession, Depends(async_get_db)],
) -> User:
    user = await _get_user_by_id(db, user_id)
    if user is None:
        raise NotFoundException("User not found")

    if user.id == current_superuser["id"] and payload.is_active is False:
        raise BadRequestException("Admin cannot deactivate the current account")

    user.is_active = payload.is_active
    user.updated_at = _utcnow()
    await db.commit()
    await db.refresh(user)
    return user


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
