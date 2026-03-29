# Story 9.4: Management Workspace Shells

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an Operator or Lot Owner,
I want a management workspace organized by function,
so that I can navigate between lot management, financial, and operational tasks clearly.

## Acceptance Criteria

1. Given I am authenticated as an Operator, when the workspace loads, then a management shell uses tabs `Bãi xe`, `Nhân viên`, `Doanh thu`.
2. Given I am in the Operator shell, when I switch tabs, then existing Operator screens integrate as the correct tab content and unfinished tabs show coherent `EmptyView` placeholders.
3. Given I am authenticated as a Lot Owner, when the workspace loads, then a management shell uses tabs `Bãi của tôi`, `Hợp đồng`, `Cá nhân`.
4. Given I am in the Lot Owner shell, when I open `Bãi của tôi`, then the existing `ParkingLotRegistrationScreen` is reachable without functional changes.
5. Given the other Lot Owner tabs are not fully implemented yet, when the shell renders, then those tabs use honest placeholders until Epic 8 and related stories are integrated.
6. Given either workspace renders, when the shell is displayed, then the light theme applies consistently and only shell structure changes are introduced.

## Implementation Clarifications

- This story should absorb the current public multi-capability bridge into durable workspace shells for Operator and Lot Owner.
- Existing feature slices already cover much of the Operator and Lot Owner business logic. Prefer wrapping current screens over splitting them prematurely.
- Use `EmptyView` only for truly missing sections. If a real surface exists, route to it rather than replacing it with placeholder content.
- No backend authorization or lease/revenue logic changes belong here.

## Tasks / Subtasks

- [x] Task 1: Create the Operator shell (AC: 1, 2, 6)
  - [x] Introduce an Operator shell with tabs `Bãi xe`, `Nhân viên`, `Doanh thu`.
  - [x] Mount the current `OperatorLotManagementScreen` inside the appropriate tab path without changing its service contract.
  - [x] Route current and future operator revenue and staffing surfaces into durable shell tabs, using `EmptyView` only where the repo truly lacks content.

- [x] Task 2: Create the Lot Owner shell (AC: 3, 4, 5, 6)
  - [x] Introduce a Lot Owner shell with tabs `Bãi của tôi`, `Hợp đồng`, `Cá nhân`.
  - [x] Mount `ParkingLotRegistrationScreen` under `Bãi của tôi`.
  - [x] Provide honest placeholder content for `Hợp đồng` and `Cá nhân` until their final feature surfaces are integrated.

- [x] Task 3: Replace the temporary public workspace switch path (AC: 1, 2, 3, 4)
  - [x] Remove the current `_PublicWorkspaceSwitcherScreen` navigation dependency from the authenticated public-account entry path.
  - [x] Ensure public users with both lot-owner and operator capabilities can deliberately enter the correct shell through route-aware navigation.
  - [x] Keep current sign-out and service injection behavior intact.

- [x] Task 4: Add regression coverage (AC: 1, 2, 3, 4, 5, 6)
  - [x] Add Flutter tests for Operator and Lot Owner shell landing, tab switching, and placeholder rendering.
  - [x] Confirm current operator lot-management and lot-owner registration flows still work after shell wrapping.
  - [x] Verify with `cd mobile && flutter test`.

## Dev Notes

### Story Foundation

- Epic 9 specifically calls out Stories 9.1 and 9.4 as the place to absorb the temporary public workspace switch bridge into durable role-aware shells.
- Operator and Lot Owner business flows from Epics 2, 3, 6, and 8 are ready to be wrapped rather than rewritten.

### Current Codebase Signals

- Public authenticated users currently reach either `OperatorLotManagementScreen`, `ParkingLotRegistrationScreen`, or `_PublicWorkspaceSwitcherScreen` directly from `AuthenticatedHome`.
- `OperatorLotManagementScreen` already contains staffing and revenue-related entry points, which makes it the natural base tab for the Operator shell.
- `ParkingLotRegistrationScreen` already hosts lot-owner lot registration and owner revenue entry paths, but not a formal shell.

