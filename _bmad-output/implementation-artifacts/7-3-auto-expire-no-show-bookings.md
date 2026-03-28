# Story 7.3: Auto-Expire No-Show Bookings

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the System,
I want to automatically expire bookings older than 30 minutes,
so that held spots are returned when drivers do not arrive.

## Acceptance Criteria

1. Given backend-managed booking expiration is enabled, when a confirmed booking passes its 30-minute time-to-live without being consumed at the gate, then the system marks it as expired and returns held capacity exactly once.
2. Given a booking is cancelled already, consumed already, or otherwise no longer eligible for expiration, when the expiration job evaluates it, then no duplicate capacity release occurs and no terminal status is overwritten incorrectly.
3. Given bookings expire, when the background process commits an expiration batch, then canonical lot-availability updates are published after commit so Driver discovery and attendant views stay accurate.
4. Given the project architecture requires backend-managed scheduling, when booking expiration is implemented, then it runs via the existing backend worker/scheduler strategy rather than mobile timers, ad hoc admin actions, or push-notification infrastructure.
5. Given a Driver later checks their booking state, when the expired reservation is read, then the system exposes the explicit expired status cleanly instead of leaving the booking looking active forever.

## Implementation Clarifications

- This story owns automatic expiration only. Manual cancellation belongs to Story 7.1, and gate conversion belongs to Story 7.2.
- The architecture explicitly allows a lightweight in-process scheduler for local development or a dedicated worker process using the same codebase. Because this repository already has ARQ worker scaffolding, prefer extending that path rather than introducing a second scheduling stack.
- The requirement is reliable backend-managed expiration, not a specific third-party scheduler brand.
- Expiration must restore capacity in the same transaction as the booking status transition.
- Epic 10 owns push notifications. This story should not expand into notification delivery even though future product phases may alert users about booking expiry.

## Tasks / Subtasks

- [x] Task 1: Implement backend expiration job and booking expiry rules (AC: 1, 2, 4, 5)
  - [x] Add focused expiration logic that finds eligible stale bookings using backend UTC timestamps and updates them to `EXPIRED` safely.
  - [x] Ensure already cancelled, already consumed, or already expired bookings are ignored without restoring capacity again.
  - [x] Expose expired booking state cleanly through booking read contracts established in Story 7.1.

- [x] Task 2: Reuse the existing worker/scheduler scaffolding (AC: 1, 4)
  - [x] Extend the current ARQ worker functions/settings with a real booking-expiration job and an appropriate cron schedule.
  - [x] Keep the implementation aligned with the repo's existing worker startup/shutdown hooks and Redis-backed queue settings.
  - [x] If local demo execution needs an in-process fallback, keep it inside the backend architecture rather than offloading responsibility to mobile or manual operator actions.

- [x] Task 3: Preserve availability truth and publication semantics (AC: 1, 2, 3)
  - [x] Restore `current_available` within the same transaction as the booking expiration state change.
  - [x] Publish lot updates through the same canonical availability channel used by the rest of the system after successful commit.
  - [x] Prevent any double-release path when a booking was already cancelled or already converted into a session.

- [x] Task 4: Add focused regression coverage and verification (AC: 1, 2, 3, 4, 5)
  - [x] Add backend tests for successful expiration, non-eligible booking skip behavior, exact-once capacity restoration, and post-commit availability publication.
  - [x] Add tests for worker/scheduler registration or equivalent proof that the expiration job is wired into the backend execution path.
  - [x] Verify with backend Docker tests; Flutter verification is only required if Driver-visible expired-state UI contracts change in Story 7.1 surfaces.

## Dev Notes

### Story Foundation

- PRD FR6 and NFR16 explicitly require backend-managed automatic booking expiration.
- The architecture already defines booking expiration as backend-managed scheduled execution and provides acceptable implementation options.
- The repository already contains ARQ worker scaffolding and Redis queue settings, which make worker-based expiration the most natural path in this codebase.
- Story 7.1 should create bookings with explicit TTL metadata (`expected_arrival` / `expiration_time`) that this story can evaluate directly.

### Previous Story Intelligence

- Story 7.1 should establish the authoritative booking hold and cancellation model; this story must treat expiration as another terminal booking transition that restores capacity exactly once.
- Story 7.2 should ensure consumed bookings are not left looking eligible for later expiration.
- Story 5.4 already established the rule that availability changes publish through one canonical backend event shape after commit; expiration must follow the same rule.

### Domain Constraints To Respect

- Booking expiration is a backend responsibility, not a client responsibility.
- Expiration must be exact-once from a capacity perspective.
- Expired bookings remain part of history/state and should not vanish from the system.
- Converted bookings and cancelled bookings must not be expired later by mistake.

### Architecture Guardrails

