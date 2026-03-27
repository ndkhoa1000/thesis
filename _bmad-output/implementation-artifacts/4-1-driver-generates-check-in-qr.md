# Story 4.1: Driver Generates Check-In QR

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Driver,
I want to generate a check-in QR code,
so that the attendant can scan it upon my arrival.

## Acceptance Criteria

1. Given I am authenticated as a public Driver with at least one registered vehicle and no active parking session, when I open the driver check-in flow, then I can choose my vehicle and see a check-in QR code ready for attendant scanning.
2. Given the check-in QR is generated, when it is displayed, then the payload is unique, non-guessable, and suitable for later attendant-side validation without exposing raw client-generated business data.
3. Given I already have an active parking session, when I try to open the driver check-in flow, then the app does not issue a new check-in QR and instead shows that my current session is already in progress.
4. Given I do not have any registered vehicles, when I try to access the check-in flow, then I am guided to the existing vehicle-management flow before QR generation is allowed.
5. Given Story 4.2 will scan this QR later, when the attendant-side flow is implemented, then the generated check-in token contains enough backend-trusted context to resolve the Driver identity and selected vehicle safely.

## Implementation Clarifications

- This story covers the Driver-side QR generation flow only. It does **not** create a `ParkingSession`; actual session creation belongs to Story 4.2.
- Do **not** overload `ParkingSession.qr_code` for this story. That field is for an actual persisted session, while Story 4.1 needs a pre-session driver check-in token.
- The QR payload must be issued by the backend, not composed purely on-device. A signed or opaque backend-generated token is required to satisfy PRD NFR8 and avoid trusting client-built business data.
- The current app shell is still the interim public workspace. Story 4.1 should plug into the existing Driver/public flow without hardcoding Epic 9 shell assumptions.
- Lot selection is out of scope for this story. The lot context is resolved operationally by the attendant-side scan flow in Story 4.2.
- NFC fallback, offline queueing, and camera scan UX belong to later attendant stories, not this story.

## Tasks / Subtasks

- [x] Task 1: Add backend driver check-in token contract (AC: 1, 2, 3, 5)
  - [x] Extend the sessions API scaffold with a Driver-facing endpoint that returns a check-in token/QR payload for a selected vehicle.
  - [x] Enforce vehicle ownership and reject QR issuance when the Driver already has an active session.
  - [x] Keep the token backend-trusted, short-lived, and suitable for future attendant-side validation in Story 4.2.

- [x] Task 2: Build the mobile Driver check-in flow (AC: 1, 3, 4)
  - [x] Add a typed mobile service for requesting a driver check-in QR from the backend.
  - [x] Add a Driver-facing screen or modal in the current public workspace that supports vehicle selection and QR display.
  - [x] Reuse the existing vehicle-management entry point when the Driver has no registered vehicles.

- [x] Task 3: Add focused regression coverage (AC: 2, 3, 4, 5)
  - [x] Add backend tests for vehicle ownership, active-session rejection, and token issuance.
  - [x] Add Flutter widget coverage for no-vehicle, active-session-blocked, and successful QR-display states.
  - [x] Verify backend in Docker and Flutter locally after wiring the flow.

## Dev Notes

### Story Foundation

- Epic 3 is now complete and provides the setup context Epic 4 relies on: leased-lot management, lot-wide capacity, operating hours, pricing rules, and dedicated Attendant accounts.
- Story 1.3 already established the Driver vehicle-management flow. Story 4.1 must reuse that flow instead of introducing duplicate vehicle entry UX.
- The backend already contains a `sessions.py` route scaffold and the `ParkingSession` model, but no session-domain API contract exists yet.
- The mobile app currently has no QR-generation feature package installed, and no dedicated Driver check-in screen exists yet.

### Domain Constraints To Respect

- The Driver public account remains part of the shared public identity model, so this story must use the authenticated public `user` plus linked `driver` capability.
- Only one active parking session should block fresh check-in QR issuance for the same Driver account.
- The token emitted here must support the PRD QR state-machine direction without prematurely implementing the full check-out state machine from FR12 and Story 4.4.
- Inactive-account enforcement is already fixed globally and must remain respected by any new Driver session endpoints.

### Architecture Guardrails

