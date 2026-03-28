import asyncio
import logging
from datetime import UTC, date, datetime, time, timedelta

from sqlalchemy import select

from ..app.core.db.database import local_session
from ..app.core.security import get_password_hash
from ..app.models.enums import LeaseStatus, ParkingLotStatus, PricingMode, SessionStatus, UserRole, VehicleTypeAll
from ..app.models.leases import LotLease
from ..app.models.parking import ParkingLot, ParkingLotConfig, ParkingLotFeature, ParkingLotTag, Pricing
from ..app.models.sessions import ParkingSession
from ..app.models.user import User
from ..app.models.users import Attendant, Driver, LotOwner, Manager
from ..app.models.vehicles import Vehicle

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    return datetime.now(UTC)


DEMO_USERS = {
    "admin": {
        "name": "Demo Admin",
        "username": "demo_admin",
        "email": "admin.demo@parking.local",
        "password": "Admin123!",
        "role": UserRole.ADMIN.value,
        "is_superuser": True,
        "phone": "0909000001",
    },
    "driver": {
        "name": "Demo Driver",
        "username": "demo_driver",
        "email": "driver.demo@parking.local",
        "password": "Driver123!",
        "role": UserRole.DRIVER.value,
        "is_superuser": False,
        "phone": "0909000002",
    },
    "lot_owner": {
        "name": "Demo Lot Owner",
        "username": "demo_owner",
        "email": "owner.demo@parking.local",
        "password": "Owner123!",
        "role": UserRole.LOT_OWNER.value,
        "is_superuser": False,
        "phone": "0909000003",
    },
    "operator": {
        "name": "Demo Operator",
        "username": "demo_operator",
        "email": "operator.demo@parking.local",
        "password": "Operator123!",
        "role": UserRole.MANAGER.value,
        "is_superuser": False,
        "phone": "0909000004",
    },
    "attendant": {
        "name": "Demo Attendant",
        "username": "demo_attendant",
        "email": "attendant.demo@parking.local",
        "password": "Attendant123!",
        "role": UserRole.ATTENDANT.value,
        "is_superuser": False,
        "phone": "0909000005",
    },
}


async def _get_user(session, email: str) -> User | None:
    result = await session.execute(select(User).where(User.email == email).limit(1))
    return result.scalar_one_or_none()


async def _ensure_user(session, *, name: str, username: str, email: str, password: str, role: str, phone: str, is_superuser: bool) -> User:
    user = await _get_user(session, email)
    hashed_password = get_password_hash(password)
    if user is None:
        user = User(
            name=name,
            username=username,
            email=email,
            hashed_password=hashed_password,
            role=role,
            phone=phone,
            is_active=True,
            is_superuser=is_superuser,
        )
        session.add(user)
        await session.flush()
        return user

    user.name = name
    user.username = username
    user.phone = phone
    user.role = role
    user.is_active = True
    user.is_deleted = False
    user.is_superuser = is_superuser
    user.hashed_password = hashed_password
    user.updated_at = _utcnow()
    await session.flush()
    return user


async def _ensure_driver(session, user_id: int) -> Driver:
    result = await session.execute(select(Driver).where(Driver.user_id == user_id).limit(1))
    driver = result.scalar_one_or_none()
    if driver is None:
        driver = Driver(user_id=user_id, wallet_balance=0)
        session.add(driver)
        await session.flush()
    return driver


async def _ensure_lot_owner(session, user_id: int) -> LotOwner:
    result = await session.execute(select(LotOwner).where(LotOwner.user_id == user_id).limit(1))
    lot_owner = result.scalar_one_or_none()
    if lot_owner is None:
        lot_owner = LotOwner(
            user_id=user_id,
            business_license="DEMO-OWNER-001",
            verified_at=_utcnow(),
        )
        session.add(lot_owner)
        await session.flush()
    else:
        lot_owner.business_license = "DEMO-OWNER-001"
        lot_owner.verified_at = lot_owner.verified_at or _utcnow()
    return lot_owner


