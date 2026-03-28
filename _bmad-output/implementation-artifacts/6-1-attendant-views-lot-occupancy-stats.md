# Story 6.1: Attendant Views Lot Occupancy Stats

Status: done

## Story

As an Attendant,
I want to see how many spots are currently taken,
so that I know when we are full.

## Acceptance Criteria

1. Given I am an authenticated attendant assigned to a parking lot, when I open the attendant workspace dashboard, then I see the lot's current occupied count, free count, and total configured capacity.
2. Given check-in, walk-in check-in, checkout finalize, checkout undo, or future timeout actions change lot availability, when the attendant reloads or receives the latest backend-backed state, then the dashboard reflects the authoritative backend counts instead of client-computed estimates.
3. Given the lot has no active capacity configuration yet, when the attendant opens the dashboard, then the UI handles the missing configuration explicitly instead of showing misleading occupancy math.
4. Given active checked-in sessions exist across vehicle types, when I view the dashboard, then I can see the current occupied-session breakdown by vehicle type; because the current lot configuration model only stores a global total capacity, per-vehicle-type free capacity may be deferred until the data model supports it explicitly.

## Implementation Clarifications

- This story is the operational stats surface for attendants, not the broader operator reporting dashboard.
- The authoritative source of occupancy must remain backend-owned lot/session state, reusing the same availability mutation boundaries already established in Epic 4 and Epic 5.
- FR22's vehicle-type requirement should be satisfied in this story by surfacing occupied-session counts grouped by vehicle type. The current schema does not yet support authoritative per-vehicle-type free-capacity configuration, so do not invent inferred free-capacity numbers without explicit backend support.
- If an active-session list is introduced as supporting context for Story 6.3, keep it scoped to the assigned lot and avoid turning this story into a generic session-management console.

## Tasks / Subtasks

- [x] Task 1: Expose attendant-scoped occupancy summary from the backend (AC: 1, 2, 3, 4)
  - [x] Add a read endpoint for the current attendant's assigned lot occupancy summary, preferably in the existing session/attendant operational surface rather than inventing a parallel dashboard API group.
  - [x] Derive `occupied_count` from `total_capacity - current_available` using the latest active `ParkingLotConfig`, and surface explicit "not configured" state when capacity is absent.
  - [x] Group active checked-in sessions by `vehicle_type` so the attendant can see occupied-session distribution without fabricating unsupported free-capacity-by-type numbers.
  - [x] Keep lot authorization strict so attendants can only read stats for their own assigned lot.

- [x] Task 2: Add an attendant-facing stats panel in the mobile app (AC: 1, 2, 3)
  - [x] Extend the existing attendant flow with a prominent occupancy card or header using large typography suitable for the attendant context.
  - [x] Present occupied, free, and total capacity values in a glanceable layout that does not interfere with the core scan workflow.
  - [x] Handle missing configuration and backend errors with explicit, non-misleading UI states.

- [x] Task 3: Add focused regression coverage and verification (AC: 1, 2, 3)
  - [x] Add backend tests for occupancy summary calculation, attendant authorization, and missing-capacity handling.
  - [x] Add Flutter tests for the attendant stats presentation and empty/error states.
  - [x] Verify with backend Docker tests and local `flutter test`.

## Dev Notes

### Story Foundation

- Epic 6 introduces attendant-facing session-management capabilities; this story is the read-only occupancy foundation for that epic.
- PRD FR22 requires attendants to view lot statistics, specifically total capacity and occupied/free slot information.
- Journey 2 in the PRD already describes the attendant starting a shift and seeing lot stats such as `45/60 occupied, 15 free`.

### Domain Constraints To Respect

- Attendant access remains separate-account, exclusive-role authorization; do not reuse the public account capability model here.
- Occupancy values must come from backend-maintained lot/session state, not a Flutter-only counter.
- If the lot is misconfigured or lacks an active `ParkingLotConfig`, the UX must surface that explicitly.

### Architecture Guardrails

- Reuse the existing backend project shape and current operational seams in `backend/src/app/api/v1/sessions.py` and related lot/session models unless a clearly justified dedicated operational module is added in the same style.
- Keep response shapes consistent with current backend conventions and the current mobile `dio` service layer.
- If realtime refresh is added, reuse the existing availability publication contract rather than creating a new bespoke event system for attendants.

