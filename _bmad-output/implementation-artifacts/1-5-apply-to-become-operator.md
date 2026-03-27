# Story 1.5: Apply to Become Operator

Status: done

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
5. If the application is rejected, the account remains usable as Driver and the rejection result is visible to the applicant.

## Implementation Clarifications

- This story extends the existing public account model. Do not create a second public login for Operator.
- The current schema represents approved Operator capability through the `manager` table tied to the same `user`; `user.role` may be updated to `MANAGER` as the primary public workspace, but the existing `driver` capability must not be deleted.
- Pending/rejected review history must use a dedicated Operator application record instead of overloading `manager` to mean both “pending request” and “approved capability”.
- The approval workflow must follow the same FastAPI-authenticated RBAC pattern used for other capability-approval flows.
- The application record should preserve enough business, document, and status metadata for Admin review and future audits.
- This story is only about capability expansion; it must not yet implement lot configuration, pricing, attendant provisioning, or lease-management workflows from later epics.
- Attendant and Admin remain separate-account flows and are out of scope for this story except where they affect authorization or approval.

## Tasks / Subtasks

- [x] Task 1: Define the Operator capability-application contract (AC: 1, 2, 5)
  - [x] Add request/response schemas for submitting and viewing an Operator application under the existing backend schema organization.
  - [x] Decide the minimum business and verification fields needed for MVP thesis review. Suggested baseline: applicant full name, phone number, business-license / tax identifier, one supporting document reference, optional notes, and application status metadata.
  - [x] Ensure the contract is tied to the current authenticated public account rather than accepting an arbitrary account identifier from the client.

- [x] Task 2: Implement backend persistence and review flow (AC: 2, 3, 4, 5)
  - [x] Add the required API endpoints for creating an Operator application and for Admin review actions.
  - [x] Persist application state with at least pending, approved, and rejected statuses.
  - [x] Update the same public account with Operator capability only after successful Admin approval by creating the linked `manager` record on the same `user` identity.
  - [x] Keep approval and capability-grant operations atomic and prevent re-review of already processed applications.
  - [x] Preserve prior review history when a rejected applicant resubmits instead of overwriting the earlier application record.

- [x] Task 3: Extend authorization and account resolution rules (AC: 3, 4)
  - [x] Ensure Admin-only review endpoints are protected consistently with the existing dependency and RBAC pattern.
  - [x] Ensure that after approval the account can access Operator-scoped features without requiring a new signup flow.
  - [x] Confirm login/session handling remains the same public-account session before and after capability approval, including capability refresh for the current device session.

- [x] Task 4: Add the minimum mobile flow for submitting and seeing application status (AC: 1, 5)
  - [x] Add a basic screen or placeholder flow that lets an authenticated public user submit the Operator application.
  - [x] Show at least the latest application state so the user can tell whether review is pending, approved, or rejected.
  - [x] Reuse the Story 1.4 capability-application UX pattern where practical, but keep copy and API contracts Operator-specific.

- [x] Task 5: Test the application and approval lifecycle (AC: 2, 3, 4, 5)
  - [x] Add backend tests for successful submission, unauthorized review access, approval, rejection, resubmission history, and capability grant.
  - [x] Verify the same account identity is preserved before and after Operator capability approval.
  - [x] Add focused mobile coverage for request submission or status rendering if a UI flow is added.
  - [x] Verify backend tests via Docker, Flutter tests locally, and Android smoke testing over ADB following the repo testing convention.

## Dev Notes

### Story Foundation

- This story depends on the public-account foundation from Story 1.1 and the shared login/session behavior from Story 1.2.
- It should mirror the dedicated capability-application pattern established in Story 1.4, adapted for Operator capability and the `manager` approved-capability table.
- It is a prerequisite for Epic 3 workflows that require an authenticated Operator.

### Domain Constraints To Respect

- Public signup remains Driver-first; this story must not reopen account creation semantics.
- Operator is a capability added to the same public account after review through the `manager` table, while `user.role` serves as the current primary public workspace.
- Because `manager` currently stores approved capability data only, pending/rejected review history should live in a separate application record rather than being inferred from missing `verified_at` alone.
- Admin approval is required before any Operator-only action becomes available.
- Do not use this story to implement lot assignment, attendant provisioning, lease application decisions, or parking-lot configuration beyond what is strictly required to grant the capability.

