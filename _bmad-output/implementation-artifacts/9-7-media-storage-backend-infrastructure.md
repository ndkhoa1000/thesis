# Story 9.7: Media Storage & Backend Infrastructure

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a developer,
I want a standardized Media Storage service bridging Flutter and FastAPI to Cloudinary,
so that all business forms that require file or image paths can correctly upload binary data without falling back to manual string URL inputs.

## Acceptance Criteria

1. Given the app requires a media upload, when a native `ImagePicker` or `FilePicker` flow is used, then the selected file is compressed when appropriate and transmitted via FastAPI as multipart form data.
2. Given FastAPI receives the upload, when authorization and file validation pass, then the backend uploads the media to Cloudinary.
3. Given Cloudinary accepts the upload, when the backend persists the result, then the resulting `secure_url` is stored in the correct database entity.
4. Given the system needs media for profile, lot, or walk-in flows, when implementation is complete, then the media pipeline is standardized and manual text URL entry is no longer the required UX path for covered forms.

## Implementation Clarifications

- The architecture and tech design already define the upload pattern: mobile sends multipart to FastAPI, FastAPI validates and uploads to Cloudinary, and only the backend holds Cloudinary credentials.
- The current codebase already has a working multipart pattern in attendant walk-in check-in, but the backend still stores files locally under `backend/src/app/uploads/walk_in_check_in`.
- The current lot-registration flow still posts `cover_image` as a raw string URL. Story 9.7 should convert at least one real manual-URL workflow into the standardized upload path so the story produces visible value.
- This story should create reusable media infrastructure, not a separate one-off upload path per feature.

## Tasks / Subtasks

- [x] Task 1: Add backend Cloudinary infrastructure (AC: 2, 3, 4)
  - [x] Implement or complete `backend/src/app/services/cloudinary_service.py` and backend configuration for `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET`.
  - [x] Add a reusable backend upload helper or endpoint layer that validates content type, size, and authorization before handing off to Cloudinary.
  - [x] Persist returned `secure_url`, `public_id`, and any required metadata in the correct entity fields.

- [x] Task 2: Reuse and evolve the current multipart pattern (AC: 1, 2, 4)
  - [x] Refactor the current walk-in upload handling in `sessions.py` away from local disk storage toward the shared media service.
  - [x] Keep existing walk-in contracts functional while changing the storage backend.
  - [x] Standardize request and response patterns so future media forms can reuse the same infrastructure.

- [x] Task 3: Integrate at least one real mobile form with the new upload flow (AC: 1, 3, 4)
  - [x] Update a current form such as parking-lot registration cover image to use native file selection and multipart upload instead of a manual URL field.
  - [x] Add a mobile-side media helper/service that performs file selection and upload through FastAPI, not directly to Cloudinary.
  - [x] Keep the mobile client thin and avoid embedding Cloudinary secrets or signature logic in Flutter.

- [x] Task 4: Add regression coverage and configuration checks (AC: 1, 2, 3, 4)
  - [x] Add backend tests for authorization, content-type validation, Cloudinary service integration boundaries, and persistence of returned URLs.
  - [x] Add Flutter tests for upload-service error handling and the selected integrated form.
  - [x] Verify with `cd backend && docker compose run --rm pytest` and `cd mobile && flutter test`.

## Dev Notes

### Story Foundation

- PRD NFR14 and the architecture both require Cloudinary as the media store with FastAPI brokering uploads.
- This story hardens an already-proven need: the app contains image-bearing fields and existing multipart upload behavior, but storage and UX are not yet standardized.

### Current Codebase Signals

- `backend/src/app/api/v1/sessions.py` contains `_store_walk_in_image` that writes files to a local `uploads/walk_in_check_in` directory.
- `mobile/lib/src/features/attendant_check_in/data/attendant_check_in_service.dart` already builds multipart form data with `MultipartFile.fromFile(...)`.
- `mobile/lib/src/features/parking_lot_registration/data/parking_lot_service.dart` still posts `cover_image` as a raw string field.
- Backend models already expose image URL-style fields such as `cover_image`, `checkin_image`, `checkout_image`, `front_image`, `back_image`, and `profile_image_url`.

### Architecture Guardrails

- Mobile never talks directly to Cloudinary.
- Cloudinary credentials live only in backend environment variables.
- FastAPI owns authorization, validation, upload handoff, and persistence.
- Reuse one shared media service instead of creating per-feature bespoke upload code.

