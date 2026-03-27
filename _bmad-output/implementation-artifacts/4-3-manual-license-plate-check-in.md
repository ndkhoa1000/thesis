# Story 4.3: Manual License Plate Check-In

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an Attendant,
I want to check in walk-in vehicles using camera capture,
so that I can process drivers without the app while maintaining the 5-second SLA.

## Acceptance Criteria

1. Given I am authenticated with a dedicated Attendant account assigned to a parking lot, when a walk-in vehicle arrives without the driver app or with unusable QR media, then I can switch from the current attendant gate flow into a walk-in check-in path without leaving the attendant workspace.
2. Given I am processing a walk-in vehicle, when I continue the flow, then the app requires camera capture for the vehicle before submission and preserves at least one plate-containing image as the check-in record.
3. Given I submit a valid walk-in check-in payload, when the backend validates the attendant context and lot availability, then the system creates exactly one active `ParkingSession` for the attendant's assigned lot, decrements `current_available` atomically, and marks the session as walk-in (no driver-linked public account required).
4. Given the lot is full or the required walk-in photo evidence is missing or invalid, when I attempt to submit the walk-in check-in, then the system rejects the request with a clear attendant-facing error and does not create partial session state.
5. Given this story is only the walk-in/manual entry path, when it is implemented, then checkout QR generation, payment resolution, OCR automation, and the larger Epic 9 attendant shell remain out of scope.

## Implementation Clarifications

- Story 4.2 already established the attendant gate shell and the atomic QR check-in contract. Story 4.3 should extend that shell with an explicit walk-in/manual path instead of replacing the QR-first flow.
- The PRD requirement for walk-ins is photo-first, not keyboard-first. Do not introduce free-text plate typing at the gate as the primary capture path.
- FR10 requires at least one photo containing the plate; the epic wording also expects a front/back capture sequence for walk-ins. If the current persistence model cannot cleanly store both images yet, the story must still preserve the required plate-containing check-in image and should document any narrowly scoped storage compromise instead of silently dropping photo evidence.
- Walk-in sessions do not have a driver QR from Story 4.1 and do not require a linked `driver_id` or `vehicle_id` to be present.
- Do not fold OCR extraction, checkout QR generation, or payment handling into this story.

## Tasks / Subtasks

- [x] Task 1: Add walk-in attendant check-in backend contract (AC: 2, 3, 4)
  - [x] Extend the sessions API with an Attendant-facing walk-in check-in endpoint that accepts vehicle type plus required image evidence and scopes the operation to the attendant's assigned lot.
  - [x] Create the `ParkingSession` atomically while updating lot availability in the same transaction, without requiring a linked driver account.
  - [x] Reject full-lot, missing-photo, malformed-upload, or unauthorized submissions without creating partial session state.

- [x] Task 2: Add walk-in capture flow to the existing attendant mobile workspace (AC: 1, 2, 4, 5)
  - [x] Extend the current attendant gate screen with a clear walk-in/manual entry action that keeps the QR-first workflow intact.
  - [x] Add a mobile service and presentation flow for capturing the required vehicle images, selecting vehicle type, and submitting the walk-in check-in request.
  - [x] Keep the gate UI camera-first and large-target; do not add checkout, payment, or OCR automation controls in this story.

- [x] Task 3: Add focused regression coverage for walk-in sessions (AC: 2, 3, 4)
  - [x] Add backend tests for successful walk-in session creation, required-photo rejection, lot-full rejection, and attendant-only authorization.
  - [x] Add Flutter widget coverage for entering the walk-in flow, submitting a successful walk-in check-in, and surfacing backend validation failures.
  - [x] Verify backend in Docker and Flutter locally after wiring the flow.

## Dev Notes

### Story Foundation

- Story 3.3 already provisions dedicated `ATTENDANT` credentials tied to a single `Attendant(user_id, parking_lot_id)` profile.
- Story 4.1 created the driver pre-session QR contract; Story 4.2 consumed that token and created the first real `ParkingSession` through `POST /sessions/attendant-check-in`.
- The current attendant mobile experience now has a scanner-first dark gate UI in `mobile/lib/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart` routed from `mobile/lib/main.dart`.
- The backend `ParkingSession` model already supports walk-in-shaped records because `driver_id` is nullable and `checkin_image` exists, but there is no dedicated walk-in upload/session endpoint yet.
- The current repo does not show an implemented Cloudinary upload service or an existing mobile image-capture dependency, so this story must add the minimum camera/upload path needed for walk-in check-in.

### Domain Constraints To Respect

