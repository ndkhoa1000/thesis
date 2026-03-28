# Story 7.1: Driver Pre-Books Parking Spot

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Driver,
I want to pay an advance reservation fee to book a spot,
so that my spot is guaranteed upon arrival.

## Acceptance Criteria

1. Given I am an authenticated Driver viewing a lot that supports booking and still has available capacity, when I choose a vehicle and confirm the reservation, then the backend creates exactly one active booking for that driver/vehicle/lot and holds one spot for 30 minutes.
2. Given a booking is confirmed, when the reservation is created, then the system records the advance payment as a backend-owned booking payment and links it via `payable_type = BOOKING` instead of inventing a parallel payment flow.
3. Given a booking is created or cancelled, when the mutation commits, then `current_available` changes in the same transaction and the canonical lot-availability event is published after commit so map/detail consumers stay accurate.
4. Given I already have an active booking for that lot, the lot is full, or a competing request claims the last spot first, when I try to reserve, then the system rejects the booking with a clear Driver-facing error and does not create a partial hold or duplicate payment.
5. Given I have an active booking that has not yet expired, when I open the Driver booking confirmation surface, then I can see a backend-trusted confirmation artifact that Story 7.2 can later scan at the gate without the client inventing booking identity fields locally.
6. Given I cancel a still-active booking before expiration, when the cancellation succeeds, then the booking becomes cancelled, held capacity is restored exactly once, and the booking can no longer be used for gate conversion.

## Implementation Clarifications

- This story owns Driver-side booking creation, cancellation, and confirmation display. It does not convert a booking into a `ParkingSession`; that belongs to Story 7.2.
- The PRD journey states that the Driver pays a deposit online before receiving booking confirmation. Keep this MVP payment backend-owned and compatible with the existing simulated-online payment model instead of inventing a separate real gateway integration in Epic 7.
- The existing `Booking` model and `PayableType.BOOKING` already exist in the backend. Reuse them rather than introducing a second reservation domain or duplicate payment table.
- Treat the hold on capacity as authoritative at booking-create time. Do not defer the capacity decrement until gate arrival.
- The Driver-facing confirmation should follow the same backend-issued token pattern used by Story 4.1. Do not build booking QR payloads purely on-device from raw booking fields.
- The current app shell is still the interim public workspace. Integrate booking entry from the existing lot details / map discovery flow without assuming the final Epic 9 shell already exists.

## Tasks / Subtasks

- [x] Task 1: Implement backend booking create/cancel/payment contracts (AC: 1, 2, 3, 4, 6)
  - [x] Extend `backend/src/app/api/v1/bookings.py` with Driver-scoped create, cancel, and active-booking read endpoints using the existing auth dependency model.
  - [x] Add a focused booking schema module if needed and keep booking/payment response contracts typed instead of using generic dict payloads.
  - [x] Create the booking, payment, and capacity hold in one transaction; cancellation must restore capacity in the same transaction and reject already expired/cancelled bookings cleanly.
  - [x] Enforce duplicate-booking, full-lot, and concurrent-last-spot rejection using row-level locking or equivalent transactional protection.

- [x] Task 2: Add Driver booking confirmation and lot-details entry flow (AC: 1, 5, 6)
  - [x] Add a Driver booking service layer in Flutter for create, cancel, and active-booking retrieval.
  - [x] Add a booking CTA from the existing lot-details experience instead of creating a disconnected Driver screen first.
  - [x] Surface a Driver-visible booking confirmation artifact and active-booking state without duplicating the existing check-in QR feature structure unnecessarily.

- [x] Task 3: Reuse canonical availability publication and payment semantics (AC: 2, 3, 4)
  - [x] Publish lot-availability updates from the same backend-owned mutation boundary already used by session and lot-capacity changes.
  - [x] Reuse `Payment` with `payable_type = BOOKING`; do not add a booking-only payment ledger.
  - [x] Keep the simulated-online MVP behavior backend-driven and consistent with the project's existing payment scope.

