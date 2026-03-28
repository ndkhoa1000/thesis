# Story 5.1: View Interactive Map & Lots

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Driver,
I want to see active parking lots on a map with clear capacity indicators,
so that I can locate nearby parking instantly.

## Acceptance Criteria

1. Given I am on the Map tab, when it loads, then I see pins for ACTIVE lots.
2. And given I deny GPS location permissions, when the map initializes, then I receive a gentle fallback UI and the app still opens in a default city view instead of blocking or crashing.
3. And the lot markers use dynamic color-coded pins that expose the current available slot count without requiring a tap.
4. And map pins are clustered when zoomed out to prevent visual clutter.

## Implementation Clarifications

- This story is the first backend-connected replacement for the current mock `MapScreen` implementation in `mobile/lib/main.dart`.
- The driver map must consume FastAPI lot data through authenticated API calls. Do not keep mock parking-lot data as the source of truth once this story is implemented.
- Only ACTIVE / APPROVED lots should appear on the map for drivers.
- The map should remain usable when location permission is denied by centering on a sensible default city viewport rather than hard-failing location features.
- Marker clustering and availability color semantics should be implemented in a way that Story 5.4 can later subscribe to realtime changes without replacing the whole map feature.
- Do not expand this story into booking, navigation, or parking-history concerns.

## Tasks / Subtasks

- [x] Task 1: Introduce backend-backed driver lot-discovery contract (AC: 1, 3)
  - [x] Reuse or extend `GET /lots` in `backend/src/app/api/v1/lots.py` so driver clients receive only active lots with coordinates, availability, and enough summary metadata for map markers.
  - [x] Keep the response read-only; this story does not mutate lots, sessions, or bookings.
  - [x] Preserve the current backend pattern of explicit schema builders and role-safe access checks.

- [x] Task 2: Move the driver map into a dedicated feature module (AC: 1, 2, 3, 4)
  - [x] Extract the temporary `MapScreen` logic from `mobile/lib/main.dart` into a dedicated feature folder such as `mobile/lib/src/features/map_discovery/`.
  - [x] Add a typed service and model layer that fetches lot markers from FastAPI using `Dio` and the authenticated access token.
  - [x] Render clustered markers with color-coded availability states and visible counts, replacing mock marker text rendering.
  - [x] Keep a non-blocking fallback viewport when location permission is denied.

- [x] Task 3: Add focused regression coverage (AC: 1, 2, 3, 4)
  - [x] Add backend tests for the driver lot-list contract, verifying inactive lots are excluded and the payload exposes coordinates plus availability.
  - [x] Add Flutter widget or integration-oriented tests for marker rendering, permission-denied fallback UI, and marker color/availability labeling behavior.
  - [x] Verify backend in Docker and Flutter locally after wiring the feature.

## Dev Notes

### Story Foundation

- Epic 5 starts from an existing Flutter `MapScreen` skeleton in `mobile/lib/main.dart`, but it is still powered by mock data and modal-only detail rendering.
- The backend already exposes `GET /lots` in `backend/src/app/api/v1/lots.py`, returning `ParkingLotRead` items with coordinates and `current_available`.
- `ParkingLot.current_available` is an intentional denormalized cache and should remain the map's availability source instead of client-side recomputation.

### Domain Constraints To Respect

- Drivers only see APPROVED / ACTIVE lots suitable for discovery.
- The mobile client must not talk directly to Mapbox data services for business entities; lot discovery remains backend-owned.
- Location denial is not an error state for the product. The user must still be able to browse lots manually.
- This story must not introduce direct database or realtime dependencies into Flutter outside the FastAPI gateway.

### Architecture Guardrails

- Reuse `mapbox_maps_flutter`, `dio`, and the existing authenticated service-factory pattern already used by other Flutter features.
- Prefer a new `map_discovery` feature module over extending `main.dart` further.
- Keep API DTO parsing explicit with `fromJson` factories and defensive date/number conversion where needed.
- Story 5.4 will depend on this feature; leave a clean seam for realtime availability updates instead of baking all state into the widget tree.

