# Story 4.4: Driver Generates Check-Out QR

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Driver,
I want to view my active parking session and generate a check-out QR,
so that I can leave the lot without extra gate friction.

## Acceptance Criteria

1. Given I am authenticated as a public account with Driver capability and I have exactly one active `ParkingSession`, when I open the driver parking flow, then I can see a dedicated active-session screen instead of the check-in-only QR flow.
2. Given I have an active parking session, when the active-session screen loads, then I see the session's key details including the parking lot context, my vehicle license plate, elapsed parking time, and an estimated cost preview suitable for confirming I am about to leave.
3. Given I have an active parking session, when I request my gate code, then the app displays a backend-issued check-out QR that represents the same driver QR identity now resolved in `CHECKOUT` state.
4. Given I do not have an active parking session, when I open the same driver parking flow, then the existing Story 4.1 check-in QR experience remains available without checkout-only UI leaking into the idle state.
5. Given this story only covers driver-side active-session visibility and QR generation, when it is implemented, then attendant checkout scanning, final fee computation, payment recording, and session closure remain out of scope for Stories 4.5 and 4.6.

## Implementation Clarifications

- Story 4.4 is the driver-side continuation of the QR state machine introduced in Story 4.1 and activated by Story 4.2. The driver still owns one QR identity; the backend decides whether it is currently `CHECKIN` or `CHECKOUT`.
- The check-out QR must be backend-issued and derived from the active session. Do not have Flutter infer checkout state or generate raw QR payloads on-device.
- The estimated cost shown in this story is a preview for the driver. Final fee authority remains with the backend checkout flow in Story 4.5 when the attendant scans the code.
- This story should reuse the existing driver parking entry point currently wired to `DriverCheckInScreen` from `mobile/lib/main.dart`, but it should not assume the future Epic 9 driver shell already exists.
- If the backend lacks an active-session read contract, add the smallest focused session endpoint needed for this story rather than overbuilding a full history or dashboard API.
- Walk-in session checkout, NFC fallback, payment capture, and session completion are not part of this story.

## Tasks / Subtasks

- [x] Task 1: Add driver active-session and check-out QR backend contract (AC: 1, 2, 3, 4)
  - [x] Add a driver-authenticated session read path that returns the current active session summary needed by the mobile UI, including timing and a backend-owned estimated cost preview.
  - [x] Add a backend-issued check-out QR/token contract for the driver's current active session, keeping the QR state-machine logic server-side.
  - [x] Reject requests when no active session exists or when the current account lacks driver capability, without breaking the Story 4.1 check-in token contract.

- [x] Task 2: Extend the driver mobile flow for active-session checkout readiness (AC: 1, 2, 3, 4, 5)
  - [x] Update the current driver parking screen so it conditionally renders either the idle check-in QR flow or the active-session checkout flow based on backend state.
  - [x] Present the active-session summary with light-theme, spacious driver UI patterns and keep the primary QR action anchored to the bottom thumb-zone.
  - [x] Keep the screen focused on showing active-session context and the check-out QR only; do not add attendant, payment, or final-checkout controls in this story.

- [x] Task 3: Add focused regression coverage (AC: 1, 2, 3, 4)
  - [x] Add backend tests for active-session lookup, no-active-session handling, and checkout-token issuance tied to the active session.
  - [x] Add Flutter widget coverage for the active-session rendering path, checkout QR display, and the fallback to the existing check-in state when no session is active.
  - [x] Verify backend in Docker and Flutter locally after wiring the flow.

### Review Findings

- [x] [Review][Patch] Duplicate active sessions are silently masked instead of rejected [backend/src/app/api/v1/sessions.py:138]
- [x] [Review][Patch] Mobile collapses every active-session 404 into "no active session" [mobile/lib/src/features/driver_check_in/data/driver_check_in_service.dart:115]
- [x] [Review][Patch] Idle check-in UI can remain stale when a session becomes active during QR generation [mobile/lib/src/features/driver_check_in/presentation/driver_check_in_screen.dart:76]
- [x] [Review][Patch] Checkout UI can remain stale when the active session disappears before QR generation [mobile/lib/src/features/driver_check_in/presentation/driver_check_in_screen.dart:124]
- [x] [Review][Patch] Estimated cost preview can use an inapplicable pricing rule and misrepresent non-HOURLY modes [backend/src/app/api/v1/sessions.py:151]
- [x] [Review][Patch] Check-out primary action is not anchored to a fixed bottom thumb-zone action area [mobile/lib/src/features/driver_check_in/presentation/driver_check_in_screen.dart:205]

## Dev Notes

### Story Foundation

- Story 4.1 currently exposes `POST /sessions/driver-check-in-token` and the mobile `DriverCheckInScreen`, but that flow assumes the driver is idle and does not surface any active session.
- Story 4.2 creates the first real `ParkingSession` for app-driver QR check-in, and Story 4.3 extends attendant-side entry with walk-ins. Those stories mean the backend can now have an active session that should flip the driver's QR into `CHECKOUT` state.
- The architecture document explicitly defines the driver QR as a state machine: no active session means `CHECKIN`; an active session means `CHECKOUT`; once the session ends, the QR returns to `CHECKIN` behavior.
- The current mobile route still opens a check-in-focused driver screen from `mobile/lib/main.dart`, so this story must evolve that flow rather than creating a disconnected temporary route.

