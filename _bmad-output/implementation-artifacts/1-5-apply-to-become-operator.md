# Story 1.5: Apply to Become Operator

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Driver,
I want to apply for Operator capability on my existing account,
so that I can lease lots and manage parking operations without creating a separate public account.

## Acceptance Criteria

1. Given I am authenticated with a public account, when I open the Operator application flow, then I can submit the business and verification information required by the platform.
2. The system stores the Operator application as a pending review tied to my existing public account instead of creating a second public user account.
3. An Admin can review the pending Operator application and approve or reject it.
4. After approval, the same public account gains Operator capability through a linked `manager` record and can access Operator-only features, with `user.role` allowed to move to `MANAGER` as the primary public workspace.
5. The approved Operator account can later create separate Attendant accounts without converting the public account itself into an Attendant login.
6. If the application is rejected, the account remains usable as Driver and the rejection result is visible to the applicant.

## Implementation Clarifications

- This story extends the existing public account model. Do not create a second public login for Operator.
- The current schema represents Operator capability on the same public identity by adding a `manager` row tied to the same `user`; `user.role` may be updated to `MANAGER` as the primary public workspace, but existing public capabilities must remain attached to that same `user`.
- The approval workflow should fit the same FastAPI-owned authentication and RBAC model used elsewhere in the project.
- The application record should preserve enough business-verification metadata for Admin review and future audits.
- This story should enable Operator capability expansion only; it should not yet implement lot configuration, pricing, or attendant account-provisioning screens from Epic 3.
- Attendant accounts remain separate credentials created later by approved Operators.

## Tasks / Subtasks

- [ ] Task 1: Define the Operator capability-application contract (AC: 1, 2, 6)
  - [ ] Add request/response schemas for submitting and viewing an Operator application.
  - [ ] Decide the minimum business and verification fields needed for MVP thesis review.
  - [ ] Ensure the contract is bound to the current authenticated public account.

- [ ] Task 2: Implement backend persistence and review flow (AC: 2, 3, 4, 6)
  - [ ] Add the required API endpoints for creating an Operator application and for Admin review actions.
  - [ ] Persist application state with at least pending, approved, and rejected statuses.
  - [ ] Update the same public account with Operator capability only after successful Admin approval by creating the linked `manager` record on the same `user` identity.
  - [ ] Keep approval and capability-grant operations atomic to avoid half-approved states.

- [ ] Task 3: Extend authorization and future-operator readiness (AC: 4, 5)
  - [ ] Ensure Admin-only review endpoints are protected consistently with the existing dependency and RBAC pattern.
  - [ ] Ensure that after approval the account can access Operator-scoped features without requiring a new signup flow.
  - [ ] Confirm the Operator capability is modeled so future stories can create dedicated Attendant accounts while keeping account identities separate.

- [ ] Task 4: Add the minimum mobile flow for submitting and seeing application status (AC: 1, 6)
  - [ ] Add a basic screen or placeholder flow that lets an authenticated public user submit the Operator application.
  - [ ] Show at least the latest application state so the user can tell whether review is pending, approved, or rejected.
  - [ ] Keep this story focused on capability application, not full operator dashboard functionality.

- [ ] Task 5: Test the application and approval lifecycle (AC: 2, 3, 4, 5, 6)
  - [ ] Add backend tests for successful submission, unauthorized review access, approval, rejection, and capability grant.
  - [ ] Verify the same account identity is preserved before and after capability approval.
  - [ ] Add focused mobile coverage for request submission or status rendering if a UI flow is added.

## Dev Notes

### Story Foundation

- This story depends on the public-account foundation from Story 1.1 and the shared login/session behavior from Story 1.2.
- It establishes the capability-expansion rule that a Driver can become an Operator on the same account.
- It is a prerequisite for Epic 3 workflows that require an authenticated Operator.

### Domain Constraints To Respect

- Public signup remains Driver-first; this story must not reopen account creation semantics.
- Operator is a capability added to the same public account after review through the `manager` table, while `user.role` serves as the current primary public workspace.
- Admin approval is required before any Operator-only action becomes available.
- Attendant remains a separate account and must not be represented as a mode-switch on the Operator's public account.

### Suggested File Areas For This Story

- Backend:
  - `backend/src/app/api/v1`
  - `backend/src/app/schemas`
  - `backend/src/app/models`
  - `backend/tests`
- Mobile:
  - `mobile/lib/src/features/auth`
  - `mobile/lib/src/features/profile` or another capability-application area if created

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 1 / Story 1.5
- [prd.md](../prd.md) - Roles & Account Model, User Management & Authentication, Journey 3
- [architecture.md](../architecture.md)
- [tech-design.md](../tech-design.md)
- [erd.md](../../project-docs/erd.md)
- [reference.md](../../project-docs/reference.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Story created to capture Operator capability expansion on the same public account.
- Story keeps Operator application and approval separate from later lot-operations implementation.
- Story explicitly preserves the rule that Attendant accounts are separate credentials created after Operator approval.

### File List

- `_bmad-output/implementation-artifacts/1-5-apply-to-become-operator.md`