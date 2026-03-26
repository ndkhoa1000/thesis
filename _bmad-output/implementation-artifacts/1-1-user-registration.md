# Story 1.1: User Registration

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a new user,
I want to register an account using my email and a password,
so that I can create a personal profile on the smart parking platform.

## Acceptance Criteria

1. Given I am on the registration screen, when I enter a valid email and a secure password and submit, then my account is created in the database atomically.
2. The API uses the existing FastAPI backend stack to create the user and issue authentication tokens.
3. I am automatically logged in after successful registration.
4. The created public account is initialized with Driver capability by default and does not require any additional approval before using Driver features.

## Implementation Clarifications

- Treat the contradictory epic wording about "Postgres Trigger" as an implementation conflict. For this repository, registration must be handled by FastAPI application logic and a normal database transaction, not by a database trigger.
- The product requirement says registration uses email + password. The current boilerplate schema also requires `name` and `username`. This story must resolve that mismatch without pushing unnecessary fields into the first mobile registration screen.
- The default registered role for MVP should be `DRIVER`, because this is the safest fit with the product journeys and existing `UserRole` enum.
- Story 1.1 only covers public-account signup and immediate Driver access. It does not include the later application flows for `LotOwner` or `Operator` capability; those belong to separate stories.
- Because the backend already contains role-specific subtables, successful driver registration should provision both the base `user` row and the related `driver` row in one transaction unless a narrower scope is explicitly documented and accepted.
- The registration token contract must be consistent with login. Do not let `/auth/register` and `/login` return different auth shapes.

## Tasks / Subtasks

- [x] Task 1: Define the thesis-specific registration contract on top of the existing backend auth stack (AC: 1, 2, 3, 4)
  - [x] Add or update request/response schemas for a mobile-friendly registration endpoint under `backend/src/app/schemas` and `backend/src/app/core/schemas.py`.
  - [x] Decide how `username` and `name` are satisfied for MVP registration: generated server-side, derived from email, or made optional through schema/model changes.
  - [x] Ensure the response model excludes sensitive fields and exposes only the auth payload and any safe user summary needed immediately after signup.

- [x] Task 2: Implement backend registration using existing reusable auth pieces instead of rewriting them (AC: 1, 2, 4)
  - [x] Add `/api/v1/auth/register` or an equivalent auth-owned endpoint in `backend/src/app/api/v1` while preserving the existing router organization.
  - [x] Register any new auth route module in `backend/src/app/api/v1/__init__.py` so the endpoint is reachable through the application router.
  - [x] Reuse `crud_users.exists`, `crud_users.create`, `get_password_hash`, `create_access_token`, and `create_refresh_token`.
  - [x] Persist users with safe defaults for thesis MVP such as `role=DRIVER` and `is_active=True`.
  - [x] Create the related `driver` row atomically with the new user row so downstream driver-owned features do not fail on missing profile records.
  - [x] Return duplicate email and duplicate username failures with the same error style already used by the backend exception layer.
  - [x] Do not break the existing `/api/v1/user` boilerplate endpoint unless the implementation intentionally migrates it with test coverage.

- [x] Task 3: Resolve token transport so Flutter can stay aligned with architecture (AC: 2, 3)
  - [x] Compare the current login implementation, which returns an access token and stores refresh token in a secure cookie, against the architecture requirement that mobile stores auth tokens on-device.
  - [x] Pick one consistent strategy for both register and login before coding the mobile flow.
  - [x] If keeping cookie-based refresh, confirm the Flutter client can capture and reuse that cookie intentionally and make the cookie security settings environment-aware for local HTTP development.
  - [x] If switching to device-stored refresh tokens, update both register and login contracts together instead of patching registration only.

- [x] Task 4: Add the minimum mobile auth foundation required for registration and automatic login (AC: 1, 3)
  - [x] Add the dependencies needed for backend auth integration, expected at minimum to include `dio` and `flutter_secure_storage`.
  - [x] Introduce a minimal mobile auth structure under `mobile/lib` for API client, token persistence, and registration flow.
  - [x] Replace the single-screen bootstrap entry behavior with an auth gate that can show a registration screen first and enter an authenticated placeholder state after success.
  - [x] Keep the existing Mapbox proof-of-concept runnable, but do not let Story 1.1 expand into full map or lot integration.

