# Story 4.6: Record Payment & Finalize Session

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an Attendant,
I want to record the payment method and finalize the session with a swipe,
so that the vehicle exit is completed quickly without fat-finger errors.

## Acceptance Criteria

1. Given I already have a valid checkout preview from Story 4.5 for an active `ParkingSession` at my assigned lot, when I use the swipe-to-resolve gesture, then the system records the chosen payment method and completes the checkout without requiring keyboard input at the gate.
2. Given I resolve the session as cash or online-paid, when the backend finalizes the operation, then it revalidates the active session and authoritative fee, creates exactly one `Payment` record linked to the session, stamps attendant checkout metadata, changes the session state to checked out, and increments lot availability in the same transaction.
3. Given the checkout finalization succeeds, when the gate flow returns to standby, then the attendant sees immediate success feedback and a non-blocking undo affordance for the short recovery window defined by the UX.
4. Given the preview is stale, the session is already checked out, the lot context is invalid, or the authoritative fee can no longer be resolved, when I attempt to finalize the payment, then the backend rejects the operation and does not create partial payment or session state.
5. Given this story is the settlement boundary for Epic 4, when it is implemented, then fee calculation logic remains server-owned, client-supplied amounts are treated as advisory only, and no second finalization path bypasses the same backend safeguards.

## Implementation Clarifications

- Story 4.6 is the only mutation boundary for Epic 4 checkout. It owns `Payment` creation, session completion, attendant checkout metadata, and capacity restoration.
- The backend must revalidate the active session and recalculate the authoritative fee during finalization. Do not trust a previewed amount echoed back from the client.
- Payment methods in MVP are limited to the two gate gestures already defined by UX: cash and online-paid.
- The undo affordance is a UX recovery layer around a just-finalized action; if the implementation persists undo server-side, it must remain narrowly scoped and deterministic rather than reopening arbitrary historical sessions.
- Future NFC and walk-in exit support must reuse the same settlement contract once their server-issued checkout credential exists.

## Tasks / Subtasks

- [x] Task 1: Add attendant checkout-finalization backend contract (AC: 1, 2, 4, 5)
  - [x] Extend the sessions or payments API with an attendant-only finalization endpoint that accepts the resolved session identity and payment method, then revalidates the active session and authoritative fee server-side.
  - [x] Create exactly one `Payment` record, stamp checkout metadata on the `ParkingSession`, update `SessionStatus`, and restore `ParkingLot.current_available` in a single transaction.
  - [x] Reject stale preview, duplicate finalization, cross-lot access, or pricing-resolution failures without partial writes.

- [x] Task 2: Add swipe-to-resolve settlement UX to the attendant gate flow (AC: 1, 3, 5)
  - [x] Extend the Story 4.5 checkout summary with macroscopic swipe gestures for cash and online-paid resolution.
  - [x] Show immediate success feedback and the non-blocking undo affordance without forcing the attendant through modal confirmation dialogs.
  - [x] Keep the layout edge-to-edge and no-keyboard, preserving the gate-speed ergonomics established earlier in Epic 4.

- [x] Task 3: Add focused regression coverage (AC: 2, 4, 5)
  - [x] Add backend tests for successful settlement, duplicate-finalization rejection, stale-preview rejection, and proof that payment/session/availability changes are atomic.
  - [x] Add Flutter widget coverage for swipe resolution, success reset to standby, and undo affordance behavior.
  - [x] Verify backend in Docker and Flutter locally after wiring the flow.

## Dev Notes

### Story Foundation

- Story 4.5 establishes the checkout-preview boundary and should hand Story 4.6 a server-owned session identity rather than a trusted client-computed amount.
- The backend data model already contains the fields Story 4.6 needs: `Payment`, `ParkingSession.attendant_checkout_id`, `ParkingSession.checkout_time`, `SessionStatus.CHECKED_OUT`, and `ParkingLot.current_available`.
- The UX specification already defines the gesture language and the non-blocking undo toast for gate-speed settlement.

### Domain Constraints To Respect

