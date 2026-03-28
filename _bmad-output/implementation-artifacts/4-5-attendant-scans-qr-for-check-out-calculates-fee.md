# Story 4.5: Attendant Scans QR for Check-Out & Calculates Fee

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an Attendant,
I want to scan a driver's check-out QR and see the final fee,
so that I can charge the correct amount rapidly at the gate.

## Acceptance Criteria

1. Given I am authenticated with a dedicated Attendant account assigned to a parking lot, when a driver wants to leave, then I can enter a check-out scan mode from the existing attendant gate workspace and scan the backend-issued check-out QR from Story 4.4 without leaving the same operational screen.
2. Given I scan a valid check-out credential for exactly one active `ParkingSession` that belongs to my assigned lot, when the backend validates the scan, then the system returns a checkout summary containing the parking lot context, vehicle plate, vehicle type, elapsed parking time, and the authoritative final fee computed from the lot's active pricing rules.
3. Given the checkout summary is shown, when I am processing the vehicle exit, then the amount due is displayed with oversized typography suitable for gate-speed operation and I am not required to inspect entry photos on-screen before continuing.
4. Given the scanned credential is invalid, expired, malformed, already used for a completed session, belongs to a different lot, or resolves to no active session, when I attempt the scan, then the system rejects it with a clear attendant-facing error and does not create a `Payment`, update availability, or mark the session as checked out.
5. Given no active pricing rule can be resolved for the session's lot and vehicle type, when I attempt the checkout scan, then the system returns a dedicated pricing-missing response that blocks automatic fee calculation while leaving the session unchanged for follow-up resolution.
6. Given this story only covers scan-time validation and fee calculation, when it is implemented, then payment recording, swipe-to-resolve settlement, undo handling, and final session closure remain out of scope for Story 4.6.

## Implementation Clarifications

- Story 4.5 is the authoritative fee-calculation boundary for the attendant flow. The amount shown in Story 4.4 remains a driver preview only.
- The backend must validate the scanned check-out token against the active session and the attendant's assigned lot. Do not trust any client-decoded QR payload as checkout authority.
- This story should stay QR-first for MVP. The epic text mentions NFC, but the current repo has no established NFC stack or card lifecycle; if implementation wants future NFC support, route it through the same backend checkout-preview contract instead of inventing a second flow.
- Checkout media conventions are fixed as follows for Epic 4: app-driver exit uses the backend-issued check-out QR from Story 4.4; future NFC support is only an alternate transport for the same backend checkout-preview contract; future walk-in exit must use a server-generated session-scoped credential tied to the `ParkingSession`, not keyboard lookup at the gate.
- Story 4.5 must not create a `Payment`, set `attendant_checkout_id`, set `checkout_time`, change `SessionStatus`, or increment `current_available`. Those side effects belong to Story 4.6.
- Walk-in exit media is not yet defined by Stories 4.1 through 4.4. Do not invent a walk-in checkout credential format inside this story without an explicit product decision.
- If pricing is missing, surface a recoverable blocking state rather than silently falling back to zero or a guessed amount. Any manual override persistence should happen at the settlement boundary in Story 4.6 unless scope is explicitly expanded.
- Story 4.6 should consume a server-owned session identity and revalidate the authoritative fee at settlement time. Do not let the client treat the previewed amount from Story 4.5 as a trusted write payload.

## Tasks / Subtasks

- [x] Task 1: Add attendant checkout-preview backend contract (AC: 2, 4, 5, 6)
  - [x] Extend the sessions API with an attendant-only check-out preview endpoint that accepts scanned checkout media, validates the Story 4.4 token server-side, and securely scopes the lookup to the attendant's assigned lot.
  - [x] Return a checkout summary with elapsed duration, pricing mode, and authoritative final fee for the single active session resolved by the scan.
  - [x] Reject invalid, expired, cross-lot, already-completed, no-active-session, duplicate-active-session, or missing-pricing cases without mutating session, payment, or lot-capacity state.

