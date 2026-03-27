# Story 2.1: Register New Parking Lot

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Lot Owner,
I want to register a new parking lot,
so that I can offer my property on the platform pending Admin approval.

## Acceptance Criteria

1. Given I am authenticated as a Lot Owner, when I fill out the lot registration form with required details, then a new parking-lot record is created and starts in pending review status.
2. Given I open the Lot Owner workspace after approval of my capability, when I view my submitted parking lots, then I can see each lot and its current review state.
3. Given I am authenticated as an Admin, when I open the parking-lot approvals tab in the Admin dashboard, then I can review pending lot registrations and approve or reject them using the same app-facing workflow.

## Implementation Clarifications

- This story intentionally reuses the existing `parking_lot` table and its `status` field instead of introducing a separate parking-lot application table.
- `PENDING` is the effective pending-approval state for this story and satisfies the Epic 2 requirement for newly registered lots to wait for Admin review before broader use.
- The story stays focused on registration and approval visibility. Post-approval configuration remains in Epic 3.
- Rejection reasons are validated during Admin review for consistency with the dashboard workflow, but no additional persistence migration was introduced for rejected-lot notes in this story.

## Tasks / Subtasks

- [x] Task 1: Complete the backend parking-lot registration contract (AC: 1, 2)
  - [x] Add typed schemas for create/read/review parking-lot payloads.
  - [x] Replace the scaffolded lots route with real list/create/my-lots/admin-review handlers.
  - [x] Enforce Lot Owner capability before allowing public-account lot registration.

- [x] Task 2: Build the Lot Owner parking-lot workspace in Flutter (AC: 1, 2)
  - [x] Replace the Lot Owner placeholder shell with a dedicated parking-lot registration screen.
  - [x] Add a submission form aligned with backend validation for name, address, and coordinates.
  - [x] Show submitted lots and their current approval state in the Lot Owner workspace.

- [x] Task 3: Wire Admin parking-lot approvals end-to-end (AC: 3)
  - [x] Extend the Admin approvals service to load pending parking-lot registrations.
  - [x] Replace the parking-lot placeholder tab with a real review list in the Admin dashboard.
  - [x] Reuse the existing approve/reject interaction pattern for parking-lot review actions.

- [x] Task 4: Verify the registration and review lifecycle (AC: 1, 2, 3)
  - [x] Add focused backend coverage for list/create/review parking-lot behavior.
  - [x] Add focused Flutter widget coverage for the Lot Owner workspace and Admin parking-lot tab.
  - [x] Run targeted backend and Flutter test suites after wiring the new flow.

## Dev Notes

### Story Foundation

- Story 1.4 established the approved Lot Owner capability on the shared public account model.
- Story 2.2 already created the Admin approvals dashboard and reserved a parking-lot tab placeholder.
- This story completes the first real inventory workflow in Epic 2 by connecting those two pieces.

### Domain Constraints To Respect

- Only public accounts with approved Lot Owner capability can create parking-lot registrations.
- Admin review still goes through app-facing flows; no raw-endpoint-only workflow is required for this story.
- The Lot Owner workspace in this story is limited to registration visibility, not full lot operations management.

### Suggested File Areas For This Story

- Backend:
  - `backend/src/app/api/v1/lots.py`
  - `backend/src/app/schemas/parking_lot.py`
  - `backend/tests/test_parking_lots.py`
- Mobile:
  - `mobile/lib/main.dart`
  - `mobile/lib/src/features/parking_lot_registration/`
  - `mobile/lib/src/features/admin_approvals/`
  - `mobile/test/widget_test.dart`

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 2 / Story 2.1
- [prd.md](../prd.md) - FR36, FR41
- [tech-design.md](../tech-design.md)
- [2-2-admin-dashboard-pending-approvals.md](./2-2-admin-dashboard-pending-approvals.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Replaced the scaffolded parking-lot API with real public/admin endpoints for listing approved lots, creating owner lots, listing owner lots, and reviewing parking-lot registrations.
- Reused the existing `ParkingLot.status` field as the approval lifecycle state to avoid unnecessary schema churn while delivering Story 2.1.
- Added a dedicated Flutter Lot Owner workspace for registering new parking lots and viewing their current statuses.
- Upgraded the Admin approvals dashboard so the `Bãi xe` tab now loads and reviews real parking-lot registrations instead of a placeholder.
- Focused verification passed with backend Docker tests (`37 passed` across parking-lot, dependency, lot-owner, and operator approval suites) and Flutter widget tests (`16 passed`).

### File List

- `_bmad-output/implementation-artifacts/2-1-register-new-parking-lot.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/lots.py`
- `backend/src/app/schemas/parking_lot.py`
- `backend/tests/test_parking_lots.py`
- `mobile/lib/main.dart`
- `mobile/lib/src/features/admin_approvals/data/admin_approvals_service.dart`
- `mobile/lib/src/features/admin_approvals/presentation/admin_approvals_screen.dart`
- `mobile/lib/src/features/parking_lot_registration/data/parking_lot_service.dart`
- `mobile/lib/src/features/parking_lot_registration/presentation/parking_lot_registration_screen.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-27: Implemented Story 2.1 end-to-end using the existing parking-lot domain model, added the Lot Owner parking-lot workspace, and wired Admin parking-lot approvals in the mobile dashboard.
- 2026-03-27: Verified the Story 2.1 flow with focused backend Docker tests and Flutter widget tests, then closed the story as done.