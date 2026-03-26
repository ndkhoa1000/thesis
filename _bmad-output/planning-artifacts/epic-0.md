---
epic_id: EPIC-0
title: Core Foundation & Integration Setup
status: Draft
---

# Epic 0: Core Foundation & Integration Setup

**Goal:** Establish the essential infrastructure, database schemas, API scaffolding, and end-to-end communication pathways before feature development. This foundation serves to prevent AI "vibe coding" loops and late-stage database migrations.

## Scope 1: Backend Foundation
- **Database Schema:** Implement the complete ERD (`project-docs/erd.md`, 22 tables) immediately inside the FastAPI project (`backend/`).
- **Implementation Rules:** Follow `SKILL.md` (FastAPI boilerplate: models → schemas → CRUD → routes → migrations).
- **Environment Structure (`backend/src/.env`):**
  - Database: `POSTGRES_SERVER`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
  - Security: `SECRET_KEY`
  - Media: `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`
- **API Scaffold & Readiness:**
  - Create the base router files (e.g., `auth.py`, `lots.py`, `sessions.py`, `bookings.py`, `payments.py`, `users.py`).
  - Implement a basic `/health` endpoint to verify the backend and DB connection.

## Scope 2: Frontend Foundation
- **App Initialization:** Setup the core Flutter mobile application structure.
- **Environment Structure (`.env`):**
  - Backend connection: `API_BASE_URL` (for injection through `--dart-define`, e.g., `http://localhost:8000/api/v1`)
  - Map rendering: `MAPBOX_ACCESS_TOKEN` (for injection through `--dart-define`, required for `mapbox_maps_flutter`)

## Scope 3: Communication & Testing
- **Shared Contracts (Workflow Recommendation):** Use an OpenAPI-to-Dart client generation workflow such as `openapi-generator-cli generate -i http://localhost:8000/openapi.json -g dart-dio -o mobile/api_client` to reduce API contract drift between backend and frontend.
- **API Verification:** Frontend implementation must systematically use the backend Swagger UI (`http://localhost:8000/docs`) to test endpoints *before* writing any mobile integration code.
- **Connectivity:** Ensure backend networking is correctly configured for local Flutter emulator/device testing.
- **AI Loop & Conflict Prevention:**
  - Actively detect and resolve contradictory instructions across docs (e.g., `SKILL.md` vs `tech-design.md`).
  - If a test fails repeatedly, stop and re-evaluate the approach to prevent "vibe coding" inside an infinite loop.
  - Rely on targeted integration tests verifying that the frontend and backend communicate smoothly.
