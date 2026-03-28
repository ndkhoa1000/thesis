# Story 6.5: Close Final Shift of Day

Status: ready-for-dev

## Story

As an Attendant,
I want to submit the lot's final shift of the day for operator close-out after the lot is empty,
so that day-end financial accountability is completed without abusing the QR handover flow.

## Acceptance Criteria

1. Given I am the attendant on the final active shift of the day for my lot, when I start day-end close-out, then the system routes me into a dedicated final-shift close-out flow instead of the QR handover flow.
2. Given I start final-shift close-out, when the backend evaluates the request, then it recalculates the shift cash total server-side and verifies the lot is operationally empty by rejecting the close-out if any parking session remains active or occupancy is otherwise unresolved.
3. Given the lot is empty and reconciliation succeeds, when I submit the close-out request, then the system locks the shift against further gate mutations, records a day-end close-out snapshot, and creates an operator-facing in-app alert that the final shift is ready to be ended.
4. Given I am the responsible Operator for that lot, when I open the close-out alert, then I can review the attendant, lot, and cash summary and explicitly complete the final shift close-out from the management workspace.
5. Given a final shift close-out has already been requested or completed for that shift, when another attendant or operator retries the same workflow, then the system rejects the duplicate action with a clear status-specific message.

## Implementation Clarifications

- This story is the intentional follow-up extracted from Story 6.4 review. It is not a bug fix inside QR handover; it is a separate lifecycle for the last shift of the day.
- Final-shift close-out has no incoming attendant and no Shift QR payload. Do not fabricate a synthetic successor shift just to reuse handover mechanics.
- "Auto-settle cash" means the backend derives the cash summary from completed cash `Payment` records for the current shift. The attendant does not type the expected amount manually.
- "Verify the lot is empty" means there must be no unresolved `CHECKED_IN` sessions or other occupancy drift for the lot at close-out time. If the lot is not empty, block close-out and surface enough detail for correction.
- Reuse the existing in-app `Notification` domain for the operator alert. Epic 10 still owns push notifications.
- Prefer a dedicated close-out persistence seam such as `ShiftCloseOut` or an equivalently narrow record rather than overloading `ShiftHandover` with day-end-only semantics.

## Tasks / Subtasks

- [ ] Task 1: Add a dedicated backend final-shift close-out domain (AC: 1, 2, 3, 5)
  - [ ] Introduce the minimum persistence needed to track a requested and completed day-end close-out separately from `ShiftHandover`.
  - [ ] Lock the target shift once close-out is requested so no later checkout/payment mutation can alter the reconciled snapshot.
  - [ ] Reject duplicate close-out requests and duplicate operator completions for the same shift.

- [ ] Task 2: Implement attendant-side close-out initiation and lot-empty validation (AC: 1, 2, 3)
  - [ ] Add an attendant API flow that starts final-shift close-out from the current active shift without creating a QR token.
  - [ ] Recalculate expected cash server-side from existing payment/session data.
  - [ ] Block the request if active sessions or occupancy inconsistencies still exist, and return actionable details.

- [ ] Task 3: Implement operator review and completion flow (AC: 3, 4, 5)
  - [ ] Reuse the operator notification/read surface from Story 6.4 for final-shift close-out alerts.
  - [ ] Add an operator endpoint and management action to explicitly complete the final close-out.
  - [ ] Keep lot ownership and active lease authorization strict for both attendants and operators.

- [ ] Task 4: Extend mobile administrative UX for attendants and operators (AC: 1, 2, 3, 4)
  - [ ] Add an off-peak attendant action for final-shift close-out that clearly differs from QR handover.
  - [ ] Surface blocking validation when the lot is not empty, without mixing the flow into the high-speed gate scanner path.
  - [ ] Add an operator-facing review card or detail sheet that can approve/complete the day-end close-out.

- [ ] Task 5: Add focused regression coverage and verification (AC: 1, 2, 3, 4, 5)
  - [ ] Add backend tests for empty-lot validation, cash snapshot creation, duplicate-close-out prevention, and operator completion authorization.
  - [ ] Add Flutter tests for attendant blocking states, operator close-out review, and successful completion feedback.
  - [ ] Verify with backend Docker tests and local `flutter test`.

## Dev Notes

### Story Foundation

- Story 6.4 review established the product rule that attendant-to-attendant handover and last-shift-of-day close-out are different business lifecycles.
- The architecture and UX documents already position operators as the financial-control actor who must trust end-of-day numbers, making operator completion the correct terminal step.
- This story preserves the integrity of Story 6.4 by removing the need to misuse QR handover when no incoming attendant exists.

### Previous Story Intelligence

