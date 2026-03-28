# Story 5.3: Driver Parking History

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Driver,
I want to view my past parking sessions,
so that I can track my expenses.

## Acceptance Criteria

1. Given I am on my Profile, when I view History, then I see a list of my COMPLETED sessions.

## Implementation Clarifications

- Story 5.3 depends on Epic 4's finalized session and payment flow; it should consume checked-out session records rather than introducing a separate receipt ledger.
- The history list is driver-owned and must only surface the authenticated driver's completed sessions.
- This story should prioritize a trustworthy chronological list with amount paid, duration, lot identity, and completion timestamps. Rich drill-down can remain minimal unless it is directly required by the current UI.
- Empty state handling is part of the scope: if the driver has no completed sessions yet, show a clean placeholder instead of an error.

## Tasks / Subtasks

- [ ] Task 1: Add a driver parking-history backend contract (AC: 1)
  - [ ] Extend `backend/src/app/api/v1/sessions.py` with a driver-only history endpoint such as `GET /sessions/driver-history`.
  - [ ] Join `ParkingSession` with its linked `Payment` records so the response exposes the settled amount and payment method for completed sessions.
  - [ ] Enforce authenticated driver scoping and return sessions in reverse chronological order.

- [ ] Task 2: Build the mobile parking-history surface (AC: 1)
  - [ ] Add a dedicated `parking_history` feature module with a typed service, DTOs, and a driver-facing list screen.
  - [ ] Integrate the feature into the driver profile/workspace navigation without coupling it to attendant or operator routes.
  - [ ] Render a clean empty state when no completed sessions exist yet.

- [ ] Task 3: Add focused regression coverage (AC: 1)
  - [ ] Add backend tests for driver-only scoping, ordering, empty history, and payment/session linkage.
  - [ ] Add Flutter tests for history loading, item rendering, and empty-state behavior.
  - [ ] Verify backend in Docker and Flutter locally after wiring the flow.

## Dev Notes

### Story Foundation

- Story 4.6 now closes sessions authoritatively and records payments, making driver parking history feasible without inventing extra state.
- The PRD explicitly lists parking history as an MVP driver capability.
- The current UI planning already hints that the history tab remains empty until Story 5.3 is implemented.

### Domain Constraints To Respect

- Only sessions belonging to the authenticated driver may be returned.
- History should reflect completed parking sessions, not active sessions or failed provisional payments.
- Amounts shown to the driver should come from backend-linked payment data where available, not client recomputation.

### Architecture Guardrails

- Reuse the sessions API module instead of introducing a separate receipts or invoices endpoint for MVP history.
- Keep the response model explicit and stable enough that future detail drill-down or filters can extend it without breaking the list contract.
- Preserve thin-client behavior: duration and monetary truth remain backend-owned fields or backend-derivable values.

### Library / Framework Requirements

- Flutter: `dio`, existing authenticated service-factory pattern
- Backend: FastAPI sessions router, async SQLAlchemy, Pydantic schemas
- Do not add local persistence or offline caching for this first history slice unless already required elsewhere.

### File Structure Requirements

- Backend:
  - `backend/src/app/api/v1/sessions.py`
  - `backend/src/app/models/sessions.py`
  - `backend/src/app/models/financials.py`
  - `backend/src/app/schemas/session.py`
  - `backend/tests/`
- Mobile:
  - `mobile/lib/src/features/parking_history/`
  - `mobile/lib/main.dart`
  - `mobile/test/`

### Testing Requirements

- Backend verification should run through Docker pytest.
- Flutter verification should run with local `flutter test`.
- History tests should cover the honest empty state and at least one completed-session row with fee data.

### Implementation Risks To Avoid

- Do not expose other drivers' sessions or operator-facing financial data.
- Do not recompute parking fees in Flutter for history rows.
- Do not mix active-session state into the completed-history list.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 5 / Story 5.3
- [prd.md](../prd.md) - FR25, FR26, NFR17
- [architecture.md](../architecture.md) - Session/payment flow and thin-client requirements
- [tech-design.md](../tech-design.md) - Sessions module plan and transactional payment recording
- [4-6-record-payment-finalize-session.md](./4-6-record-payment-finalize-session.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Story created to consume the authoritative session/payment state produced by Epic 4 rather than inventing a separate driver expense ledger.
- Current codebase anchor: there is no driver-history endpoint yet, so this story must extend the sessions domain cleanly on both backend and Flutter.

### File List

- `_bmad-output/implementation-artifacts/5-3-driver-parking-history.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

### Change Log

- 2026-03-28: Created Story 5.3 implementation artifact for driver-scoped completed-session history backed by authoritative payment/session data.