# Story 8.1: Create Lease Contract

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Lot Owner,
I want to send a lease contract to an Operator,
so that they can manage my lot for a revenue split.

## Acceptance Criteria

1. Given I am authenticated as a Lot Owner for an approved parking lot without an active lease, when I invite an approved Operator and define the commercial terms, then the backend creates a pending lease record plus a generated lease contract draft that the target Operator can retrieve.
2. Given a lease contract draft exists for a lot, when the invited Operator reviews and accepts it, then the contract transitions out of draft, the lease becomes the authoritative operator-assignment path for that lot, and the temporary lease-bootstrap bridge is no longer required for this workflow.
3. Given a lot already has an active lease, or the selected Operator/lot relationship is otherwise invalid, when the owner tries to create another contract, then the contract is rejected cleanly without creating duplicate lease or contract state.
4. Given a lease later reaches its end-of-term or is otherwise no longer active, when the lease state is read in owner or operator flows, then it is surfaced explicitly as `EXPIRED` and the Lot Owner is provided the planned manual override entry point to disable new check-ins rather than leaving the lot looking actively managed forever.
5. Given this epic is replacing the temporary UAT bootstrap path identified in the Epic 3 retrospective, when Story 8.1 is implemented, then the backend and mobile flows remain reachable through the current Lot Owner and Operator workspaces without inventing a second capability model, shell system, or out-of-band admin shortcut.

## Implementation Clarifications

- This story owns lease-contract creation, owner invitation, operator review, and operator acceptance for the first-class lease path. Revenue dashboards belong to Stories 8.2 and 8.3.
- The existing `/user/me/parking-lots/{lot_id}/lease-bootstrap` flow is a temporary bridge used for earlier UAT. Story 8.1 should replace that path for real lease onboarding instead of polishing it into the permanent design.
- The contract artifact should be backend-generated and stored in repository-aligned contract fields (`LeaseContract.content`, `LeaseContract.contract_number`, and any linked file/HTML output) rather than assembled on the mobile client.
- The ERD and existing models already define both `LotLease` and `LeaseContract`; however, the current implementation only partially uses them. The story should complete the lifecycle rather than introducing parallel lease tables.
- FR42 still governs admin approval of lease requests at the broader platform level. If Story 8.1 touches approval state, it should reuse the existing domain direction for admin-reviewed leasing instead of inventing a separate contract-approval authority.
- The acceptance criterion about expired leases is primarily a state-truth requirement in this story. The eventual manual override action may share backend seams with the existing lot suspension capability, but this story should not expand into a full admin/operator lot-suspension redesign.

## Tasks / Subtasks

- [x] Task 1: Implement the backend lease-contract lifecycle for owner invitation and operator acceptance (AC: 1, 2, 3, 4)
  - [x] Add or complete the backend schemas, route contracts, and persistence logic required for a Lot Owner to create a lease contract draft for an approved lot and invited Operator.
  - [x] Ensure the Operator can read and accept the received contract through backend-owned state transitions that activate the lease without duplicate active-lease records.
  - [x] Reject invalid lot/operator combinations, duplicate active leases, and malformed commercial terms without partial state.

- [x] Task 2: Replace the temporary bootstrap path with a first-class owner/operator workflow (AC: 2, 5)
  - [x] Rework the current lease-bootstrap entry point in the Lot Owner flow so it leads into a formal contract-generation experience instead of directly activating an operator.
  - [x] Add the minimum Operator-facing contract review/acceptance surface needed to exercise the lease lifecycle in the current app shell arrangement.
  - [x] Keep the workflow consistent with the existing multi-capability public account model and avoid introducing a second workspace-routing mechanism ahead of Epic 9.

- [x] Task 3: Preserve lifecycle truth for active and expired leases (AC: 3, 4)
  - [x] Enforce that only one authoritative active lease exists per lot at a time.
  - [x] Surface explicit lease/contract status information to owner/operator reads so expired or inactive contracts do not masquerade as active management.
  - [x] Keep the owner-visible manual override seam for expired leases aligned with the repo's existing lot-status and suspension patterns.

- [x] Task 4: Add focused regression coverage and verification (AC: 1, 2, 3, 4, 5)
  - [x] Add backend tests for contract creation, duplicate-lease rejection, operator acceptance, and expired-state visibility.
  - [x] Add mobile tests for the Lot Owner contract-invitation surface and the Operator contract-review/acceptance path.
  - [x] Verify with backend Docker tests and local `flutter test` for the touched lease-management surfaces.

