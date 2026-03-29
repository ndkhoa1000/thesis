# Story 9.2: Driver Workspace Shell

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Driver,
I want a consistent app shell with clear bottom navigation,
so that I can access all driving features predictably without hidden icon-bar actions.

## Acceptance Criteria

1. Given I am authenticated as a Driver, when the workspace loads, then a `BottomNavigationBar` with 3 tabs is shown: `Bản đồ`, `Lịch sử`, `Cá nhân`.
2. Given I am in the Driver workspace, when screens render, then `AppTheme.light()` applies consistently.
3. Given the shell presents primary actions, when the user needs to act, then primary actions are anchored to the bottom thumb-zone using the light MD3 driver pattern.
4. Given the Bản đồ tab opens, when the tab is selected, then the existing `MapDiscoveryScreen` integrates without functional changes.
5. Given the Lịch sử tab opens before later enhancements, when there is no extra shell-specific content, then it shows a coherent placeholder or existing history surface without inventing unsupported behavior.
6. Given the Cá nhân tab opens, when the driver needs profile utilities, then it exposes vehicle management entry plus capability application shortcuts.

## Implementation Clarifications

- This story wraps existing driver feature slices; it does not rewrite map discovery, booking, driver check-in token flow, or parking history business logic.
- The current `MapDiscoveryScreen` already carries callbacks for parking history, vehicle management, and capability applications. The shell should absorb those reachability paths into durable navigation.
- If `ParkingHistoryScreen` is already usable, prefer integrating it over adding a fake empty state. Only use `EmptyView` when a tab has no real feature slice yet.
- Keep the driver UI aligned with the airy light-theme direction from the UX spec: map-dominant, generous spacing, bottom-anchored primary actions.

## Tasks / Subtasks

- [x] Task 1: Create the Driver shell scaffold (AC: 1, 2, 3)
  - [x] Introduce a dedicated driver shell widget under a workspace/shell layer instead of embedding navigation logic inside `MapDiscoveryScreen`.
  - [x] Add 3-tab bottom navigation: `Bản đồ`, `Lịch sử`, `Cá nhân`.
  - [x] Apply `AppTheme.light()` consistently through the routed driver workspace.

- [x] Task 2: Integrate current driver features without logic rewrites (AC: 4, 5, 6)
  - [x] Mount `MapDiscoveryScreen` as the Bản đồ tab with its current booking, lot-details, and driver check-in callbacks intact.
  - [x] Mount `ParkingHistoryScreen` or a valid shell placeholder under Lịch sử depending on current feature readiness.
  - [x] Create a profile/personal tab that exposes vehicle management plus existing lot-owner/operator application shortcuts.

- [x] Task 3: Normalize bottom-thumb-zone actions (AC: 3, 4, 6)
  - [x] Move hidden or ad hoc action entry points into clear bottom-positioned actions within the shell or child tabs.
  - [x] Keep map-centric behavior and avoid shrinking the core map surface below the UX intent.
  - [x] Ensure shell navigation does not break the current lot-details and booking flows.

- [x] Task 4: Add regression coverage (AC: 1, 2, 4, 5, 6)
  - [x] Add Flutter tests for driver route landing, tab switching, and preservation of current feature callbacks.
  - [x] Assert that `MapDiscoveryScreen` still renders and that vehicle/application shortcuts remain reachable.
  - [x] Verify with `cd mobile && flutter test`.

## Dev Notes

### Story Foundation

- Driver shell work is primarily orchestration and UX hardening. The existing driver features from Epics 4, 5, and 7 already provide the business logic.
- This shell should become the durable home for map discovery, parking history, and personal/profile actions ahead of demo hardening.

### Current Codebase Signals

- Driver users currently fall through to `MapDiscoveryScreen` directly from `AuthenticatedHome`.
- `MapDiscoveryScreen` already receives callbacks for parking history, vehicle management, lot-owner application, operator application, sign-out, and driver check-in.
- There is no shared shell layer yet, so feature navigation is currently callback-driven and screen-local.

