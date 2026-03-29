# Story 8.3: Operator Revenue Dashboard

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an Operator,
I want to view my lot's performance and operator share,
so that I know how much my business makes.

## Acceptance Criteria

1. Given I am an authenticated Operator with at least one accepted or historical lease, when I open the operator revenue dashboard for a managed lot and selected period, then I see backend-calculated gross revenue, my operator share, the owner share, and explicit lease status for that reporting scope.
2. Given I change the reporting range to day, week, or month, when the dashboard reloads, then I see total revenue, completed session count, occupancy-rate context, and vehicle-type breakdown derived from authoritative backend data for that period.
3. Given the selected lot has no settled payments or completed sessions in the selected range, when I open the dashboard, then the UI renders an honest empty state instead of showing fabricated utilization or revenue numbers.
4. Given I try to request dashboard data for a lot I do not currently or historically manage through an accepted lease, when the backend evaluates the request, then access is denied and no other operator's business metrics are exposed.
5. Given the lease for a lot has expired, when I review historical dashboard data, then the operator can still see past performance while the lease status is surfaced explicitly as `EXPIRED` so inactive management is not misrepresented as active control.

## Implementation Clarifications

- Story 8.3 is the operator-facing reporting slice for Epic 8 and depends on Story 8.1 for authoritative lease truth plus a backend-readable revenue split term.
- FR31 and FR32 belong primarily to this story: period-based revenue totals, session counts, occupancy rates, and vehicle-type breakdowns should be exposed as backend-aggregated read models.
- Reuse finalized payments and completed session history as the source of truth. Do not create a second operator earnings ledger or depend on client-side rollups.
- This story is about operator performance visibility, not cash handover discrepancy management, attendant staffing CRUD, lease creation, or payout settlement.
- Epic 9 later provides the formal operator shell `Doanh thu` tab. Until then, the dashboard only needs to be reachable through the current operator workspace without hardcoding future shell architecture.

## Tasks / Subtasks

- [x] Task 1: Add operator-scoped backend reporting endpoints (AC: 1, 2, 4, 5)
  - [x] Implement or extend a backend reporting module, preferably `backend/src/app/api/v1/reports.py`, for operator revenue/performance reads filtered by lot and reporting period.
  - [x] Return a typed summary including gross revenue, operator share, owner share, completed session count, occupancy-rate context, vehicle-type breakdown, and lease status.
  - [x] Enforce operator scoping through accepted lease ownership rather than loose role checks or client-submitted lot IDs.

- [x] Task 2: Reuse authoritative operational and financial data sources (AC: 1, 2, 3, 5)
  - [x] Aggregate finalized `Payment` records and completed `ParkingSession` data instead of recomputing business totals from UI state.
  - [x] Reuse occupancy/reporting patterns already established in attendant and parking-history stories where appropriate.
  - [x] Ensure historical reads remain available after lease expiration while exposing the inactive lease state explicitly.

- [x] Task 3: Add an operator-facing revenue dashboard surface in the mobile app (AC: 1, 2, 3, 5)
  - [x] Add a dedicated operator revenue feature or a clearly separated operator reporting surface compatible with the current `OperatorLotManagementScreen` reachability.
  - [x] Support period switching, multi-metric summary rendering, vehicle-type breakdown presentation, and honest empty/error states.
  - [x] Keep the UX aligned with the current bright MD3 management experience rather than importing attendant-style operational layouts.

- [x] Task 4: Add focused regression coverage and verification (AC: 1, 2, 3, 4, 5)
  - [x] Add backend tests for operator-only scoping, period aggregation, session-count and vehicle-breakdown correctness, expired-lease visibility, and no-data ranges.
  - [x] Add Flutter tests for dashboard loading, period switching, empty-state handling, and rendering of operator-share metrics.
  - [x] Verify with backend Docker tests and local `flutter test` for the touched reporting surfaces.

## Dev Notes

### Story Foundation

