# Story 2.3: Admin System Management & Lot Suspension

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an Admin,
I want to manage users and suspend lots,
so that I can maintain a safe ecosystem.

## Acceptance Criteria

1. Given I am authenticated as an Admin, when I open the admin workspace, then I can see and manage existing user accounts without using raw backend endpoints.
2. Given I am an Admin viewing a managed account, when I deactivate or reactivate that account, then the backend persists the activation state and the mobile workspace reflects the new status.
3. Given I am an Admin viewing an approved parking lot, when I suspend it, then the lot moves to a suspended state that is hidden from public approved-lot queries.
4. Given I am an Admin viewing a suspended parking lot, when I reopen it, then the lot returns to the approved inventory and becomes publicly visible again.
5. Given I work in the admin workspace, when I switch between approvals, users, and parking-lot operations, then the experience stays in one coherent dashboard instead of fragmented one-off screens.

## Implementation Clarifications

- This story extends the existing Admin approvals workspace introduced in Story 2.2 instead of creating a second Admin shell.
- User moderation reuses the existing `User.is_active` field rather than introducing a new account-state model.
- Parking-lot suspension reuses `ParkingLot.status` transitions between `APPROVED` and `CLOSED` rather than adding new persistence or migrations.
- Public lot visibility already depends on the approved-lot query, so suspended lots are hidden by moving them out of the `APPROVED` state.
- Session and booking APIs are still scaffold-only in the current codebase, so the enforceable part of suspension in this story is status control plus removal from public approved-lot inventory.

## Tasks / Subtasks

- [x] Task 1: Add Admin user-management backend contracts (AC: 1, 2)
  - [x] Define Admin-facing user read and activation-update schemas.
  - [x] Add Admin list/search and activation toggle routes.
  - [x] Prevent Admins from deactivating the current signed-in Admin account.

- [x] Task 2: Add Admin parking-lot moderation backend contracts (AC: 3, 4)
  - [x] Define a strict parking-lot status update schema.
  - [x] Add an Admin route to suspend approved lots and reopen suspended lots.
  - [x] Preserve the existing approved-only public listing behavior so suspended lots disappear from map/list queries.

- [x] Task 3: Expand the mobile Admin workspace (AC: 1, 2, 5)
  - [x] Rebuild the Admin data service with managed-user and managed-lot support.
  - [x] Extend the Admin screen to include tabs for user management and lot operations.
  - [x] Keep approval review flows available in the same unified Admin workspace.

- [x] Task 4: Add focused regression coverage (AC: 2, 3, 4, 5)
  - [x] Add backend tests for Admin user activation and parking-lot suspend/reopen flows.
  - [x] Add Flutter widget coverage for user activation and parking-lot suspension/reopen actions.
  - [x] Run focused verification where the local environment supports it.

## Dev Notes

### Story Foundation

- This story follows Story 2.2 and broadens the Admin dashboard from pure approvals into operational system management.
- It deliberately reuses the current backend model instead of widening scope with new moderation tables or migrations.

### Domain Constraints To Respect

- Admin management must stay behind existing Admin authorization.
- Suspended lots should not appear in public approved-lot inventory.
- The current repository does not yet implement full session/check-in creation endpoints, so lot suspension cannot enforce check-in rejection beyond inventory visibility in this story.

### Suggested File Areas For This Story

- Backend:
  - `backend/src/app/api/v1/users.py`
  - `backend/src/app/api/v1/lots.py`
  - `backend/src/app/schemas/user.py`
  - `backend/src/app/schemas/parking_lot.py`
  - `backend/tests`
- Mobile:
  - `mobile/lib/src/features/admin_approvals/`
  - `mobile/test/widget_test.dart`

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 2 / Story 2.3
- [prd.md](../prd.md)
- [tech-design.md](../tech-design.md)
- [2-2-admin-dashboard-pending-approvals.md](./2-2-admin-dashboard-pending-approvals.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Added Admin user-management backend contracts for listing/searching users and toggling activation with self-deactivation protection.
- Added Admin parking-lot moderation backend contracts that allow `APPROVED -> CLOSED` suspension and `CLOSED -> APPROVED` reopening.
- Rebuilt the mobile Admin service after a failed patch merge and expanded the Admin screen into a five-tab operational workspace.
- Added Flutter widget coverage for the new user activation and parking-lot suspension flows.
- Focused Flutter verification passed locally with `flutter test test/widget_test.dart`.
- Focused backend pytest could not run to completion in the current environment because `backend/tests/conftest.py` depends on the missing package `faker`.

### File List

- `_bmad-output/implementation-artifacts/2-3-admin-system-management-lot-suspension.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/users.py`
- `backend/src/app/api/v1/lots.py`
- `backend/src/app/schemas/user.py`
- `backend/src/app/schemas/parking_lot.py`
- `backend/tests/test_admin_system_management.py`
- `mobile/lib/src/features/admin_approvals/data/admin_approvals_service.dart`
- `mobile/lib/src/features/admin_approvals/presentation/admin_approvals_screen.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-27: Implemented Story 2.3 backend Admin user-management and parking-lot suspension APIs plus focused backend test coverage.
- 2026-03-27: Expanded the mobile Admin workspace to include user activation management and parking-lot suspension/reopen controls in the same dashboard.
- 2026-03-27: Verified focused Flutter widget coverage successfully; backend pytest remains blocked in this environment until `faker` is installed.