# Architecture Document - Smart Parking Management System

**Author:** Khoa
**Date:** 2026-03-22
**Based on:** [PRD](./prd.md) · [ERD](../project-docs/erd.md) · [Reference](../project-docs/reference.md) · [Use Cases](../project-docs/usecase.md)

---

## 1. System Overview

The system uses a three-part architecture:

1. **Mobile client:** Flutter for all user-facing flows.
2. **Backend:** FastAPI monolith using `uv`, built on top of the existing backend already present in this repository.
3. **Data and media services:** PostgreSQL for relational data and Cloudinary for image/document storage.

**All client requests go through FastAPI.** The mobile app does not communicate directly with PostgreSQL or Cloudinary. This keeps business rules, security, and data consistency in one place.

```
┌─────────────────────────────────────────────────────────────┐
│                          Flutter                           │
│  Driver · Attendant · Operator · LotOwner · Admin screens  │
│  Camera · QR Scanner · Map · Secure token storage          │
└─────────────────────────┬───────────────────────────────────┘
                          │ HTTPS (Bearer access token)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  FastAPI Backend (existing repo)           │
│  Auth · Lots · Sessions · Bookings · Payments · Admin      │
│  Pricing engine · QR engine · Reports · Contracts          │
│  WebSocket/SSE broadcaster · Cloudinary integration        │
└───────────────┬───────────────────────────────┬─────────────┘
                │                               │
                ▼                               ▼
┌──────────────────────────────┐   ┌──────────────────────────┐
│         PostgreSQL           │   │        Cloudinary        │
│  Users · Lots · Sessions     │   │  Vehicle photos          │
│  Bookings · Payments         │   │  Lot covers              │
│  Leases · Reports            │   │  Ownership documents     │
└──────────────────────────────┘   └──────────────────────────┘
```

> **Terminology:** “Operator” is the product term. The data model may still use `Manager` for the same business role.

---

## 2. Architectural Decisions

### 2.1 Mobile Client

The mobile app is a thin client responsible for:

- Rendering screens for each role
- Capturing QR scans, photos, and user input
- Storing access and refresh tokens securely on-device
- Calling FastAPI endpoints for all reads and writes

Suggested mobile libraries remain:

| Capability | Library |
|-----------|---------|
| Navigation | `go_router` |
| HTTP client | `dio` |
| State management | `flutter_riverpod` |
| QR scanning | `mobile_scanner` |
| Image selection | `image_picker` |
| Map rendering | `mapbox_maps_flutter` |
| Token storage | `flutter_secure_storage` |
| Styling | `Material 3` + custom theme |

### 2.2 Backend

The backend in [backend](../backend) is mandatory and becomes the system entry point for:

- Authentication and token lifecycle
- Role-based authorization
- Parking lot search and detail APIs
- Check-in and check-out workflows
- Booking expiration and slot accounting
- Payment recording and simulated online payment flow
- Cloudinary uploads for images and documents
- Realtime updates over WebSocket or SSE

The backend is already scaffolded from `fastapi-boilerplate`. The implementation strategy is to **reuse the existing project structure** and replace generic starter-domain modules with parking-domain modules incrementally.

### 2.3 Database

PostgreSQL is the primary system of record.

- The 23-table parking schema remains the target schema.
- Migrations should be managed with the backend's Alembic setup.
- The database is accessed only by FastAPI.
- Application-level RBAC and ownership checks replace Supabase-specific RLS assumptions.

### 2.4 Media Storage

Cloudinary stores:

- Vehicle check-in and check-out photos
- Vehicle profile photos
- Parking lot cover images
- Ownership and lease-supporting documents

Upload flow:

1. Mobile captures file.
2. Mobile sends multipart request to FastAPI.
3. FastAPI validates authorization and file type.
4. FastAPI uploads to Cloudinary.
5. FastAPI stores returned public IDs and URLs in PostgreSQL.

---

## 3. Security Architecture

Authentication is backend-owned.

- Users register and log in through FastAPI endpoints.
- Passwords are hashed in the backend.
- FastAPI issues access and refresh tokens.
- The mobile client stores tokens with `flutter_secure_storage`.

Authorization is enforced in FastAPI via role-aware dependencies such as `get_current_user()` and `require_role()`.

**Security principles:**

- No direct mobile access to PostgreSQL
- No direct mobile access to Cloudinary credentials
- All sensitive flows executed server-side
- Token validation and permission checks in backend dependencies and services
- File upload validation before Cloudinary handoff

---

## 4. Core Data Flows

### 4.1 Driver QR State Machine

The driver owns one QR identity in the app. The backend determines whether that QR means check-in or check-out by looking up active sessions.