async def _ensure_manager(session, user_id: int) -> Manager:
    result = await session.execute(select(Manager).where(Manager.user_id == user_id).limit(1))
    manager = result.scalar_one_or_none()
    if manager is None:
        manager = Manager(
            user_id=user_id,
            business_license="DEMO-OP-001",
            verified_at=_utcnow(),
        )
        session.add(manager)
        await session.flush()
    else:
        manager.business_license = "DEMO-OP-001"
        manager.verified_at = manager.verified_at or _utcnow()
    return manager


async def _ensure_attendant(session, user_id: int, parking_lot_id: int) -> Attendant:
    result = await session.execute(select(Attendant).where(Attendant.user_id == user_id).limit(1))
    attendant = result.scalar_one_or_none()
    if attendant is None:
        attendant = Attendant(
            user_id=user_id,
            parking_lot_id=parking_lot_id,
            hired_at=date.today(),
        )
        session.add(attendant)
        await session.flush()
    else:
        attendant.parking_lot_id = parking_lot_id
        attendant.hired_at = attendant.hired_at or date.today()
    return attendant


async def _ensure_parking_lot(
    session,
    *,
    lot_owner_id: int,
    name: str,
    address: str,
    latitude: float,
    longitude: float,
    description: str,
    current_available: int,
    status: str = ParkingLotStatus.APPROVED.value,
) -> ParkingLot:
    result = await session.execute(
        select(ParkingLot)
        .where(ParkingLot.lot_owner_id == lot_owner_id, ParkingLot.name == name)
        .limit(1)
    )
    parking_lot = result.scalar_one_or_none()
    if parking_lot is None:
        parking_lot = ParkingLot(
            lot_owner_id=lot_owner_id,
            name=name,
            address=address,
            latitude=latitude,
            longitude=longitude,
            description=description,
            current_available=current_available,
            status=status,
        )
        session.add(parking_lot)
        await session.flush()
    else:
        parking_lot.address = address
        parking_lot.latitude = latitude
        parking_lot.longitude = longitude
        parking_lot.description = description
        parking_lot.current_available = current_available
        parking_lot.status = status
        parking_lot.updated_at = _utcnow()
    return parking_lot


async def _ensure_active_lease(session, parking_lot_id: int, manager_id: int) -> LotLease:
    result = await session.execute(
        select(LotLease)
        .where(
            LotLease.parking_lot_id == parking_lot_id,
            LotLease.manager_id == manager_id,
            LotLease.status == LeaseStatus.ACTIVE.value,
        )
        .limit(1)
    )
    lease = result.scalar_one_or_none()
    if lease is None:
        lease = LotLease(
            parking_lot_id=parking_lot_id,
            manager_id=manager_id,
            monthly_fee=0,
            start_date=date.today(),
            status=LeaseStatus.ACTIVE.value,
        )
        session.add(lease)
        await session.flush()
    return lease


async def _ensure_config(session, parking_lot_id: int, manager_id: int, total_capacity: int, opening_time: time, closing_time: time) -> ParkingLotConfig:
    today = date.today()
    result = await session.execute(
        select(ParkingLotConfig)
        .where(
            ParkingLotConfig.parking_lot_id == parking_lot_id,
            ParkingLotConfig.vehicle_type == VehicleTypeAll.ALL.value,
            ParkingLotConfig.effective_from == today,
            ParkingLotConfig.effective_to.is_(None),
        )
        .limit(1)
    )
    config = result.scalar_one_or_none()
    if config is None:
        config = ParkingLotConfig(
            parking_lot_id=parking_lot_id,
            set_by=manager_id,
            total_capacity=total_capacity,
            vehicle_type=VehicleTypeAll.ALL.value,
            opening_time=opening_time,
            closing_time=closing_time,
            effective_from=today,
            effective_to=None,
        )
        session.add(config)
        await session.flush()
    else:
        config.total_capacity = total_capacity
        config.opening_time = opening_time
        config.closing_time = closing_time
    return config


