# Story 8.2: Owner Revenue Dashboard

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Lot Owner,
I want to view my share of the revenue,
so that I can track my income.

## Acceptance Criteria

1. Given I am an authenticated Lot Owner with a lot that has an accepted lease and settled parking payments, when I open the owner revenue dashboard for a selected lot and period, then I see backend-calculated gross revenue, my owner share, the operator share, and the lease status for that period.
2. Given I change the reporting range to day, week, or month, when the dashboard reloads, then the totals are recalculated on the backend from authoritative payment and session data rather than from Flutter-side math.
3. Given the lot has no accepted lease yet, no completed paid sessions in the selected range, or no revenue-bearing data at all, when I open the dashboard, then the UI shows an honest empty state explaining why there is no revenue to display instead of rendering misleading zero-value business metrics.
4. Given the underlying lease has expired or is otherwise no longer active, when I view the revenue dashboard, then historical earnings remain visible with explicit lease status such as `EXPIRED` so the owner can distinguish past revenue from an actively managed lot.
5. Given I attempt to request revenue for a lot I do not own, when the backend evaluates the request, then access is denied and no operator or cross-owner financial data is exposed.

## Implementation Clarifications

- Story 8.2 is the Lot Owner reporting slice of Epic 8. It depends on Story 8.1 to establish an authoritative accepted lease path and a backend-readable revenue split term.
- The dashboard must calculate owner share from authoritative backend data. Do not parse share percentages back out of generated contract HTML or let Flutter recompute totals from raw rows.
- Epic 4 payment finalization and Story 5.3 history proved that finalized session/payment data already forms the trustworthy financial base. Reuse those records rather than inventing a second owner ledger.
- This story is about read-side revenue visibility, not lease creation, admin lease approval, payout settlement, invoicing, or accounting export.
- Epic 9 will later normalize owner shell navigation. Until then, the dashboard only needs to be reachable from the current Lot Owner workspace without introducing a premature shell refactor.

## Tasks / Subtasks

- [ ] Task 1: Add owner-scoped backend revenue reporting contracts (AC: 1, 2, 4, 5)
  - [ ] Introduce or extend a backend reports surface, preferably `backend/src/app/api/v1/reports.py`, for Lot Owner revenue summaries filtered by lot and period.
  - [ ] Aggregate authoritative settled payment data plus accepted lease terms to return gross revenue, owner share, operator share, and lease status in one typed response.
  - [ ] Enforce strict ownership scoping so a Lot Owner can only read revenue for lots they own.

- [ ] Task 2: Preserve lease-term and financial truth in the reporting model (AC: 1, 2, 4)
  - [ ] Reuse the accepted-lease lifecycle from Story 8.1 as the source of reporting eligibility and lease status.
  - [ ] Ensure the revenue split percentage is stored in an explicit backend-readable field or equivalent canonical structure; do not rely on contract-body parsing.
  - [ ] Keep historical revenue readable after lease expiration while making expired-state visibility explicit.

- [ ] Task 3: Add the Lot Owner revenue dashboard to the mobile workspace (AC: 1, 2, 3, 4)
  - [ ] Add a dedicated owner revenue feature or a clearly separated owner-reporting surface rather than overloading parking-lot registration form code with dense financial logic.
  - [ ] Make the dashboard reachable from the current Lot Owner workspace patterns, likely from the lot card or a follow-on owner management surface, without waiting for Epic 9 shell work.
  - [ ] Render summary metrics, period switching, honest empty state, and explicit expired-lease messaging using the same lightweight Dio-backed service pattern already used in owner/operator features.

- [ ] Task 4: Add focused regression coverage and verification (AC: 1, 2, 3, 4, 5)
  - [ ] Add backend tests for owner-only scoping, period filtering, split-based revenue calculation, expired-lease visibility, and honest no-data responses.
  - [ ] Add Flutter tests for dashboard loading, period switching, empty-state rendering, and expired-lease labeling.
  - [ ] Verify with backend Docker tests and local `flutter test` on the affected revenue-dashboard surfaces.

## Dev Notes

### Story Foundation

- PRD Journey 4 says the Lot Owner monitors the active contract and can see when it is expiring; Epic 8 extends that into owner-visible earnings derived from the accepted lease business relationship.
- PRD FR39 and FR40 make lease visibility and generated contract truth part of the owner workflow; Story 8.2 should consume that lease truth, not duplicate it.
- Epic 8 is a workflow-enablement epic after the Epic 3 retrospective. A usable owner dashboard should reinforce the proper lease lifecycle rather than reintroducing temporary bootstrap shortcuts.

### Cross-Epic Intelligence

- Story 8.1 is the prerequisite for this dashboard because it must create the authoritative accepted lease path and persist the commercial split terms in backend-readable form.
- Story 4.6 already records finalized payment truth, and Story 5.3 already consumes completed payment/session history for drivers. Story 8.2 should extend those backend-owned financial patterns to the owner role instead of inventing a new ledger.
- Story 6.1 already introduced backend-owned occupancy summary patterns. If occupancy-related business context is shown on the owner dashboard, reuse reporting-style backend aggregation rather than client-side estimation.