### Architecture Guardrails

- Preserve the public-account capability model from the architecture: one shared user identity may accumulate Lot Owner and Operator capabilities over time.
- Shell code must not duplicate lease, revenue, or staffing truth that already lives in backend-driven feature modules.
- Keep all management shells in the light-theme family defined by Story 9.1.

### File Structure Requirements

- Expected mobile touch points:
  - `mobile/lib/src/app/app_router.dart`
  - `mobile/lib/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart`
  - `mobile/lib/src/features/operator_revenue_dashboard/presentation/operator_revenue_dashboard_sheet.dart`
  - `mobile/lib/src/features/parking_lot_registration/presentation/parking_lot_registration_screen.dart`
  - `mobile/lib/src/features/management_workspace/` (new shell folder or split operator/owner shell folders)
  - shared components from Story 9.6
  - `mobile/test/`

### Testing Requirements

- Test both single-capability and multi-capability public accounts.
- Test shell tab labels, tab switching, and preservation of existing feature flows.
- Assert placeholder tabs are honest and do not imply implemented functionality that the repo does not yet have.

### Implementation Risks To Avoid

- Do not keep the temporary workspace switch bridge as the long-term public-account UX.
- Do not split stable feature screens into unnecessary micro-widgets if simple shell wrapping is enough.
- Do not break owner revenue, lease creation, operator staffing, or operator revenue entry points while reorganizing tabs.
- Do not treat `EmptyView` as a substitute for existing working screens.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 9 / Story 9.4
- [epics-distillate.md](../planning-artifacts/epics-distillate.md) - Management shells summary
- [architecture.md](../architecture.md) - public capability model and mobile stack
- [sprint-change-proposal-2026-03-27-ux-shell.md](../planning-artifacts/sprint-change-proposal-2026-03-27-ux-shell.md) - Story 9.4 bridge absorption note
- [3-1-configure-lot-details-capacity.md](./3-1-configure-lot-details-capacity.md)
- [3-3-create-attendant-accounts.md](./3-3-create-attendant-accounts.md)
- [8-1-create-lease-contract.md](./8-1-create-lease-contract.md)
- [8-2-owner-revenue-dashboard.md](./8-2-owner-revenue-dashboard.md)
- [8-3-operator-revenue-dashboard.md](./8-3-operator-revenue-dashboard.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Introduce light-theme Operator and Lot Owner shells with durable tab structure.
- Rehome current public workspace reachability out of the temporary switch screen and into route-aware shells.
- Validate shell navigation while preserving operator and lot-owner business flows.

### Completion Notes List

- Story context anchored on the current direct public workspace entry logic in `main.dart` and Epic 9's explicit requirement to absorb temporary workspace switching.
- Added guardrails to prevent shell work from duplicating backend-driven lease, revenue, and staffing logic.
- Added durable `OperatorWorkspaceShell` and `LotOwnerWorkspaceShell` tabs while keeping the existing business screens intact as embedded tab roots instead of rewriting stable feature logic.
- Updated route authorization and driver profile actions so multi-capability public accounts can deliberately enter Operator or Lot Owner shells without reviving a temporary workspace switch bridge.
- Extended widget coverage for management shell landing, placeholder rendering, and cross-workspace navigation, then validated with `flutter test test/widget_test.dart -r expanded` and the full `flutter test` suite.

### File List

- `_bmad-output/implementation-artifacts/9-4-management-workspace-shells.md`
- `mobile/lib/src/app/app_router.dart`
- `mobile/lib/src/app/app.dart`
- `mobile/lib/src/features/driver_workspace/presentation/driver_workspace_shell.dart`
- `mobile/lib/src/features/management_workspace/presentation/management_workspace_shell.dart`
- `mobile/test/widget_test.dart`

### Change Log

- Added operator and lot-owner management shells with honest placeholder tabs for unfinished top-level sections.
- Made app routing capability-aware so authorized users can enter non-primary management shells without being redirected away.
- Updated driver profile actions to surface workspace navigation when operator or lot-owner capabilities already exist.