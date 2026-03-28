# Story 7.2: Attendant Scans Pre-Booked Check-In

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an Attendant,
I want to scan a driver's booking QR code,
so that their booking converts to an active parking session.

## Acceptance Criteria

1. Given I am authenticated as an Attendant assigned to a parking lot, when I scan a valid booking confirmation from Story 7.1, then the backend validates the booking server-side and converts it into exactly one active `ParkingSession` linked back to that booking.
2. Given the booking is valid, confirmed, unexpired, and belongs to the same lot, when the conversion succeeds, then the system reuses the booking's held capacity instead of decrementing `current_available` a second time.
3. Given the booking has already expired, been cancelled, been consumed already, belongs to another lot, or is otherwise invalid, when I try to convert it at the gate, then the system rejects the booking scan cleanly and does not create a partial session.
4. Given PRD edge case EC14 applies, when a Driver arrives with an expired booking QR, then the attendant is informed that booking conversion is rejected and may still use the regular non-booking check-in flow if spots are available.
5. Given the booking conversion succeeds, when the attendant remains in the gate workflow, then the scanner-first UX continues without introducing a second scanner surface, keyboard-heavy form, or extra payment step in this story.

## Implementation Clarifications

- This story converts a confirmed booking into an active session; it does not create the booking itself and it does not implement no-show expiration.
- The existing attendant scanner flow from Story 4.2 should remain the primary gate surface. Prefer extending backend token-purpose handling and attendant service logic over creating a separate booking-only scanner screen.
- A booking already reserved capacity in Story 7.1. Conversion must not decrement `current_available` again.
- The current `BookingStatus` model may not be sufficient to represent a consumed booking distinctly. If the existing states are too ambiguous, introduce the minimum explicit terminal state needed rather than hiding consumption behind an overloaded status.
- Story 7.2 should not collect another reservation payment or introduce a second booking-finance flow. The booking deposit/payment belongs to Story 7.1; checkout settlement remains part of the existing parking-session lifecycle.

## Tasks / Subtasks

- [x] Task 1: Implement backend booking-to-session conversion contract (AC: 1, 2, 3, 4)
  - [x] Extend the booking/session backend so an Attendant can submit a booking confirmation token and convert it to a `ParkingSession` for the assigned lot.
  - [x] Link the created session back to `ParkingSession.booking_id` and prevent duplicate conversion of the same booking.
  - [x] Reject expired, cancelled, already-consumed, malformed, or cross-lot booking tokens without leaving partial state.

- [x] Task 2: Reuse existing attendant scanner flow and QR validation patterns (AC: 1, 4, 5)
  - [x] Extend the attendant Flutter service and scanner workflow so the existing gate flow can process booking confirmation payloads.
  - [x] Keep the UX scanner-first and gate-safe, with fast success/error feedback consistent with the Attendant operational experience.
  - [x] Preserve the fallback path: if a booking has expired, the attendant should still be able to proceed with the regular check-in flow outside this failed booking conversion.

- [x] Task 3: Protect capacity and lifecycle integrity (AC: 2, 3)
  - [x] Ensure booking conversion does not decrement availability again because the spot was already held at booking-create time.
  - [x] If a new consumed/checked-in booking status is introduced, update enums, schemas, tests, and mobile contracts consistently.
  - [x] Publish any necessary post-conversion availability or session state updates only if they reflect authoritative state changes rather than duplicating the original hold event.

- [x] Task 4: Add focused regression coverage and verification (AC: 1, 2, 3, 4, 5)
  - [x] Add backend tests for successful conversion, duplicate-consumption rejection, expired/cancelled booking rejection, cross-lot rejection, and no double-decrement of `current_available`.
  - [x] Add Flutter tests for booking QR success, booking QR rejection, and continued use of the existing scanner-first attendant surface.
  - [x] Verify with backend Docker tests and local `flutter test`.

## Dev Notes

### Story Foundation

- Story 7.1 should establish the booking confirmation artifact, booking payment linkage, and held-capacity semantics that this story consumes.
- Story 4.2 already created the scanner-first attendant check-in boundary and the rule that the backend, not the client, validates QR token purpose and identity.
- PRD edge case EC14 explicitly states that an expired booking must be rejected for booking conversion, while the attendant may still perform a regular check-in if spots remain.
- `ParkingSession` already has a nullable `booking_id` field in the backend model, so conversion should reuse that existing link instead of inventing a parallel association.

### Previous Story Intelligence

- Story 4.1 and Story 4.2 established the preferred QR pattern: backend-issued token first, server-side validation second, real session creation only at the attendant boundary.
- Story 7.1 should already hold capacity at booking creation, so this story must treat conversion as a lifecycle transition, not a second reservation mutation.
- Epic 6 retrospective explicitly warns against inventing booking-specific shortcuts that diverge from existing session/capacity invariants.

### Domain Constraints To Respect