async def _ensure_pricing(session, parking_lot_id: int, amount: float, mode: str) -> Pricing:
    today = date.today()
    result = await session.execute(
        select(Pricing)
        .where(
            Pricing.parking_lot_id == parking_lot_id,
            Pricing.vehicle_type == VehicleTypeAll.ALL.value,
            Pricing.effective_from == today,
            Pricing.effective_to.is_(None),
        )
        .limit(1)
    )
    pricing = result.scalar_one_or_none()
    if pricing is None:
        pricing = Pricing(
            parking_lot_id=parking_lot_id,
            price_amount=amount,
            vehicle_type=VehicleTypeAll.ALL.value,
            pricing_mode=mode,
            effective_from=today,
            effective_to=None,
        )
        session.add(pricing)
        await session.flush()
    else:
        pricing.price_amount = amount
        pricing.pricing_mode = mode
    return pricing


async def _ensure_tag(session, parking_lot_id: int, tag_name: str) -> None:
    result = await session.execute(
        select(ParkingLotTag)
        .where(ParkingLotTag.parking_lot_id == parking_lot_id, ParkingLotTag.tag_name == tag_name)
        .limit(1)
    )
    if result.scalar_one_or_none() is None:
        session.add(ParkingLotTag(parking_lot_id=parking_lot_id, tag_name=tag_name))
        await session.flush()


async def _ensure_feature(session, parking_lot_id: int, feature_type: str) -> None:
    result = await session.execute(
        select(ParkingLotFeature)
        .where(
            ParkingLotFeature.parking_lot_id == parking_lot_id,
            ParkingLotFeature.feature_type == feature_type,
        )
        .limit(1)
    )
    feature = result.scalar_one_or_none()
    if feature is None:
        session.add(
            ParkingLotFeature(
                parking_lot_id=parking_lot_id,
                feature_type=feature_type,
                enabled=True,
            )
        )
        await session.flush()
    else:
        feature.enabled = True


async def _ensure_vehicle(session, driver_id: int) -> Vehicle:
    result = await session.execute(select(Vehicle).where(Vehicle.license_plate == "59A-88888").limit(1))
    vehicle = result.scalar_one_or_none()
    if vehicle is None:
        vehicle = Vehicle(
            driver_id=driver_id,
            license_plate="59A-88888",
            vehicle_type=VehicleTypeAll.CAR.value,
            brand="Toyota",
            color="White",
            is_verified=True,
        )
        session.add(vehicle)
        await session.flush()
    else:
        vehicle.driver_id = driver_id
        vehicle.is_verified = True
    return vehicle


async def _ensure_session(
    session,
    *,
    parking_lot_id: int,
    driver_id: int,
    attendant_id: int,
    license_plate: str,
    checkin_time: datetime,
    status: str,
    checkout_time: datetime | None,
) -> None:
    result = await session.execute(
        select(ParkingSession)
        .where(
            ParkingSession.parking_lot_id == parking_lot_id,
            ParkingSession.license_plate == license_plate,
            ParkingSession.checkin_time == checkin_time,
        )
        .limit(1)
    )
    parking_session = result.scalar_one_or_none()
    if parking_session is None:
        parking_session = ParkingSession(
            parking_lot_id=parking_lot_id,
            driver_id=driver_id,
            attendant_checkin_id=attendant_id,
            attendant_checkout_id=attendant_id if checkout_time is not None else None,
            license_plate=license_plate,
            vehicle_type=VehicleTypeAll.CAR.value,
            checkin_time=checkin_time,
            checkout_time=checkout_time,
            status=status,
        )
        session.add(parking_session)
        await session.flush()
        return

    parking_session.driver_id = driver_id
    parking_session.attendant_checkin_id = attendant_id
    parking_session.attendant_checkout_id = attendant_id if checkout_time is not None else None
    parking_session.status = status
    parking_session.checkout_time = checkout_time


