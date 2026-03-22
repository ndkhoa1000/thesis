"""Shared enums for the smart parking domain models."""

import enum


class UserRole(str, enum.Enum):
    DRIVER = "DRIVER"
    ATTENDANT = "ATTENDANT"
    MANAGER = "MANAGER"
    LOT_OWNER = "LOT_OWNER"
    ADMIN = "ADMIN"


class VehicleType(str, enum.Enum):
    MOTORBIKE = "MOTORBIKE"
    CAR = "CAR"


class VehicleTypeAll(str, enum.Enum):
    """Vehicle type including ALL option for configs and pricing."""
    MOTORBIKE = "MOTORBIKE"
    CAR = "CAR"
    ALL = "ALL"


class ParkingLotStatus(str, enum.Enum):
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    CLOSED = "CLOSED"


class SlotType(str, enum.Enum):
    STANDARD = "STANDARD"
    VIP = "VIP"
    DISABLED = "DISABLED"


class PricingMode(str, enum.Enum):
    SESSION = "SESSION"
    HOURLY = "HOURLY"
    DAILY = "DAILY"
    MONTHLY = "MONTHLY"
    CUSTOM = "CUSTOM"


class FeatureType(str, enum.Enum):
    CAMERA = "CAMERA"
    IOT = "IOT"
    SLOT_MANAGEMENT = "SLOT_MANAGEMENT"
    BARRIER = "BARRIER"


class LeaseStatus(str, enum.Enum):
    PENDING = "PENDING"
    ACTIVE = "ACTIVE"
    EXPIRED = "EXPIRED"
    TERMINATED = "TERMINATED"


class LeaseContractStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    ACTIVE = "ACTIVE"
    EXPIRED = "EXPIRED"


class SubscriptionType(str, enum.Enum):
    WEEKLY = "WEEKLY"
    MONTHLY = "MONTHLY"


class SubscriptionStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    EXPIRED = "EXPIRED"
    CANCELLED = "CANCELLED"


class BookingStatus(str, enum.Enum):
    PENDING = "PENDING"
    CONFIRMED = "CONFIRMED"
    EXPIRED = "EXPIRED"
    CANCELLED = "CANCELLED"


class SessionStatus(str, enum.Enum):
    CHECKED_IN = "CHECKED_IN"
    CHECKED_OUT = "CHECKED_OUT"


class PayableType(str, enum.Enum):
    SESSION = "SESSION"
    SUBSCRIPTION = "SUBSCRIPTION"
    BOOKING = "BOOKING"


class PaymentMethod(str, enum.Enum):
    CASH = "CASH"
    ONLINE = "ONLINE"


class PaymentStatus(str, enum.Enum):
    PENDING = "PENDING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"


class AnnouncementType(str, enum.Enum):
    EVENT = "EVENT"
    TRAFFIC_ALERT = "TRAFFIC_ALERT"
    PEAK_HOURS = "PEAK_HOURS"
    CLOSURE = "CLOSURE"
    GENERAL = "GENERAL"


class NotificationType(str, enum.Enum):
    BOOKING_EXPIRING = "BOOKING_EXPIRING"
    SUBSCRIPTION_EXPIRING = "SUBSCRIPTION_EXPIRING"
    PAYMENT_SUCCESS = "PAYMENT_SUCCESS"
    LOT_CLOSING = "LOT_CLOSING"
    SYSTEM_ALERT = "SYSTEM_ALERT"


class ReferenceType(str, enum.Enum):
    BOOKING = "BOOKING"
    SESSION = "SESSION"
    SUBSCRIPTION = "SUBSCRIPTION"
    LOT = "LOT"