### Library / Framework Requirements

- Backend: FastAPI + SQLAlchemy models already used in the parking/session domain.
- Mobile: Flutter feature/service pattern already used by `attendant_check_in`, `operator_lot_management`, and `lot_details`.
- Do not introduce a state-management framework migration or dashboard package just for this story.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/sessions.py` or a same-style attendant operational route module
  - `backend/src/app/models/parking.py`
  - `backend/src/app/models/sessions.py`
  - `backend/src/app/schemas/`
  - `backend/tests/`
- Mobile:
  - `mobile/lib/src/features/attendant_check_in/`
  - `mobile/lib/src/core/`
  - `mobile/test/`

### Testing Requirements

- Backend verification should run through Docker pytest.
- Flutter verification should run with local `flutter test`.
- Tests should explicitly cover authorization and capacity-missing behavior, not only the happy path.

### Implementation Risks To Avoid

- Do not compute occupancy only on the client from stale UI events.
- Do not expose cross-lot or operator-wide reporting data to attendants.
- Do not block the main scan workflow with unnecessary modal confirmations just to view stats.

### Recent Repository Patterns

- Recent stories have used backend-owned contracts first, then thin `dio` service integration in Flutter.
- Current mobile management and lot-detail flows already display occupancy-related information; this story should reuse those formatting patterns where appropriate without collapsing attendant UX into operator UX.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 6 / Story 6.1
- [prd.md](../prd.md) - Journey 2, FR22
- [architecture.md](../architecture.md) - attendant operational constraints, API design principles, backend project shape
- [tech-design.md](../tech-design.md) - API module plan and reports/occupancy direction
- [5-4-en-route-lot-capacity-alert.md](./5-4-en-route-lot-capacity-alert.md) - current backend-owned availability pattern

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Add an attendant-scoped occupancy summary endpoint using existing lot/session data.
- Extend the attendant mobile feature with a high-visibility stats surface that stays compatible with the fast operational UX.
- Cover authorization, missing configuration, and summary calculation with backend and Flutter tests.

### Completion Notes List

- Added a new attendant-scoped backend summary contract that returns total capacity, free count, occupied count, missing-capacity state, and occupied-session breakdown by vehicle type for the assigned lot only.
- Extended the attendant Flutter workspace with an occupancy summary panel, explicit missing-capacity and load-error handling, and summary refresh after check-in, walk-in check-in, checkout finalize, and checkout undo.
- Refactored the attendant screen layout to remain scroll-safe under constrained widget-test viewports and made the checkout preview card internally scrollable to prevent overflow regressions.
- Added focused backend and Flutter coverage for the new occupancy flow, then cleared the broader regression fallout from the new attendant service method across existing widget tests.
- Validation passed with `cd backend && docker compose run --rm pytest`, `cd mobile && flutter test test/attendant_check_in_screen_test.dart test/attendant_check_out_screen_test.dart test/attendant_check_out_finalize_test.dart test/attendant_walk_in_check_in_test.dart`, and `cd mobile && flutter test`.

### File List

- `_bmad-output/implementation-artifacts/6-1-attendant-views-lot-occupancy-stats.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/sessions.py`
- `backend/src/app/schemas/session.py`
- `backend/tests/test_attendant_occupancy_summary.py`
- `backend/tests/test_lot_availability_events.py`
- `mobile/lib/src/features/attendant_check_in/data/attendant_check_in_service.dart`
- `mobile/lib/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart`
- `mobile/test/attendant_check_in_screen_test.dart`
- `mobile/test/attendant_check_out_finalize_test.dart`
- `mobile/test/attendant_check_out_screen_test.dart`
- `mobile/test/attendant_walk_in_check_in_test.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-28: Created Story 6.1 implementation artifact for backend-owned attendant occupancy stats.
- 2026-03-28: Implemented Story 6.1 with an attendant occupancy summary endpoint, mobile occupancy panel, scroll-safe attendant layout updates, and full backend/mobile regression validation.
- 2026-03-28: Epic 6 code review completed with no remaining action items for Story 6.1.