- [x] Task 5: Test the backend and mobile registration flow at the right layers (AC: 1, 2, 3)
  - [x] Add backend tests for successful registration, duplicate email, duplicate username, password hashing, driver-row provisioning, and auth token issuance.
  - [x] Reuse the current testing style in `backend/tests/test_user.py` and shared fixtures in `backend/tests/conftest.py` where practical.
  - [x] Add at least one mobile test for registration form behavior or auth service success handling.
  - [x] Verify the final backend contract from Swagger/OpenAPI before wiring the mobile request payload.

## Dev Notes

### Story Foundation

- Epic 1 goal is secure identity and user profile foundation for all later parking flows.
- Story 1.1 specifically covers account creation and immediate authenticated state.
- Story 1.2 User Login follows immediately after this story and should reuse the same token contract decisions.

### Existing Backend Auth Inventory

- `backend/src/app/api/v1/login.py` already supports login with username or email and issues an access token plus refresh cookie.
- `backend/src/app/api/v1/logout.py` already blacklists both access and refresh tokens.
- `backend/src/app/core/security.py` already provides password hashing, password verification, token creation, token verification, and token blacklist helpers.
- `backend/src/app/api/dependencies.py` already provides `get_current_user`, `get_optional_user`, and `get_current_superuser`.
- `backend/src/app/api/v1/users.py` already contains boilerplate user creation logic, but it returns a `UserRead` payload and does not automatically log the user in.

### Existing Backend Gaps Relevant To This Story

- Current registration lives under `/api/v1/user`, not under an auth-owned route such as `/api/v1/auth/register` described by the project architecture.
- Current `UserCreate` schema requires `name`, `username`, `email`, and `password`, which does not match the product story wording for email + password signup.
- Current `Token` schema only models `access_token` and `token_type`, while architecture expects mobile-safe auth lifecycle handling that may require a clearer refresh-token strategy.
- Current login sets refresh cookies with `secure=True`, which will not behave correctly for plain-HTTP local mobile testing unless the config becomes environment-aware or the refresh strategy changes.
- Current router layout still carries boilerplate routes like posts, tiers, and rate limits, so keep Story 1.1 changes tightly scoped.

### Domain Constraints To Respect

- All auth flows must go through FastAPI. Do not introduce direct database access from mobile.
- Use PostgreSQL through the existing backend stack and migration tooling.
- New user registration for MVP should result in a platform user that can later act as a driver without extra admin setup.
- New user registration must not present role selection during signup. The public account starts as Driver by default.
- The backend already includes a dedicated `driver` table, so registration should not leave the user in a half-created state where `role=DRIVER` exists but no driver profile record exists.
- Do not introduce Supabase assumptions anywhere in backend or mobile auth.

### Mobile Constraints To Respect

- `mobile/lib` currently contains only `main.dart`; there is no established feature/module structure yet.
- `mobile/pubspec.yaml` currently lacks auth/network libraries such as `dio` and `flutter_secure_storage`.
- Keep Story 1.1 focused on auth bootstrap. Do not combine it with lot search, map data loading, or role-based dashboards.

### Suggested File Structure For This Story

- Backend:
  - `backend/src/app/api/v1/auth.py` or another auth-owned route module compatible with the existing router pattern
  - `backend/src/app/schemas/user.py`
  - `backend/src/app/core/schemas.py`
  - `backend/tests/test_user.py` or a focused auth test file if that is cleaner
- Mobile:
  - `mobile/lib/main.dart`
  - `mobile/lib/src/core/network/api_client.dart`
  - `mobile/lib/src/core/auth/token_store.dart`
  - `mobile/lib/src/features/auth/data/auth_service.dart`
  - `mobile/lib/src/features/auth/presentation/register_screen.dart`
  - `mobile/lib/src/features/auth/presentation/auth_gate.dart`

### Testing Requirements

- Backend test style should stay pytest-based and async where relevant.
- Reuse mocked `AsyncSession` patterns already present in `backend/tests/test_user.py` for unit tests.
- If adding integration coverage, keep it targeted to register contract behavior and token response shape.
- Mobile tests should stay within `flutter_test` unless a new dependency is genuinely required.

### Latest Technical Guidance

