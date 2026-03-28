---
type: bmad-distillate
sources:
  - "tech-design.md"
downstream_consumer: "general"
created: "2026-03-28"
token_estimate: 1100
parts: 1
---

## Technical Direction
- **MANDATE:** Supabase is completely removed from the system design. The mobile app must migrate exclusively to backend APIs.
- **Backend Reuse:** The existing `fastapi-boilerplate` in `backend/` must be used as the implementation base. Generic starter routes (posts, tiers) must be incrementally replaced with the parking domain.

## Database Strategy (Alembic + PostgreSQL)
- **Target Schema:** The 23-table parking ERD (users, lots, sessions, bookings, payments, leases).
- **Tooling:** Database migrations must be managed entirely via the backend's Alembic implementation (`uv run alembic`).
- **Atomicity:** Check-in, check-out, bookings, and payments must be transactional. `current_available` updates must occur within the same transaction.

## Authentication & Workspace Model
- **Auth Provider:** Handled 100% by FastAPI. App posts to `/auth/login`, receives JWTs, stores in `flutter_secure_storage`.
- **Capability Resolution:** 
  - One central `user` identity.
  - Linked rows (`driver`, `lot_owner`, `manager`) grant public capabilities. 
  - `user.role` tracks the current active workspace for compatibility with existing RBAC guards.
  - `Attendant` and `Admin` are distinct accounts with their own exclusive login sessions.

## Media & Realtime Services
- **Cloudinary:** Mobile sends multipart/form-data to FastAPI -> FastAPI validates & uploads -> Stores `public_id` and secure URL in DB. Cloudinary secrets exist *only* in the backend `#env`.
- **Realtime Availability:** Supabase Realtime is gone. Replaced by a FastAPI-owned WebSocket (or SSE fallback) endpoint (`/ws/availability`) broadcasting `lot.availability.updated` events.

## Mobile Migration Priorities
1. Remove all direct Supabase auth calls. Replace with a custom API Client + Auth Interceptor.
2. Remove direct Supabase table queries. Replace with HTTP calls to FastAPI endpoints.
3. Remove Supabase realtime listeners. Replace with standard WebSocket connections.
4. Remove Supabase URL/Anon keys from the mobile environment.

## API & Response Design
- **Success:** `{ "data": {}, "message": "Success", "status": 200 }`
- **Error:** `{ "data": null, "error": { "code": "PARK_409_02", "message": "..." }, "status": 409 }`

## Sprint Implementation Roadmap
- **S0:** Align backend config, models, migrations (Alembic), and API foundations.
- **S1:** Auth, profile, vehicles APIs.
- **S2:** Lots, map data, Realtime WebSocket APIs.
- **S3:** Sessions, QR flows, Pricing calculation hooks.
- **S4:** Bookings & Payments APIs.
- **S5:** Leases, Attendants, Announcements, Reports, Admins APIs.
- **S6:** End-to-end testing and demo hardening.