- Only the assigned lot attendant may convert a booking at that lot.
- Booking conversion must result in exactly one active session or a clean rejection; partial session creation is unacceptable.
- Capacity reserved by booking creation must not be consumed a second time during conversion.
- Expired or cancelled bookings are terminal from the booking-conversion perspective.

### Architecture Guardrails

- Prefer extending the existing attendant check-in flow in `sessions.py` over building a separate scanner subsystem for bookings.
- Keep booking/session mutation logic transactional and backend-owned.
- Reuse backend-issued token semantics from earlier QR stories rather than trusting client-built booking payloads.
- If booking lifecycle rules become complex, isolate them behind a focused booking service rather than scattering state transitions across route functions.

### Library / Framework Requirements

- Flutter: reuse the existing attendant scanner package and attendant feature service structure.
- Backend: reuse FastAPI auth dependencies, existing session model, booking model, and current transaction patterns.
- Do not add NFC, real payment processing, or a second QR scanning library for this story.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/sessions.py`
  - `backend/src/app/api/v1/bookings.py` if booking-read helpers need to live there
  - `backend/src/app/models/sessions.py`
  - `backend/src/app/schemas/session.py`
  - `backend/src/app/schemas/booking.py` if needed
  - `backend/tests/` focused booking conversion suites
- Mobile:
  - `mobile/lib/src/features/attendant_check_in/`
  - `mobile/lib/src/features/driver_booking/` only if booking metadata must be shared
  - `mobile/test/` attendant booking conversion tests

### Testing Requirements

- Backend verification should run through Docker pytest using targeted booking/session suites.
- Flutter verification should run with local `flutter test`.
- Tests must explicitly prove that booking conversion does not double-release or double-consume capacity.

### Implementation Risks To Avoid

- Do not create a second scanner experience just for bookings.
- Do not decrement `current_available` on booking conversion if the spot was already held during booking creation.
- Do not treat `CONFIRMED` bookings as endlessly reusable if the model needs a consumed terminal state.
- Do not silently auto-convert expired bookings into regular check-ins inside the backend; the attendant should make that next action explicitly.
- Do not duplicate Story 4.2's direct check-in logic instead of layering booking validation on top of it carefully.

### Recent Repository Patterns

- Attendant gate workflows have stayed scanner-first, dark-mode, and explicit about success/failure feedback.
- Session creation boundaries already live in `sessions.py`, while booking lifecycle work belongs primarily in `bookings.py` and related services.
- Recent story hardening consistently favored strict lifecycle modeling over ambiguous state reuse.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 7 / Story 7.2
- [prd.md](../prd.md) - FR4, FR6, FR7, FR8, FR9, FR12, EC14, NFR2, NFR15
- [architecture.md](../architecture.md) - realtime availability, booking expiration, `/bookings/*`, `/sessions/*`, backend project shape
- [tech-design.md](../tech-design.md) - transactional session/booking updates, API module plan
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - Driver Booking & Sync Flow, Zero-Typing Gate, Sensory-First Confirmation
- [4-1-driver-generates-check-in-qr.md](./4-1-driver-generates-check-in-qr.md)
- [4-2-attendant-scans-qr-for-check-in.md](./4-2-attendant-scans-qr-for-check-in.md)
- [7-1-driver-pre-books-parking-spot.md](./7-1-driver-pre-books-parking-spot.md)
- [epic-6-retro-2026-03-28.md](./epic-6-retro-2026-03-28.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Extend the existing attendant scanner flow so booking confirmation tokens can be validated and converted into linked parking sessions.
- Preserve booking-held capacity and lifecycle integrity by preventing duplicate conversion and avoiding a second availability decrement.
- Add focused backend and Flutter regression coverage for conversion success, rejection paths, and scanner UX continuity.

### Completion Notes List

- Extended the existing attendant QR check-in endpoint to accept booking confirmation tokens and convert valid bookings into linked active parking sessions.
- Introduced explicit booking consumption handling so converted bookings cannot be reused and booking-held capacity is not decremented twice.
- Kept the scanner-first mobile gate flow unchanged and added widget coverage for booking QR success plus expired-booking fallback guidance.
- Verified the story with focused Flutter and backend tests plus related attendant/availability backend regressions.

### File List

- `backend/src/app/api/v1/bookings.py`
- `backend/src/app/api/v1/sessions.py`
- `backend/src/app/models/enums.py`
- `backend/tests/test_attendant_booking_check_in.py`
- `mobile/test/attendant_check_in_screen_test.dart`
- `_bmad-output/implementation-artifacts/7-2-attendant-scans-pre-booked-check-in.md`

### Change Log

- 2026-03-28: Implemented Story 7.2 by extending attendant QR check-in to consume booking confirmation tokens, preserving held capacity, and adding backend/mobile regression coverage.
- 2026-03-28: Created Story 7.2 implementation artifact for attendant-side booking QR conversion into active parking sessions.
- 2026-03-28: Closed Epic 7 review follow-up by rechecking booking expiry at the session-conversion boundary and revalidated focused plus full backend regressions.