- PRD Journey 3 explicitly states that the Operator checks a revenue dashboard containing session totals, revenue, and occupancy rate at the end of the month.
- PRD FR31 and FR32 map directly to this story and should drive the dashboard contract rather than vague generic analytics.
- Epic 8 is now a workflow-enablement epic. A credible operator dashboard depends on real lease lifecycle truth instead of the temporary bootstrap path used earlier in UAT.

### Cross-Epic Intelligence

- Story 8.1 is the prerequisite because the operator dashboard must be limited to lots governed by accepted lease truth, not by temporary bootstrap shortcuts.
- Story 4.6 already established finalized payment truth, Story 5.3 established completed-session financial reads, and Story 6.1 established backend-owned occupancy aggregation. Story 8.3 should compose those proven data sources instead of inventing a new reporting substrate.
- Story 3.2 and Story 3.3 already made operator-managed lot and attendant workflows depend on active lease access. This dashboard should follow that same authoritative lease boundary.

### Domain Constraints To Respect

- The operator may only view metrics for lots they manage through accepted lease relationships.
- Operator share must come from canonical lease terms and finalized revenue events.
- Occupancy rate and vehicle-type breakdown must be backend-derived, not inferred from client-local state.
- Historical metrics should remain visible after lease expiration, but the UI must distinguish historical performance from currently active management.

### Architecture Guardrails

- The architecture and tech design already reserve `reports.py` for revenue and occupancy. Prefer that route family over embedding report logic inside unrelated modules.
- Keep report payloads typed, likely through a dedicated `backend/src/app/schemas/report.py`, and avoid generic dict responses for complex business metrics.
- Reuse the current shared public-account capability model and linked `manager` profile checks; do not invent a separate operator-auth path.
- If Story 8.1 introduces lease-term fields for revenue split, consume those fields directly rather than reverse-engineering contract output.

### Library / Framework Requirements

- Backend: FastAPI, async SQLAlchemy, existing lease/session/payment models, and current ownership/authorization patterns.
- Mobile: Flutter, `dio`, existing operator service/screen patterns, and current role routing in `main.dart`.
- Do not introduce advanced analytics/chart dependencies or a web-first dashboard stack for this first mobile reporting slice unless the repo already requires them.

### File Structure Requirements

- Backend likely touch points:
  - `backend/src/app/api/v1/reports.py` (new or completed)
  - `backend/src/app/models/financials.py`
  - `backend/src/app/models/leases.py`
  - `backend/src/app/models/sessions.py`
  - `backend/src/app/schemas/report.py` (new if needed)
  - `backend/src/app/services/` reporting helper module if aggregation/query complexity grows
  - `backend/tests/` focused operator-report suites
- Mobile likely touch points:
  - `mobile/lib/main.dart`
  - `mobile/lib/src/features/operator_lot_management/`
  - `mobile/lib/src/features/operator_revenue_dashboard/` (new feature folder if cleaner)
  - `mobile/test/`

### Testing Requirements

- Backend verification should run through Docker pytest and explicitly cover period filters, session-count aggregation, vehicle-type breakdown accuracy, operator-only scoping, and expired-lease reads.
- Flutter verification should run with local `flutter test` and prove the operator can actually reach and use the dashboard from the current workspace, not only parse one happy-path payload.
- Include honest empty-state tests for newly accepted leases or quiet periods where no settled sessions exist yet.

### Implementation Risks To Avoid

- Do not calculate revenue share or occupancy percentages in Flutter.
- Do not leak other operators' lot metrics through weak filtering or broad role checks.
- Do not treat bootstrap-managed access as equivalent to accepted lease truth once Story 8.1 exists.
- Do not overbuild charts, exports, or accounting workflows that are outside this story's mobile MVP scope.
- Do not collapse operator financial reporting into attendant operational stats; they serve different roles and trust requirements.

### Recent Repository Patterns