### Suggested File Areas For This Story

- Backend:
  - `backend/src/app/api/v1/users.py` or a new capability-application module under `backend/src/app/api/v1`
  - `backend/src/app/schemas`
  - `backend/src/app/models`
  - `backend/src/app/models/users.py`
  - `backend/src/migrations/versions`
  - `backend/tests`
- Mobile:
  - `mobile/lib/main.dart`
  - `mobile/lib/src/features/auth`
  - `mobile/lib/src/features/`
  - `mobile/test/`

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 1 / Story 1.5
- [prd.md](../prd.md) - FR45 and shared public-account capability model
- [tech-design.md](../tech-design.md)
- [1-4-apply-to-become-lot-owner.md](./1-4-apply-to-become-lot-owner.md)
- [users.py](../../backend/src/app/api/v1/users.py)
- [users.py](../../backend/src/app/models/users.py)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Story planned after closing Story 1.4 so the next capability-expansion flow can reuse the validated application pattern.
- Planning assumption: Operator capability should follow the same dedicated application-record approach as LotOwner, with `manager` remaining approved-capability storage only.
- Planning emphasis: include review-state guardrails, preserved resubmission history, and a checked-in migration from the start to avoid repeating Story 1.4 review findings.
- Review patch fixes completed: approved LotOwner applicants are now promoted into the Operator workspace, and the Flutter Operator form now validates the same minimum field lengths enforced by the backend schema.
- Focused verification passed after the patch fixes with backend Docker tests (`12 passed` in `tests/test_operator_applications.py`) and Flutter widget tests (`11 passed` in `mobile/test/widget_test.dart`).
- Story close-out decision: app-facing Admin review UI is tracked separately in Story 2.2, so Story 1.5 is considered complete for Epic 1 scope after the applicant flow, backend approval API, review fixes, and focused verification all passed.

### File List

- `_bmad-output/implementation-artifacts/1-5-apply-to-become-operator.md`
- `backend/src/app/api/v1/users.py`
- `backend/src/app/models/__init__.py`
- `backend/src/app/models/users.py`
- `backend/src/app/schemas/operator_application.py`
- `backend/src/migrations/versions/1a2b3c4d5e6f_add_operator_application_table.py`
- `backend/tests/test_operator_applications.py`
- `mobile/lib/main.dart`
- `mobile/lib/src/features/operator_application/data/operator_application_service.dart`
- `mobile/lib/src/features/operator_application/presentation/operator_application_screen.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-27: Created Story 1.5 plan for Operator capability application on the same public account, using the Story 1.4 capability-application pattern as the implementation baseline.
- 2026-03-27: Implemented backend Operator application flow, applicant mobile flow, migration, and focused tests.
- 2026-03-27: BMAD review recorded current implementation gaps after manual device validation.
- 2026-03-27: Closed Story 1.5 after patch fixes for Operator workspace promotion, frontend/backend validation alignment, and follow-up scope split for Admin approvals into Story 2.2.

## Review Findings

### Patch

1. [x] AC4 broken for approved LotOwner applicants. `review_operator_application()` only promoted `user.role` when it was `DRIVER` or `MANAGER`, so a user whose current workspace was `LOT_OWNER` gained Operator capability but stayed stranded in the LotOwner shell instead of accessing Operator workspace.
2. [x] AC1 was failing in real app usage. Backend logs showed repeated `POST /api/v1/user/me/operator-application` responses with HTTP 422, while the mobile form only validated non-empty fields and did not enforce the backend minimum lengths for `full_name`, `phone_number`, `business_license`, and `document_reference`.
3. [x] The story artifact had been malformed by two spliced Story 1.5 variants in one file, making the implementation record unreliable for further BMAD workflow steps.

### Defer / Decision Needed

1. The current app still has no app-facing Admin review screen for pending Operator applications. Backend review endpoints exist and satisfy the minimum system workflow, but if Epic 1 is expected to deliver the approval path inside Flutter, this needs a follow-up story or an explicit scope decision.
2. Admin capability resolution is not yet aligned end-to-end: auth capability payload treats `role == ADMIN` as admin-capable, but review endpoints require `is_superuser`. This becomes a real blocker once admin review UI is added.
3. Public shell copy and navigation are still mixed-language and placeholder-heavy. The request for a more standard app layout should be handled as a dedicated UX/story effort rather than folded into this capability-application patch set.