# Story 1.4: Apply to Become Lot Owner

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Driver,
I want to apply for LotOwner capability on my existing account,
so that I can register parking lots and post them for lease without creating a separate public account.

## Acceptance Criteria

1. Given I am authenticated with a public account, when I open the LotOwner application flow, then I can submit the ownership and verification information required by the platform.
2. The system stores the LotOwner application as a pending review tied to my existing public account instead of creating a second public user account.
3. An Admin can review the pending LotOwner application and approve or reject it.
4. After approval, the same public account gains LotOwner capability through a linked `lot_owner` record and can access LotOwner-only features, with `user.role` allowed to move to `LOT_OWNER` as the primary public workspace.
5. If the application is rejected, the account remains usable as Driver and the rejection result is visible to the applicant.

## Implementation Clarifications

- This story extends the existing public account model. Do not create a second public login for LotOwner.
- The current schema represents capability on the same public identity by adding a `lot_owner` row tied to the same `user`; `user.role` may be updated to `LOT_OWNER` as the primary public workspace, but the existing `driver` capability must not be deleted.
- The approval workflow should fit the same FastAPI-owned authentication and RBAC model used elsewhere in the project.
- The application record should preserve enough document and status metadata for Admin review and future audits.
- This story should enable capability expansion only; it should not yet implement the full parking-lot registration UI from Epic 2.
- Attendant and Admin remain separate-account flows and are out of scope for this story except where they affect authorization or approval.

## Tasks / Subtasks

- [ ] Task 1: Define the LotOwner capability-application contract (AC: 1, 2, 5)
  - [ ] Add request/response schemas for submitting and viewing a LotOwner application under the existing backend schema organization.
  - [ ] Decide the minimum ownership and verification fields needed for MVP thesis review.
  - [ ] Ensure the contract is tied to the current authenticated public account rather than accepting an arbitrary account identifier from the client.

- [ ] Task 2: Implement backend persistence and review flow (AC: 2, 3, 4, 5)
  - [ ] Add the required API endpoints for creating a LotOwner application and for Admin review actions.
  - [ ] Persist application state with at least pending, approved, and rejected statuses.
  - [ ] Update the same public account with LotOwner capability only after successful Admin approval by creating the linked `lot_owner` record on the same `user` identity.
  - [ ] Keep approval and capability-grant operations atomic to avoid half-approved states.

- [ ] Task 3: Extend authorization and account resolution rules (AC: 3, 4)
  - [ ] Ensure Admin-only review endpoints are protected consistently with the existing dependency and RBAC pattern.
  - [ ] Ensure that after approval the account can access LotOwner-scoped features without requiring a new signup flow.
  - [ ] Confirm login/session handling remains the same public-account session before and after capability approval.

- [ ] Task 4: Add the minimum mobile flow for submitting and seeing application status (AC: 1, 5)
  - [ ] Add a basic screen or placeholder flow that lets an authenticated public user submit the LotOwner application.
  - [ ] Show at least the latest application state so the user can tell whether review is pending, approved, or rejected.
  - [ ] Keep this story focused on capability application, not full lot-registration workflows.

- [ ] Task 5: Test the application and approval lifecycle (AC: 2, 3, 4, 5)
  - [ ] Add backend tests for successful submission, unauthorized review access, approval, rejection, and capability grant.
  - [ ] Verify the same account identity is preserved before and after capability approval.
  - [ ] Add focused mobile coverage for request submission or status rendering if a UI flow is added.

## Dev Notes

### Story Foundation

- This story depends on the public-account foundation from Story 1.1 and the shared login/session behavior from Story 1.2.
- It establishes the capability-expansion rule that a Driver can become a LotOwner on the same account.
- It is a prerequisite for Epic 2 workflows that require an authenticated LotOwner.

### Domain Constraints To Respect

- Public signup remains Driver-first; this story must not reopen account creation semantics.
- LotOwner is a capability added to the same public account after review through the `lot_owner` table, while `user.role` serves as the current primary public workspace.
- Admin approval is required before any LotOwner-only action becomes available.
- Do not use this story to implement separate Admin provisioning or Attendant-account behavior.

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

- [epics.md](../planning-artifacts/epics.md) - Epic 1 / Story 1.4
- [prd.md](../prd.md) - Roles & Account Model, User Management & Authentication, Journey 4
- [architecture.md](../architecture.md)
- [tech-design.md](../tech-design.md)
- [erd.md](../../project-docs/erd.md)
- [reference.md](../../project-docs/reference.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Story created to capture LotOwner capability expansion on the same public account.
- Story keeps LotOwner application and approval separate from full lot-registration implementation.
- Story aligns with the clarified auth model where Attendant and Admin remain separate-account flows.

### File List

- `_bmad-output/implementation-artifacts/1-4-apply-to-become-lot-owner.md`