### Architecture Guardrails

- Preserve thin-client boundaries: the shell composes existing screens and callbacks rather than reimplementing booking, details, or history logic.
- Keep the driver shell in the light theme family defined by Story 9.1.
- Follow the UX spec's airy and map-dominant driver context, with bottom-anchored actions instead of dense operational layouts.

### File Structure Requirements

- Expected mobile touch points:
  - `mobile/lib/src/app/app_router.dart`
  - `mobile/lib/src/features/map_discovery/presentation/map_discovery_screen.dart`
  - `mobile/lib/src/features/parking_history/presentation/parking_history_screen.dart`
  - `mobile/lib/src/features/vehicles/presentation/vehicle_screen.dart`
  - `mobile/lib/src/features/driver_workspace/` (new shell folder)
  - `mobile/test/`

### Testing Requirements

- Test bottom-navigation tab state and route restoration for the driver workspace.
- Test that map discovery still opens lot details and preserves booking/check-in entry points.
- Verify Vietnamese tab labels and shell-level logout/profile reachability where applicable.

### Implementation Risks To Avoid

- Do not move driver business flows into the shell widget.
- Do not reduce the map experience to a narrow tab with cramped layout.
- Do not hide vehicle management or capability applications behind temporary dev-only buttons.
- Do not invent new driver features beyond shell composition.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 9 / Story 9.2
- [epics-distillate.md](../planning-artifacts/epics-distillate.md) - Driver shell summary
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - Driver Layout and Divergent Dual-Context direction
- [architecture.md](../architecture.md) - mobile client stack and thin-client rules
- [5-1-view-interactive-map-lots.md](./5-1-view-interactive-map-lots.md)
- [5-2-view-lot-details-availability.md](./5-2-view-lot-details-availability.md)
- [5-3-driver-parking-history.md](./5-3-driver-parking-history.md)
- [7-1-driver-pre-books-parking-spot.md](./7-1-driver-pre-books-parking-spot.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Introduce a dedicated Driver shell with 3 bottom tabs and light-theme composition.
- Rehome current callback-based driver feature reachability into stable workspace tabs.
- Validate tab switching and existing driver feature entry points with Flutter tests.

### Completion Notes List

- Story context anchored on the existing direct `MapDiscoveryScreen` entry path and Epic 9's requirement to formalize the Driver workspace into a bottom-navigation shell.
- Added guardrails to keep shell composition separate from booking, map, and parking-history business logic.
- Implemented a dedicated `DriverWorkspaceShell` with 3 bottom tabs: `Bản đồ`, `Lịch sử`, and `Cá nhân`, while keeping the driver route on the light MD3 theme from Story 9.1.
- Rehomed driver quick actions out of the map app bar and into the `Cá nhân` tab using full-width buttons for check-in, vehicle management, capability applications, and logout.
- Embedded `MapDiscoveryScreen` as the map tab and `ParkingHistoryScreen` as the history tab without changing their backend contracts or data-loading logic.
- Added configurability to `MapDiscoveryScreen` so shell-managed driver routes can hide icon-bar actions while non-shell use cases continue to work.
- Validation completed with `cd /home/khoa/thesis/app/mobile && TERM=dumb flutter test test/widget_test.dart -r expanded` and `cd /home/khoa/thesis/app/mobile && TERM=dumb flutter test`.

### File List

- `_bmad-output/implementation-artifacts/9-2-driver-workspace-shell.md`
- `mobile/lib/src/app/app.dart`
- `mobile/lib/src/features/driver_workspace/presentation/driver_workspace_shell.dart`
- `mobile/lib/src/features/map_discovery/presentation/map_discovery_screen.dart`
- `mobile/lib/src/features/parking_history/presentation/parking_history_screen.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-29: Added the Driver workspace shell with bottom navigation, moved personal driver actions into a dedicated profile tab, and updated widget regression coverage for the new navigation model.