- [x] Task 4: Add focused regression coverage and verification (AC: 1, 2, 3, 4, 5, 6)
  - [x] Add backend tests for successful booking creation, duplicate booking rejection, full-lot rejection, cancellation, payment linkage, and atomic availability changes.
  - [x] Add Flutter tests for booking CTA visibility, booking confirmation rendering, cancellation success, and Driver-facing error handling.
  - [x] Verify with backend Docker tests and local `flutter test`.

## Dev Notes

### Story Foundation

- PRD Journey 1 already defines the intended user flow: the Driver books from lot discovery/details, pays a deposit online, and receives QR confirmation before arriving at the lot.
- Epic 5 already delivered the lot-discovery and lot-details surfaces that should be the booking entry point. This story should build on those surfaces instead of introducing a parallel discovery flow.
- The backend already contains a `Booking` model, `BookingStatus`, and `PayableType.BOOKING`, but `backend/src/app/api/v1/bookings.py` is still scaffold-only.
- Epic 6 retrospective explicitly recommends that Epic 7 reuse existing capacity/session invariants and canonical availability contracts instead of inventing booking-specific shortcuts.

### Previous Epic Intelligence

- Story 5.4 established the canonical rule that availability events must publish from the backend's real mutation boundary after commit; booking mutations should follow the same pattern.
- Story 4.1 established the preferred pattern for backend-issued QR/token artifacts consumed later by another workflow. Booking confirmation should follow that model rather than client-composed payloads.
- Epic 6 retrospective identified a process risk around central change surfaces. Keep new booking logic focused and avoid unnecessarily bloating `sessions.py` when `bookings.py` and a dedicated booking service can own the primary reservation lifecycle.

### Domain Constraints To Respect

- Booking is Driver-scoped and lot-scoped; the same Driver must not be allowed to accumulate duplicate active holds for the same lot.
- `current_available` must be decremented when the booking becomes active and restored when it is cancelled or later expired.
- Booking payments remain part of the existing polymorphic payment domain; they are not a new finance subsystem.
- Story 7.1 should not create a `ParkingSession` or perform attendant gate conversion.

### Architecture Guardrails

- Reuse `backend/src/app/api/v1/bookings.py` as the booking route family and add a dedicated `booking_service.py` only if it improves transactional clarity within the current backend project shape.
- Follow the architecture's atomicity rule: booking create/cancel must update `current_available` within the same transaction as the booking state change.
- Publish lot updates through the same backend availability contract already used by Story 5.4; do not poll or synthesize client-side capacity state.
- Keep auth and authorization on the existing FastAPI dependency and ownership-check pattern. Do not trust client-submitted Driver identity beyond the authenticated token.

### Library / Framework Requirements

