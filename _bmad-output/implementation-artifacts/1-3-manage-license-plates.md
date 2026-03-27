# Story 1.3: Manage License Plates

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a driver,
I want to add and remove vehicle license plates on my profile,
so that the system and lot attendants can identify my vehicle.

## Acceptance Criteria

1. Given I am logged into the public mobile app, when I add a new vehicle plate, then it is saved to my profile and shown in my registered vehicles list.
2. Given I already have registered vehicles, when I open the vehicle management screen, then I can see the full list of my saved plates.
3. Given I no longer use a saved vehicle, when I remove it, then it disappears from my list and is no longer selectable for later parking flows.
4. Duplicate license plates are rejected with a clear backend-driven error message.
5. Vehicle records created in this story stay tied to the authenticated driver's existing public account and current `driver` profile.

## Implementation Clarifications

- Keep this story focused on driver vehicle records, not on attendant check-in, QR generation, or photo uploads.
- Use the existing `vehicle` table and `Vehicle` model as the storage base instead of inventing a parallel profile structure.
- Because upcoming parking flows need vehicle type, the create/edit contract should at minimum support `license_plate` and `vehicle_type`, while optional brand/color/photos can stay deferred.
- Vehicle access must be scoped to the current authenticated driver only; do not expose cross-user vehicle management.

## Tasks / Subtasks

- [x] Task 1: Define the vehicle-profile contract on top of the existing schema (AC: 1, 2, 4, 5)
  - [x] Add the missing Pydantic schemas for vehicle create/read/delete flows under `backend/src/app/schemas`.
  - [x] Decide plate normalization rules for MVP, including trimming, casing, and duplicate comparison behavior.
  - [x] Keep the API response small and mobile-friendly, returning only fields needed by Story 1.3 and later check-in flows.

- [x] Task 2: Implement backend vehicle management for the authenticated driver (AC: 1, 2, 3, 4, 5)
  - [x] Add driver-scoped vehicle endpoints under the existing users/profile domain, reusing `backend/src/app/api/v1/users.py` unless a cleaner vehicle submodule is clearly better.
  - [x] Resolve the current authenticated `user` to its linked `driver` record before reading or mutating vehicle data.
  - [x] Support listing current vehicles, creating a vehicle, and deleting a vehicle.
  - [x] Reject duplicate license plates with the backend exception style already used by auth and users.

- [x] Task 3: Add a minimal mobile vehicle management flow for the public account shell (AC: 1, 2, 3)
  - [x] Introduce a simple vehicle management screen reachable from the authenticated public flow.
  - [x] Show the current list of saved plates and provide a compact add/remove UI.
  - [x] Preserve the current authenticated session and map prototype while adding this screen.

- [x] Task 4: Guard business rules needed by upcoming parking flows (AC: 3, 4, 5)
  - [x] Prevent deleting a vehicle that is still referenced by future protected flows if the current backend rules require it; otherwise document the temporary MVP behavior.
  - [x] Ensure only driver-capable public accounts can manage vehicle records.
  - [x] Make error states explicit enough for mobile to surface actionable messages.

- [x] Task 5: Test backend and mobile vehicle management (AC: 1, 2, 3, 4, 5)
  - [x] Add backend tests for list/create/delete, duplicate rejection, and driver ownership enforcement.
  - [x] Add at least one Flutter test covering list rendering or add/remove behavior.
  - [x] Smoke-test the end-to-end flow on the current Android device/backend setup used for Story 1.2.

## Dev Notes

### Story Foundation

- Story 1.1 established the public driver account bootstrap.
- Story 1.2 established authenticated public sessions and capability-aware routing.
- Story 1.3 should now attach driver-owned vehicle data to that authenticated public account.

### Relevant Existing Backend Assets

- `backend/src/app/models/vehicles.py` already defines `Vehicle` with `driver_id`, `license_plate`, `vehicle_type`, and optional metadata fields.
- `backend/src/app/models/enums.py` already defines `VehicleType` values for `MOTORBIKE` and `CAR`.
- `backend/src/app/api/v1/users.py` is currently the nearest existing module for profile-style endpoints and is the preferred first place to extend.

### Scope Guardrails

