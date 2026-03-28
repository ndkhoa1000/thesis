# Story 6.2: Configure Announcements

Status: done

## Story

As an Operator,
I want to post announcements to my lot profile,
so that drivers see important notices.

## Acceptance Criteria

1. Given I am an operator managing an active lot, when I create or update an announcement with title, content, type, and visibility dates, then it is persisted against that managed lot.
2. Given a driver opens that lot's details page during the configured visibility window, when the lot details payload is loaded, then the active announcement appears in the driver-facing lot details experience.
3. Given an announcement is not yet active or already expired, when drivers load the lot details page, then that announcement is hidden from the public driver view.

## Implementation Clarifications

- This story must use the parking-domain announcement model, not the generic starter-blog `Post` feature.
- "Configure" means operators can at minimum list existing announcements and create/update their content plus visibility window for a managed lot.
- Announcement delivery in this story is in-app and lot-detail based. Do not turn it into a push-notification feature.

## Tasks / Subtasks

- [x] Task 1: Add lot announcement management endpoints for operators (AC: 1, 3)
  - [x] Introduce or expose a parking-lot announcement API surface bound to the operator's managed lots.
  - [x] Reuse `ParkingLotAnnouncement` as the canonical domain model and enforce lot ownership/lease authorization.
  - [x] Filter driver-visible announcement reads by `visible_from` and `visible_until` so hidden or expired items never leak to the lot details response.

- [x] Task 2: Surface operator announcement management in the mobile operator workspace (AC: 1)
  - [x] Extend the existing operator lot-management flow with an announcement management entry point per managed lot.
  - [x] Allow operators to create and update announcement metadata without leaving the lot-management experience.
  - [x] Keep the UX aligned to the bright, management-oriented operator context rather than the attendant dark operational UI.

- [x] Task 3: Render active announcements on the driver lot-details surface (AC: 2, 3)
  - [x] Extend the lot-detail backend contract and Flutter model to include visible announcements.
  - [x] Add an announcement section to the existing lot-details sheet instead of creating a separate driver page.
  - [x] Ensure announcement ordering and empty states are explicit and deterministic.

- [x] Task 4: Add focused regression coverage and verification (AC: 1, 2, 3)
  - [x] Add backend tests for operator authorization, visibility-window filtering, and lot-detail announcement projection.
  - [x] Add Flutter tests for operator announcement configuration UI and driver lot-detail rendering.
  - [x] Verify with backend Docker tests and local `flutter test`.

### Review Findings

- [x] [Review][Patch] Invalid calendar inputs are silently normalized instead of rejected [mobile/lib/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart:15]
- [x] [Review][Patch] Visibility-window behavior is under-tested end-to-end for future and expired announcements [backend/tests/test_parking_lots.py:343]
- [x] [Review][Patch] Driver announcement rendering is only covered for the visible happy path, not hidden-window regressions [mobile/test/map_discovery_screen_test.dart:246]

## Dev Notes

### Story Foundation

- PRD FR30 requires operators to post announcements with visibility dates.
- PRD FR3 and Journey 3 expect announcements to be visible on the driver lot-detail page.
- Epic 6 Story 6.2 is the bridge between operator management and driver lot discovery.

### Domain Constraints To Respect

- Operators can only manage announcements for lots they actively operate.
- Driver visibility must be time-window aware using backend filtering.
- Announcements belong to the parking domain and should remain lot-scoped, not user-feed scoped.

### Architecture Guardrails

- Use `backend/src/app/models/notifications.py::ParkingLotAnnouncement` as the canonical persistence model.
- Do not reuse `backend/src/app/api/v1/posts.py` or `backend/src/app/models/post.py`; those are generic starter scaffolds and do not satisfy the parking-domain contract.
- Prefer a dedicated `announcements.py` route module if introduced, while keeping the driver lot-detail read path integrated with the existing `/lots/{id}` contract.

### Library / Framework Requirements

- Backend: existing FastAPI routing, SQLAlchemy models, and schema patterns.
- Mobile: existing `operator_lot_management` and `lot_details` feature/service structure with `dio`.
- Do not add push-notification packages or background delivery systems in this story.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/announcements.py` or equivalent same-style route module
  - `backend/src/app/api/v1/lots.py`
  - `backend/src/app/models/notifications.py`
  - `backend/src/app/schemas/`
  - `backend/tests/`
- Mobile:
  - `mobile/lib/src/features/operator_lot_management/`
  - `mobile/lib/src/features/lot_details/`
  - `mobile/test/`

### Testing Requirements

- Backend tests should validate time-window filtering and role-based access.
- Flutter tests should cover both operator-side configuration and driver-side rendering.
- Verification should use backend Docker tests and local `flutter test`.

### Implementation Risks To Avoid

- Do not implement this on top of the generic `Post` CRUD stack.
- Do not expose draft/future/expired announcements to drivers.
- Do not create a separate driver announcement screen when lot details already exist as the natural surface.

### Recent Repository Patterns

- Operator management already lives inside `operator_lot_management` with per-lot actions; announcement controls should follow that pattern.
- Driver lot details already aggregate pricing, hours, tags, and trends; announcements should extend that contract rather than split it.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 6 / Story 6.2
- [prd.md](../prd.md) - Journey 3, FR3, FR30
- [architecture.md](../architecture.md) - backend project shape and API module direction
- [tech-design.md](../tech-design.md) - `announcements.py` module plan
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - operator vs driver interface context

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Expose parking-lot announcement CRUD for operators using the existing parking-domain notification model.
- Extend operator lot management with announcement configuration and extend driver lot details with visible announcement rendering.
- Cover authorization, visibility windows, and rendering with backend and Flutter tests.

### Completion Notes List

- Added operator-managed announcement endpoints on the existing lot management surface for list, create, and update flows, all guarded by active lease authorization and backed by `ParkingLotAnnouncement`.
- Extended the public `/lots/{id}` detail projection and Flutter lot-detail model so drivers only receive announcements whose visibility window is active at read time.
- Added a management sheet in the operator workspace for creating and updating lot-scoped announcements with title, content, type, and visibility window fields, while preserving the existing bright management UI.
- Added an announcement section to the driver lot-details sheet and kept ordering deterministic by sorting the backend response by `visible_from` descending and `id` descending.
- Validation passed with `cd backend && docker compose run --rm pytest`, `cd mobile && flutter test test/map_discovery_screen_test.dart test/widget_test.dart`, and `cd mobile && flutter test`.
- Epic 6 review follow-up hardened announcement scheduling by rejecting impossible calendar dates and expanded backend/mobile regression coverage around announcement visibility windows and hidden states.

### File List

- `_bmad-output/implementation-artifacts/6-2-configure-announcements.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/lots.py`
- `backend/src/app/schemas/parking_lot.py`
- `backend/tests/test_operator_announcements.py`
- `backend/tests/test_parking_lots.py`
- `mobile/lib/src/features/lot_details/data/lot_details_service.dart`
- `mobile/lib/src/features/lot_details/presentation/lot_details_sheet.dart`
- `mobile/lib/src/features/operator_lot_management/data/operator_lot_management_service.dart`
- `mobile/lib/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart`
- `mobile/test/map_discovery_screen_test.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-28: Created Story 6.2 implementation artifact for operator-managed lot announcements shown in driver lot details.
- 2026-03-28: Implemented Story 6.2 with operator announcement management endpoints, mobile operator announcement configuration UI, driver lot-detail announcement rendering, and full backend/mobile regression validation.
- 2026-03-28: Resolved Epic 6 review findings for invalid announcement date input handling and announcement visibility coverage gaps.
