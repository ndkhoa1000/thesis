---
type: bmad-distillate
sources:
  - "erd.md"
downstream_consumer: "general"
created: "2026-03-28"
token_estimate: 1200
parts: 1
---

## Core Design
- Standard: BCNF/4NF; no data redundancy; complete dependency on PK
- Denormalized cache: `ParkingLot[current_available]` for realtime queries
- Subclassing: Class Table Inheritance for `User` -> `Driver`, `LotOwner`, `Manager`, `Attendant`

## User Entities
- `User`: Base; `user_id` (PK), `email` (UK), `role` (DRIVER, ATTENDANT, MANAGER, LOT_OWNER, ADMIN), `is_active`
- `Driver`: Extends `User`; `wallet_balance`
- `LotOwner`: Extends `User`; `business_license`, `verified_at`
- `Manager` (Operator): Extends `User`; `business_license`, `verified_at`
- `Attendant`: Extends `User`; `parking_lot_id` (FK)

## Vehicle
- `Vehicle`: `driver_id`, `license_plate` (UK), `vehicle_type` (MOTORBIKE, CAR), images, `is_verified`

## Parking Lot
- `ParkingLot`: Physical entity; `lot_owner_id`, `latitude`/`longitude`, `current_available` (cache), `status` (PENDING, APPROVED, REJECTED, CLOSED)
- `ParkingLotConfig`: Temporal config (1 active per lot where `effective_to` is NULL); capacity, hours, accepted `vehicle_type`
- `LotLease`: Manager rents ParkingLot; `monthly_fee`, `status` (PENDING, ACTIVE, EXPIRED, TERMINATED)
- `LeaseContract`: Document for `LotLease`; HTML content, `status`
- `ParkingLotFeature`: Enabled IoT modules (CAMERA, SLOT_MANAGEMENT, BARRIER)
- `ParkingLotTag`: Descriptive tags
- `Slot`: `slot_code`, `slot_type` (STANDARD, VIP, DISABLED), `is_occupied`, `sensor_id`

## Pricing & Subscriptions
- `Pricing`: Modes (SESSION, HOURLY, DAILY, MONTHLY, CUSTOM); per lot and `vehicle_type`
- `Subscription`: Weekly/Monthly passes; linked to `Driver`, optionally to specific `Vehicle`; `price`, `status`
- `SubscriptionLot`: Junction mapping `Subscription` to valid `ParkingLot`(s)

## Operations
- `Booking`: Advance reservation; `driver_id`, `parking_lot_id`, `vehicle_id`, `expected_arrival`, `expiration_time`, `status` (PENDING, CONFIRMED, EXPIRED, CANCELLED)
- `ParkingSession`: The core event; nullable `booking_id`/`subscription_id`; checkin/checkout times, images, `qr_code` (UK), `status` (CHECKED_IN, CHECKED_OUT)
- `SessionEdit`: Audit trail of manual session changes by Attendants; track `field_changed`, old/new values, `reason`
- `Shift`: Attendant's working window per lot; `starting_cash`, `expected_cash`, `actual_cash`
- `ShiftHandover`: Between two Shifts; `transferred_cash`, `discrepancy_amount`, `discrepancy_reason`

## Finance & Communication
- `Payment`: Polymorphic (`payable_type`: SESSION, SUBSCRIPTION, BOOKING); `amount` minus `discount` equals `final_amount`; `payment_status` (PENDING, COMPLETED, FAILED)
- `Invoice`: Maps 1:1 to completed `Payment`; track `print_count`
- `ParkingLotAnnouncement`: Manager broadcasts to users; types (EVENT, TRAFFIC_ALERT, CLOSURE, etc.)
- `Notification`: System alerts to User; types (BOOKING_EXPIRING, PAYMENT_SUCCESS, etc.)

## Key Relationships
- `LotOwner` + `Manager` -> `LotLease` (N:M): Manger leases lot from Owner
- `ParkingSession` -> `Payment` (1:0..1): 1 session max 1 payment
- `Shift` -> `ShiftHandover` (1:1): Shift hands over to max 1 shift

## Indexing Strategy
- Realtime operations: `ParkingSession` (status, time), `Slot` (availability)
- Lookup: `Vehicle` and `ParkingSession` by `license_plate`
- Geo: `ParkingLot` by `latitude`/`longitude`
- Expirations: `Booking` (status, expiration_time)