### File Structure Requirements

- Expected backend touch points:
  - `backend/src/app/core/config.py`
  - `backend/src/app/services/cloudinary_service.py`
  - `backend/src/app/api/v1/sessions.py`
  - possible new media-focused API module under `backend/src/app/api/v1/`
  - relevant schema/model files for stored media metadata
  - `backend/tests/`
- Expected mobile touch points:
  - `mobile/lib/src/features/attendant_check_in/data/attendant_check_in_service.dart`
  - `mobile/lib/src/features/parking_lot_registration/data/parking_lot_service.dart`
  - `mobile/lib/src/features/parking_lot_registration/presentation/parking_lot_registration_screen.dart`
  - shared media helper/service folder
  - `mobile/pubspec.yaml` if additional lightweight client-side support is needed
  - `mobile/test/`

### Testing Requirements

- Backend tests should cover upload authorization, invalid media type rejection, Cloudinary handoff behavior through mocks/fakes, and persisted URL fields.
- Flutter tests should cover upload failure messaging and the integrated form that now uses file picking instead of URL-only entry.
- Respect current verification conventions: backend via Docker pytest, mobile via local `flutter test`.

### Implementation Risks To Avoid

- Do not ship direct-to-Cloudinary uploads from the mobile client.
- Do not leave local-disk walk-in uploads as a parallel permanent storage path unless explicitly documented as temporary fallback.
- Do not convert only the backend storage path without changing at least one real user-facing manual URL workflow.
- Do not over-scope into full media management, deletion, or signed transformation workflows unless required by the current stories.

### References

- [epics.md](../planning-artifacts/epics.md) - Epic 9 / Story 9.7 and NFR14 references
- [architecture.md](../architecture.md) - media storage, upload flow, backend-only Cloudinary credentials
- [tech-design.md](../tech-design.md) - Section 5.2 upload flow and Cloudinary rule
- [epic-0.md](../planning-artifacts/epic-0.md) - environment variable checklist
- [4-3-manual-license-plate-check-in.md](./4-3-manual-license-plate-check-in.md)

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Implementation Plan

- Add reusable backend Cloudinary infrastructure and replace local-disk walk-in storage with the shared media service.
- Integrate at least one current mobile form away from manual image URL entry into the standardized multipart upload path.
- Validate the infrastructure with backend Docker tests and Flutter tests.

### Completion Notes List

- Story context anchored on architecture and tech-design Cloudinary requirements, the current local-disk walk-in upload implementation, and the still-manual `cover_image` string workflow in lot registration.
- Added guardrails to force backend-brokered media flow and to avoid direct mobile Cloudinary access.
- Added shared backend Cloudinary media infrastructure, `public_id` persistence fields, and a migration so walk-in uploads and parking-lot cover images now store Cloudinary-backed references instead of local-disk paths or manual text URLs.
- Reworked the parking-lot registration form to use a native compressed image picker and multipart upload flow through FastAPI, backed by focused service/widget tests.
- Validation completed with `cd backend && docker compose run --rm pytest` passing 201 tests and `cd mobile && flutter test` passing 85 tests.

### File List

- `_bmad-output/implementation-artifacts/9-7-media-storage-backend-infrastructure.md`
- `backend/pyproject.toml`
- `backend/uv.lock`
- `backend/src/app/core/config.py`
- `backend/src/app/services/cloudinary_service.py`
- `backend/src/app/models/parking.py`
- `backend/src/app/models/sessions.py`
- `backend/src/app/api/v1/sessions.py`
- `backend/src/app/api/v1/lots.py`
- `backend/src/migrations/versions/e7c9a1b2d3f4_add_media_public_ids.py`
- `backend/tests/test_walk_in_check_in.py`
- `backend/tests/test_parking_lots.py`
- `mobile/lib/src/features/parking_lot_registration/data/parking_lot_service.dart`
- `mobile/lib/src/features/parking_lot_registration/presentation/parking_lot_registration_screen.dart`
- `mobile/lib/src/shared/media/media_picker_service.dart`
- `mobile/test/widget_test.dart`
- `mobile/test/parking_lot_service_test.dart`

### Change Log

- 2026-03-29: Completed Story 9.7 by adding Cloudinary-backed media storage infrastructure, migrating walk-in and parking-lot cover-image uploads to the shared multipart pipeline, persisting Cloudinary public IDs, and validating with full backend/mobile regression suites.