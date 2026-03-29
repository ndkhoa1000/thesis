# Story 9.5: Admin Workspace Shell

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an Admin,
I want a clear workspace structure organized by administrative function,
so that approvals, user management, and lot suspension are navigable from one place.

## Acceptance Criteria

1. Given I am authenticated as an Admin, when the workspace loads, then a tab structure is shown with `Duyệt hồ sơ`, `Người dùng`, `Bãi xe`.
2. Given I open `Duyệt hồ sơ`, when the Admin shell renders, then the existing `AdminApprovalsScreen` integrates with no functional changes.
3. Given I open `Người dùng` or `Bãi xe` before those flows are fully integrated, when the shell renders, then honest placeholder content appears.
4. Given the Admin shell exists, when routing resolves an admin session, then `AdminApprovalsScreen` is no longer the standalone workspace entry and is instead reached through `AdminShell`.
5. Given the Admin workspace renders, when the shell appears, then the light theme applies consistently.

## Implementation Clarifications

- This story is shell structure only. It does not implement new admin business features beyond organizing reachability.
- `AdminApprovalsScreen` should remain functionally intact and become the first tab under the shell.
- Placeholder tabs must remain honest; do not imply user management or lot suspension functionality if those integrations are not yet wired.
- Keep admin as a separate-account route, not part of public multi-capability navigation.

## Tasks / Subtasks

- [x] Task 1: Create the Admin shell (AC: 1, 4, 5)
  - [x] Introduce a dedicated admin shell with tabs `Duyệt hồ sơ`, `Người dùng`, `Bãi xe`.
  - [x] Route admin sessions into the shell instead of directly into `AdminApprovalsScreen`.
  - [x] Apply the light theme consistently.

- [x] Task 2: Integrate existing approvals flow and honest placeholders (AC: 2, 3)
  - [x] Mount `AdminApprovalsScreen` as the `Duyệt hồ sơ` tab content.
  - [x] Create shell placeholders for `Người dùng` and `Bãi xe` using the shared placeholder pattern from Story 9.6.
  - [x] Preserve sign-out and approval-refresh behavior.

- [x] Task 3: Add regression coverage (AC: 1, 2, 3, 4, 5)
  - [x] Add Flutter tests for admin route landing, tab switching, and continued `AdminApprovalsScreen` rendering under the shell.
  - [x] Verify placeholder honesty and light-theme usage.
  - [x] Verify with `cd mobile && flutter test`.

### Review Findings

- [x] [Review][Patch] Admin placeholder tabs bypass the shared placeholder pattern required by Stories 9.5 and 9.6 [mobile/lib/src/features/admin_workspace/presentation/admin_workspace_shell.dart:76]

## Dev Notes

### Story Foundation

- Admin already has a working approvals surface from Epic 2; Epic 9 formalizes its workspace structure for demo readiness.
- This shell aligns Admin with the same role-aware workspace framework as the other actors without changing admin business rules.

### Current Codebase Signals

- `AuthenticatedHome` currently returns `AdminApprovalsScreen` directly for admin sessions.
- No admin shell or shared placeholder system exists yet.
- Admin sign-out currently lives at the screen boundary and must remain visible after shell introduction.

### Architecture Guardrails

- Keep Admin as a separate-account flow.
- Do not move admin approval fetching or mutation logic into shell code.
- Reuse the light-theme profile from Story 9.1 and the shared state/placeholder widgets from Story 9.6.

### File Structure Requirements

- Expected mobile touch points:
  - `mobile/lib/src/app/app_router.dart`
  - `mobile/lib/src/features/admin_approvals/presentation/admin_approvals_screen.dart`
  - `mobile/lib/src/features/admin_workspace/` (new shell folder)
  - shared widgets from Story 9.6
  - `mobile/test/`

### Testing Requirements

- Test admin route landing into the shell and continued rendering of the approvals tab.
- Test tab labels and placeholder tabs.
- Keep verification to `cd mobile && flutter test`.

### Implementation Risks To Avoid

- Do not bury the approvals workflow behind extra navigation hops that slow the core admin action.
- Do not imply unimplemented admin management surfaces are complete.
- Do not duplicate approvals state loading at both shell and tab levels.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 9 / Story 9.5
- [epics-distillate.md](../planning-artifacts/epics-distillate.md) - Admin shell summary
- [architecture.md](../architecture.md) - role-aware mobile routing and thin-client guidance
- [2-2-admin-dashboard-pending-approvals.md](./2-2-admin-dashboard-pending-approvals.md)
- [2-3-admin-system-management-lot-suspension.md](./2-3-admin-system-management-lot-suspension.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Introduce an Admin shell with clear tabs and light-theme composition.
- Route current admin entry through the shell while preserving the approvals workflow.
- Validate route landing and placeholder honesty with Flutter tests.

### Completion Notes List

- Story context anchored on the current direct `AdminApprovalsScreen` entry path and Epic 9's requirement to organize Admin by administrative function.
- Added guardrails to keep the shell lightweight and separate from approval business logic.
- Added `AdminWorkspaceShell` with workspace tabs `Duyệt hồ sơ`, `Người dùng`, and `Bãi xe`, keeping approvals as the first tab while presenting honest placeholders for the unfinished admin surfaces.
- Re-routed admin sessions through the shell in the shared app composition layer without changing `AdminApprovalsScreen` approval loading, mutation, refresh, or sign-out behavior.
- Extended widget coverage for admin route landing and placeholder tabs, then validated with `flutter test test/widget_test.dart -r expanded` and the full `flutter test` suite.

### File List

- `_bmad-output/implementation-artifacts/9-5-admin-workspace-shell.md`
- `mobile/lib/src/app/app.dart`
- `mobile/lib/src/features/admin_workspace/presentation/admin_workspace_shell.dart`
- `mobile/test/widget_test.dart`

### Change Log

- Added a dedicated admin shell and routed admin entry through it instead of landing directly on the approvals screen.
- Kept `AdminApprovalsScreen` intact as the first admin workspace tab while adding honest placeholder tabs for user and parking-lot administration.
- Updated admin route widget coverage and confirmed the full mobile regression suite remains green.