### Domain Constraints To Respect

- Public accounts remain the driver-authenticated surface here; do not route this flow through Attendant or Admin auth paths.
- The driver may only view and generate a checkout QR for their own currently active session.
- The backend must remain the source of truth for active-session existence, elapsed time, and estimated price preview. Do not duplicate pricing logic in Flutter.
- A driver without an active session must continue to see the Story 4.1 check-in experience.
- This story must not mark the session as checked out, increment lot availability, or create payment records.

### Architecture Guardrails

- Keep backend implementation inside `backend/src/app/api/v1/sessions.py` and related session schemas; do not create a temporary parallel route family for driver checkout preview.
- Reuse the existing driver resolution helper pattern from Story 4.1 and active-session semantics from Stories 4.2 and 4.3.
- If estimated pricing is needed, prefer a focused backend helper or service that consumes the active lot pricing configuration rather than embedding provisional math in the mobile client.
- Preserve Story 4.1 behavior for idle drivers. The active-session branch should be additive, not a rewrite that breaks check-in token generation.
- Keep the driver mobile implementation self-contained within the current driver parking feature and main routing branch without assuming Epic 9 shell infrastructure.

### Library / Framework Requirements

- Continue using `qr_flutter` for rendering the driver QR unless there is a proven compatibility issue.
- Continue using FastAPI route dependencies and async SQLAlchemy queries for session ownership checks.
- Do not add payment SDKs, realtime dependencies, or attendant-scanner packages for this story.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/sessions.py`
  - `backend/src/app/schemas/session.py`
  - `backend/src/app/models/sessions.py`
  - `backend/tests/test_driver_check_out_qr.py` (preferred focused suite)
- Mobile:
  - `mobile/lib/main.dart`
  - `mobile/lib/src/features/driver_check_in/`
  - `mobile/test/driver_check_in_screen_test.dart`

### Testing Requirements

- Backend verification should run through the Docker pytest service using the repo convention for targeted suites.
- Flutter verification should run with local `flutter test`.
- Manual device validation of QR readability remains user-owned unless explicitly requested.

### Implementation Risks To Avoid

- Do not let Flutter guess whether the QR is a check-in or check-out token from local heuristics alone.
- Do not leak final-fee promises into this story; the UI should clearly present the amount as an estimate until Story 4.5 completes attendant-side fee calculation.
- Do not break the no-active-session path that already powers Story 4.1.
- Do not mark sessions completed, update lot availability, or create payments in this story.
- Do not pull attendant checkout scanning, swipe-to-resolve payment UX, or walk-in exit flows into Story 4.4.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 4 / Story 4.4
- [prd.md](../prd.md) - FR12, FR13, FR15, FR16, NFR2, NFR15, EC7, EC8, EC10
- [architecture.md](../architecture.md) - driver QR state machine, check-out flow
- [tech-design.md](../tech-design.md) - transactional session handling, sessions module plan, backend-owned pricing logic
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - Divergent Dual-Context Direction, driver light-theme/thumb-zone guidance
- [4-1-driver-generates-check-in-qr.md](./4-1-driver-generates-check-in-qr.md)
- [4-2-attendant-scans-qr-for-check-in.md](./4-2-attendant-scans-qr-for-check-in.md)
- [4-3-manual-license-plate-check-in.md](./4-3-manual-license-plate-check-in.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Story created from Epic 4 planning, PRD checkout/state-machine requirements, architecture QR-state guidance, current tech design, and the implementation baseline established by Stories 4.1 through 4.3.
- Key guardrail: Story 4.4 is driver-side only and must keep checkout-state resolution, active-session ownership, and estimated pricing on the backend while preserving the existing idle check-in experience.
- Added `GET /sessions/driver-active-session` and `POST /sessions/driver-check-out-token`, keeping QR state resolution server-side and deriving the estimated cost preview from the lot's latest pricing rule.
- Extended the existing driver parking screen to branch between idle check-in and active-session checkout states, show the lot/session summary, and render a backend-issued check-out QR on demand.
- Added focused backend and Flutter coverage for active-session lookup, no-active-session fallback, and checkout QR rendering.
- Validated Story 4.4 with the full backend test suite (`119 passed`) and the full Flutter test suite (`41 passed`).
- Addressed all review patch findings: duplicate active-session detection, safer 404 handling, state refresh on session-race transitions, pricing-rule selection, pricing-mode labeling, and fixed thumb-zone checkout action placement.

### File List

- `_bmad-output/implementation-artifacts/4-4-driver-generates-check-out-qr.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/sessions.py`
- `backend/src/app/schemas/session.py`
- `backend/tests/test_driver_check_out_qr.py`
- `mobile/lib/src/features/driver_check_in/data/driver_check_in_service.dart`
- `mobile/lib/src/features/driver_check_in/presentation/driver_check_in_screen.dart`
- `mobile/test/driver_check_in_screen_test.dart`

### Change Log

- 2026-03-27: Created Story 4.4 implementation artifact with driver checkout QR state-machine guardrails, active-session preview scope, and focused backend/mobile integration guidance.
- 2026-03-27: Implemented driver active-session checkout preview, backend-issued check-out QR contract, regression coverage, and full validation for Story 4.4.
- 2026-03-28: Applied code-review fixes, revalidated full backend and Flutter suites, and closed Story 4.4 as done.