- Do not expand this story into Cloudinary uploads, vehicle photos, or verification workflows unless the current code path absolutely requires placeholders.
- Do not implement parking session selection yet; only make the data ready for later stories.
- Keep the mobile UI intentionally narrow: a vehicle list plus add/remove interactions is sufficient for this story.

### Suggested File Areas For This Story

- Backend:
  - `backend/src/app/api/v1/users.py`
  - `backend/src/app/models/vehicles.py`
  - `backend/src/app/schemas/`
  - `backend/tests/`
- Mobile:
  - `mobile/lib/main.dart`
  - `mobile/lib/src/features/`
  - `mobile/test/`

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 1 / Story 1.3
- [prd.md](../prd.md) - FR46 and driver identity/vehicle requirements
- [tech-design.md](../tech-design.md) - Sections 3 and 8
- [1-2-user-login.md](./1-2-user-login.md)
- [users.py](../../backend/src/app/api/v1/users.py)
- [vehicles.py](../../backend/src/app/models/vehicles.py)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Tasks 1 & 2 were partially complete from a prior session: `VehicleCreate`/`VehicleRead` schemas and three endpoints (`GET/POST /user/me/vehicles`, `DELETE /user/me/vehicles/{id}`) were already in `users.py`.
- Task 1: Plate normalization: `normalize_license_plate()` trims, uppercases, and collapses whitespace. Empty-after-strip now raises `BadRequestException("License plate is required")` so blank input is treated as validation failure instead of conflict. Duplicate check remains global because `vehicle.license_plate` is unique.
- Task 2: `_get_driver_for_user()` helper resolves `user → driver`; accepts DRIVER, LOT_OWNER, MANAGER roles for driver capability (AC 5).
- Task 3: Created `VehicleService` abstract contract + `BackendVehicleService` (Dio) in `mobile/lib/src/features/vehicles/data/`. Created `VehicleScreen` with list view, add dialog (SegmentedButton for MOTORBIKE/CAR), and delete confirmation in `mobile/lib/src/features/vehicles/presentation/`.
- The public authenticated shell no longer blocks vehicle management when `MAPBOX_ACCESS_TOKEN` is absent. The same `Xe của tôi` entry is now reachable from both the map shell and the fallback public shell, so Story 1.3 is usable on current dev setups without Mapbox.
- Task 4: Driver-only guard already enforced by `_get_driver_for_user()`; ATTENDANT/ADMIN roles raise `ForbiddenException`. Delete endpoint checks `vehicle.driver_id == driver.id`. MVP deletion is unrestricted (no active session check needed at this stage).
- Task 5: 16 unit tests in `backend/tests/test_vehicles.py` now cover normalization, blank-input validation, list/create/delete flows, duplicate rejection, and ownership enforcement. Backend verification passed in Docker with `docker compose run --rm pytest` (`34 passed`).
- Added Flutter widget coverage for Story 1.3 in `mobile/test/widget_test.dart`: one test confirms the vehicle-management entry remains reachable without Mapbox, and one test exercises add/remove behavior on `VehicleScreen`. `flutter test` passes locally.

### File List

- `backend/src/app/api/v1/users.py` (modified — vehicle endpoints + helpers)
- `backend/src/app/schemas/vehicle.py` (modified — VehicleCreate, VehicleRead)
- `backend/tests/test_vehicles.py` (new — 15 unit tests)
- `backend/Dockerfile` (modified — added `--dev --all-extras` to `uv sync`)
- `mobile/lib/main.dart` (modified — imports, MapScreen receives session, car-icon AppBar button)
- `mobile/lib/src/features/vehicles/data/vehicle_service.dart` (new — Vehicle model, VehicleService, BackendVehicleService, VehicleException)
- `mobile/lib/src/features/vehicles/presentation/vehicle_screen.dart` (new — VehicleScreen + _AddVehicleDialog)
- `mobile/test/widget_test.dart` (modified — Story 1.3 widget coverage)
- `_bmad-output/implementation-artifacts/1-3-manage-license-plates.md` (this file)

### Change Log

- 2026-03-27: Finalized Story 1.3 by unblocking vehicle management from the no-Mapbox fallback shell, correcting blank-plate validation semantics, adding Flutter widget coverage, and re-verifying backend tests in Docker (`34 passed`) plus local Flutter tests.