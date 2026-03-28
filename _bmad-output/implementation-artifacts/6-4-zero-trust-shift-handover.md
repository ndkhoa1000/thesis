# Story 6.4: Zero-Trust Shift Handover

Status: review

## Story

As an Attendant,
I want to transfer my shift and cash balance to the incoming attendant via QR scan,
so that financial accountability is strictly enforced.

## Acceptance Criteria

1. Given I am the outgoing attendant ending my shift, when I start shift handover, then the system calculates the expected cash total for that shift and generates a Shift QR payload for transfer.
2. Given I am the incoming attendant, when I scan the Shift QR and enter the actual cash counted, then the shift is locked and transferred if the amount matches the expected cash.
3. Given the actual cash does not match the expected cash, when I proceed with handover, then I am blocked by a full-screen discrepancy flow that requires a text rationale before the handover can be completed and flagged.
4. Given a discrepancy is submitted, when the handover completes, then the system stores the discrepancy details and notifies the responsible operator through the application's existing in-app notification domain rather than a new push-notification integration.

## Implementation Clarifications

- This story introduces a new shift-handover domain seam that is described in the architecture but not yet implemented in the current codebase.
- The discrepancy flow is intentionally high-friction and high-contrast because it is a financial-control action, not a high-speed gate action.
- UX documents mention operator alerts; Epic 10 owns real push notifications, so this story should persist an in-app `Notification` record or equivalent backend alert state instead of adding FCM/device-push infrastructure.
- Baseline data-model assumption for this story: add an explicit `Shift` domain that tracks `parking_lot_id`, `attendant_id`, `started_at`, `ended_at`, and a lifecycle status such as `OPEN`, `HANDOVER_PENDING`, and `LOCKED`; add a separate `ShiftHandover` record that stores outgoing shift identity, incoming attendant identity, expected cash, actual cash, discrepancy reason, and completion timestamps.
- `expected_cash` should be backend-derived from completed cash `Payment` records linked to parking sessions finalized by the outgoing attendant during the shift window. Do not extend `Payment.payable_type` to `SHIFT` for this story; payments remain session-linked and shift totals are aggregated from them.
- Minimum in-app operator notification acceptance for Epic 6 is: persist a `Notification` record and make that alert visible from the current operator workspace if no dedicated notification inbox already exists.

## Tasks / Subtasks

- [x] Task 1: Add backend shift and handover domain support (AC: 1, 2, 3, 4)
  - [x] Introduce `Shift` and `ShiftHandover` persistence plus the minimum service layer needed to compute `expected_cash`, issue a Shift QR payload, and record handover completion.
  - [x] Lock the outgoing shift after successful handover to prevent post-handover cash drift.
  - [x] Persist discrepancy details, including actual cash and rationale, when the incoming attendant reports a mismatch.

- [x] Task 2: Add shift handover endpoints and operator alert creation (AC: 1, 2, 3, 4)
  - [x] Create a shift-handover API surface consistent with the architecture's `/shifts/*` direction.
  - [x] Reuse the existing notification domain for operator alert creation when discrepancies occur.
  - [x] Keep authentication and lot assignment strict for both outgoing and incoming attendants.
  - [x] Expose a minimum operator-facing read path for discrepancy alerts if no existing notification feed already surfaces `Notification` records.

- [x] Task 3: Implement the mobile QR handover flow for attendants (AC: 1, 2, 3)
  - [x] Add an outgoing flow that ends the current shift and displays the Shift QR.
  - [x] Add an incoming flow that scans the Shift QR, collects the counted cash amount, and finalizes handover.
  - [x] Use a hard-blocking, high-contrast discrepancy screen that cannot be dismissed without submitting the required rationale.

- [x] Task 4: Add focused regression coverage and verification (AC: 1, 2, 3, 4)
  - [x] Add backend tests for expected-cash calculation, shift locking, discrepancy persistence, and operator alert creation.
  - [x] Add Flutter tests for QR handover happy path and hard-blocking discrepancy UX behavior.
  - [x] Verify with backend Docker tests and local `flutter test`.

## Dev Notes

### Story Foundation

- Architecture section 4.7 explicitly defines the QR-based zero-trust shift handover flow and the required discrepancy reason.
- UX specification elevates this as a critical financial-integrity pattern with a serious, high-contrast discrepancy screen.
- Epic 6 Story 6.4 is the first place where shift accountability becomes a concrete implementation artifact.

### Domain Constraints To Respect

- Shift handover must be attendant-to-attendant and lot-scoped.
- Expected cash must be backend-calculated from recorded shift cash payments, not typed in by the outgoing attendant.
- Discrepancy rationale is mandatory when cash does not match.
- Payments remain session-linked; shift cash is an aggregate reporting/control concern rather than a new payment target.

### Architecture Guardrails

- Follow the architecture's `/shifts/*` API direction and `shift_service.py` service concept.
- Reuse the existing `Notification` domain for operator alerts; do not add true push delivery in Epic 6.
- Keep the discrepancy UX as a hard-blocking modal/overlay and not a toast or dismissible sheet.
- Do not start implementation until the `Shift` and `ShiftHandover` persistence shape is created in code and tests, because the current repository does not contain this domain yet.