- Backend implementation should extend the existing sessions module incrementally: `backend/src/app/api/v1/sessions.py` is already the intended domain route, so do not create an unrelated temporary route family.
- Keep auth and authorization aligned with the current FastAPI dependency model (`get_current_user` and capability/ownership checks), not ad hoc token parsing in route functions.
- Render the QR code on the mobile client. The backend should issue the trusted payload; it should not need to return a pre-rendered image.
- Prefer a lightweight, dedicated QR widget package on Flutter for rendering only. The current `pubspec.yaml` does not contain one yet.
- Because no session schema module exists yet, it is acceptable to introduce a focused `backend/src/app/schemas/session.py` file if that is the cleanest place for request/response contracts.

### Library / Framework Requirements

- Flutter currently does **not** include a QR-rendering dependency. Add one deliberately during implementation rather than faking QR UI with placeholder text.
- FastAPI already includes `python-jose`; if a signed token approach is chosen, reuse the existing backend security approach carefully instead of inventing a second incompatible signing model.
- Do not add heavy image-generation dependencies to the backend solely for QR display. The story only needs a trusted payload contract plus mobile rendering.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/sessions.py`
  - `backend/src/app/schemas/session.py` (new if needed)
  - `backend/src/app/models/sessions.py`
  - `backend/tests/test_driver_check_in_qr.py` (preferred focused suite)
- Mobile:
  - `mobile/lib/main.dart`
  - `mobile/lib/src/features/driver_check_in/` (new feature folder if needed)
  - `mobile/lib/src/features/vehicles/`
  - `mobile/test/widget_test.dart`

### Testing Requirements

- Backend verification should run through the Docker pytest service using the repo convention for targeted suites.
- Flutter verification should run with local `flutter test`.
- Android/manual smoke validation is currently user-owned and should not be assumed as part of this story's default validation unless explicitly requested.

### Implementation Risks To Avoid

- Do not create the real `ParkingSession` in Story 4.1. That would collapse Story 4.1 and 4.2 into one feature and break the intended attendant flow boundary.
- Do not let the mobile app invent the QR payload locally from raw user or vehicle fields.
- Do not assume the final Driver shell from Epic 9 already exists; keep the check-in flow self-contained and injectable into the current public workspace.
- Do not assume booking is required. This story is about direct check-in readiness, not the advance booking flow from Epic 7.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 4 / Story 4.1
- [prd.md](../prd.md) - FR8, FR12, NFR2, NFR8, NFR9
- [tech-design.md](../tech-design.md) - Authentication, sessions module plan, mobile migration guidance
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - Driver context, core user experience, divergent dual-context strategy
- [1-3-manage-license-plates.md](./1-3-manage-license-plates.md)
- [epic-3-retro-2026-03-27.md](./epic-3-retro-2026-03-27.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Added a Driver-facing sessions endpoint that issues short-lived backend-signed check-in tokens for owned vehicles and blocks issuance when a checked-in session already exists.
- Added a dedicated Flutter driver check-in feature that loads registered vehicles, redirects no-vehicle users back to vehicle management, and renders the backend payload as a QR code.
- Wired the current public workspace to expose the check-in flow from both the no-Mapbox fallback shell and the map-based driver shell.
- Focused backend verification passed in Docker with `tests/test_driver_check_in_qr.py`.
- Focused Flutter verification passed locally with `flutter test test/driver_check_in_screen_test.dart`.

### File List

- `_bmad-output/implementation-artifacts/4-1-driver-generates-check-in-qr.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/sessions.py`
- `backend/src/app/schemas/session.py`
- `backend/tests/test_driver_check_in_qr.py`
- `mobile/pubspec.yaml`
- `mobile/lib/main.dart`
- `mobile/lib/src/features/driver_check_in/data/driver_check_in_service.dart`
- `mobile/lib/src/features/driver_check_in/presentation/driver_check_in_screen.dart`
- `mobile/test/driver_check_in_screen_test.dart`

### Change Log

- 2026-03-27: Created Story 4.1 implementation artifact with explicit backend/mobile guardrails and readiness notes derived from Epic 3 learnings.
- 2026-03-27: Implemented backend-issued pre-session check-in QR tokens plus the mobile driver QR flow and focused regression coverage.