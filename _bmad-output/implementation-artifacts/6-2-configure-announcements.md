# Story 6.2: Configure Announcements

Status: ready-for-dev

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

- [ ] Task 1: Add lot announcement management endpoints for operators (AC: 1, 3)
  - [ ] Introduce or expose a parking-lot announcement API surface bound to the operator's managed lots.
  - [ ] Reuse `ParkingLotAnnouncement` as the canonical domain model and enforce lot ownership/lease authorization.
  - [ ] Filter driver-visible announcement reads by `visible_from` and `visible_until` so hidden or expired items never leak to the lot details response.

- [ ] Task 2: Surface operator announcement management in the mobile operator workspace (AC: 1)
  - [ ] Extend the existing operator lot-management flow with an announcement management entry point per managed lot.
  - [ ] Allow operators to create and update announcement metadata without leaving the lot-management experience.
  - [ ] Keep the UX aligned to the bright, management-oriented operator context rather than the attendant dark operational UI.

- [ ] Task 3: Render active announcements on the driver lot-details surface (AC: 2, 3)
  - [ ] Extend the lot-detail backend contract and Flutter model to include visible announcements.
  - [ ] Add an announcement section to the existing lot-details sheet instead of creating a separate driver page.
  - [ ] Ensure announcement ordering and empty states are explicit and deterministic.

- [ ] Task 4: Add focused regression coverage and verification (AC: 1, 2, 3)
  - [ ] Add backend tests for operator authorization, visibility-window filtering, and lot-detail announcement projection.
  - [ ] Add Flutter tests for operator announcement configuration UI and driver lot-detail rendering.
  - [ ] Verify with backend Docker tests and local `flutter test`.

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

- Story context prepared for Epic 6 implementation.
- Key guardrail: `ParkingLotAnnouncement` is the canonical announcement model; `Post` is explicitly out of scope.
- No `project-context.md` file was present in the repository at story creation time.

### File List

- `_bmad-output/implementation-artifacts/6-2-configure-announcements.md`
