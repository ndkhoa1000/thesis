# Story 5.4: En-route Lot Capacity Alert

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Driver,
I want to be notified if the lot I am navigating to becomes full,
so that my expectations are managed without forced rerouting.

## Acceptance Criteria

1. Given I have tapped Navigate for a specific lot, when the lot capacity reaches 100% while I am en-route, then I receive a temporary UI alert indicating the lot has recently filled up.
2. And the system does not force an auto-reroute, respecting my navigation autonomy.

## Implementation Clarifications

- Story 5.4 is an in-app alerting experience, not the push-notification system reserved for Epic 10.
- This story depends on Story 5.1's backend-backed map state and should reuse the same selected-lot identity instead of inventing a parallel watchlist.
- The alert is advisory only. It must not alter the user's navigation destination automatically.
- Availability changes should come from the backend's canonical realtime channel or an equivalent server-owned delivery path, not from client polling loops that duplicate business logic.

## Tasks / Subtasks

- [x] Task 1: Add realtime availability delivery for driver lot watching (AC: 1, 2)
  - [x] Introduce or expose a FastAPI-managed realtime availability channel that emits lot-capacity updates in a driver-consumable event shape.
  - [x] Publish updates from the same availability mutation boundary already used by sessions and future bookings rather than duplicating write paths.
  - [x] Keep the contract advisory and read-only for drivers.

- [x] Task 2: Wire en-route alert behavior into the driver map/navigation flow (AC: 1, 2)
  - [x] Track the currently navigated lot in the map/discovery feature.
  - [x] Subscribe to availability updates and surface a temporary alert when that lot transitions to full.
  - [x] Ensure the alert does not reroute, dismiss the map, or block continued navigation.

- [x] Task 3: Add focused regression coverage (AC: 1, 2)
  - [x] Add backend tests for availability event publication around lot-capacity changes.
  - [x] Add Flutter tests for en-route alert display and non-rerouting behavior when a watched lot becomes full.
  - [x] Verify backend in Docker and Flutter locally after wiring the flow.

## Dev Notes

### Story Foundation

- The architecture already expects backend-owned realtime availability updates over WebSocket or SSE after session and booking mutations.
- Story 5.4 should sit on top of Story 5.1 map discovery rather than introducing a new navigation product surface.
- Epic 10 owns system-level push notifications; this story must stay in-app and temporary.

### Domain Constraints To Respect

- The alert only applies when the driver has actively chosen a navigation target lot.
- The alert is informational; driver autonomy must be preserved.
- The authoritative fullness signal is lot availability reaching zero or equivalent full-state semantics on the backend.

### Architecture Guardrails

- Prefer FastAPI WebSocket delivery if feasible, with SSE only as a fallback if implementation cost forces it.
- Publish a single canonical lot-availability event shape so map markers, lot details, and en-route alerts can share the same stream.
- Keep mobile alert state scoped to the driver discovery flow rather than introducing a global notification subsystem early.

### Library / Framework Requirements

- Flutter: reuse the map/discovery feature state, `dio` for initial data, and a lightweight websocket client if needed.
- Backend: FastAPI realtime endpoint/service, existing sessions and bookings mutation boundaries.
- Do not introduce FCM, local notification plugins, or route-optimization SDKs in this story.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/`
  - `backend/src/app/models/parking.py`
  - `backend/src/app/api/v1/sessions.py`
  - `backend/src/app/api/v1/bookings.py`
  - `backend/tests/`
- Mobile:
  - `mobile/lib/src/features/map_discovery/`
  - `mobile/lib/src/core/`
  - `mobile/test/`

### Testing Requirements

- Backend verification should run through Docker pytest.
- Flutter verification should run with local `flutter test`.
- Realtime tests may validate event publication and state transitions with controlled fakes rather than requiring a full live socket integration in every test.

### Implementation Risks To Avoid

- Do not turn this into an Epic 10 push-notification implementation.
- Do not poll the lot-detail endpoint repeatedly as a substitute for a realtime availability contract unless a documented fallback is explicitly accepted.
- Do not force route changes or navigation cancellation when the alert fires.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 5 / Story 5.4
- [prd.md](../prd.md) - FR1, NFR4, NFR17
- [architecture.md](../architecture.md) - Realtime availability and map delivery principles
- [tech-design.md](../tech-design.md) - Backend-owned realtime strategy
- [5-1-view-interactive-map-lots.md](./5-1-view-interactive-map-lots.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Add a backend-owned lot availability event contract and websocket stream that drivers can consume without introducing push notifications.
- Publish availability changes from the existing parking-session and operator lot-configuration mutation boundaries after successful commits.
- Extend the driver map discovery flow with a lightweight "Navigate" target, live availability updates, and a temporary advisory alert when the watched lot becomes full.
- Add focused backend and Flutter regression coverage, then verify through Docker pytest and local flutter test.

### Completion Notes List

- Story created as an in-app advisory alert layered on top of Epic 5 map discovery, explicitly separated from the later push-notification epic.
- Current codebase anchor: realtime availability delivery is still a planned gap, so this story documents both the backend event seam and the driver-side alert boundary.
- Added an authenticated FastAPI websocket stream at `/lots/availability/stream` with a canonical `lot_availability.updated` payload for driver-facing availability updates.
- Published availability events from the existing attendant check-in, walk-in check-in, checkout finalize/undo, and operator lot configuration flows after successful commits.
- Extended the driver map quick cards with a `Dẫn đường` action, tracked the active navigation target in the discovery flow, and surfaced a temporary advisory alert when that lot transitions to full without clearing the route target.
- Validation passed with `cd backend && docker compose run --rm pytest python -m pytest tests/test_lot_availability_events.py`, `cd mobile && flutter test test/map_discovery_screen_test.dart`, and `cd mobile && flutter test test/widget_test.dart`.

### File List

- `_bmad-output/implementation-artifacts/5-4-en-route-lot-capacity-alert.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/lots.py`
- `backend/src/app/api/v1/sessions.py`
- `backend/src/app/core/lot_availability.py`
- `backend/src/app/schemas/parking_lot.py`
- `backend/tests/test_lot_availability_events.py`
- `mobile/lib/src/features/map_discovery/data/map_discovery_service.dart`
- `mobile/lib/src/features/map_discovery/presentation/map_discovery_screen.dart`
- `mobile/test/map_discovery_screen_test.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-28: Created Story 5.4 implementation artifact for backend-owned en-route fullness alerts without forced rerouting.
- 2026-03-28: Implemented Story 5.4 with a backend availability websocket, canonical event publication from lot/session mutation boundaries, driver en-route alerts on the map flow, and focused backend/mobile regression coverage.