- FastAPI best practice is to use distinct request and response models so password-bearing inputs never leak back in responses.
- Token payload validation should stay explicit and typed through Pydantic models, matching the current `TokenData` approach.
- Keep OpenAPI response models accurate because the mobile client will use Swagger/OpenAPI as the contract source before wiring requests.

### Git Intelligence Summary

- Recent work has focused on Flutter migration, parking-domain scaffolds, and planning/documentation updates.
- That history suggests this story should extend the current scaffold incrementally rather than attempting a broad auth or app-shell rewrite.

### Project Structure Notes

- Backend changes should follow the existing boilerplate layering: API route -> schema -> CRUD/helper reuse -> tests.
- Avoid moving core security helpers out of `backend/src/app/core/security.py`; reuse them from the new registration path.
- Because the mobile structure is still greenfield, create the smallest stable structure that later auth and vehicle-profile stories can build on.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 1 / Story 1.1
- [architecture.md](../architecture.md) - Sections 2.1, 2.2, 3, 5
- [tech-design.md](../tech-design.md) - Sections 2, 4, 7, 8
- [erd.md](../../project-docs/erd.md) - User entity and role model
- [reference.md](../../project-docs/reference.md) - Driver-first product flows
- [login.py](../../backend/src/app/api/v1/login.py)
- [logout.py](../../backend/src/app/api/v1/logout.py)
- [users.py](../../backend/src/app/api/v1/users.py)
- [__init__.py](../../backend/src/app/api/v1/__init__.py)
- [dependencies.py](../../backend/src/app/api/dependencies.py)
- [security.py](../../backend/src/app/core/security.py)
- [user.py](../../backend/src/app/schemas/user.py)
- [user.py](../../backend/src/app/models/user.py)
- [users.py](../../backend/src/app/models/users.py)
- [user-management.md](../../backend/docs/user-guide/authentication/user-management.md)
- [project-structure.md](../../backend/docs/user-guide/project-structure.md)
- [testing.md](../../backend/docs/user-guide/testing.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- Backend auth baseline reviewed before story creation.
- Epic wording conflict on "Postgres Trigger" reviewed against architecture and ERD.
- Backend tests executed in compose `pytest` service with editable project install and `pytest-asyncio`.
- Backend health and registration were smoke-tested inside the running `web` container using `fastapi.testclient`.
- Flutter auth bootstrap was verified with `flutter test test/widget_test.dart`.

### Completion Notes List

- Story created with backend-auth reuse guidance.
- Story includes explicit guardrails for schema mismatch (`email + password` vs current `name + username + email + password`).
- Story includes token transport decision as an explicit task to prevent mobile/backend contract drift.
- Story validation added missing guidance for router registration, `driver` subtable provisioning, local cookie behavior, and markdown link references.
- Story clarified that public signup creates Driver capability only; LotOwner and Operator upgrades are deferred to separate follow-up stories.
- Implemented `/api/v1/auth/register` with generated profile data, atomic `user` + `driver` creation, and immediate token return.
- Updated login/refresh/logout token handling toward a mobile-friendly token-body contract while preserving refresh fallback compatibility.
- Added backend auth coverage in `backend/tests/test_auth.py` and verified it alongside the existing `backend/tests/test_user.py` suite in container.
- Added a minimal Flutter auth shell with Dio API client, secure token store, auth gate, register screen, and authenticated placeholder preserving the map proof-of-concept.

### File List

- `_bmad-output/implementation-artifacts/1-1-user-registration.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `backend/src/app/api/v1/auth.py`
- `backend/src/app/api/v1/__init__.py`
- `backend/src/app/api/v1/login.py`
- `backend/src/app/api/v1/logout.py`
- `backend/src/app/core/schemas.py`
- `backend/src/app/schemas/user.py`
- `backend/tests/test_auth.py`
- `mobile/pubspec.yaml`
- `mobile/lib/main.dart`
- `mobile/lib/src/core/network/api_client.dart`
- `mobile/lib/src/core/auth/token_store.dart`
- `mobile/lib/src/features/auth/data/auth_service.dart`
- `mobile/lib/src/features/auth/presentation/auth_gate.dart`
- `mobile/lib/src/features/auth/presentation/register_screen.dart`
- `mobile/test/widget_test.dart`

### Change Log

- 2026-03-26: Implemented Story 1.1 across backend auth registration and Flutter auth bootstrap; verified backend tests, health smoke test, registration smoke test, and Flutter widget test.