- Attendant accounts remain separate sessions and may only create sessions for `Attendant.parking_lot_id`.
- Walk-in check-in must still obey lot capacity and atomic session plus availability updates from NFR15.
- At least one image containing the plate is mandatory for walk-ins. Do not permit a no-photo walk-in success path.
- Because walk-in drivers do not use the app, `ParkingSession.driver_id` may remain null for this story.
- Do not repurpose Story 4.1 QR tokens, checkout state transitions, or payment records for walk-in entry.

### Architecture Guardrails

- Keep backend implementation inside `backend/src/app/api/v1/sessions.py` and related schema modules; do not introduce a parallel temporary route family for walk-ins.
- Follow the backend-owned media rule: mobile captures files, FastAPI validates them, and any storage integration remains server-side.
- Reuse the existing attendant authorization helpers and lot lookup pattern introduced in Story 4.2.
- Do not misuse `checkout_image` as a second check-in evidence slot. If additional persistence is truly required beyond `checkin_image`, make the smallest schema change necessary and keep it narrowly scoped to walk-in evidence.
- Keep the mobile walk-in flow injectable/testable from the current attendant route in `mobile/lib/main.dart`, without assuming the later Epic 9 shell.

### Library / Framework Requirements

- Flutter currently has `mobile_scanner` for QR but no image-capture package configured. Use a standard Flutter image capture package such as `image_picker` if needed for this story's camera flow.
- Continue using FastAPI route dependencies and async SQLAlchemy transaction patterns already used in Stories 4.1 and 4.2.
- Any media upload contract should use multipart submission through the backend rather than direct client-side storage access.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/sessions.py`
  - `backend/src/app/schemas/session.py`
  - `backend/src/app/models/sessions.py`
  - `backend/tests/test_walk_in_check_in.py` (preferred focused suite)
- Mobile:
  - `mobile/lib/main.dart`
  - `mobile/lib/src/features/attendant_check_in/`
  - `mobile/pubspec.yaml`
  - `mobile/test/` focused attendant walk-in widget test file

### Testing Requirements

- Backend verification should run through the Docker pytest service using the repo convention for targeted suites.
- Flutter verification should run with local `flutter test`.
- Android/manual camera-permission smoke validation remains user-owned unless explicitly requested.

### Implementation Risks To Avoid

- Do not collapse this story into OCR automation, checkout flows, or payment handling.
- Do not add keyboard-heavy manual plate typing as the primary gate interaction.
- Do not create a walk-in session without required image evidence or without atomically updating `current_available`.
- Do not break the QR-first attendant flow implemented in Story 4.2 while adding walk-in support.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 4 / Story 4.3
- [prd.md](../prd.md) - FR10, FR11, FR12, FR16, FR47, NFR2, NFR15, EC5, EC6
- [tech-design.md](../tech-design.md) - backend-owned media uploads, sessions module plan, transactional session updates
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - High-Speed Universal Attendant Flow, conditional capture flow, dark-mode gate UI
- [4-2-attendant-scans-qr-for-check-in.md](./4-2-attendant-scans-qr-for-check-in.md)
- [3-3-create-attendant-accounts.md](./3-3-create-attendant-accounts.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Story created from Epic 4 planning, PRD walk-in check-in requirements, current tech design, attendant UX gate-flow guidance, and the implementation baseline established by Story 4.2.
- Key guardrail: walk-in check-in must remain attendant-only, camera-first, and atomic with lot-capacity updates, while preserving at least one plate-containing image through the backend-owned upload path.
- Added `POST /sessions/attendant-walk-in-check-in` with attendant-only authorization, multipart image validation, local backend-owned image persistence, atomic availability updates, and walk-in `ParkingSession` creation without a linked driver.
- Extended the existing attendant gate screen with a QR-preserving walk-in mode, vehicle type selection, camera capture hooks, and backend-driven success or failure feedback for walk-in entry.
- Validation completed with focused backend Docker tests and focused Flutter widget tests covering both existing QR and new walk-in attendant flows.

### File List

- `_bmad-output/implementation-artifacts/4-3-manual-license-plate-check-in.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/sessions.py`
- `backend/tests/test_walk_in_check_in.py`
- `mobile/lib/src/features/attendant_check_in/data/attendant_check_in_service.dart`
- `mobile/lib/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart`
- `mobile/pubspec.yaml`
- `mobile/test/attendant_check_in_screen_test.dart`
- `mobile/test/attendant_walk_in_check_in_test.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-27: Created Story 4.3 implementation artifact with walk-in photo-capture guardrails, atomic session requirements, and current repo media constraints.
- 2026-03-27: Implemented attendant walk-in check-in backend and mobile flow, added focused regression coverage, and validated the story end-to-end.