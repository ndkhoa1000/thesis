# Boilerplate models (kept for reference/compatibility)
from .post import Post
from .rate_limit import RateLimit
from .tier import Tier
from .user import User

# --- Smart Parking Domain Models ---
from .enums import (
    AnnouncementType,
    BookingStatus,
    CapabilityApplicationStatus,
    FeatureType,
    LeaseContractStatus,
    LeaseStatus,
    NotificationType,
    ParkingLotStatus,
    PayableType,
    PaymentMethod,
    PaymentStatus,
    PricingMode,
    ReferenceType,
    SessionStatus,
    SlotType,
    SubscriptionStatus,
    SubscriptionType,
    UserRole,
    VehicleType,
    VehicleTypeAll,
)
from .users import Attendant, Driver, LotOwner, LotOwnerApplication, Manager, OperatorApplication
from .parking import ParkingLot, ParkingLotConfig, ParkingLotFeature, ParkingLotTag, Pricing, Slot
from .leases import LeaseContract, LotLease
from .vehicles import Subscription, SubscriptionLot, Vehicle
from .sessions import Booking, ParkingSession, SessionEdit
from .financials import Invoice, Payment
from .notifications import Notification, ParkingLotAnnouncement