- Prefer extending `backend/src/app/core/worker/functions.py` and `backend/src/app/core/worker/settings.py` using ARQ's existing worker settings and cron job support.
- Keep expiration logic inside a focused booking service/helper rather than embedding too much business logic in the cron registration layer.
- Use the same transaction and row-locking discipline the project already expects for session and booking mutations.
- Publish availability updates only after commit through the canonical backend lot-availability contract.

### Library / Framework Requirements

- Backend: reuse ARQ, Redis settings, FastAPI/SQLAlchemy async, and the existing backend worker scaffolding.
- ARQ supports `cron_jobs` on `WorkerSettings`; use that capability or an equivalent repository-aligned worker registration path instead of inventing a separate scheduler package.
- Do not add mobile timers, FCM/local notifications, or a second background-job framework in this story.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/bookings.py`
  - `backend/src/app/models/sessions.py`
  - `backend/src/app/services/booking_service.py` (new if needed)
  - `backend/src/app/core/worker/functions.py`
  - `backend/src/app/core/worker/settings.py`
  - `backend/src/app/core/lot_availability.py`
  - `backend/tests/` focused booking expiration and worker wiring suites
- Mobile:
  - `mobile/lib/src/features/driver_booking/` only if expired-state UI changes are required
  - `mobile/test/` only if Driver-visible booking state changes need coverage

### Testing Requirements

- Backend verification should run through Docker pytest and should explicitly test edge cases where bookings are already cancelled, already expired, or already consumed.
- If the worker registration path is hard to test end-to-end, add focused unit-level proof around cron registration and job dispatch rather than skipping scheduler coverage entirely.
- Flutter tests are optional unless Story 7.1 booking reads are extended to surface expired-state UI.

### Implementation Risks To Avoid

- Do not run booking expiration from the mobile client or an operator-triggered manual action.
- Do not restore capacity twice for the same booking.
- Do not expire bookings that were already consumed into sessions.
- Do not introduce push notifications, reminder notifications, or booking warning alerts in this story.
- Do not leave the expiration job unwired after implementing the business logic.

### Recent Repository Patterns

- The backend already has worker lifecycle hooks and Redis-backed ARQ configuration that should be extended rather than replaced.
- Booking, session, and lot-capacity state are expected to stay transactional and backend-owned.
- Recent stories have validated post-commit availability publication explicitly; booking expiration should do the same.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 7 / Story 7.3
- [prd.md](../prd.md) - FR6, FR7, NFR4, NFR16, EC13, EC14, EC15
- [architecture.md](../architecture.md) - Booking Expiration, Realtime Availability, backend project shape
- [tech-design.md](../tech-design.md) - booking expire transaction rules, scheduling/background work, API module plan
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - Honest Degradation principles where expired booking state is surfaced later
- [5-4-en-route-lot-capacity-alert.md](./5-4-en-route-lot-capacity-alert.md)
- [7-1-driver-pre-books-parking-spot.md](./7-1-driver-pre-books-parking-spot.md)
- [7-2-attendant-scans-pre-booked-check-in.md](./7-2-attendant-scans-pre-booked-check-in.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Add a backend-managed booking expiration job using the existing ARQ worker scaffold and cron-job support.
- Expire only eligible stale bookings, restore held capacity exactly once in the same transaction, and publish canonical availability updates after commit.
- Add focused backend regression coverage for expiration correctness, worker wiring, and exact-once capacity restoration.

### Completion Notes List

- Added a shared booking expiration service that expires stale confirmed bookings in batches, restores held capacity exactly once, and publishes canonical lot-availability updates only after commit.
- Wired the expiration path into the existing ARQ worker scaffold with a cron job so no-show expiry is backend-managed instead of client-managed.
- Extended booking reads so expired reservations surface explicit `EXPIRED` status and no longer look active forever.
- Updated the lot-details booking UI to show expired booking state cleanly and still allow immediate rebooking from the same scanner-free driver surface.
- Verified the story with focused backend Docker suites plus related availability regression and focused Flutter widget regressions.

### File List

- `backend/src/app/services/booking_service.py`
- `backend/src/app/api/v1/bookings.py`
- `backend/src/app/core/worker/functions.py`
- `backend/src/app/core/worker/settings.py`
- `backend/tests/test_bookings.py`
- `backend/tests/test_booking_expiration.py`
- `backend/tests/test_worker_settings.py`
- `mobile/lib/src/features/lot_details/presentation/lot_details_sheet.dart`
- `mobile/test/lot_details_booking_test.dart`
- `_bmad-output/implementation-artifacts/7-3-auto-expire-no-show-bookings.md`

### Change Log

- 2026-03-28: Implemented Story 7.3 with ARQ-backed booking expiration, exact-once capacity restoration, expired-state booking reads, and driver lot-details expired-booking UI coverage.
- 2026-03-28: Created Story 7.3 implementation artifact for backend-managed automatic expiration of no-show bookings.