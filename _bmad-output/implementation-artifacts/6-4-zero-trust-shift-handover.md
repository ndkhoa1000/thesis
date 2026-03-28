# Story 6.4: Zero-Trust Shift Handover

Status: ready-for-dev

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

- [ ] Task 1: Add backend shift and handover domain support (AC: 1, 2, 3, 4)
  - [ ] Introduce `Shift` and `ShiftHandover` persistence plus the minimum service layer needed to compute `expected_cash`, issue a Shift QR payload, and record handover completion.
  - [ ] Lock the outgoing shift after successful handover to prevent post-handover cash drift.
  - [ ] Persist discrepancy details, including actual cash and rationale, when the incoming attendant reports a mismatch.

- [ ] Task 2: Add shift handover endpoints and operator alert creation (AC: 1, 2, 3, 4)
  - [ ] Create a shift-handover API surface consistent with the architecture's `/shifts/*` direction.
  - [ ] Reuse the existing notification domain for operator alert creation when discrepancies occur.
  - [ ] Keep authentication and lot assignment strict for both outgoing and incoming attendants.
  - [ ] Expose a minimum operator-facing read path for discrepancy alerts if no existing notification feed already surfaces `Notification` records.

- [ ] Task 3: Implement the mobile QR handover flow for attendants (AC: 1, 2, 3)
  - [ ] Add an outgoing flow that ends the current shift and displays the Shift QR.
  - [ ] Add an incoming flow that scans the Shift QR, collects the counted cash amount, and finalizes handover.
  - [ ] Use a hard-blocking, high-contrast discrepancy screen that cannot be dismissed without submitting the required rationale.

- [ ] Task 4: Add focused regression coverage and verification (AC: 1, 2, 3, 4)
  - [ ] Add backend tests for expected-cash calculation, shift locking, discrepancy persistence, and operator alert creation.
  - [ ] Add Flutter tests for QR handover happy path and hard-blocking discrepancy UX behavior.
  - [ ] Verify with backend Docker tests and local `flutter test`.

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

- Story context prepared for Epic 6 implementation.
- Key guardrail: discrepancy alerting should use the existing notification domain, not new push infrastructure.
- No `project-context.md` file was present in the repository at story creation time.

### File List

- `_bmad-output/implementation-artifacts/6-4-zero-trust-shift-handover.md`