- [x] Task 2: Extend the attendant mobile gate flow with checkout scan mode (AC: 1, 3, 4, 5, 6)
  - [x] Evolve the existing dark-mode attendant workspace so the operator can switch between check-in and check-out scan modes without losing the gate-first ergonomics introduced in Stories 4.2 and 4.3.
  - [x] Add a checkout summary state that renders oversized price and duration information, keeps the layout dense and thumb-zone friendly, and explicitly avoids any photo-review requirement for the happy path.
  - [x] Keep the mobile flow limited to scan-time validation and fee display; do not add swipe-to-resolve settlement, undo toasts, or final session-closing actions in this story.

- [x] Task 3: Add focused regression coverage (AC: 2, 4, 5)
  - [x] Add backend tests for successful checkout preview, invalid-token rejection, no-active-session rejection, lot-mismatch rejection, missing-pricing handling, and proof that no state mutation occurs during preview.
  - [x] Add Flutter widget coverage for checkout scan mode entry, oversized fee rendering, no-look summary behavior, and attendant-facing error states.
  - [x] Verify backend in Docker and Flutter locally after wiring the flow.

## Dev Notes

### Story Foundation

- Story 4.2 already introduced the attendant scanner-first gate workspace and the first attendant-owned session creation contract for app-driver QR check-in.
- Story 4.3 extended that same attendant workspace with walk-in photo capture, but it did not establish a walk-in checkout credential.
- Story 4.4 added `GET /sessions/driver-active-session` and `POST /sessions/driver-check-out-token`, which now form the driver-side source for checkout-state QR media.
- The backend already has pricing lookup helpers and active-session semantics in `backend/src/app/api/v1/sessions.py`, but it does not yet expose an attendant checkout-preview contract.
- The data model already includes `attendant_checkout_id`, `checkout_time`, `SessionStatus.CHECKED_OUT`, and `Payment`, but those are for Story 4.6 and should remain untouched by Story 4.5.

### Domain Constraints To Respect

- Only authenticated Attendant accounts may use this flow, and they may only preview checkout for sessions at `Attendant.parking_lot_id`.
- The backend is the source of truth for final fee calculation, elapsed time, and pricing applicability. Flutter must not compute the amount due locally.
- Story 4.5 is a preview-and-validation boundary only. It must not settle the transaction or complete the parking session.
- The same active session should not produce multiple contradictory checkout previews. If the backend detects duplicate active sessions for the scanned driver, reject the flow rather than masking the data issue.
- The currently supported happy path is app-driver QR checkout. NFC should be treated as a future alternate transport for the same contract, and walk-in exit should eventually resolve through a session-scoped credential rather than free-form gate input.

### Architecture Guardrails

- Keep backend implementation in `backend/src/app/api/v1/sessions.py` and `backend/src/app/schemas/session.py`; do not introduce a temporary parallel checkout route family.
- Prefer a focused endpoint such as `POST /sessions/attendant-check-out-preview` that accepts scanned media and returns a read-only checkout summary for the resolved session.
- Reuse the pricing-selection logic from Story 4.4 where appropriate, but keep the attendant-facing final-fee contract distinct from the driver's estimated-cost preview so the API semantics stay clear.
- Do not set `attendant_checkout_id`, `checkout_time`, `status`, `Payment`, or `ParkingLot.current_available` inside this story. Story 4.6 owns the mutation boundary.
- If future NFC support is added, map it to the same backend validation path instead of duplicating fee-calculation logic in a second endpoint.
- Future walk-in exit support should plug into the same preview endpoint by presenting a server-issued session credential, not by bolting on a separate plate-search endpoint for gate use.
- Keep the mobile implementation self-contained inside the current attendant feature wiring in `mobile/lib/main.dart` and `mobile/lib/src/features/attendant_check_in/`, without assuming Epic 9 shell infrastructure.

### Library / Framework Requirements