## Dev Notes

### Story Foundation

- Epic 8 is now a workflow-enablement epic, not just a finance/reporting add-on. The Epic 3 retrospective explicitly states that real lease lifecycle work replaces the temporary lease-bootstrap path used to unblock earlier UAT.
- PRD FR37-FR40 define the lease business flow: Lot Owners post lease terms, Operators lease posted lots, active lease contracts are visible/manageable, and the system generates the contract artifact automatically.
- The tech design already calls out lease contract generation in HTML as part of thesis MVP completion, which makes backend-owned contract rendering/storage the intended direction.
- The UX specification frames Lot Owners as users who manage lease contracts, not merely assign an operator behind the scenes.

### Cross-Epic Intelligence

- Story 3.1 and Story 3.2 established lot-owner parking-lot management and operator managed-lot patterns that this story should extend instead of bypassing.
- Story 3.3 proved that operator functionality is gated by active lease truth. Story 8.1 must become the durable path that makes those operator workflows naturally reachable.
- Epic 9 will normalize shells later, so Story 8.1 should keep any owner/operator navigation additions lightweight and compatible with the current temporary workspace-switch approach rather than hardcoding a new shell architecture.

### Domain Constraints To Respect

- Only a Lot Owner who owns the parking lot may initiate a lease contract for that lot.
- Only one active lease may govern a lot at a time.
- The contract artifact must remain backend-owned and historically readable; it should not disappear once accepted or expired.
- Lease expiration must be visible as explicit state because later owner/operator workflows depend on contract truth, not inferred reachability.
- Story 8.1 must not silently preserve the direct-activation bootstrap path as the primary business flow.

### Architecture Guardrails

- Prefer extending the existing lease domain in `backend/src/app/models/leases.py` and related lot routes before creating new domain modules or duplicate models.
- If a migration is required for `lease_contract`, create it explicitly; the table is modeled in code and ERD documents, but the repository may not yet have a migration/wired route surface for it.
- Keep contract generation and lease-state transitions transactional and backend-owned. Mobile should submit terms and decisions, not construct canonical contract content.
- Reuse the current owner/operator workspace seams in Flutter (`parking_lot_registration` and `operator_lot_management`) rather than introducing a parallel management feature namespace.
- If admin-reviewed lease approval is involved in the story slice, keep it aligned with existing leasing/admin contracts in the backend instead of inventing a second approval authority tied only to the contract artifact.

### Library / Framework Requirements

- Backend: reuse FastAPI, SQLAlchemy async, existing lot/lease models, existing exception types, and the current route/scheduler patterns already used in the backend codebase.
- Contract generation should stay within backend-owned HTML/string/file generation patterns already envisioned by the tech design. Do not move contract rendering to Flutter.
- Mobile: reuse the existing Dio service pattern, bottom-sheet/form interaction patterns, and workspace screens already used for lot owner/operator management flows.
- Do not introduce a new document-generation framework or a second persistence store unless the repo already requires it.

### File Structure Requirements

- Backend likely touch points:
  - `backend/src/app/models/leases.py`
  - `backend/src/app/api/v1/lots.py`
  - `backend/src/app/schemas/parking_lot.py`
  - `backend/src/app/schemas/lease_contract.py` (new if needed)
  - `backend/src/app/crud/` or `backend/src/app/services/` lease-focused helper module if lifecycle complexity grows
  - `backend/src/migrations/versions/` for any missing lease-contract schema migration
  - `backend/tests/test_parking_lots.py` or a new focused lease-contract suite
- Mobile likely touch points:
  - `mobile/lib/src/features/parking_lot_registration/data/parking_lot_service.dart`
  - `mobile/lib/src/features/parking_lot_registration/presentation/parking_lot_registration_screen.dart`
  - `mobile/lib/src/features/operator_lot_management/data/operator_lot_management_service.dart`
  - `mobile/lib/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart`
  - `mobile/lib/src/features/.../data/lease_contract_service.dart` if a dedicated service is cleaner than overloading lot registration
  - `mobile/test/` owner/operator lease-management widget tests

### Testing Requirements

- Backend verification should run through Docker pytest and explicitly cover duplicate active-lease rejection, operator-only acceptance, owner-only contract creation, and expired-state visibility.
- If contract acceptance changes managed-lot reachability, tests should prove that operator lot reads depend on the authoritative accepted lease instead of the legacy bootstrap path.
- Flutter verification should prove both sides of the workflow are reachable in the current mobile shell arrangement: owner creates/sends the contract, operator can review/accept it.
- Prefer focused tests that mirror existing service/widget test patterns already used in lot registration and operator management.