- Only authenticated Attendant accounts may finalize exit for sessions in their assigned lot.
- Settlement must remain atomic to satisfy NFR15: payment, session completion, and availability restoration succeed or fail together.
- Client-supplied fee displays from Story 4.5 are not trusted write inputs.
- This story must not create a second settlement route that bypasses the same backend revalidation logic.

### Architecture Guardrails

- Prefer keeping settlement logic near the sessions/payment boundary already used by Epic 4 instead of inventing a disconnected temporary module.
- Recalculate the authoritative amount from the active session and lot pricing rules inside the finalization transaction.
- Enforce idempotency against double swipes or repeated checkout submissions for the same session.
- If undo is implemented against persisted data, keep the allowed reversal window narrowly bounded and attendant-scoped.

### Library / Framework Requirements

- Reuse the existing Flutter attendant feature module and gesture primitives.
- Reuse FastAPI auth dependencies, async SQLAlchemy transaction handling, and current enum models for `PaymentMethod`, `PaymentStatus`, and `SessionStatus`.
- Do not add external payment-gateway SDKs in this story; online-paid remains the simulated MVP path.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/sessions.py`
  - `backend/src/app/models/financials.py`
  - `backend/src/app/schemas/session.py`
  - `backend/tests/test_attendant_check_out_finalize.py` (preferred focused suite)
- Mobile:
  - `mobile/lib/src/features/attendant_check_in/`
  - `mobile/test/attendant_check_out_finalize_test.dart`

### Testing Requirements

- Backend verification should run through the Docker pytest service using the repo convention for targeted suites.
- Flutter verification should run with local `flutter test`.

### Implementation Risks To Avoid

- Do not trust previewed fee data sent back from the client.
- Do not split payment creation, session checkout, and capacity restoration across multiple independent commits.
- Do not let the undo affordance become an unrestricted session-reopen feature.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 4 / Story 4.6
- [prd.md](../prd.md) - FR17, FR18, FR19, FR20, NFR15, EC8, EC10
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - Swipe-to-Resolve, non-blocking undo toast, gate-speed interaction patterns
- [4-5-attendant-scans-qr-for-check-out-calculates-fee.md](./4-5-attendant-scans-qr-for-check-out-calculates-fee.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Story created to lock the settlement boundary after Story 4.5: fee preview stays read-only, while payment creation and session completion are deferred here.
- Key guardrail: finalization must revalidate the active session and authoritative fee server-side instead of trusting the client preview payload.
- Added `POST /sessions/attendant-check-out-finalize` with authoritative fee revalidation, atomic `Payment` creation, checkout metadata stamping, capacity restoration, and stale-preview / duplicate-finalization rejection.
- Added a narrowly scoped `POST /sessions/attendant-check-out-undo` recovery path for the 3-second attendant undo affordance, reverting the just-finalized checkout back to an active session and marking the provisional payment as failed.
- Reworked the attendant checkout screen into a full-screen swipe settlement zone with cash-left / online-right gestures, success reset to standby, and the non-blocking undo toast.
- Added focused backend and Flutter coverage for settlement + undo behavior, then validated with the full backend suite (`130 passed`) and full Flutter suite (`46 passed`).

### File List

- `_bmad-output/implementation-artifacts/4-6-record-payment-finalize-session.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/sessions.py`
- `backend/src/app/schemas/session.py`
- `backend/tests/test_attendant_check_out_finalize.py`
- `mobile/lib/src/features/attendant_check_in/data/attendant_check_in_service.dart`
- `mobile/lib/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart`
- `mobile/test/attendant_check_in_screen_test.dart`
- `mobile/test/attendant_check_out_screen_test.dart`
- `mobile/test/attendant_check_out_finalize_test.dart`
- `mobile/test/attendant_walk_in_check_in_test.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-28: Created Story 4.6 implementation artifact with settlement-boundary guardrails, atomic finalization requirements, and gesture-first UX constraints.
- 2026-03-28: Implemented Story 4.6 backend settlement + bounded undo, added swipe-to-resolve attendant checkout UX, and validated with full backend/Flutter regression suites.