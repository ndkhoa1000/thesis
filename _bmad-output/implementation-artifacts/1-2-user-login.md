# Story 1.2: User Login

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a registered user,
I want to log into my account,
so that I can access the parking platform features securely.

## Acceptance Criteria

1. Given I am on the login screen, when I enter my correct email and password, then I am authenticated as one `user` identity and receive the backend token contract used by mobile.
2. Public accounts resolve to the current primary public workspace from `user.role`, while preserving access to any approved public capabilities linked to that same `user` identity through `driver`, `lot_owner`, and `manager` records.
3. Attendant and Admin accounts authenticate through separate credentials and enter dedicated account flows rather than public workspace switching.
4. The mobile app stores the issued tokens securely and restores the authenticated session on app restart.
5. Login failures return clear backend-driven error messages for invalid credentials or inactive access.

## Implementation Clarifications

- This story must stay compatible with the current schema, where `user.role` is a single field and public capabilities are represented by linked rows in `driver`, `lot_owner`, and `manager` tables.
- “Same account” means one shared `user` identity and credential set for public Driver, LotOwner, and Operator workspaces.
- `user.role` should be treated as the current primary public workspace, not the full capability list.
- Attendant and Admin remain separate-account flows and must not be merged into the public workspace-switching model.
- The login response should be consistent with the token-body strategy already introduced in Story 1.1.

## Tasks / Subtasks

- [ ] Task 1: Define the login and session contract for the shared public-account model (AC: 1, 2, 3, 5)
  - [ ] Confirm the login response shape includes token data plus a safe user summary suitable for mobile session restoration.
  - [ ] Decide how capability availability is exposed for public users: explicit capability flags, linked-profile summary, or equivalent typed fields.
  - [ ] Keep the contract compatible with the current `user.role` field while avoiding the assumption that it is the complete capability set.

- [ ] Task 2: Implement backend login resolution for public and separate-account flows (AC: 1, 2, 3, 5)
  - [ ] Reuse the existing auth stack in `backend/src/app/api/v1/login.py`, `logout.py`, and related security helpers.
  - [ ] Ensure public login returns one authenticated `user` identity with the current primary role and enough data to determine accessible public workspaces.
  - [ ] Ensure Attendant and Admin logins remain dedicated sessions rather than entering the public workspace model.
  - [ ] Preserve the token-body strategy introduced for mobile in Story 1.1.

- [ ] Task 3: Implement mobile session bootstrap and workspace entry (AC: 2, 3, 4)
  - [ ] Add the login screen and auth service call using the backend contract.
  - [ ] Restore the saved session on app start and route to the correct initial workspace.
  - [ ] Use `user.role` as the default public workspace while keeping room for later workspace switching when additional public capabilities are approved.
  - [ ] Keep Attendant/Admin entry separate from the public workspace shell.

- [ ] Task 4: Harden logout and token lifecycle around the new contract (AC: 3, 4)
  - [ ] Ensure logout revokes tokens server-side and clears secure local storage.
  - [ ] Confirm refresh behavior remains compatible with mobile-stored refresh tokens.
  - [ ] Verify that app restart restores only valid sessions.

- [ ] Task 5: Test login, session restoration, and role/capability routing (AC: 1, 2, 3, 4, 5)
  - [ ] Add backend tests for successful login, failed login, and response contract correctness.
  - [ ] Add focused backend coverage for public-account identity resolution versus separate-account flows.
  - [ ] Add mobile tests for login form behavior and session bootstrap routing.

## Dev Notes

### Story Foundation

- Story 1.1 established backend-owned registration plus token-body auth for mobile.
- Story 1.2 extends that work into authenticated re-entry, session restoration, and workspace-aware routing.
- Story 1.4 and Story 1.5 depend on this story because approved capabilities must be discoverable at login.

### Domain Constraints To Respect

- Public Driver, LotOwner, and Operator experiences share one `user` identity.
- Public capabilities are represented by linked `driver`, `lot_owner`, and `manager` rows.
- `user.role` remains the current primary public workspace for compatibility with the existing schema.
- `Attendant` and `Admin` remain separate credentials and separate login sessions.

### Backend Guidance

- Reuse existing auth helpers in `backend/src/app/core/security.py` and route modules in `backend/src/app/api/v1`.
- Avoid rewriting auth around a brand-new role system; extend the existing response contract incrementally.
- If capability data is added to the login response, keep it explicit and safe for OpenAPI/mobile consumption.

### Mobile Guidance

- Extend the auth shell introduced in Story 1.1 rather than replacing it.
- Keep secure token storage in `flutter_secure_storage`.
- Structure the mobile flow so later capability switching can be added without reworking the whole app shell.

### Suggested File Areas For This Story

- Backend:
  - `backend/src/app/api/v1/login.py`
  - `backend/src/app/api/v1/logout.py`
  - `backend/src/app/core/schemas.py`
  - `backend/src/app/core/security.py`
  - `backend/tests/test_auth.py`
- Mobile:
  - `mobile/lib/src/features/auth/data/auth_service.dart`
  - `mobile/lib/src/features/auth/presentation/`
  - `mobile/lib/main.dart`
  - `mobile/test/`

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 1 / Story 1.2
- [prd.md](../prd.md) - Roles & Account Model, Journey 3, Journey 4
- [architecture.md](../architecture.md) - Sections 2, 3, 5
- [tech-design.md](../tech-design.md) - Section 4
- [1-1-user-registration.md](./1-1-user-registration.md)
- [login.py](../../backend/src/app/api/v1/login.py)
- [logout.py](../../backend/src/app/api/v1/logout.py)
- [security.py](../../backend/src/app/core/security.py)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Completion Notes List

- Story created to align login behavior with the shared public-identity capability model.
- Story preserves the existing schema assumption that `user.role` is the current primary public workspace.
- Story keeps Attendant and Admin as separate-account flows.

### File List

- `_bmad-output/implementation-artifacts/1-2-user-login.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/tech-design.md`