### Library / Framework Requirements

- Backend: FastAPI + SQLAlchemy consistent with the existing domain modules.
- Mobile: Flutter QR scanning patterns already used in the attendant feature; use them rather than introducing another scanner stack.
- Do not add FCM, local notification plugins, or a background push pipeline in this story.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/shifts.py`
  - `backend/src/app/services/shift_service.py`
  - `backend/src/app/models/financials.py` and/or new shift-domain models as needed
  - `backend/src/app/models/notifications.py`
  - `backend/src/app/schemas/`
  - `backend/tests/`
- Mobile:
  - `mobile/lib/src/features/attendant_check_in/` if handover is added there
  - or `mobile/lib/src/features/shift_handover/` if split into a dedicated feature
  - `mobile/lib/src/core/`
  - `mobile/test/`

### Testing Requirements

- Backend tests should validate cash total calculation, lot/attendant authorization, duplicate handover prevention, and discrepancy alert persistence.
- Flutter tests should validate the match flow, mismatch hard-blocking modal, and mandatory rationale enforcement.
- Verification should use backend Docker tests and local `flutter test`.

### Implementation Risks To Avoid

- Do not treat operator alerting here as full push-notification delivery.
- Do not let attendants bypass the discrepancy rationale by backing out or tapping outside the overlay.
- Do not calculate expected cash on the client.

### Recent Repository Patterns

- The current attendant flow already relies on QR scanning and fast operational feedback; reuse that scanner investment for shift QR interactions.
- Recent stories have separated backend source-of-truth mutations from lightweight Flutter orchestration, which should continue here.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 6 / Story 6.4
- [architecture.md](../architecture.md) - section 4.7 Zero-Trust Shift Handover, API design principles, backend project shape
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - QR Shift Handover, discrepancy reporting UX, hard-blocking modal guidance
- [prd.md](../prd.md) - operator financial accountability context and notification strategy
- [tech-design.md](../tech-design.md) - backend module plan and notification direction

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Introduce the minimum backend shift/handover domain to calculate expected cash, issue Shift QR payloads, and lock outgoing shifts.
- Build the attendant QR transfer flow with a hard-blocking discrepancy path and operator in-app alert creation.
- Add focused backend and Flutter tests for happy-path and mismatch scenarios.

### Completion Notes List

- Added a dedicated shift domain with `Shift`, `ShiftHandover`, `ShiftStatus`, and a `shift_service.py` helper layer to calculate expected cash from completed cash session payments, sign shift handover QR payloads, and enforce outgoing-shift locking.
- Implemented `/shifts/attendant-handover/start`, `/shifts/attendant-handover/finalize`, and `/shifts/operator-alerts` with strict attendant/operator authorization, lot scoping, discrepancy rationale enforcement, and reuse of the existing `Notification` domain for operator discrepancy alerts.
- Extended the attendant mobile workspace with an app-bar driven shift handover sheet that generates Shift QR payloads, scans incoming handover QR tokens, captures actual cash, and forces a non-dismissible discrepancy rationale flow before completion.
- Added an operator-facing in-app discrepancy alert surface to the existing lot-management screen instead of introducing a new push-notification channel.
- Validation passed with `cd backend && docker compose run --rm pytest python -m pytest`, `cd mobile && flutter test test/shift_handover_test.dart test/attendant_check_in_screen_test.dart test/attendant_check_out_screen_test.dart test/attendant_check_out_finalize_test.dart test/attendant_walk_in_check_in_test.dart test/attendant_timeout_session_test.dart test/widget_test.dart`, and `cd mobile && flutter test`.

### File List

- `_bmad-output/implementation-artifacts/6-4-zero-trust-shift-handover.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/__init__.py`
- `backend/src/app/api/v1/sessions.py`
- `backend/src/app/api/v1/shifts.py`
- `backend/src/app/models/__init__.py`
- `backend/src/app/models/enums.py`
- `backend/src/app/models/shifts.py`
- `backend/src/app/schemas/shift.py`
- `backend/src/app/services/__init__.py`
- `backend/src/app/services/shift_service.py`
- `backend/tests/test_attendant_check_out_finalize.py`
- `backend/tests/test_lot_availability_events.py`
- `backend/tests/test_shift_handover.py`
- `mobile/lib/src/features/attendant_check_in/data/attendant_check_in_service.dart`
- `mobile/lib/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart`
- `mobile/lib/src/features/operator_lot_management/data/operator_lot_management_service.dart`
- `mobile/lib/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart`
- `mobile/test/attendant_check_in_screen_test.dart`
- `mobile/test/attendant_check_out_finalize_test.dart`
- `mobile/test/attendant_check_out_screen_test.dart`
- `mobile/test/attendant_timeout_session_test.dart`
- `mobile/test/attendant_walk_in_check_in_test.dart`
- `mobile/test/shift_handover_test.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-28: Created Story 6.4 implementation artifact for zero-trust attendant shift handover.
- 2026-03-28: Implemented Story 6.4 with backend shift/handover domain support, signed QR handover APIs, hard-blocking discrepancy UX, operator alert visibility, and full backend/mobile regression validation.
