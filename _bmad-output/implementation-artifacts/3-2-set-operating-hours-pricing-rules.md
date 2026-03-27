# Story 3.2: Set Operating Hours & Pricing Rules

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an Operator,
I want to define operating hours and pricing rules,
so that fees calculate automatically at check-out.

## Acceptance Criteria

1. Given I am authenticated as an Operator with an active lot lease, when I open the operator workspace, then I can view the current operating hours and active pricing rule for each managed lot.
2. Given I am configuring a managed lot, when I save opening time, closing time, pricing mode, and price amount, then the backend persists the latest lot-wide operating/pricing configuration and the mobile workspace reflects the new values.
3. Given I save new operating hours for a managed lot, when later check-in flows are implemented, then the newest `ParkingLotConfig` record exposes the lot-wide `opening_time` and `closing_time` needed by those workflows.
4. Given I save a pricing rule for a managed lot, when later check-out flows are implemented, then the newest lot-wide `Pricing` record exposes the active `pricing_mode` and `price_amount` needed for fee calculation.
5. Given I am not managing a lot through an active lease, when I try to update operating hours or pricing for that lot, then the operator contract rejects the request.

## Implementation Clarifications

- This story extends the existing Story 3.1 operator lot-management contract instead of creating a second Operator workspace.
- Operating hours are stored on a new lot-wide `ParkingLotConfig` version together with total capacity using `vehicle_type = ALL`.
- Pricing is stored as a new lot-wide `Pricing` version using `vehicle_type = ALL`.
- The operator UI in this story manages the currently active rule set only; fee calculation itself remains part of Epic 4.
- Future-dated scheduling remains out of scope for this story even though the underlying models support effective date fields.

## Tasks / Subtasks

- [x] Task 1: Extend operator lot-management backend contracts (AC: 1, 2, 3, 4, 5)
  - [x] Add operator-facing read/update schema fields for operating hours and pricing.
  - [x] Return the newest lot-wide operating/pricing configuration in the managed-lot list response.
  - [x] Persist new `ParkingLotConfig` and `Pricing` versions when an Operator updates a managed lot.

- [x] Task 2: Extend the mobile Operator workspace (AC: 1, 2)
  - [x] Show operating hours and pricing details in each managed lot card.
  - [x] Expand the configuration form to edit opening time, closing time, pricing mode, and price amount.
  - [x] Keep the workspace in the same Operator flow introduced in Story 3.1.

- [x] Task 3: Add focused regression coverage (AC: 2, 3, 4, 5)
  - [x] Add backend tests for lot-wide operating/pricing retrieval and persistence.
  - [x] Add Flutter widget coverage for updating hours and pricing from the Operator workspace.
  - [x] Verify backend in Docker and Flutter locally after wiring the new flow.

## Dev Notes

### Story Foundation

- Story 3.1 already established the active-lease operator workspace and the versioned `ParkingLotConfig` pattern for total capacity.
- The `Pricing` model already exists in the backend domain and is the natural persistence target for this story.
- Epic 4 will consume the data path created here for fee calculation and check-in/check-out validation.

### Domain Constraints To Respect

- Only active leased lots may be configured by an Operator.
- Story 3.2 should keep using lot-wide `vehicle_type = ALL` rows rather than introducing per-vehicle pricing complexity.
- This story persists the configuration data required for later session flows, but does not implement fee calculation itself.

### Suggested File Areas For This Story

- Backend:
  - `backend/src/app/api/v1/lots.py`
  - `backend/src/app/schemas/parking_lot.py`
  - `backend/tests/test_operator_lot_management.py`
- Mobile:
  - `mobile/lib/main.dart`
  - `mobile/lib/src/features/operator_lot_management/`
  - `mobile/test/widget_test.dart`

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 3 / Story 3.2
- [prd.md](../prd.md) - FR28, FR29
- [tech-design.md](../tech-design.md)
- [3-1-configure-lot-details-capacity.md](./3-1-configure-lot-details-capacity.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Extended the existing Story 3.1 operator contract to return and persist lot-wide opening hours, closing hours, pricing mode, and price amount.
- Reused `ParkingLotConfig` for lot-wide hours/capacity and `Pricing` for lot-wide pricing versions with `vehicle_type = ALL`.
- Expanded the mobile Operator workspace so each managed lot now shows operating hours and active pricing, and the same bottom-sheet form updates those values.
- Focused backend verification passed in Docker with `tests/test_operator_lot_management.py`.
- Focused Flutter verification passed locally with `flutter test test/widget_test.dart`, and the app successfully launched on the connected Android device for smoke validation.

### File List

- `_bmad-output/implementation-artifacts/3-2-set-operating-hours-pricing-rules.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/lots.py`
- `backend/src/app/schemas/parking_lot.py`
- `backend/tests/test_operator_lot_management.py`
- `mobile/lib/src/features/operator_lot_management/data/operator_lot_management_service.dart`
- `mobile/lib/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-27: Created Story 3.2 implementation artifact and clarified the current-story scope for operating hours and lot-wide pricing rules.
- 2026-03-27: Implemented lot-wide operating hours and pricing rule persistence on top of the existing operator lot-management flow.
- 2026-03-27: Verified Story 3.2 with focused backend Docker tests, local Flutter widget tests, and Android smoke launch on the connected device.