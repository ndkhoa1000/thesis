# Story 9.6: Shared UI Components & Localization

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As any app user,
I want consistent loading, error, and empty states across all workspaces,
so that the UI feels coherent and polished for the thesis demo.

## Acceptance Criteria

1. Given any workspace is in a loading state, when it renders, then it uses a shared `LoadingView` with light and dark variants.
2. Given any workspace is in an error state, when it renders, then it uses a shared `ErrorView` with light and dark variants.
3. Given any workspace is in an empty state, when it renders, then it uses a shared `EmptyView` with light and dark variants.
4. Given workspace labels are shown, when user-facing text renders, then Vietnamese labels are used for role names, navigation tabs, and user-visible error messaging.
5. Given there are existing English placeholder workspace title strings, when Story 9.6 completes, then those English placeholders are removed.
6. Given each workspace is integrated, when the story is complete, then at least one screen per workspace uses the shared widgets to prove adoption.

## Implementation Clarifications

- This story standardizes presentation only. It should not replace feature-specific domain explanations that are already accurate.
- The current repo has many inline `CircularProgressIndicator` and ad hoc placeholder/error blocks. Replace repetition with shared views where practical, not by introducing a heavy localization framework.
- Vietnamese localization here means user-visible strings in current thesis scope. A full ARB/i18n pipeline is optional unless it is the smallest maintainable path.
- Shared widgets must support both light and dark shells so the attendant workspace is not forced into public visual styles.

## Tasks / Subtasks

- [x] Task 1: Create shared state widgets (AC: 1, 2, 3)
  - [x] Introduce `LoadingView`, `ErrorView`, and `EmptyView` in a shared presentation layer.
  - [x] Support light and dark variants, either through theme-aware rendering or explicit configuration.
  - [x] Keep the widgets flexible enough for title, description, retry action, and icon treatment without overengineering.

- [x] Task 2: Replace repeated inline state rendering in key workspaces (AC: 1, 2, 3, 6)
  - [x] Integrate the shared widgets into at least one Driver, Attendant, Operator, Lot Owner, and Admin screen.
  - [x] Prioritize screens currently using inline `CircularProgressIndicator` or ad hoc placeholder text.
  - [x] Preserve existing retry or refresh actions where they already exist.

- [x] Task 3: Normalize Vietnamese labels and placeholder copy (AC: 4, 5)
  - [x] Replace remaining visible English workspace labels or placeholder copy with Vietnamese text.
  - [x] Standardize role display names: `Tài xế`, `Nhân viên`, `Vận hành viên`, `Chủ bãi xe`, `Quản trị viên`.
  - [x] Standardize navigation tab labels from Stories 9.2 to 9.5 and align error strings where the repo currently exposes English placeholders.

- [x] Task 4: Add regression coverage (AC: 1, 2, 3, 4, 5, 6)
  - [x] Add Flutter tests for shared state widgets in both light and dark contexts.
  - [x] Add targeted tests proving at least one screen per workspace adopts the shared widgets.
  - [x] Verify with `cd mobile && flutter test`.

## Dev Notes

### Story Foundation

- Epic 9 is partly about visible polish, but this story still serves workflow clarity by making state transitions predictable across all actor contexts.
- The thesis demo will be more credible if loading, error, and empty states feel deliberate rather than pieced together per screen.

### Current Codebase Signals

- The current mobile repo contains many inline `CircularProgressIndicator` usages across Driver, Attendant, Operator, Lot Owner, Admin, Auth, and reporting screens.
- There is no shared `LoadingView`, `ErrorView`, or `EmptyView` widget yet.
- Some visible labels are already Vietnamese, but localization is inconsistent and still tied to screen-local copy.

### Architecture Guardrails

- Keep shared presentation components thin and theme-aware.
- Do not introduce a localization framework so large that it stalls Epic 9 delivery unless it clearly reduces duplication with minimal migration cost.
- Shared views must respect the dual-theme direction from Story 9.1.

### File Structure Requirements

- Expected mobile touch points:
  - `mobile/lib/src/shared/` or `mobile/lib/src/core/presentation/` (new shared views)
  - `mobile/lib/src/features/admin_approvals/presentation/admin_approvals_screen.dart`
  - `mobile/lib/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart`
  - `mobile/lib/src/features/map_discovery/presentation/map_discovery_screen.dart`
  - `mobile/lib/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart`
  - `mobile/lib/src/features/parking_lot_registration/presentation/parking_lot_registration_screen.dart`
  - `mobile/test/`

