# Story 6.3: Force Close/Timeout Session

Status: review

## Story

As an Attendant,
I want to manually end a stuck session,
so that lot occupancy remains accurate.

## Acceptance Criteria

1. Given I am an authenticated attendant assigned to a lot, when I view the active sessions for my lot, then I can identify a session that never completed checkout.
2. Given a checked-in session is confirmed as stuck, when I force-close it with a required reason, then the session is moved to a timeout terminal state, the associated spot/capacity is released exactly once, and the lot occupancy reflects the change.
3. Given a force-close action occurs, when the mutation completes, then the system records an audit trail containing the acting attendant, the affected session, the reason, and the old/new values needed for later review.

## Implementation Clarifications

- This story is the operational timeout correction path for stale sessions. It is not a license to build a full unrestricted session editor.
- Epic 6 covers FR21-FR24, so this story should establish the active-session operational list plus the audit discipline required for attendant corrections.
- The epic language requires the session to be marked `TIMEOUT`. The current codebase only defines `CHECKED_IN` and `CHECKED_OUT`, so implementation must first extend enum/schema/mobile-contract/test coverage for `TIMEOUT`; this is a hard prerequisite, not an optional enhancement.
- This story owns the minimum active-session visibility needed to identify stale sessions. It should reuse Story 6.1 occupancy-query foundations when available, but it does not require Story 6.1 UI delivery to ship first.

## Tasks / Subtasks

- [x] Task 1: Add attendant-scoped active-session visibility for stale-session resolution (AC: 1)
  - [x] Expose a lot-scoped active session list for the current attendant, limited to their assigned lot.
  - [x] Include enough metadata to safely identify stale sessions without overexposing unrelated data.
  - [x] Keep this list aligned with Story 6.1 occupancy data so both views reflect the same backend source of truth.

- [x] Task 2: Implement the backend force-close timeout mutation with audit logging (AC: 2, 3)
  - [x] Before implementing the mutation, extend `SessionStatus` and all dependent schemas/clients to support `TIMEOUT` consistently.
  - [x] Add a dedicated attendant force-close endpoint for stale sessions.
  - [x] Require a human-entered reason and persist an audit trail capturing old/new values and actor identity.
  - [x] Release lot availability atomically and protect against double-release or duplicate timeout transitions.

- [x] Task 3: Extend the mobile attendant experience for administrative timeout resolution (AC: 1, 2, 3)
  - [x] Add an off-peak administrative surface for viewing active sessions and force-closing a stale one.
  - [x] Collect the mandatory reason in a deliberate, explicit form flow rather than the high-speed gate scanner interaction zone.
  - [x] Refresh the attendant stats/session state after success so the lot no longer appears over-occupied.

- [x] Task 4: Add focused regression coverage and verification (AC: 1, 2, 3)
  - [x] Add backend tests for attendant authorization, timeout transition rules, atomic capacity release, and audit-record persistence.
  - [x] Add Flutter tests for the active-session administrative list, required-reason validation, and successful state refresh.
  - [x] Verify with backend Docker tests and local `flutter test`.

## Dev Notes

### Story Foundation

- PRD FR21 and FR22 establish the attendant session-management context; FR23 and FR24 require reasoned edits and audit logging.
- Epic 6 Story 6.3 narrows that general requirement into the operational timeout/force-close path needed to keep occupancy accurate.
- This story should become the operational correction seam that future richer session edits can build on, without over-expanding scope now.

### Domain Constraints To Respect

- Attendants may only see and mutate sessions belonging to their assigned lot.
- Force-close is a high-accountability action and must require a reason.
- Availability release must be atomic and idempotency-safe; a stale session cannot free capacity twice.

### Architecture Guardrails

- Reuse the existing `parking_session`, `ParkingLot.current_available`, and attendant authorization patterns already present in `sessions.py`.
- If implementing `TIMEOUT`, extend `SessionStatus` and all dependent schemas/tests consistently instead of storing an undocumented magic string.
- Use the existing `SessionEdit` audit table or an explicitly justified extension in the same audit style for the mutation record.

### Library / Framework Requirements