- Story 6.4 already introduced `Shift`, `ShiftHandover`, `/shifts/*`, signed handover tokens, and operator alert visibility. Reuse those seams where they fit, but do not collapse this story back into handover.
- Story 6.4 review fixes already changed `/shifts/attendant-handover/start` to reject missing active shifts with an explicit message telling attendants to use the daily close-out flow instead. This story must fulfill that contract.
- Story 6.3 already provides attendant-side active-session visibility and timeout correction. Use that administrative surface and session-state knowledge when explaining why a lot is not yet empty.

### Domain Constraints To Respect

- Final-shift close-out is lot-scoped and only valid for the attendant who owns the active final shift.
- The lot must be empty before the day can be closed. Occupancy drift is a blocker, not a warning.
- Day-end cash is backend-derived from completed session-linked cash payments, not free-form user input.
- Operator completion is required before the day-end close-out becomes final.

### Architecture Guardrails

- Extend the existing `/shifts/*` API surface rather than creating a generic finance module.
- Reuse `shift_service.py` for reconciliation helpers where possible, but keep close-out-specific rules in explicitly named helpers or services.
- Use the existing `Notification` domain and operator management workspace rather than introducing Epic 10 push infrastructure.
- Keep the attendant entry point out of the fast scanner/check-in lane. This is an off-peak administrative workflow.

### Library / Framework Requirements

- Backend: FastAPI + SQLAlchemy async, consistent with existing shift/session/payment modules.
- Mobile: Flutter service layering already used by `attendant_check_in` and `operator_lot_management`.
- Do not add a new scanner stack, background worker, or reporting framework for this story.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/shifts.py`
  - `backend/src/app/services/shift_service.py`
  - `backend/src/app/models/shifts.py` and/or a close-out-specific model file if split
  - `backend/src/app/models/notifications.py`
  - `backend/src/app/models/sessions.py`
  - `backend/src/app/schemas/shift.py`
  - `backend/tests/`
- Mobile:
  - `mobile/lib/src/features/attendant_check_in/data/attendant_check_in_service.dart`
  - `mobile/lib/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart`
  - `mobile/lib/src/features/operator_lot_management/data/operator_lot_management_service.dart`
  - `mobile/lib/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart`
  - `mobile/test/`

### Testing Requirements

- Backend tests should cover lot-empty validation, shift locking, duplicate request prevention, operator authorization, and final close-out completion.
- Flutter tests should cover the attendant blocked state when vehicles remain, the operator review surface, and the completion happy path.
- Verification should use backend Docker tests and local `flutter test`.

### Implementation Risks To Avoid

- Do not reuse `ShiftHandover` as a catch-all day-end record; that would blur two different business events.
- Do not allow close-out while active sessions remain, even if `current_available` appears numerically correct.
- Do not let an operator complete a close-out for a lot they do not actively manage.
- Do not leave a requested final close-out mutable by later checkout/payment activity.

### Recent Repository Patterns

- `backend/src/app/api/v1/shifts.py` already contains attendant/operator split endpoints and strict role checks for financial workflows.
- `backend/src/app/services/shift_service.py` already computes shift cash from session-linked payments and builds operator-facing discrepancy notifications.
- `mobile/lib/src/features/attendant_check_in/` already hosts both the high-speed gate flow and the slower administrative shift-handover/time-out surfaces.
- `mobile/lib/src/features/operator_lot_management/` already renders operator-side shift alerts, making it the natural home for day-end close-out review.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 6 / Story 6.5
- [6-4-zero-trust-shift-handover.md](./6-4-zero-trust-shift-handover.md) - source review decision and predecessor shift-domain implementation
- [6-3-force-close-timeout-session.md](./6-3-force-close-timeout-session.md) - attendant administrative session visibility and correction flow
- [architecture.md](../architecture.md) - section 4.7 Zero-Trust Shift Handover, API design principles, backend project shape
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - operator financial trust goals, attendant administrative-flow constraints, hard-blocking financial UX patterns
- [prd.md](../prd.md) - operator financial-control context and end-to-end thesis workflow goals
- [tech-design.md](../tech-design.md) - backend reuse strategy and transactional mutation constraints

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Add a dedicated final-shift close-out seam that sits beside, not inside, shift handover.
- Reuse existing shift cash reconciliation and operator notification surfaces while adding lot-empty enforcement and explicit operator completion.
- Extend the attendant and operator administrative mobile flows with focused backend and Flutter regression coverage.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Story created as an Epic 6 follow-up to implement the previously agreed business rule separating day-end close-out from attendant handover.
- Sprint tracker reopened Epic 6 and set Story 6.5 to `ready-for-dev`.

### Change Log

- 2026-03-28: Created Story 6.5 implementation artifact for final-shift-of-day close-out and reopened Epic 6 for follow-up delivery.