### Testing Requirements

- Test the shared views in isolation and in at least one light-shell plus one dark-shell consumer.
- Prove one consumer per workspace category adopts the shared components.
- Validate Vietnamese labels in the shared views and shell tabs.

### Implementation Risks To Avoid

- Do not replace meaningful domain-specific empty states with vague generic copy.
- Do not hardcode light-theme visuals into widgets that must also serve the attendant workspace.
- Do not scatter duplicated Vietnamese strings after introducing shared presentation components.
- Do not attempt a full-scale localization replatform if scoped copy normalization is enough for the thesis demo.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 9 / Story 9.6
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - design system foundation, component strategy, dual-theme direction
- [architecture.md](../architecture.md) - Material 3 plus custom theme guidance
- [deferred-work.md](./deferred-work.md) - earlier note to standardize shells and finish Vietnamese localization

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Add reusable loading/error/empty presentation primitives with light and dark variants.
- Replace the most repetitive inline state rendering across all workspaces and normalize visible copy to Vietnamese.
- Validate shared widget adoption and theme correctness with Flutter tests.

### Completion Notes List

- Added shared `LoadingView`, `ErrorView`, and `EmptyView` under `mobile/lib/src/shared/presentation/state_views.dart` with adaptive, light, and dark presentation support.
- Replaced repeated loading, error, and empty-state rendering in Driver (`MapDiscoveryScreen`), Attendant (`AttendantCheckInScreen` occupancy panel), Operator (`OperatorLotManagementScreen`), Lot Owner (`ParkingLotRegistrationScreen`), and Admin (`AdminApprovalsScreen`).
- Normalized visible workspace and role copy from lingering English/ASCII placeholders to Vietnamese across driver profile actions, management placeholders, admin approvals, operator application flow, parking-lot leasing labels, and revenue dashboards.
- Added direct widget coverage for `LoadingView`, `ErrorView`, and `EmptyView` in both light/adaptive and dark-tone scenarios.
- Updated attendant, workspace, admin, lease, and revenue widget tests to match the shared-state adoption and localized copy.
- Validation passed with `flutter test test/state_views_test.dart -r expanded`, `flutter test test/widget_test.dart -r expanded`, `flutter test test/attendant_walk_in_check_in_test.dart -r expanded`, and full `flutter test`.

### File List

- `_bmad-output/implementation-artifacts/9-6-shared-ui-components-localization.md`
- `mobile/lib/src/shared/presentation/state_views.dart`
- `mobile/lib/src/features/admin_approvals/presentation/admin_approvals_screen.dart`
- `mobile/lib/src/features/admin_approvals/data/admin_approvals_service.dart`
- `mobile/lib/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart`
- `mobile/lib/src/features/map_discovery/presentation/map_discovery_screen.dart`
- `mobile/lib/src/features/operator_application/presentation/operator_application_screen.dart`
- `mobile/lib/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart`
- `mobile/lib/src/features/operator_revenue_dashboard/presentation/operator_revenue_dashboard_sheet.dart`
- `mobile/lib/src/features/owner_revenue_dashboard/presentation/owner_revenue_dashboard_sheet.dart`
- `mobile/lib/src/features/parking_lot_registration/presentation/parking_lot_registration_screen.dart`
- `mobile/lib/src/features/management_workspace/presentation/management_workspace_shell.dart`
- `mobile/lib/src/features/driver_workspace/presentation/driver_workspace_shell.dart`
- `mobile/test/widget_test.dart`
- `mobile/test/state_views_test.dart`
- `mobile/test/attendant_walk_in_check_in_test.dart`
- `mobile/test/attendant_check_in_screen_test.dart`
- `mobile/test/attendant_check_out_screen_test.dart`
- `mobile/test/attendant_check_out_finalize_test.dart`
- `mobile/test/shift_handover_test.dart`
- `mobile/test/final_shift_close_out_test.dart`

## Change Log

- 2026-03-29: Completed Story 9.6 shared state views rollout, Vietnamese copy normalization, regression updates, and direct shared-widget test coverage.