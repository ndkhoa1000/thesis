# Story 9.1: App Routing Foundation & Dual Theme System

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want a centralized routing system and two ThemeData profiles,
so that all workspace screens consistently use correct themes and navigation from the start.

## Acceptance Criteria

1. Given the app launches, when authentication state resolves, then `go_router` routes the user to the correct workspace entry point by session role.
2. Given the user is unauthenticated or authenticated, when routing resolves, then unauthenticated users are routed to `AuthGate` and authenticated users land in their workspace.
3. Given the authenticated workspace is Driver, Operator, Lot Owner, or Admin, when the app renders, then `AppTheme.light()` applies Material 3 styling with primary `#1A73E8` and standard MD3 paddings.
4. Given the authenticated workspace is Attendant, when the app renders, then `AppTheme.dark()` applies oversized typography, dark surface `#121212`, and high-contrast styling.
5. Given the app bootstraps services, when `main.dart` starts the application, then app bootstrap is delegated to a dedicated `app.dart` and service factories initialize once and are injected through constructor boundaries or a minimal provider layer.
6. Given the routing layer is introduced, when implementation is complete, then the architecture navigation decision in `architecture.md` is satisfied.

## Implementation Clarifications

- This story is infrastructure, not feature expansion. It replaces the current `MaterialApp(home: AuthGate(...))` bootstrap and `_PublicWorkspaceSwitcherScreen` bridge with durable routing.
- Do not rewrite business logic inside feature screens. Existing screens should remain thin constructor-driven destinations wrapped by routing and shell composition.
- The architecture names `go_router` and `flutter_riverpod`, but the current repo only ships constructor-based injection. A full state-management migration is out of scope unless it is the smallest way to keep routing bootstrap clean.
- Epic 9 must absorb the current public multi-capability bridge into explicit workspace entry points without reintroducing role shortcuts that bypass capability checks.

## Tasks / Subtasks

- [ ] Task 1: Introduce app bootstrap and routing foundation (AC: 1, 2, 5, 6)
  - [ ] Create a dedicated mobile bootstrap entry such as `mobile/lib/src/app/app.dart` and move `MaterialApp` composition out of `mobile/lib/main.dart`.
  - [ ] Add `go_router` to `pubspec.yaml` if missing and configure named routes for auth plus all 5 workspace entry points.
  - [ ] Keep `AuthGate` as the authentication resolver, but route from its result instead of hardwiring workspace widgets directly in `home:`.

- [ ] Task 2: Implement dual theme system (AC: 3, 4)
  - [ ] Create a reusable theme module such as `mobile/lib/src/app/app_theme.dart` exposing `AppTheme.light()` and `AppTheme.dark()`.
  - [ ] Encode MD3 light defaults around primary `#1A73E8` and the dark attendant profile around `#121212` plus oversized typography.
  - [ ] Ensure the attendant workspace can override the default light app theme without forking app bootstrap logic.

- [ ] Task 3: Replace temporary workspace switching with route-aware entry (AC: 1, 2, 5)
  - [ ] Remove `_PublicWorkspaceSwitcherScreen` as the primary bridge and replace it with explicit role-aware route destinations.
  - [ ] Preserve the current public-account capability model: one `user.role` primary workspace with optional linked `lot_owner` and `manager` capabilities.
  - [ ] Keep Admin and Attendant as separate-account flows and do not merge them into the public capability switcher.

- [ ] Task 4: Preserve service boundaries and existing feature reachability (AC: 2, 5)
  - [ ] Consolidate service factory creation so each authenticated session creates service instances once per app composition path.
  - [ ] Pass existing services into screens without moving API logic into router classes.
  - [ ] Confirm Driver, Attendant, Operator, Lot Owner, and Admin entry screens still work through the new routing layer.

- [ ] Task 5: Add focused regression coverage (AC: 1, 2, 3, 4, 5, 6)
  - [ ] Add Flutter tests for unauthenticated redirect, role-based route resolution, and multi-capability public-account routing.
  - [ ] Add theme assertions proving Attendant uses dark styling while other workspaces use light styling.
  - [ ] Verify with `cd mobile && flutter test`.

## Dev Notes

### Story Foundation