### Domain Constraints To Respect

- Only lots owned by the authenticated Lot Owner are reportable in this story.
- Owner share must be computed from finalized revenue events and canonical lease terms, not from draft contracts or client-entered numbers.
- Historical revenue must remain visible even after lease expiration, but the UI must not imply that the lease is still actively governing the lot.
- If there is no accepted lease or no settled revenue in the selected period, the dashboard should explain that state explicitly.

### Architecture Guardrails

- The backend project shape already reserves `reports.py` for revenue and occupancy. Prefer that module over hiding reporting logic inside `lots.py` or ad hoc mobile aggregation.
- Keep the financial calculation backend-owned and typed through explicit schemas such as a new `backend/src/app/schemas/report.py` if needed.
- Reuse the current shared public-account model: the Lot Owner dashboard must operate under the same authenticated `user` identity and linked `lot_owner` record rather than inventing a separate business-login concept.
- If Story 8.1 introduces new lease-term fields, Story 8.2 should consume those fields directly rather than reverse-engineering contract HTML.

### Library / Framework Requirements

- Backend: FastAPI, async SQLAlchemy, existing payment/session/lease models, and current exception/ownership-check patterns.
- Mobile: Flutter with `dio`, the current service-factory pattern in `main.dart`, and management-style screens consistent with existing owner/operator flows.
- Do not introduce BI/dashboard packages, client-side charting complexity, or a second persistence layer for this first owner reporting slice unless the repo already needs it.

### File Structure Requirements

- Backend likely touch points:
  - `backend/src/app/api/v1/reports.py` (new or completed)
  - `backend/src/app/models/financials.py`
  - `backend/src/app/models/leases.py`
  - `backend/src/app/models/sessions.py`
  - `backend/src/app/schemas/report.py` (new if needed)
  - `backend/src/app/services/` reporting helper module if aggregation complexity grows
  - `backend/tests/` focused revenue-report suites
- Mobile likely touch points:
  - `mobile/lib/main.dart`
  - `mobile/lib/src/features/parking_lot_registration/`
  - `mobile/lib/src/features/owner_revenue_dashboard/` (new feature folder if cleaner)
  - `mobile/test/`

### Testing Requirements

- Backend verification should run through Docker pytest and cover split-based math, owner-only scoping, no-data ranges, and expired-lease visibility.
- Flutter verification should run with local `flutter test` and prove the dashboard is reachable from the current Lot Owner workspace, not only that DTO parsing works.
- Tests should explicitly cover the case where Story 8.1 has not yet produced an accepted lease for the lot, because that is a likely real-world state during rollout.

### Implementation Risks To Avoid

- Do not compute owner share in Flutter from raw payment rows.
- Do not expose operator-wide or other owners' financial data through weak lot filtering.
- Do not depend on parsing generated lease contract HTML to recover commercial terms.
- Do not block Story 8.2 behind Epic 9 shell work if the current owner workspace can host a reachable entry point.
- Do not silently treat missing revenue data as a successful business result without explaining why the dashboard is empty.

### Recent Repository Patterns

- Recent stories consistently centralize truth on the backend and expose thin typed Flutter services for presentation.
- Current owner and operator flows favor extending existing workspace screens with focused new sheets, cards, or routes rather than restructuring the whole app before Epic 9.
- Financial and occupancy read models already rely on explicit backend aggregation contracts; Story 8.2 should follow the same discipline.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 8 / Story 8.2
- [prd.md](../prd.md) - Journey 3, Journey 4, FR39, FR40
- [architecture.md](../architecture.md) - backend-owned business truth, `/reports/*`, shared public-account model
- [tech-design.md](../tech-design.md) - `reports.py`, revenue and occupancy plan, thesis MVP completion roadmap
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - Lot Owner contract-management expectations and Operator/LotOwner management UX direction
- [8-1-create-lease-contract.md](./8-1-create-lease-contract.md)
- [4-6-record-payment-finalize-session.md](./4-6-record-payment-finalize-session.md)
- [5-3-driver-parking-history.md](./5-3-driver-parking-history.md)
- [6-1-attendant-views-lot-occupancy-stats.md](./6-1-attendant-views-lot-occupancy-stats.md)
- [epic-3-retro-2026-03-27.md](./epic-3-retro-2026-03-27.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Build an owner-scoped reporting contract on top of finalized payment/session data and accepted lease terms.
- Keep revenue split math backend-owned and expose a thin typed dashboard surface in the current Lot Owner workspace.
- Add focused backend and Flutter regression coverage for scoping, no-data handling, and expired-lease visibility.

### Completion Notes List

- Story context anchored on Epic 8 lease lifecycle dependencies, owner-facing revenue visibility, finalized payment truth, and current Lot Owner workspace reachability.
- Added explicit guardrails that the revenue split must be stored in backend-readable lease data rather than inferred from generated contract content.

### File List

- `_bmad-output/implementation-artifacts/8-2-owner-revenue-dashboard.md`

### Change Log

- 2026-03-28: Created Story 8.2 implementation artifact for owner-scoped revenue reporting derived from accepted lease terms and finalized payment data.