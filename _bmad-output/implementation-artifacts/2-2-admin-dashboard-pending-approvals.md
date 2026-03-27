# Story 2.2: Admin Dashboard & Pending Approvals

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an Admin,
I want to review pending approvals from one dashboard,
so that I can vet capability applications and inventory submissions without using raw backend endpoints.

## Acceptance Criteria

1. Given I am authenticated as an Admin in the mobile app, when I open the pending approvals dashboard, then I can see pending LotOwner applications, Operator applications, and pending parking-lot registrations supported by the backend.
2. Given I open a pending capability application, when I review its submitted business or ownership information, then I can approve or reject it with a visible decision result.
3. Given I reject an application, when I submit the decision, then I must provide a rejection reason and the applicant can later see that result in their own application status screen.
4. Given I approve an Operator or LotOwner capability application, when the review succeeds, then the same public account keeps its identity and gains the approved capability through the existing backend approval flow.
5. Given I am authenticated with Admin capability in the app, when I access the approval dashboard, then the backend authorization model and mobile session model are aligned so valid Admin users can actually perform review actions.

## Implementation Clarifications

- This story is the follow-up to Stories 1.4 and 1.5 for the missing app-facing Admin review flow. It should consume the approval endpoints already added for capability applications and extend them where needed for lot registration review.
- The dashboard should prefer one approvals workspace over separate ad hoc review screens so Admin users have a predictable place to process pending work.
- This story must resolve the current mismatch where the auth payload can mark `role == ADMIN` as admin-capable while some protected routes still require `is_superuser`.
- This story should stay focused on review operations and approval visibility. It must not expand into the broader system-management and suspension workflows reserved for Story 2.3.
- Capability approval decisions must preserve the same-account model introduced in Epic 1. Admin review must not create secondary public identities.

## Tasks / Subtasks

- [x] Task 1: Define the Admin approvals dashboard contract (AC: 1, 2, 3)
  - [x] Identify the minimum list/detail fields needed for pending LotOwner applications, Operator applications, and pending lot registrations.
  - [x] Normalize the mobile data contract so Admin users can distinguish approval type, applicant, current status, and submitted verification material.
  - [x] Confirm the rejection-reason requirement is enforced consistently between mobile validation and backend responses.

- [x] Task 2: Align Admin authorization end-to-end (AC: 5)
  - [x] Reconcile Admin capability detection in auth/session payloads with the route dependency used by review endpoints.
  - [x] Add or adjust backend tests so valid Admin users can list and review pending approvals while non-admin users are rejected.
  - [x] Verify the mobile app lands Admin users in an approvals workspace instead of a placeholder shell.

- [x] Task 3: Build the mobile Admin approvals workspace (AC: 1, 2, 3)
  - [x] Add an Admin dashboard screen that lists pending approvals by type.
  - [x] Add detail/review flows for approving or rejecting LotOwner and Operator applications.
  - [x] Reuse consistent loading, error, and empty states instead of one-off placeholder layouts.

- [x] Task 4: Integrate decision results with existing applicant flows (AC: 3, 4)
  - [x] Verify approved/rejected decisions surface correctly in the applicant-facing LotOwner and Operator status screens.
  - [x] Verify approved capability applications still refresh the same-account session correctly after Admin review.
  - [x] Document any lot-registration approval behavior that depends on later Epic 2 stories.

- [x] Task 5: Test the Admin review lifecycle (AC: 1, 2, 3, 4, 5)
  - [x] Add backend tests for Admin list/review access and rejection-reason enforcement.
  - [x] Add focused Flutter coverage for the Admin dashboard list and review actions.
  - [x] Verify the integrated flow manually on Android after wiring the Admin workspace.

## Dev Notes

### Story Foundation

- This story follows Stories 1.4 and 1.5, which already implemented applicant-side LotOwner and Operator submission/status flows.
- It provides the first app-facing Admin workspace needed to complete those approval loops end-to-end.
- It also sets the dashboard pattern that later Epic 2 approval and moderation stories can reuse.

### Domain Constraints To Respect

- Admin accounts remain separate privileged accounts outside the public signup flow.
- Public capability applications must continue to grant capabilities on the same `user` identity after approval.
- Review actions should be auditable and must not allow silent rejection without a reason when the workflow requires one.
- This story is not the place to redesign the full product shell; it should use the best available shared layout patterns without absorbing broader UX standardization work.

### Suggested File Areas For This Story

- Backend:
  - `backend/src/app/api/v1/users.py`
  - `backend/src/app/api/v1/auth.py`
  - `backend/src/app/api/dependencies.py`
  - `backend/src/app/schemas`
  - `backend/tests`
- Mobile:
  - `mobile/lib/main.dart`
  - `mobile/lib/src/features/`
  - `mobile/test/`

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 2 / Story 2.2
- [prd.md](../prd.md) - FR41, FR43, FR45, FR48
- [tech-design.md](../tech-design.md)
- [1-4-apply-to-become-lot-owner.md](./1-4-apply-to-become-lot-owner.md)
- [1-5-apply-to-become-operator.md](./1-5-apply-to-become-operator.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Story created as the explicit follow-up for the missing app-facing Admin review flow identified during Story 1.5 review.
- Scope intentionally keeps broader app shell standardization and localization out of this story so capability-approval closure can proceed independently.
- Implemented `AdminApprovalsScreen` as the first app-facing Admin workspace and replaced the previous Admin placeholder shell.
- Added a typed admin approvals service that lists and reviews pending LotOwner and Operator applications through the existing backend approval endpoints.
- Aligned backend authorization with the current mobile session model by allowing `role == ADMIN` to satisfy the Admin dependency even when `is_superuser` is false.
- Parking-lot approvals remain a documented placeholder tab until Story 2.1 provides backend registration/review contracts; the dashboard already reserves the navigation slot for that follow-up.
- Focused verification passed with backend Docker tests (`26 passed` across dependency, lot-owner, and operator approval suites), Flutter widget tests (`13 passed`), and Android manual verification showing the Admin approvals dashboard rendered correctly on-device with a live pending LotOwner application visible.

### File List

- `_bmad-output/implementation-artifacts/2-2-admin-dashboard-pending-approvals.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/dependencies.py`
- `backend/tests/test_dependencies.py`
- `mobile/lib/main.dart`
- `mobile/lib/src/features/admin_approvals/data/admin_approvals_service.dart`
- `mobile/lib/src/features/admin_approvals/presentation/admin_approvals_screen.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-27: Created follow-up Story 2.2 artifact to cover Admin approval UI, authorization alignment, and end-to-end pending approval handling after Story 1.5 review.
- 2026-03-27: Implemented the Admin approvals dashboard for LotOwner and Operator applications, aligned Admin authorization with session payloads, added focused backend/widget coverage, and left a documented placeholder for parking-lot approvals pending Story 2.1 backend support.
- 2026-03-27: Closed Story 2.2 after Android manual verification confirmed the Admin approvals dashboard rendered correctly on a connected device and surfaced live pending approval data.