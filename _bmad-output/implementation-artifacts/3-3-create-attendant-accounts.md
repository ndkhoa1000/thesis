# Story 3.3: Create Attendant Accounts

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an Operator,
I want to create and provision dedicated Attendant accounts for my lot staff,
so that attendants can process check-ins and check-outs using separate credentials.

## Acceptance Criteria

1. Given I am authenticated as an Operator with an active lot lease, when I open attendant management for a managed lot, then I can view the currently active attendant accounts assigned to that lot.
2. Given I am managing a leased lot, when I create a new attendant account with dedicated credentials, then the backend provisions a separate `ATTENDANT` login identity linked to that lot.
3. Given an attendant account has been provisioned, when that user logs in, then the session remains an Attendant-only account rather than switching from a public Driver/Operator session.
4. Given I no longer want an attendant to work at my lot, when I remove that attendant from the operator workspace, then the credential is deactivated and the attendant no longer appears in the active roster for that lot.
5. Given I do not manage a lot through an active lease, when I try to list, create, or remove attendants for that lot, then the operator contract rejects the request.

## Implementation Clarifications

- This story extends the existing Story 3.1 and 3.2 operator workspace instead of introducing a new management shell.
- Dedicated attendant credentials are provisioned as separate `User(role=ATTENDANT)` identities plus `Attendant(user_id, parking_lot_id)` rows.
- Removing an attendant from the active roster deactivates the credential instead of deleting the historical row, preserving future compatibility with session audit references.
- The current schema supports one active lot assignment per attendant account through `Attendant.parking_lot_id`; broader multi-lot assignment remains future model work.

## Tasks / Subtasks

- [x] Task 1: Extend operator backend attendant management contracts (AC: 1, 2, 4, 5)
  - [x] Add operator-facing attendant read/create schemas.
  - [x] Add list/create/remove endpoints scoped to operator-managed lots with active leases.
  - [x] Provision dedicated attendant credentials and deactivate them on removal.

- [x] Task 2: Extend the mobile Operator workspace (AC: 1, 2, 4)
  - [x] Add a per-lot attendant management action in the Operator workspace.
  - [x] Show the active attendant roster for each lot in a dedicated management sheet.
  - [x] Add a separate create-attendant form flow using dedicated credentials.

- [x] Task 3: Add focused regression coverage (AC: 2, 3, 4, 5)
  - [x] Add backend tests for list/create/remove attendant management flows.
  - [x] Add Flutter widget coverage for creating and removing attendants from the operator workspace.
  - [x] Verify backend in Docker and Flutter locally after wiring the new flow.

## Dev Notes

### Story Foundation

- Stories 3.1 and 3.2 already established the operator-managed-lot contract and workspace shell that this story extends.
- The existing auth flow already supports separate `ATTENDANT` role sessions, so this story focuses on provisioning and lot-scoped management.
- Later attendant operational stories can consume the dedicated credentials created here without changing the public-account capability model.

### Domain Constraints To Respect

- Only Operators with an active lease on a lot may list, create, or deactivate attendants for that lot.
- Attendant identities remain separate credentials, outside the public Driver/LotOwner/Operator capability flow.
- Removal currently means deactivation of the dedicated credential and exclusion from the active lot roster.

### Suggested File Areas For This Story

- Backend:
  - `backend/src/app/api/v1/lots.py`
  - `backend/src/app/schemas/parking_lot.py`
  - `backend/src/app/schemas/user.py`
  - `backend/tests/test_operator_attendant_management.py`
- Mobile:
  - `mobile/lib/src/features/operator_lot_management/data/operator_lot_management_service.dart`
  - `mobile/lib/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart`
  - `mobile/test/widget_test.dart`

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 3 / Story 3.3
- [prd.md](../prd.md) - FR33, FR34, FR35, FR47
- [tech-design.md](../tech-design.md)
- [3-2-set-operating-hours-pricing-rules.md](./3-2-set-operating-hours-pricing-rules.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Added lot-scoped operator endpoints to list, create, and deactivate attendant accounts for lots managed through active leases.
- Provisioned dedicated `ATTENDANT` credentials using separate `User` identities and the existing `Attendant` domain table.
- Extended the mobile operator workspace with per-lot attendant management and a dedicated create-attendant credential form.
- Focused backend verification passed in Docker with `tests/test_operator_lot_management.py` and `tests/test_operator_attendant_management.py`.
- Focused Flutter verification passed locally with `flutter test test/widget_test.dart`.
- Android smoke validation was not completed in this pass because the terminal tool calls for device checks and launch were skipped.

### File List

- `_bmad-output/implementation-artifacts/3-3-create-attendant-accounts.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/lots.py`
- `backend/src/app/schemas/parking_lot.py`
- `backend/src/app/schemas/user.py`
- `backend/tests/test_operator_attendant_management.py`
- `mobile/lib/src/features/operator_lot_management/data/operator_lot_management_service.dart`
- `mobile/lib/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-27: Implemented operator-managed attendant provisioning and active-roster management for leased lots.
- 2026-03-27: Extended the operator workspace with attendant roster and dedicated credential creation flow.
- 2026-03-27: Verified Story 3.3 with focused backend Docker tests and local Flutter widget tests.