1. No active session: QR is interpreted as `CHECKIN`.
2. Active session exists: same QR is interpreted as `CHECKOUT`.
3. Session ends: QR returns to `CHECKIN` behavior.

### 4.2 Check-In Flow

1. Driver or walk-in arrives at lot.
2. Attendant scans driver QR or creates a walk-in session.
3. FastAPI validates lot, vehicle, and capacity.
4. FastAPI creates `parking_session` in PostgreSQL.
5. FastAPI adjusts `current_available` atomically.
6. FastAPI uploads any required photos to Cloudinary.
7. FastAPI broadcasts updated availability to connected clients.

### 4.3 Check-Out Flow

1. Attendant scans QR.
2. FastAPI loads active session.
3. Pricing service calculates the fee.
4. Payment is recorded.
5. Session status changes to checked out.
6. Availability is incremented atomically.
7. Updated lot state is broadcast.

### 4.4 Booking Expiration

Booking expiration is handled by backend-managed scheduled execution.

Candidate implementations:

1. A lightweight scheduler running inside the backend process for local development.
2. A dedicated worker process using the same codebase.
3. A database-assisted schedule if the deployment environment supports it.

The requirement is reliability, not a specific third-party scheduler.

### 4.5 Realtime Availability

Realtime updates are produced by FastAPI, not an external realtime platform.

1. Session or booking events change `current_available`.
2. FastAPI commits the database transaction.
3. FastAPI publishes lot updates to connected clients over WebSocket or SSE.
4. Mobile map screens refresh visible lot markers in near real time.

---

## 5. API Design Principles

Base URL:

```
/api/v1
```

Authentication:

```
Authorization: Bearer <backend_access_token>
```

Response envelope:

```json
{ "data": {}, "message": "Success", "status": 200 }
```

Representative endpoint groups:

- `/auth/*`
- `/users/*`
- `/lots/*`
- `/sessions/*`
- `/bookings/*`
- `/payments/*`
- `/leases/*`
- `/admin/*`
- `/reports/*`
- `/ws/availability`

---

## 6. Backend Project Shape

The existing backend layout should be reused, not replaced.

Recommended direction inside the current backend structure:

```
backend/src/app/
├── api/v1/
│   ├── auth.py
│   ├── lots.py
│   ├── sessions.py
│   ├── bookings.py
│   ├── payments.py
│   ├── users.py
│   ├── leases.py
│   ├── attendants.py
│   ├── announcements.py
│   └── reports.py
├── core/
│   ├── config.py
│   ├── security.py
│   └── dependencies.py
├── services/
│   ├── qr_service.py
│   ├── pricing_service.py
│   ├── booking_service.py
│   ├── cloudinary_service.py
│   └── contract_service.py
├── models/
├── schemas/
└── migrations/
```

This is an adaptation plan, not a mandate to delete the starter code in one step.

---

## 7. Infrastructure and Deployment

| Component | Decision |
|-----------|----------|
| Mobile app | Flutter for development, with Android-focused thesis demo and future multi-platform expansion |
| Backend runtime | FastAPI with `uv` |
| Backend base | Existing `backend/` project in this repository |
| Database | PostgreSQL |
| Migrations | Alembic in backend |
| File storage | Cloudinary |
| Local orchestration | Existing Docker Compose setup in backend |

Environment variables should move toward:

```env
# backend/src/.env
POSTGRES_SERVER=localhost
POSTGRES_PORT=5432
POSTGRES_DB=parking
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
SECRET_KEY=<backend-secret>
CLOUDINARY_CLOUD_NAME=<name>
CLOUDINARY_API_KEY=<key>
CLOUDINARY_API_SECRET=<secret>
```

```env
# mobile
API_BASE_URL=http://<host>:8000/api/v1
MAPBOX_ACCESS_TOKEN=<token>
```

---

## 8. Key Trade-offs

| Decision | Rationale |
|----------|-----------|
| Keep FastAPI as single gateway | Centralizes business logic and avoids split authority between client and platform services |
| Remove Supabase from architecture | Simplifies stack and matches the chosen backend-first implementation path |
| Reuse existing backend scaffold | Faster than rebuilding auth, config, Docker, and testing foundations from scratch |
| Use PostgreSQL directly | Aligns with the existing backend setup and Alembic workflow |
| Use Cloudinary for media | Removes storage responsibility from the database layer and fits mobile upload needs |
| Use FastAPI-managed realtime | Keeps update rules close to business transactions |

---

## 9. Open Items

- Final token strategy: JWT-only or JWT access token with refresh-token persistence
- Worker strategy for booking expiration in deployment
- Exact Cloudinary folder and naming conventions
- Whether Google sign-in remains in scope for thesis MVP
- Whether realtime delivery uses WebSocket only or supports SSE fallback