- Epic 9 is explicitly workflow-validation infrastructure, not cosmetic polish. Routing and shell composition are now system-level concerns.
- This story is the prerequisite for Stories 9.2 through 9.6 because all workspace shells depend on canonical route and theme composition.
- The architecture already declares `go_router`, Material 3, and custom theme profiles as the intended direction; the current repo has not caught up yet.

### Current Codebase Signals

- `mobile/lib/main.dart` currently builds `MaterialApp` directly and uses `home: AuthGate(...)` with an `AuthenticatedHome` switch statement.
- The current file still contains `_PublicWorkspaceSwitcherScreen`, which is the temporary bridge Epic 9 is supposed to absorb and retire.
- Service factories are currently top-level functions in `main.dart`; keep the constructor-driven pattern but move composition into a dedicated app layer.
- `mobile/pubspec.yaml` currently includes `dio`, `image_picker`, and other core libraries, but does not yet list `go_router`.

### Architecture Guardrails

- Follow the architecture navigation choice: `go_router` for navigation, Material 3 plus custom theme for styling, and constructor/provider-based service injection at app boundaries.
- Keep public capability resolution aligned with backend truth: linked `driver`, `lot_owner`, and `manager` rows define capabilities, while `user.role` remains the current primary public workspace.
- Do not move authorization, capability resolution, or business logic into Flutter route guards beyond selecting the correct workspace entry.
- Keep `main.dart` minimal: env loading, Mapbox token setup, and `runApp`; all other composition belongs in the app layer.

### File Structure Requirements

- Expected mobile touch points:
  - `mobile/lib/main.dart`
  - `mobile/lib/src/app/app.dart` (new)
  - `mobile/lib/src/app/app_router.dart` (new)
  - `mobile/lib/src/app/app_theme.dart` (new)
  - `mobile/lib/src/features/auth/presentation/auth_gate.dart`
  - workspace shell files introduced in Stories 9.2 to 9.5
  - `mobile/pubspec.yaml`
  - `mobile/test/`

### Testing Requirements

- Add widget or app-level routing tests that cover unauthenticated, Admin, Attendant, Driver-only, Lot Owner-only, Operator-only, and multi-capability public accounts.
- Assert the theme split rather than only checking text labels.
- Keep verification local with `cd mobile && flutter test`.

### Implementation Risks To Avoid

- Do not entangle route definitions with API client creation or feature business rules.
- Do not keep `_PublicWorkspaceSwitcherScreen` alive as a hidden fallback after route-based workspace entry exists.
- Do not force a repo-wide rewrite to Riverpod if constructor injection remains sufficient.
- Do not change backend capability semantics to make routing easier.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 9 / Story 9.1
- [epics-distillate.md](../planning-artifacts/epics-distillate.md) - Epic 9 summary
- [architecture.md](../architecture.md) - Section 2.1 mobile libraries, Section 2.2 capability model
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - Micro-Themes, Design Direction Decision, Implementation Approach
- [sprint-change-proposal-2026-03-27-ux-shell.md](../planning-artifacts/sprint-change-proposal-2026-03-27-ux-shell.md) - routing/theme rationale and temporary bridge replacement intent
- [epic-8-retro-2026-03-29.md](./epic-8-retro-2026-03-29.md) - Epic 9 readiness and shell separation guardrails

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Extract app composition out of `main.dart`, introduce canonical routes, and centralize theme definitions.
- Replace the temporary public workspace switch bridge with explicit role-aware entry routes.
- Keep feature slices intact and verify route/theme behavior with focused Flutter tests.

### Completion Notes List

- Story context anchored on Epic 9 routing and dual-theme acceptance criteria, current bootstrap drift in `main.dart`, and the architecture requirement to adopt `go_router`.
- Added explicit guardrails to prevent route-level business logic creep and to retire the temporary multi-capability switcher during implementation.

### File List

- `_bmad-output/implementation-artifacts/9-1-app-routing-foundation-dual-theme-system.md`
- `mobile/lib/main.dart`
- `mobile/lib/src/app/app.dart`
- `mobile/lib/src/app/app_router.dart`
- `mobile/lib/src/app/app_theme.dart`
- `mobile/lib/src/features/auth/presentation/auth_gate.dart`
- `mobile/pubspec.yaml`
- `mobile/test/`