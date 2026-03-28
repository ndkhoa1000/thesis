---
type: bmad-distillate
sources:
  - "prd.md"
downstream_consumer: "general"
created: "2026-03-28"
token_estimate: 2100
parts: 1
---

## Project Context
- **Product:** Smart Parking Management System (Thesis PoC demo)
- **Goal:** Digitize Vietnam's parking via a mobile-first platform replacing kiosk/NFC/camera setups. Create a marketplace connecting Drivers, Attendants, Operators, and Lot Owners.
- **Tech Stack:** Flutter Mobile App (Android 24+) -> FastAPI Monolith (uv) -> PostgreSQL + Cloudinary.

## Account Model & RBAC
- **Driver:** Default public account schema (`user.role = DRIVER`).
- **LotOwner:** Capability granted to public account post-approval (`user.role = LOT_OWNER` as active workspace).
- **Operator (Manager):** Capability granted to public account post-approval (`user.role = MANAGER` as active workspace).
- **Attendant:** Distinct account created/provisioned by Operator. Requires a dedicated login session (no switching from a public account).
- **Admin:** Distinct privileged account outside public signup flow.

## Functional Requirements (FRs)

### Discovery & Booking
- Drivers view map with real-time lot availability and can filter by distance/price/vehicle-type/tags (FR1-FR3).
- Drivers can book spots in advance; bookings auto-expire if unused (FR4-FR6).
- `current_available` updates instantaneously via FastAPI WebSocket/SSE (FR7, FR16).

### Core Parking Loop (Check-In/Out)
- **Driver App:** Generates QR code. Acts as state machine (CHECKIN -> CHECKOUT -> CHECKIN) (FR8, FR12-FR13).
- **Attendant Scan:** Scans Driver QR for check-in/out (FR9, FR14).
- **Walk-ins:** Attendant snaps vehicle photos (plate required) to check in drivers without the app; bypassed for full-profile registered active users (FR10-FR11).
- **Pricing:** Calculated at check-out via active `Pricing` rules. MVP supports **SESSION** (flat-rate) and **HOURLY** modes (FR15).

### Payments & History
- Payment flow supports Cash (Attendant confirmation) and Online variants. (MVP Online flow is simulated/mocked) (FR17-18).
- Payment records linked via polymorphic `payable_type` (FR19-FR20).
- Session edits are logged via `SessionEdit` with mandatory reasons (FR23-FR24).
- Drivers view parking history and e-receipts (FR25-FR26).

### Business Operations
- Operators set fixed lot info, capacity, opening hours, pricing grids with effective dates, and broadcast announcements (FR27-FR30).
- Operators view revenue reports and configure Attendant accounts (FR31-35).
- Lot Owners register lots and lease them to Operators. Contracts are auto-generated on approval (FR36-FR40).
- Admins vet lot registrations, manage leases, and handle user suspensions (FR41-FR43).

## Non-Functional Requirements (NFRs)
- **SLA:** 5-second QR check-in/out completion; 3-second map load; <1s API response (NFR1-3).
- **Architecture:** Client *never* talks to DB directly. All auth flows rely strictly on FastAPI backend tokens (NFR6-7).
- **Security:** HTTPS TLS 1.2+; QR codes are un-guessable and single-use per session (NFR5, NFR8).
- **Data Integrity:** Check-in/out logic must be atomic. `adjust_available()` logic uses row-level locking to prevent overbooking races (NFR15).
- **Device Requirements:** Always-online required for MVP (GPS + Camera). No offline mode required yet.

## Phase Strategy
- **Phase 1 (MVP):** End-to-end Driver & Attendant QR flow, Map Discovery, Lot Configuration, Basic leasing, Mocked Payments. Primary thesis focus.
- **Phase 2 (Growth):** Weekly/monthly subscriptions, NFC card scanning for Attendants, In-app/Push notifications (FR49-50).
- **Phase 3 (Expansion):** Stripe/Momo full integration, Biometric Login.

## Critical Edge Cases
- **Check-in Rejection:** Reject check-in if Driver has an active session (same or different lot) or if lot is full (`current_available = 0`).
- **Walk-in Reject:** Reject walk-in check-in if plate photo is missing.
- **Network Failure at Checkout:** Atomic rollback. Client must retry with same QR to guarantee zero data loss.
- **Simultaneous Booking:** Handled via row-level locks on `current_available`. Loser gets "lot full" error.
- **Capacity Adjustment:** Decreasing `total_capacity` below active sessions sets `current_available` to 0; no negative values allowed.