- Backend: FastAPI + SQLAlchemy operational session patterns already established in Epic 4.
- Mobile: Flutter feature/service layering already used by `attendant_check_in`.
- Do not introduce a generic admin framework, data grid, or new state-management stack for this story.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/sessions.py`
  - `backend/src/app/models/sessions.py`
  - `backend/src/app/models/enums.py`
  - `backend/src/app/models/parking.py`
  - `backend/src/app/schemas/`
  - `backend/tests/`
- Mobile:
  - `mobile/lib/src/features/attendant_check_in/`
  - `mobile/lib/src/core/`
  - `mobile/test/`

### Testing Requirements

- Backend tests should cover unauthorized access, duplicate-close prevention, timeout status persistence, and availability reconciliation.
- Flutter tests should cover required-reason validation and post-mutation UI refresh.
- Verification should use backend Docker tests and local `flutter test`.

### Implementation Risks To Avoid

- Do not free lot capacity twice when the same stale session is acted on more than once.
- Do not add `TIMEOUT` behavior in only one layer while leaving enums/schemas/clients inconsistent.
- Do not bury the required reason inside a silent or auto-generated fallback.

### Recent Repository Patterns

- The existing attendant flow already distinguishes fast operational gestures from slower corrective actions; force-close belongs in the latter category.
- Recent backend work has concentrated operational mutations inside `sessions.py`, with tests validating mutation boundaries and downstream availability effects.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 6 / Story 6.3
- [prd.md](../prd.md) - Journey 2, FR21, FR22, FR23, FR24
- [architecture.md](../architecture.md) - attendant workflow, API design principles, backend project shape
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - attendant operational vs administrative interaction guidance
- [5-4-en-route-lot-capacity-alert.md](./5-4-en-route-lot-capacity-alert.md) - availability consistency pattern

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Add an attendant-scoped active-session read path and a dedicated force-close timeout mutation with required-reason audit logging.
- Extend session enums/schemas safely if `TIMEOUT` is implemented, and keep occupancy release atomic.
- Add an administrative mobile flow for stale-session resolution plus focused backend/Flutter tests.

### Completion Notes List

- Extended the session domain with `SessionStatus.TIMEOUT` and added attendant-scoped backend contracts for listing active sessions and force-closing a stuck session with a required reason.
- Implemented the timeout mutation in `sessions.py` with lot-scoped attendant authorization, duplicate-transition protection, `SessionEdit` audit logging, atomic availability release, and downstream availability event publication.
- Added a separate attendant administrative flow for stale-session handling from the app bar, keeping timeout correction out of the fast scanner workflow while refreshing Story 6.1 occupancy stats after success.
- Added focused backend and Flutter coverage for active-session visibility, required-reason validation, timeout success, and state refresh.
- Validation passed with `cd backend && docker compose run --rm pytest python -m pytest`, `cd mobile && flutter test test/attendant_timeout_session_test.dart test/attendant_check_in_screen_test.dart test/attendant_check_out_screen_test.dart test/attendant_check_out_finalize_test.dart test/attendant_walk_in_check_in_test.dart test/widget_test.dart`, and `cd mobile && flutter test`.

### File List

- `_bmad-output/implementation-artifacts/6-3-force-close-timeout-session.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/sessions.py`
- `backend/src/app/models/enums.py`
- `backend/src/app/schemas/session.py`
- `backend/tests/test_attendant_force_close_timeout.py`
- `mobile/lib/src/features/attendant_check_in/data/attendant_check_in_service.dart`
- `mobile/lib/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart`
- `mobile/test/attendant_check_in_screen_test.dart`
- `mobile/test/attendant_check_out_finalize_test.dart`
- `mobile/test/attendant_check_out_screen_test.dart`
- `mobile/test/attendant_timeout_session_test.dart`
- `mobile/test/attendant_walk_in_check_in_test.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-28: Created Story 6.3 implementation artifact for attendant timeout handling of stale parking sessions.
- 2026-03-28: Implemented Story 6.3 with attendant active-session visibility, timeout mutation and audit logging, administrative mobile timeout flow, and full backend/mobile regression validation.