### Library / Framework Requirements

- Flutter: `mapbox_maps_flutter`, `permission_handler`, `dio`
- Backend: FastAPI router patterns, async SQLAlchemy, Pydantic schemas
- Do not introduce a new map provider or alternate HTTP client for this story.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/lots.py`
  - `backend/src/app/schemas/parking_lot.py`
  - `backend/tests/test_parking_lots.py`
- Mobile:
  - `mobile/lib/main.dart` (only to reroute into the extracted feature)
  - `mobile/lib/src/features/map_discovery/`
  - `mobile/test/`

### Testing Requirements

- Backend verification should run through the Docker pytest service using the repo convention.
- Flutter verification should run with local `flutter test`.
- Prefer deterministic widget tests for fallback UI and marker-state logic even if full Mapbox rendering remains hard to assert directly.

### Implementation Risks To Avoid

- Do not keep mock lot data as the production data source once the backend contract is wired.
- Do not hard-block the map on GPS permission or device geolocation failures.
- Do not couple Story 5.1 to lot-detail, navigation, or history APIs beyond the minimum summary payload needed for markers.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 5 / Story 5.1
- [prd.md](../prd.md) - FR1, FR2, NFR1, NFR4, NFR17
- [architecture.md](../architecture.md) - Mobile client, lot APIs, realtime availability principles
- [tech-design.md](../tech-design.md) - Mobile migration strategy, lots API reuse

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Story created from Epic 5 planning with explicit guardrails to replace the current mock map implementation with backend-backed discovery.
- Current codebase anchor: the temporary driver map lives in `mobile/lib/main.dart`; this story should extract it into a dedicated feature module rather than extending the bootstrap file further.
- Reused the existing `GET /lots` contract as the driver discovery backend and added a marker-summary regression test to lock coordinates, availability, and approved-only payload expectations.
- Extracted the driver map into `mobile/lib/src/features/map_discovery/` with a dedicated Dio-backed service, permission fallback notice, activity summary/legend, and a production Mapbox canvas that renders clustered GeoJSON layers plus color-coded availability counts.
- Removed the obsolete mock `MapScreen` implementation from `mobile/lib/main.dart` so the bootstrap file now routes into the extracted feature instead of holding map domain logic directly.
- Added focused Flutter coverage for backend lot loading, cluster-enabled marker state handoff, and denied-location fallback messaging, then validated with the full Flutter suite (`48 passed`) and full backend suite (`131 passed`).
- Resolved the post-review follow-ups by making cluster markers neutral instead of availability-colored, replacing the hard `MAPBOX_ACCESS_TOKEN` gate with an in-app fallback canvas, and removing the stray walk-in upload artifact from the repo.
- Revalidated after the review-fix pass with focused Flutter/backend suites plus the current full regressions (`49 passed` Flutter, `134 passed` backend).

### File List

- `_bmad-output/implementation-artifacts/5-1-view-interactive-map-lots.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/tests/test_parking_lots.py`
- `mobile/lib/main.dart`
- `mobile/lib/src/features/map_discovery/data/map_discovery_service.dart`
- `mobile/lib/src/features/map_discovery/presentation/map_discovery_screen.dart`
- `mobile/test/map_discovery_screen_test.dart`

### Change Log

- 2026-03-28: Created Story 5.1 implementation artifact for backend-backed map discovery, permission fallback, and clustered availability markers.
- 2026-03-28: Implemented Story 5.1 by extracting the driver map into a backend-backed `map_discovery` feature, locking the lot marker contract with tests, and validating full backend/mobile regressions.
- 2026-03-28: Cleared Story 5.1 review findings by normalizing cluster semantics, adding a non-blocking map fallback canvas, and deleting the stray upload artifact before rerunning focused and full validation.