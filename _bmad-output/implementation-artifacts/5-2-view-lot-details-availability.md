# Story 5.2: View Lot Details & Availability

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Driver,
I want to tap a lot to see its details, realtime availability, and historical trends,
so that I can decide if I want to park there.

## Acceptance Criteria

1. Given I select a lot on the map, when the details open, then I see price, hours, and available spots.
2. And I can view a Historical Peak Hours chart to anticipate if the lot will fill up by my estimated arrival time.

## Implementation Clarifications

- Story 5.2 builds on Story 5.1 and should consume the selected lot identity from the map feature rather than reintroducing a separate lot-search workflow.
- The current bottom-sheet in `mobile/lib/main.dart` is only a mock placeholder. Replace it with a backend-backed detail model and presentation flow.
- Realtime availability here means the detail view must be able to refresh the visible availability state when upstream lot availability changes; it does not require a second business source beyond the canonical lot availability contract.
- The historical peak-hours chart should be derived from server-owned data. Do not synthesize fake trend data in the mobile layer once the story is implemented.
- Keep this story read-only. Booking, navigation start, and alerting belong elsewhere.

## Tasks / Subtasks

- [ ] Task 1: Add a driver-facing lot-details backend contract (AC: 1, 2)
  - [ ] Extend the lots API with a focused detail endpoint such as `GET /lots/{lot_id}` that returns the lot summary, effective pricing snapshot, operating hours, features/tags, and current availability.
  - [ ] Add a server-owned trend payload for the Historical Peak Hours visualization, using deterministic historical or aggregate occupancy data rather than client-generated guesses.
  - [ ] Reject missing or inaccessible lots without leaking suspended or unauthorized inventory.

- [ ] Task 2: Build the mobile lot-details experience on top of Story 5.1 (AC: 1, 2)
  - [ ] Introduce a dedicated lot-details feature module and typed DTOs instead of keeping an ad hoc modal in `main.dart`.
  - [ ] Render pricing, hours, capacity/availability, tags/features, and the trend chart in a driver-friendly detail surface.
  - [ ] Ensure the detail view can accept fresh availability updates cleanly so Story 5.4 and later realtime work can reuse the same state boundary.

- [ ] Task 3: Add focused regression coverage (AC: 1, 2)
  - [ ] Add backend tests for lot-detail reads, missing-lot rejection, and trend payload shape.
  - [ ] Add Flutter tests for detail rendering, empty/blocked trend states, and driver-facing availability display.
  - [ ] Verify backend in Docker and Flutter locally after wiring the flow.

## Dev Notes

### Story Foundation

- The current driver map already opens a basic bottom sheet with name, address, price, and capacity text, but it is driven by mock objects and does not represent the final API contract.
- Backend parking models already contain the raw data needed for this story: `ParkingLot`, `ParkingLotConfig`, `Pricing`, `ParkingLotFeature`, `ParkingLotTag`, and `ParkingLotAnnouncement`.
- Epic 5 planning explicitly expects a read-heavy driver decision surface rather than a transactional flow here.

### Domain Constraints To Respect

- Only public driver-visible lot data should be returned. Internal operator-only details must stay out of the payload.
- Hours and pricing shown to the driver must reflect the currently effective configuration, not stale or future draft values.
- Historical trend data must be derived from actual stored occupancy/session history when available; if insufficient data exists, surface an honest empty state rather than fabricated analytics.

### Architecture Guardrails

- Reuse the existing lots router and schema modules instead of creating a disconnected driver-only API family.
- Prefer a single detail endpoint that aggregates the driver-safe read model server-side.
- Keep the mobile detail flow as its own feature module so the map remains a summary surface and the detail view owns richer rendering concerns.
- If realtime availability is introduced as part of this story, route it through the same availability event shape planned in architecture instead of polling multiple bespoke endpoints.

### Library / Framework Requirements

- Flutter: `dio`, `mapbox_maps_flutter`, charting library already approved by the repo if one exists; otherwise choose a lightweight Flutter chart package only if necessary.
- Backend: FastAPI lots router, async SQLAlchemy joins, Pydantic response models.
- Avoid introducing analytics or BI tooling; this is still a thesis-scope read model.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/lots.py`
  - `backend/src/app/models/parking.py`
  - `backend/src/app/models/notifications.py`
  - `backend/src/app/schemas/parking_lot.py`
  - `backend/tests/test_parking_lots.py`
- Mobile:
  - `mobile/lib/src/features/map_discovery/`
  - `mobile/lib/src/features/lot_details/`
  - `mobile/test/`

### Testing Requirements

- Backend verification should run through Docker pytest.
- Flutter verification should run with local `flutter test`.
- Chart rendering tests may assert visible labels and empty-state behavior rather than pixel-perfect chart geometry.

### Implementation Risks To Avoid

- Do not keep Story 5.2 tied to mock bottom-sheet data once backend wiring exists.
- Do not expose operator-only configuration or unpublished announcements to drivers.
- Do not fabricate peak-hours data in the client merely to satisfy chart UX.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 5 / Story 5.2
- [prd.md](../prd.md) - FR1, FR3, NFR1, NFR17
- [architecture.md](../architecture.md) - Lots, announcements, realtime availability, thin-client principles
- [tech-design.md](../tech-design.md) - Lots module plan and backend-owned data flows
- [5-1-view-interactive-map-lots.md](./5-1-view-interactive-map-lots.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Story created as the read-only lot decision surface that sits directly on top of Story 5.1 map discovery.
- Current codebase anchor: the existing map bottom sheet is only a placeholder and should be replaced by a dedicated detail feature with backend-owned data.

### File List

- `_bmad-output/implementation-artifacts/5-2-view-lot-details-availability.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

### Change Log

- 2026-03-28: Created Story 5.2 implementation artifact for backend-backed lot details, effective pricing/hours, and historical peak-hours trend presentation.