async def seed_demo_data() -> None:
    async with local_session() as session:
        admin_user = await _ensure_user(session, **DEMO_USERS["admin"])
        driver_user = await _ensure_user(session, **DEMO_USERS["driver"])
        lot_owner_user = await _ensure_user(session, **DEMO_USERS["lot_owner"])
        operator_user = await _ensure_user(session, **DEMO_USERS["operator"])
        attendant_user = await _ensure_user(session, **DEMO_USERS["attendant"])

        driver = await _ensure_driver(session, driver_user.id)
        lot_owner = await _ensure_lot_owner(session, lot_owner_user.id)
        manager = await _ensure_manager(session, operator_user.id)

        ready_lot = await _ensure_parking_lot(
            session,
            lot_owner_id=lot_owner.id,
            name="Bãi xe Demo Nguyễn Huệ",
            address="1 Nguyen Hue, Quan 1, TP.HCM",
            latitude=10.7732,
            longitude=106.7041,
            description="Bãi demo đã cấu hình sẵn để test check-in, map discovery và lot details.",
            current_available=17,
        )
        setup_lot = await _ensure_parking_lot(
            session,
            lot_owner_id=lot_owner.id,
            name="Bãi xe Demo Thiết Lập",
            address="45 Le Loi, Quan 1, TP.HCM",
            latitude=10.7729,
            longitude=106.6983,
            description="Bãi demo đã gán operator nhưng để trống cấu hình để test flow thiết lập trên Android.",
            current_available=0,
            status=ParkingLotStatus.CLOSED.value,
        )

        await _ensure_active_lease(session, ready_lot.id, manager.id)
        await _ensure_active_lease(session, setup_lot.id, manager.id)
        await _ensure_config(session, ready_lot.id, manager.id, 20, time(6, 0), time(22, 0))
        await _ensure_pricing(session, ready_lot.id, 15000, PricingMode.HOURLY.value)
        await _ensure_tag(session, ready_lot.id, "trung-tam")
        await _ensure_tag(session, ready_lot.id, "co-mai-che")
        await _ensure_feature(session, ready_lot.id, "CAMERA")
        await _ensure_feature(session, ready_lot.id, "BARRIER")

        attendant = await _ensure_attendant(session, attendant_user.id, ready_lot.id)
        await _ensure_vehicle(session, driver.id)

        historical_slots = [
            (_utcnow() - timedelta(days=7)).replace(hour=8, minute=0, second=0, microsecond=0),
            (_utcnow() - timedelta(days=5)).replace(hour=8, minute=30, second=0, microsecond=0),
            (_utcnow() - timedelta(days=3)).replace(hour=18, minute=0, second=0, microsecond=0),
        ]
        for index, checkin_time in enumerate(historical_slots, start=1):
            await _ensure_session(
                session,
                parking_lot_id=ready_lot.id,
                driver_id=driver.id,
                attendant_id=attendant.id,
                license_plate=f"59A-8888{index}",
                checkin_time=checkin_time,
                checkout_time=checkin_time + timedelta(hours=2),
                status=SessionStatus.CHECKED_OUT.value,
            )

        await _ensure_session(
            session,
            parking_lot_id=ready_lot.id,
            driver_id=driver.id,
            attendant_id=attendant.id,
            license_plate="59A-88888",
            checkin_time=_utcnow() - timedelta(minutes=45),
            checkout_time=None,
            status=SessionStatus.CHECKED_IN.value,
        )

        await session.commit()
        logger.info("Android demo data seeded successfully.")
        logger.info("Demo accounts:")
        for key, config in DEMO_USERS.items():
            logger.info("- %s: %s / %s", key, config["email"], config["password"])
        logger.info("Ready lot: %s", ready_lot.name)
        logger.info("Setup lot: %s", setup_lot.name)
        logger.info("Admin user id: %s", admin_user.id)


async def main() -> None:
    await seed_demo_data()


if __name__ == "__main__":
    asyncio.run(main())