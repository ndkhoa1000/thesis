# Story 3.1: Configure Lot Details & Capacity

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an Operator,
I want to configure the capacity and details of my lot,
so that the system limits check-ins automatically.

## Acceptance Criteria

1. Given I am authenticated as an Operator with an active lot lease, when I open the operator workspace, then I can see the parking lots currently assigned to me.
2. Given I am an Operator managing an active lot, when I update the lot name, address, description, and maximum capacity, then the backend persists the latest configuration and the mobile workspace reflects the new values.
3. Given a lot already has active parking sessions, when I change `total_capacity`, then `current_available` is recalculated as `total_capacity - active_sessions_count` and never drops below `0`.
4. Given I am configuring a lot, when there is no active lease for that lot, then I cannot update it through the operator workspace.
5. Given I configure lot capacity in this story, when later check-in flows are implemented, then they will have the necessary `current_available` and configuration data to enforce lot capacity limits.

## Implementation Clarifications

- This story reuses the existing `parking_lot`, `parking_lot_config`, `lot_lease`, and `parking_session` tables instead of inventing a temporary operator-ownership shortcut.
- Operator access is limited to `LotLease.status == ACTIVE`, which is the cleanest current representation of a managed lot.
- The latest capacity configuration is stored by inserting a new `ParkingLotConfig` record and returning the newest effective value.
- `current_available` is recalculated immediately from the requested capacity and the count of `CHECKED_IN` sessions.
- Full check-in rejection at capacity remains dependent on Epic 4 because the session/check-in API is still scaffolded today.

## Tasks / Subtasks

- [x] Task 1: Add operator managed-lot backend contracts (AC: 1, 2, 3, 4)
  - [x] Define operator-facing read and update schemas for managed parking lots.
  - [x] Add a route to list active leased lots for the current Operator.
  - [x] Add a route to update lot details and capacity with availability recalculation.

- [x] Task 2: Build the mobile Operator workspace (AC: 1, 2)
  - [x] Add a typed mobile service for listing and updating managed parking lots.
  - [x] Replace the Manager placeholder shell with a real operator lot-management workspace.
  - [x] Add a configuration form for lot details and total capacity.

- [x] Task 3: Add focused regression coverage (AC: 2, 3, 4)
  - [x] Add backend unit tests for active-lease lot listing and capacity recalculation.
  - [x] Add Flutter widget coverage for manager routing and lot configuration updates.
  - [x] Verify backend in Docker and Flutter on both local test runner and connected Android device.

### Review Findings

- [x] [Review][Patch] Route the operator workspace by capability, not only primary role [mobile/lib/main.dart:350]
- [x] [Review][Patch] Filter latest capacity lookup to lot-wide parking-lot config rows [backend/src/app/api/v1/lots.py:86]
- [x] [Review][Patch] Add floor-at-zero regression coverage and align the widget fake with backend capacity clamping [backend/tests/test_operator_lot_management.py:117]

## Dev Notes

### Story Foundation

- Story 1.5 introduced the approved Operator capability on the public account model.
- This story is the first Operator-facing workspace in the app and replaces the previous placeholder branch in `main.dart`.
- The current domain already models leased lot management via `LotLease` and `ParkingLotConfig`, so this story extends that model instead of bypassing it.

### Domain Constraints To Respect

- Only public accounts with approved Operator capability and an active lease may manage a parking lot.
- Capacity changes must account for currently checked-in sessions to avoid negative availability.
- The repository still lacks the Epic 4 check-in endpoints, so this story prepares the enforcement data path rather than the final gate logic itself.

### Suggested File Areas For This Story

- Backend:
  - `backend/src/app/api/v1/lots.py`
  - `backend/src/app/schemas/parking_lot.py`
  - `backend/tests/test_operator_lot_management.py`
- Mobile:
  - `mobile/lib/main.dart`
  - `mobile/lib/src/features/operator_lot_management/`
  - `mobile/test/widget_test.dart`

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 3 / Story 3.1
- [prd.md](../prd.md) - FR27, FR28, EC20
- [tech-design.md](../tech-design.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Added operator-facing lot-management endpoints that list active leased lots and update lot details plus total capacity.
- Reused `ParkingLotConfig` for versioned capacity persistence and recalculated `current_available` from active checked-in sessions.
- Added the first real Operator workspace in the mobile app and removed the previous Manager placeholder route.
- Focused backend verification passed inside Docker with `tests/test_admin_system_management.py` and `tests/test_operator_lot_management.py`.
- Focused Flutter verification passed locally with `flutter test test/widget_test.dart` and the app successfully launched on the connected Android device over ADB.
- Story closed after review fixes for operator routing, lot-wide capacity lookup, and floor-at-zero regression coverage; final hard capacity enforcement still depends on Epic 4 session/check-in endpoints.

### File List

- `_bmad-output/implementation-artifacts/3-1-configure-lot-details-capacity.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/lots.py`
- `backend/src/app/schemas/parking_lot.py`
- `backend/tests/test_operator_lot_management.py`
- `mobile/lib/main.dart`
- `mobile/lib/src/features/operator_lot_management/data/operator_lot_management_service.dart`
- `mobile/lib/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-27: Implemented Story 3.1 backend operator lot-management contracts using active leases and versioned parking-lot configuration records.
- 2026-03-27: Replaced the Manager placeholder with a real mobile Operator workspace for viewing and updating lot details and capacity.
- 2026-03-27: Verified focused backend tests in Docker, Flutter widget tests locally, and Android app launch over ADB; remaining acceptance dependency is the future check-in flow.