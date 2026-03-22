# Tech Design - Smart Parking Management System

**Author:** Khoa
**Date:** 2026-03-22
**Based on:** [PRD](./prd.md) · [Architecture](./architecture.md) · [ERD](../project-docs/erd.md)

---

## 1. Technical Direction

This document aligns implementation with the chosen stack:

- **Frontend:** React Native with Expo
- **Backend:** existing FastAPI project in [backend](../backend), managed with `uv`
- **Database:** PostgreSQL
- **Storage:** Cloudinary

Supabase is no longer part of the system design. The mobile app must be migrated away from direct Supabase usage and onto backend APIs exclusively.

---

## 2. Backend Reuse Strategy

The backend already exists and must be used as the implementation base.

### 2.1 What stays

- FastAPI application bootstrap
- `uv` workflow and dependency management
- Docker and local development setup
- Alembic configuration
- Existing auth/security structure as a starting point
- Existing test harness and repo layout

### 2.2 What changes

- Replace generic starter-domain routes such as posts, tiers, and rate-limits with parking-domain modules
- Replace starter-domain models with the parking ERD
- Move auth to project-owned account and token handling
- Add Cloudinary integration service
- Add realtime broadcasting for availability updates

### 2.3 Migration principle

Do not rewrite the backend wholesale. Convert it incrementally so the repo remains runnable during development.

---

## 3. Database Strategy

PostgreSQL is the system of record.

### 3.1 Schema scope

The target schema remains the parking-domain schema described in the ERD, including:

- users and role-specialized profile tables
- vehicles
- parking lots and configs
- leases and contracts
- bookings
- parking sessions and edits
- payments and invoices
- announcements and notifications

### 3.2 Migration tooling

Use the backend's existing Alembic setup.

Preferred implementation path:

1. Define SQLAlchemy models for the parking domain.
2. Generate Alembic revisions from the backend project.
3. Apply migrations through the backend workflow.

Example workflow:

```bash
cd backend/src
uv run alembic revision --autogenerate -m "create parking domain tables"
uv run alembic upgrade head
```

### 3.3 Concurrency and atomicity

The following operations must be transactional:

- check-in
- check-out
- booking create
- booking cancel
- booking expire
- payment record creation

`current_available` must be updated within the same transaction as the session or booking state change.

---

## 4. Authentication Design

Authentication is handled fully by FastAPI.

### 4.1 Registration

1. Client submits email and password to `/auth/register`.
2. FastAPI validates uniqueness and password policy.
3. FastAPI hashes password and creates the user row.
4. Optional role-profile rows are created depending on onboarding flow.
5. FastAPI returns access and refresh tokens.

### 4.2 Login

1. Client posts credentials to `/auth/login`.
2. FastAPI verifies password hash.
3. FastAPI returns signed tokens.
4. Mobile stores tokens in `expo-secure-store`.

### 4.3 Authorization

Use route dependencies such as:

- `get_current_user()`
- `get_current_active_user()`
- `require_role(["ATTENDANT"])`

Authorization is enforced in:

1. route dependencies
2. service-layer ownership checks
3. filtered repository queries

---

## 5. Media Storage Design

Cloudinary is used for user-submitted media.

### 5.1 Upload categories

- `vehicle-checkin/`
- `vehicle-checkout/`
- `vehicle-profiles/`
- `lot-covers/`
- `ownership-docs/`

### 5.2 Upload flow

1. Mobile sends file to FastAPI as multipart form data.
2. FastAPI validates content type and authorization.
3. FastAPI uploads to Cloudinary using a dedicated service module.
4. FastAPI stores returned `public_id`, secure URL, and metadata in PostgreSQL.

### 5.3 Design rule

Cloudinary credentials exist only in the backend environment. The mobile app never holds upload secrets.

---

## 6. Realtime Strategy

Supabase Realtime is removed. Realtime is now backend-owned.

### 6.1 Purpose

Broadcast `parking_lot.current_available` updates to clients after:

- session check-in
- session check-out
- booking create
- booking cancel
- booking expiration

### 6.2 Transport

Primary option: WebSocket endpoint in FastAPI.

Fallback option: SSE if WebSocket handling becomes too heavy for the thesis scope.

### 6.3 Event shape