- Backend: reuse FastAPI, SQLAlchemy async, the existing `Payment` domain, and the current realtime availability publication path.
- Mobile: reuse `dio`, existing lot-details and map-discovery features, and the QR rendering approach already introduced for Driver check-in.
- Do not add a real payment gateway, push notifications, or a second QR-generation stack for this story.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/bookings.py`
  - `backend/src/app/models/sessions.py`
  - `backend/src/app/models/financials.py`
  - `backend/src/app/schemas/booking.py` (new if needed)
  - `backend/src/app/services/booking_service.py` (new if needed)
  - `backend/src/app/core/lot_availability.py`
  - `backend/tests/` focused booking suites
- Mobile:
  - `mobile/lib/src/features/lot_details/`
  - `mobile/lib/src/features/map_discovery/`
  - `mobile/lib/src/features/driver_booking/` (new feature folder if needed)
  - `mobile/lib/src/features/driver_check_in/` if QR-display patterns are reused
  - `mobile/test/`

### Testing Requirements

- Backend verification should run through the Docker pytest flow used by recent stories.
- Flutter verification should run with local `flutter test`.
- Tests must cover concurrency-sensitive last-spot booking behavior and duplicate-hold rejection, not only the happy path.

### Implementation Risks To Avoid

- Do not invent a new reservation model when `Booking` already exists.
- Do not decrement capacity outside the booking transaction or forget to restore it on cancellation.
- Do not issue a Driver-visible booking QR/token that is composed purely on-device.
- Do not add speculative booking analytics, push notifications, or real gateway integration in this story.
- Do not leave an unpaid or partially created booking holding capacity after an error.

### Recent Repository Patterns

- Driver-facing workflows have used thin Flutter services over backend-owned contracts, with typed DTOs and focused widget tests.
- The lot-details sheet is already the place where drivers review pricing, hours, and announcements; it is the natural booking entry point.
- Availability publication already exists as a canonical backend event stream and should be reused for booking holds and releases.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 7 / Story 7.1
- [prd.md](../prd.md) - Journey 1, FR4, FR5, FR7, FR20, NFR4, NFR15, NFR16, EC11, EC12, EC13, EC15
- [architecture.md](../architecture.md) - Booking expiration, realtime availability, API module plan, backend project shape
- [tech-design.md](../tech-design.md) - booking create/cancel/expire transaction rules, API module plan, scheduling options
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - Driver Booking & Sync Flow, Thumb-Zone and honest-degradation patterns
- [5-2-view-lot-details-availability.md](./5-2-view-lot-details-availability.md)
- [5-4-en-route-lot-capacity-alert.md](./5-4-en-route-lot-capacity-alert.md)
- [epic-6-retro-2026-03-28.md](./epic-6-retro-2026-03-28.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Extend the scaffolded bookings API into a real Driver booking lifecycle with atomic capacity holds, cancellation, and booking-linked payment records.
- Reuse the existing lot-details/map-discovery entry points and backend-issued QR/token pattern for Driver confirmation rather than inventing a disconnected booking UI.
- Add focused backend and Flutter regression coverage around booking correctness, capacity integrity, and Driver-facing confirmation states.

### Completion Notes List

- Implemented backend driver booking lifecycle endpoints with typed schemas, signed booking confirmation tokens, simulated-online booking payments, duplicate-booking protection, and transactional capacity hold/cancel behavior.
- Integrated booking entry directly into the lot-details bottom sheet with vehicle selection, backend-backed confirmation QR rendering, cancellation, and manage-vehicle fallback.
- Added backend unit coverage in `tests/test_bookings.py` and Flutter widget coverage in `mobile/test/lot_details_booking_test.dart`; preserved existing discovery tests by wiring new booking dependencies into `mobile/test/map_discovery_screen_test.dart`.
- Verification completed: `cd backend && docker compose run --rm pytest python -m pytest`, `cd mobile && flutter test`, `cd backend && . .venv/bin/activate && ruff check src/app/api/v1/bookings.py src/app/schemas/booking.py tests/test_bookings.py`, and targeted `flutter analyze` on Story 7.1 files all passed.

### File List

- `backend/src/app/api/v1/bookings.py`
- `backend/src/app/schemas/booking.py`
- `backend/tests/test_bookings.py`
- `mobile/lib/main.dart`
- `mobile/lib/src/features/driver_booking/data/driver_booking_service.dart`
- `mobile/lib/src/features/lot_details/presentation/lot_details_sheet.dart`
- `mobile/lib/src/features/map_discovery/presentation/map_discovery_screen.dart`
- `mobile/test/lot_details_booking_test.dart`
- `mobile/test/map_discovery_screen_test.dart`

### Change Log

- 2026-03-28: Created Story 7.1 implementation artifact for Driver-side booking creation, cancellation, payment linkage, and confirmation guidance.
- 2026-03-28: Implemented Story 7.1 booking backend/mobile flow, added booking regression tests, and completed full backend plus Flutter regression verification.