### Implementation Risks To Avoid

- Do not leave the temporary lease-bootstrap route as the de facto primary lease flow after Story 8.1 lands.
- Do not allow duplicate active leases or duplicate contract activation for the same lot.
- Do not store critical contract terms only on the mobile client or inside transient UI state.
- Do not make operator workflow reachability depend on undocumented manual DB seeding or hidden admin shortcuts.
- Do not expand Story 8.1 into full dashboard/reporting work from Stories 8.2 or 8.3.

### Recent Repository Patterns

- Recent stories favored backend-owned lifecycle truth with explicit status modeling over ambiguous UI-side inference.
- Mobile management features currently extend existing screens with focused sheets/forms instead of introducing large shell refactors before Epic 9.
- Recent backend work has added focused regression suites around the exact mutation boundary being introduced; Story 8.1 should do the same for lease activation and contract truth.
- The latest repository commits show a pattern of implementing domain lifecycle logic first and then wiring the corresponding UI state, which fits this story's owner/operator lease flow.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 8 / Story 8.1
- [epics-distillate.md](../planning-artifacts/epics-distillate.md) - Epic 8 summary
- [prd.md](../prd.md) - FR37, FR38, FR39, FR40, FR42
- [architecture.md](../architecture.md) - backend project shape and business-flow architecture
- [tech-design.md](../tech-design.md) - lease contract generation in HTML, thesis MVP completion plan
- [ux-design-specification.md](../planning-artifacts/ux-design-specification.md) - Lot Owner contract-management expectations and current shell limitations
- [epic-3-retro-2026-03-27.md](./epic-3-retro-2026-03-27.md) - lease lifecycle readiness note replacing the bootstrap path
- [3-1-configure-lot-details-capacity.md](./3-1-configure-lot-details-capacity.md)
- [3-2-set-operating-hours-pricing-rules.md](./3-2-set-operating-hours-pricing-rules.md)
- [3-3-create-attendant-accounts.md](./3-3-create-attendant-accounts.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Replace the temporary lot-owner lease bootstrap with a first-class lease-contract lifecycle covering owner invitation, operator review, and operator acceptance.
- Keep the contract artifact and lifecycle transitions backend-owned using the existing lease domain models, migrations, and lot-management routes.
- Add focused backend and Flutter coverage proving the workflow is reachable from the current Lot Owner and Operator workspaces without duplicate active-lease state.

### Completion Notes List

- Added a dedicated backend lease router with owner contract creation plus operator contract list and acceptance endpoints, backed by canonical lease commercial-term fields and generated contract content.
- Replaced the owner-side temporary bootstrap interaction with a contract-draft flow in the current Lot Owner workspace and added an operator pending-contract review/acceptance surface in the current operator workspace.
- Hardened lease reads so expired leases surface explicitly without leaving operator-managed flows looking actively assigned forever.
- Validation completed with `cd backend && uv run pytest`, `cd mobile && flutter test`, focused owner/operator widget tests, and `cd backend && docker compose run --rm pytest python -m pytest tests/test_leases.py tests/test_parking_lots.py`.

### File List

- `_bmad-output/implementation-artifacts/8-1-create-lease-contract.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/__init__.py`
- `backend/src/app/api/v1/leases.py`
- `backend/src/app/api/v1/lots.py`
- `backend/src/app/models/leases.py`
- `backend/src/app/schemas/lease_contract.py`
- `backend/src/migrations/versions/c1b2c3d4e5f6_add_lease_terms_fields.py`
- `backend/tests/test_leases.py`
- `mobile/lib/src/features/lease_contract/data/lease_contract_models.dart`
- `mobile/lib/src/features/parking_lot_registration/data/parking_lot_service.dart`
- `mobile/lib/src/features/parking_lot_registration/presentation/parking_lot_registration_screen.dart`
- `mobile/lib/src/features/operator_lot_management/data/operator_lot_management_service.dart`
- `mobile/lib/src/features/operator_lot_management/presentation/operator_lot_management_screen.dart`
- `mobile/test/final_shift_close_out_test.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-28: Created Story 8.1 implementation artifact for replacing temporary lease bootstrap with a first-class lease contract lifecycle.
- 2026-03-28: Implemented Story 8.1 with canonical lease commercial-term fields, backend contract draft/accept APIs, owner/operator workspace integration, and focused plus full regression validation.