```json
{
  "type": "lot.availability.updated",
  "lot_id": 12,
  "current_available": 18,
  "updated_at": "2026-03-22T10:15:30Z"
}
```

---

## 7. Mobile Migration Strategy

The mobile app is currently preconfigured to use Supabase directly. That must be removed.

### 7.1 Remove

- direct Supabase auth calls
- direct lot queries from Supabase tables
- Supabase session listeners
- hardcoded Supabase URL and anon key

### 7.2 Replace with backend equivalents

- `AuthContext` becomes backend-token based
- map and lot screens consume FastAPI lot endpoints
- profile screens consume FastAPI user endpoints
- photo and document uploads go through FastAPI

### 7.3 Mobile client modules to introduce

- API client with auth interceptor
- auth token persistence utility
- typed service modules by domain
- optional websocket client for availability updates

---

## 8. API Module Plan

Recommended backend route modules:

| Module | Responsibility |
|--------|----------------|
| `auth.py` | register, login, refresh, logout, me |
| `users.py` | profile and vehicles |
| `lots.py` | lot list, detail, config, pricing, tags |
| `sessions.py` | check-in, check-out, edits, photos |
| `bookings.py` | create, cancel, list |
| `payments.py` | cash and simulated online payment |
| `leases.py` | lot registration, lease application, contracts |
| `attendants.py` | operator attendant management |
| `announcements.py` | lot announcements |
| `reports.py` | revenue and occupancy |
| `admin.py` | lot approvals, lease approvals, user management |

---

## 9. Error and Response Design

Response envelope:

```json
{
  "data": {},
  "message": "Success",
  "status": 200
}
```

Error envelope:

```json
{
  "data": null,
  "error": {
    "code": "PARK_409_02",
    "message": "Driver already has an active session at this lot"
  },
  "status": 409
}
```

Core domains needing explicit error codes:

- auth
- lots
- sessions
- bookings
- payments
- leases
- admin approvals

---

## 10. Scheduling and Background Work

Booking expiration and other background tasks should stay inside the backend architecture.

Options, ordered by implementation simplicity:

1. Background scheduler inside FastAPI process for local demo use
2. Separate worker process using the same codebase
3. Database-backed scheduling where available in deployment

Required jobs:

- expire stale bookings
- release held availability
- send future notification reminders if Phase 2 starts

---

## 11. Implementation Roadmap

### Phase A - Context and Infrastructure Alignment

1. Finalize docs to remove Supabase assumptions
2. Confirm PostgreSQL connection in backend `.env`
3. Add Cloudinary settings to backend config
4. Define parking-domain SQLAlchemy models

### Phase B - Backend Domain Migration

1. Create parking-domain migrations
2. Add auth endpoints aligned to backend-owned tokens
3. Add lots, sessions, bookings, and payments endpoints
4. Add Cloudinary upload service
5. Add availability websocket or SSE endpoint

### Phase C - Mobile Migration

1. Remove Supabase client dependency from app flows
2. Replace auth flow with backend endpoints
3. Replace lot fetching with backend APIs
4. Add backend token persistence and refresh handling
5. Integrate realtime availability from FastAPI

### Phase D - Thesis MVP Completion

1. End-to-end driver flow
2. End-to-end attendant flow
3. Operator lot management basics
4. Admin approval basics
5. Lease contract generation in HTML

---

## 12. Sprint-Oriented Task Breakdown

| Sprint | Focus |
|--------|-------|
| S0 | Align backend config, models, migrations, and mobile API foundation |
| S1 | Auth, profile, and vehicles |
| S2 | Lots, map data, and realtime availability |
| S3 | Sessions, QR flow, and pricing |
| S4 | Bookings and payments |
| S5 | Leases, attendants, announcements, reports, admin |
| S6 | End-to-end testing, polish, and demo hardening |

---

## 13. Constraints

- The existing backend in [backend](../backend) is mandatory.
- The mobile app must stop using Supabase directly.
- PostgreSQL is the only database in the target design.
- Cloudinary is the only media storage service in the target design.
- All business logic must be centralized in FastAPI.

---

## 14. Open Technical Questions

- Whether Google sign-in remains in MVP or moves to later scope
- Whether websocket support is necessary on day one or SSE is enough
- Whether payment integration remains mocked for the entire thesis timeline
- Whether some Phase 2 tables should be migrated now or deferred until used
