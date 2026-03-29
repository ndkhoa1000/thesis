# Story 9.3: Attendant Workspace Shell

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an Attendant,
I want a dedicated dark-mode shell optimized for gate operations,
so that the correct high-contrast, edge-to-edge Dark UI is in place for all Epic 4 stories.

## Acceptance Criteria

1. Given I am authenticated as an Attendant, when the workspace loads, then `AppTheme.dark()` is applied and the `Scaffold` background is `#121212`.
2. Given the shell is rendered, when the screen opens, then it uses an edge-to-edge layout where the status bar integrates into the dark header zone and no wasted AppBar padding remains.
3. Given the shell body is displayed, when the gate workspace loads, then the layout uses a proportional split with the top 50% reserved for camera or viewfinder and the bottom 50% for the interaction zone.
4. Given the attendant has an assigned lot name, when the shell renders, then a dark header label shows `BÃI XE — [Tên bãi]`.
5. Given the current placeholder entry is replaced, when navigation resolves to the attendant workspace, then the existing screen is hosted through the proper shell rather than as a standalone workspace.
6. Given Story 4.2 and later gate flows are already implemented, when the shell is complete, then it is ready to host those flows without structural changes.

## Implementation Clarifications

- This is a shell story, not a rewrite of attendant scanning, walk-in check-in, checkout preview, shift close-out, or discrepancy logic.
- The shell should wrap `AttendantCheckInScreen` or its extracted content, preserving current service boundaries and scanner builder wiring.
- The UX spec explicitly allows abandoning standard airy MD3 layouts here. Prioritize dark, dense, high-contrast operability over visual consistency with public workspaces.
- If lot assignment data is not already available at the shell boundary, derive the header label from existing session/profile data with the smallest honest fallback instead of fabricating a lot name.

## Tasks / Subtasks

- [x] Task 1: Create the Attendant shell container (AC: 1, 2, 3, 4, 5)
  - [x] Introduce a dedicated attendant shell widget and route destination under the new app routing foundation.
  - [x] Apply `AppTheme.dark()` with `#121212` scaffold surface and edge-to-edge system UI treatment.
  - [x] Provide a header area for the lot label and a 50/50 operational layout split using `Expanded`, `Flex`, or equivalent.

- [x] Task 2: Rehost the existing gate workflow inside the shell (AC: 3, 5, 6)
  - [x] Mount the current attendant scanning/check-in screen inside the shell without changing API contracts.
  - [x] Preserve scanner, walk-in upload, checkout preview, and logout actions.
  - [x] Ensure current operational flows still fit the new layout without introducing nested navigation confusion.

- [x] Task 3: Normalize attendant-specific operational presentation (AC: 1, 2, 3, 4)
  - [x] Use oversized typography and high-contrast treatment consistent with the attendant UX direction.
  - [x] Remove wasted padding and bright public-theme widgets from the workspace entry path.
  - [x] Keep the top visual zone structurally ready for the camera/viewfinder even when the scanner is idle.

- [x] Task 4: Add regression coverage (AC: 1, 2, 3, 4, 5, 6)
  - [x] Add Flutter tests for attendant route landing, dark theme application, and shell layout rendering.
  - [x] Assert that the gate flow remains reachable and the header label logic behaves honestly.
  - [x] Verify with `cd mobile && flutter test`.

## Dev Notes

### Story Foundation

- Epic 4 established the gate workflows; Epic 9 gives them the correct operational shell.
- The attendant workspace is intentionally the opposite of the public-management UI: dense, dark, edge-to-edge, and optimized for rapid physical operation.

### Current Codebase Signals

- `AuthenticatedHome` currently returns `AttendantCheckInScreen` directly for attendant sessions.
- The attendant presentation already contains scanner and loading UI, but not a formal shell boundary with the required dark header and layout split.
- Walk-in check-in already uses multipart upload in Flutter and a backend endpoint that stores images locally; this shell must not disturb that path.

### Architecture Guardrails

- Keep Attendant as a separate-account flow, not part of public multi-capability routing.
- Preserve existing service injection and scanner builder boundaries.
- Let the shell own layout and theming while the feature screen continues owning gate workflow state and API calls.

### File Structure Requirements

- Expected mobile touch points:
  - `mobile/lib/src/app/app_router.dart`
  - `mobile/lib/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart`
  - `mobile/lib/src/features/attendant_workspace/` (new shell folder)
  - shared theme/components introduced in Stories 9.1 and 9.6
  - `mobile/test/`

### Testing Requirements

- Add widget tests for dark-shell rendering, layout split structure, and route landing for attendant users.
- Confirm existing gate actions still render under the shell and that logout remains visible.
- Verify Vietnamese header text and honest fallback behavior when lot name is unavailable.

### Implementation Risks To Avoid

- Do not break scanner lifecycle or camera permissions while reorganizing layout.
- Do not force the attendant workspace into the public light-theme shell conventions.
- Do not fabricate lot metadata solely to satisfy the header label.
- Do not introduce shell-specific API calls when current session/profile data is enough.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 9 / Story 9.3
- [epics-distillate.md](../planning-artifacts/epics-distillate.md) - Attendant shell summary
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - Attendant layout, dark mode, oversized typography, edge-to-edge direction
- [architecture.md](../architecture.md) - mobile stack and separate-account role guidance
- [4-2-attendant-scans-qr-for-check-in.md](./4-2-attendant-scans-qr-for-check-in.md)
- [4-3-manual-license-plate-check-in.md](./4-3-manual-license-plate-check-in.md)
- [4-5-attendant-scans-qr-for-check-out-calculates-fee.md](./4-5-attendant-scans-qr-for-check-out-calculates-fee.md)
- [6-4-zero-trust-shift-handover.md](./6-4-zero-trust-shift-handover.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Create a dedicated dark attendant shell with edge-to-edge layout and clear operational zones.
- Rehost the existing gate workflow inside that shell without changing backend contracts or scanner behavior.
- Validate dark-theme rendering and preserved gate reachability with Flutter tests.

### Completion Notes List

- Story context anchored on Epic 9's dark-shell acceptance criteria and the current direct `AttendantCheckInScreen` workspace entry.
- Added guardrails to keep shell layout work separate from gate workflow logic and multipart upload behavior.
- Added `AttendantWorkspaceShell` with edge-to-edge dark chrome, a dynamic `BÃI XE — ...` header, and an honest `CHƯA GÁN` fallback when lot data is unavailable.
- Rehosted the gate workflow through an embedded 50/50 attendant layout so scanner, walk-in, checkout preview, active-session, shift handover, and logout actions remain available without nested navigation.
- Extended widget coverage for attendant shell rendering and fallback header logic, then validated `flutter test test/widget_test.dart -r expanded`, `flutter test test/attendant_check_in_screen_test.dart`, and the full `flutter test` suite.

### File List

- `_bmad-output/implementation-artifacts/9-3-attendant-workspace-shell.md`
- `mobile/lib/src/app/app.dart`
- `mobile/lib/src/features/attendant_workspace/presentation/attendant_workspace_shell.dart`
- `mobile/lib/src/features/attendant_workspace/`
- `mobile/lib/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart`
- `mobile/test/widget_test.dart`
- `mobile/test/attendant_check_in_screen_test.dart`

### Change Log

- Added a dedicated attendant workspace shell and routed attendant sessions through it from the shared app composition layer.
- Updated `AttendantCheckInScreen` to support embedded shell mode, lot-name reporting, and a preserved standalone test viewport.
- Added attendant shell widget tests and kept full mobile regression coverage green.