- Continue using the existing Flutter scanner stack (`mobile_scanner`) for MVP checkout scanning unless a proven blocker appears.
- Continue using FastAPI route dependencies and async SQLAlchemy ownership checks for attendant authorization.
- Do not add payment SDKs, NFC-native dependencies, or realtime plumbing in this story.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/sessions.py`
  - `backend/src/app/schemas/session.py`
  - `backend/tests/test_attendant_check_out_preview.py` (preferred focused suite)
- Mobile:
  - `mobile/lib/main.dart`
  - `mobile/lib/src/features/attendant_check_in/`
  - `mobile/test/attendant_check_out_screen_test.dart` or the existing attendant screen suite if it remains cohesive

### Testing Requirements

- Backend verification should run through the Docker pytest service using the repo convention for targeted suites.
- Flutter verification should run with local `flutter test`.
- Manual device validation of QR readability and outdoor gate ergonomics remains user-owned unless explicitly requested.

### Implementation Risks To Avoid

- Do not close the parking session during fee calculation.
- Do not let Flutter infer the final fee from local time math or cached pricing.
- Do not force attendants to inspect entry photos during the happy-path checkout scan.
- Do not silently degrade missing pricing into `0` or another guessed amount.
- Do not invent incomplete NFC or walk-in exit credentials ad hoc inside implementation.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 4 / Story 4.5
- [prd.md](../prd.md) - FR13, FR14, FR15, FR16, NFR2, NFR15, EC7, EC8, EC9, EC10
- [architecture.md](../architecture.md) - check-out flow, driver QR state machine
- [tech-design.md](../tech-design.md) - sessions module plan, error design, transactional boundaries
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - High-Speed Universal Attendant Flow, no-look verification, oversized attendant typography
- [4-2-attendant-scans-qr-for-check-in.md](./4-2-attendant-scans-qr-for-check-in.md)
- [4-3-manual-license-plate-check-in.md](./4-3-manual-license-plate-check-in.md)
- [4-4-driver-generates-check-out-qr.md](./4-4-driver-generates-check-out-qr.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Story created from Epic 4 planning, PRD checkout requirements, architecture checkout sequencing, attendant UX gate-flow constraints, and the implementation baseline established by Stories 4.2 through 4.4.
- Key guardrail: Story 4.5 calculates the authoritative fee for the attendant but does not create a payment or close the session; Story 4.6 owns settlement and state mutation.
- Planning caveat captured in this story: NFC support and walk-in checkout media are not yet established in the current codebase, so MVP implementation should stay QR-first while keeping the backend contract extensible.
- Added `POST /sessions/attendant-check-out-preview`, server-side checkout token validation, checked-out-session detection, cross-lot protection, pricing-required enforcement, and read-only checkout summary responses without mutating payment or availability state.
- Extended the existing attendant gate workspace with explicit check-in/check-out scan modes, oversized checkout summary rendering, and backend-driven error handling while keeping walk-in and settlement behavior out of scope.
- Added focused backend and Flutter coverage for checkout preview behavior, then validated the implementation with the full backend suite (`124 passed`) and full Flutter suite (`44 passed`).

### File List

- `_bmad-output/implementation-artifacts/4-5-attendant-scans-qr-for-check-out-calculates-fee.md`
- `_bmad-output/implementation-artifacts/4-6-record-payment-finalize-session.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/sessions.py`
- `backend/src/app/schemas/session.py`
- `backend/tests/test_attendant_check_out_preview.py`
- `mobile/lib/src/features/attendant_check_in/data/attendant_check_in_service.dart`
- `mobile/lib/src/features/attendant_check_in/presentation/attendant_check_in_screen.dart`
- `mobile/test/attendant_check_in_screen_test.dart`
- `mobile/test/attendant_walk_in_check_in_test.dart`
- `mobile/test/attendant_check_out_screen_test.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-28: Created Story 4.5 implementation artifact with attendant checkout-preview guardrails, fee-calculation boundaries, and MVP QR-first scope.
- 2026-03-28: Implemented Story 4.5 backend checkout preview endpoint, attendant checkout scan mode, focused regression coverage, and full backend/Flutter validation.