- Recent stories prefer backend-owned aggregation and thin mobile service integration over client-side reconstruction of business truth.
- Existing operator screens already use dedicated services, sheet-based workflows, and explicit empty states; Story 8.3 should extend those conventions rather than introducing a new navigation architecture.
- The project consistently treats race conditions, stale state, and role scoping as review blockers. Reporting endpoints must be equally strict.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 8 / Story 8.3
- [prd.md](../prd.md) - Journey 3, FR31, FR32
- [architecture.md](../architecture.md) - backend-owned truth, `/reports/*`, shared public-account model
- [tech-design.md](../tech-design.md) - `reports.py`, revenue and occupancy module plan, thesis MVP completion roadmap
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - Operator control/reconciliation UX direction and current management experience
- [8-1-create-lease-contract.md](./8-1-create-lease-contract.md)
- [4-6-record-payment-finalize-session.md](./4-6-record-payment-finalize-session.md)
- [5-3-driver-parking-history.md](./5-3-driver-parking-history.md)
- [6-1-attendant-views-lot-occupancy-stats.md](./6-1-attendant-views-lot-occupancy-stats.md)
- [3-2-set-operating-hours-pricing-rules.md](./3-2-set-operating-hours-pricing-rules.md)
- [3-3-create-attendant-accounts.md](./3-3-create-attendant-accounts.md)
- [epic-3-retro-2026-03-27.md](./epic-3-retro-2026-03-27.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Build an operator-scoped reporting contract that combines finalized payments, completed sessions, occupancy metrics, and accepted lease terms.
- Keep all revenue and performance calculations backend-owned and expose a thin typed mobile dashboard reachable from the current operator workspace.
- Add focused backend and Flutter regression coverage for scoping, aggregation correctness, empty states, and expired-lease visibility.

### Completion Notes List

- Story context anchored on Epic 8 lease truth, PRD operator-reporting requirements, existing operator lot-management patterns, and backend-owned financial/occupancy aggregation.
- Added explicit guardrails that operator reporting must depend on accepted lease access and backend-readable split terms, not bootstrap shortcuts or contract HTML parsing.
- Implemented an operator-only reports endpoint in `reports.py` that aggregates completed session payments for historical or active managed lots, computes operator and owner shares from canonical lease terms, derives period occupancy context from session overlap, and returns explicit `EXPIRED` lease visibility plus honest empty states.
- Added a dedicated operator revenue dashboard sheet reachable from each managed lot card, with backend-driven day/week/month switching, operator-share metrics, and vehicle-type breakdown rendering inside the current operator workspace.
- Validation completed with `cd backend && docker compose run --rm pytest python -m pytest tests/test_operator_revenue_reports.py tests/test_owner_revenue_reports.py tests/test_operator_lot_management.py`, `cd backend && docker compose run --rm pytest python -m pytest`, `cd mobile && flutter test test/widget_test.dart`, and `cd mobile && flutter test`.
- Post-review closure updated operator managed-lot reads to drop expired leases from active workspace surfaces, aligned reporting expiry behavior with shared contract-state transitions, and passed full backend/mobile regression.

### File List

- `_bmad-output/implementation-artifacts/8-3-operator-revenue-dashboard.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/reports.py`
- `backend/src/app/schemas/report.py`
- `backend/tests/test_operator_revenue_reports.py`
- `mobile/lib/src/features/operator_lot_management/data/operator_lot_management_service.dart`
- `mobile/lib/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart`
- `mobile/lib/src/features/operator_revenue_dashboard/presentation/operator_revenue_dashboard_sheet.dart`
- `mobile/test/final_shift_close_out_test.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-28: Created Story 8.3 implementation artifact for operator-scoped revenue and performance reporting derived from accepted lease terms, finalized payments, and completed session data.
- 2026-03-29: Implemented Story 8.3 with backend-owned operator revenue/performance reporting, operator workspace dashboard access, and focused plus full backend/mobile regression validation.
- 2026-03-29: Closed review findings by fixing expired-lease workspace/report handling and re-validating the complete backend/mobile test suites.