---
type: bmad-distillate
sources:
  - "architecture.md"
downstream_consumer: "general"
created: "2026-03-28"
token_estimate: 1100
parts: 1
---

## System Architecture Overview
- **Structure:** 3-tier architecture. Flutter Mobile Client -> FastAPI Backend -> PostgreSQL & Cloudinary.
- **Data Flow:** All client requests MUST route through FastAPI. Mobile never communicates directly with PostgreSQL or Cloudinary.
- **Backend Role:** Mandatory system entry point for Auth, RBAC, Parking APIs, Realtime Updates (WebSocket/SSE), and Media upload brokering.
- **Infrastructure:** Local Docker Compose setup. Redis handles Realtime & Caching. 

## Architectural Decisions

### Mobile Client
- **Tech:** Flutter (Android prioritized). `go_router` (navigation), `dio` (HTTP), `flutter_riverpod` (state), `mobile_scanner` (QR), `mapbox_maps_flutter` (Maps).
- **Responsibility:** Thin client. Captures inputs/media, renders views, securely stores tokens (`flutter_secure_storage`).

### Backend (FastAPI Monolith)
- **Tech:** FastAPI with `uv`. Extends existing `fastapi-boilerplate` in `backend/` directory.
- **Auth:** Backend hashes passwords, issues JWT access/refresh tokens.
- **Account Resolution:** `user.role` tracks active public workspace for compatibility. Capabilities resolve from linked `driver`, `lot_owner`, `manager` rows. Attendants and Admins exist as entirely separate credentials.
- **Booking Expiration:** Managed via backend scheduled execution (worker/cron/internal-scheduler).

### Databases & Media
- **Database:** PostgreSQL (23-table schema). Migrations handled by Alembic. Application-level RBAC replaces Supabase RLS.
- **Media Storage:** Cloudinary (Vehicle/Lot/Document images). Uploads broker strictly via FastAPI validation.

## Core Data Flows
- **QR State Machine:** Backend determines QR intent. No active session = `CHECKIN`. Active session = `CHECKOUT`.
- **Atomic Operations:** Check-in/out must be atomic. `adjust_available()` uses row-level locking to prevent overbooking races.
- **Realtime Availability:** Availability changes trigger database commits -> FastAPI publishes -> WebSockets/SSE broadcast to clients.

## Offline Resilience (Pending Sync)
- **Mechanism:** If network fails at the gate, Mobile queues the Check-in/out event in local SQLite/Hive and displays "Pending Sync" to unblock the attendant. 
- **Recovery:** Background sync flushes queue to FastAPI upon reconnection. 
- **Throttling:** Redis buffers validations before PostgreSQL atomic writes to protect the DB from burst syncs.

## Shift Handover Flow
- **Mechanism:** Outgoing attendant generates Shift QR containing `expected_cash`. Incoming scans QR, enters `actual_cash`.
- **Validation:** Discrepancy requires text rationale. FastAPI records `ShiftHandover`, locks old shift.

## API & Environment Strategy
- **Base URL:** `/api/v1`
- **Auth Scheme:** `Authorization: Bearer <token>`
- **Response Format:** `{ "data": {}, "message": "Success", "status": 200 }`
- **Backend ENV:** `POSTGRES_*`, `REDIS_URL`, `SECRET_KEY`, `CLOUDINARY_*`
- **Mobile ENV:** `API_BASE_URL`, `MAPBOX_ACCESS_TOKEN`

## Key Trade-offs
- FastAPI as single gateway (Centralized control > split services).
- Reuse existing backend scaffold (Speed over rebuilding perfectly clean slate).
- PostgreSQL direct usage via Alembic (Alings with existing backend DB stack).
- Cloudinary (Offloads image weight from PostgreSQL).
