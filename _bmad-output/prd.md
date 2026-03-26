---
stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-02b-vision', 'step-02c-executive-summary', 'step-03-success', 'step-04-journeys', 'step-05-domain', 'step-06-innovation', 'step-07-project-type', 'step-08-scoping', 'step-09-functional', 'step-10-nonfunctional', 'step-11-polish', 'step-12-complete']
inputDocuments: ['doc/usecase.md', 'doc/erd.md', 'doc/reference.md']
documentCounts:
  briefs: 0
  research: 0
  brainstorming: 0
  projectDocs: 3
workflowType: 'prd'
classification:
  projectType: mobile_app
  domain: Transportation / Urban Mobility
  complexity: medium
  projectContext: brownfield
techStack:
  frontend: Flutter
  backend: FastAPI Monolith
  database: PostgreSQL
---

# Product Requirements Document - Smart Parking Management System

**Author:** Khoa
**Date:** 2026-03-19

## Executive Summary

Smart Parking Management System is a mobile-first platform that digitizes Vietnam's fragmented parking ecosystem. The system connects four key actors — lot owners who lease physical space, operators who rent and run parking businesses, attendants who manage day-to-day operations, and drivers who need to find and pay for parking — into a unified marketplace.

The primary problem addressed is that drivers cannot find available parking during peak hours, traffic congestion, and city events. The secondary problem is that most Vietnamese parking lots rely on outdated methods (NFC cards, dedicated kiosks with cameras and PCs), creating friction for both operators and drivers. This platform replaces the entire kiosk setup with a single phone: attendants scan QR codes for check-in/check-out, drivers pay online, and real-time availability is shown on a map.

This is a thesis project demonstrating proof of concept. The scope targets a functional demo with complete user flows rather than production-grade deployment.

### What Makes This Special

- **Phone replaces kiosk infrastructure.** Traditional Vietnamese parking requires NFC cards, cameras, PCs, and dedicated kiosk hardware. This system reduces all of that to a mobile phone — eliminating card loss, reducing setup cost, and enabling any lot to go digital instantly.
- **Platform model, not per-lot software.** Existing parking apps in Vietnam sell to individual lots. This system creates a marketplace: LotOwners advertise space for lease, Operators rent and configure lots, and Drivers discover everything in one place. The addressable market expands from individual lots to the entire parking supply chain.
- **Real-time spot discovery with rich context.** Drivers see not just availability but pricing, operating hours, security features (cameras, IoT), and convenience tags on a map — enabling informed decisions during traffic jams or events.

## Project Classification

| Dimension | Value |
|-----------|-------|
| **Project Type** | Mobile App (Flutter) |
| **Domain** | Transportation / Urban Mobility |
| **Complexity** | Medium |
| **Project Context** | Brownfield (existing documentation: use cases, ERD, user stories) |
| **Tech Stack** | Flutter → FastAPI Monolith (uv) → PostgreSQL + Cloudinary |
| **Scope** | Thesis project — proof of concept with demo |

> **Terminology note:** The PRD uses **Operator** to refer to the business entity that leases and runs a parking lot. In the ERD and database schema, the same role is modeled as the `Manager` entity with `User.role = MANAGER`. These terms are interchangeable — "Operator" is the product-facing name, "Manager" is the data-model name.

## Roles & Account Model

- **Driver (default public account):** Any user who registers through the public app flow is created as a `Driver` by default.
- **LotOwner capability:** A public account that starts as `Driver` can later apply to become a `LotOwner`. Once approved, the same account gains the ability to register lots, submit ownership documents, and post lots for lease.
- **Operator capability:** A public account that starts as `Driver` can later apply to become an `Operator`. Once approved, the same account gains the ability to lease lots, configure operations, and manage attendants.
- **Shared public-account model:** `Driver`, `LotOwner`, and `Operator` are treated as capabilities on the same public account lifecycle. They are not modeled as isolated login identities that require separate credentials.
- **Attendant account:** `Attendant` is always a separate account created and provisioned by an `Operator`. It is not added as an extra capability on the public Driver/LotOwner/Operator account. A user acting as an attendant must sign out and sign back in with dedicated Attendant credentials.
- **Admin account:** `Admin` is always a separate privileged account managed outside the public signup flow.

## Success Criteria

### User Success

- **Driver finds available parking instantly.** Real-time map shows slot availability, pricing, features, and security level — driver makes an informed choice in under 30 seconds even during traffic or events.
- **QR check-in/check-out is faster than NFC.** Driver scans QR from their phone — no physical card to lose, no kiosk queue. Daily parkers carry only their phone.
- **Smart notifications keep drivers informed.** *(Phase 2)* Subscribed drivers receive alerts when their lot is getting busy/full, when lot owners post event notices or holiday closures, and when their subscription is expiring.
- **Flexible passes for regulars.** *(Phase 2)* Drivers can purchase weekly/monthly QR-based passes, or receive free member cards for buildings where the lot is located.

### Business Success (Thesis Context)

- **All implemented features work end-to-end.** Each user flow (find → check-in → check-out → payment) completes without manual workaround.
- **Architecture is explainable.** Every feature can be explained in terms of why it was built that way and how it works — suitable for thesis defense.
- **Proof of concept demonstrates automation potential.** The QR check-in → checkout → online payment flow shows that with IoT, the entire process could run without human intervention.

### Technical Success

- **Mobile-first, phone-only operation.** Attendant app replaces kiosk/PC/camera setup entirely. All operations run on a phone.
- **Backend handles concurrent parking sessions.** FastAPI processes multiple check-ins/check-outs simultaneously without data inconsistency.
- **Real-time availability updates.** `current_available` count on the map reflects actual state within acceptable latency.

### Measurable Outcomes

| Metric | Target |
|--------|--------|
| QR check-in time | < 5 seconds from scan to confirmation |
| Map load with availability | < 3 seconds |
| Complete driver flow (find → pay) | Demonstrable end-to-end in thesis demo |
| Attendant flow (scan-in → scan-out → collect) | Demonstrable end-to-end |
| All use case flows | Functionally complete, no broken flows |

## Product Scope & Phased Development

### MVP Strategy

**Approach:** Problem-solving MVP — prove that the core driver-attendant flow (find → check-in → check-out → pay) works end-to-end on mobile, replacing the kiosk/NFC model.

**Resource:** Solo developer (thesis project). One Flutter app, one FastAPI backend already set up from `fastapi-boilerplate`, one PostgreSQL database, and Cloudinary for image storage.

### MVP Feature Set (Phase 1)

**Core User Journeys Supported:**
- Minh (Driver): find parking → book → QR check-in → check-out → pay
- Hùng (Attendant): QR scan-in → photo → scan-out → collect payment

**Must-Have Capabilities:**

| Feature | Actor | Priority |
|---------|-------|----------|
| Map with real-time lot availability | Driver | P1 |
| Lot detail view (price, hours, tags, announcements) | Driver | P1 |
| QR check-in / check-out | Driver + Attendant | P1 |
| Manual plate entry (walk-in) | Attendant | P1 |
| Vehicle photo capture | Attendant | P1 |
| Payment — cash confirmation | Attendant | P1 |
| Payment — online (basic) | Driver | P1 |
| Parking history | Driver | P1 |
| Lot stats (occupied/free) | Attendant | P1 |
| Session editing with audit log | Attendant | P1 |
| Booking (reserve in advance) | Driver | P1 |
| Lot configuration (hours, capacity, pricing) | Operator | P2 |
| Post announcements | Operator | P2 |
| Revenue reports | Operator | P2 |
| Register lot + submit for approval | LotOwner | P3 |
| Post lot for lease | LotOwner | P3 |
| Approve lots / leases | Admin | P3 |
| Manage users | Admin | P3 |

### Phase 2 — Growth

- In-app notification system (busy lot, events, expiry alerts)
- Weekly/monthly subscription passes with QR
- NFC card scanning for attendants
- Push notifications (FCM)
- Invoice generation and printing

### Phase 3 — Expansion

- Biometric login (Google auth)
- Advanced payment integrations (Stripe/Momo full flow)
- Offline mode for attendant
- Dynamic pricing / demand prediction
- Fully unmanned parking flow

### Risk Mitigation Strategy

| Risk | Impact | Mitigation |
|------|--------|------------|
| **QR scanning reliability** | Core flow breaks if scan fails | Use a proven Flutter scanner such as `mobile_scanner`. Fallback: manual plate entry |
| **Real-time availability accuracy** | Driver sees wrong data, loses trust | `current_available` updated at check-in/out via API. Acceptable latency for thesis demo |
| **Single developer bandwidth** | Can't finish all features | P1 features first. P3 features only if time allows. Thesis demo focuses on P1+P2 partial |
| **Payment integration complexity** | Stripe/Momo requires API keys + testing | Basic mock payment for thesis. Real integration when API keys provided |
| **Flutter plugin configuration complexity** | Some capabilities such as NFC or advanced camera integrations need platform-specific setup | Thesis MVP stays with QR-based mobile flow first; advanced plugins are deferred |

## User Journeys

### Journey 1: Minh — Driver Finds Parking During Rush Hour

**Persona:** Minh, 28, daily commuter in Ho Chi Minh City. Drives a motorbike to work.

**Opening:** Minh is stuck in traffic near District 1 during evening rush. His usual lot was full last time, and he wasted 20 minutes circling the block.

**Journey:**
1. Opens the app → map shows nearby lots with real-time availability, pricing, and tags (covered, camera-secured).
2. Spots a lot 300m away with 12 slots free at 3,000₫/session → taps to see details, hours, announcements.
3. Decides to book a spot → pays deposit online → receives QR confirmation.
4. Arrives at the lot → scans QR at entry → attendant sees check-in confirmed, takes a photo of his bike.
5. After work, scans QR to check out → app shows 3,000₫ flat rate → pays remaining via Momo.
6. Receives digital receipt → parking history updated.

**Resolution:** Minh saved 20 minutes and never worried about having cash. He bookmarks this lot for next time. *(In Phase 2, Minh could purchase a monthly pass for even faster daily parking.)*

### Journey 2: Hùng — Attendant Manages Morning Rush

**Persona:** Hùng, 35, parking attendant at a busy lot in District 3. Uses a phone instead of a kiosk.

**Journey:**
1. Morning shift starts → opens attendant app → sees lot stats: 45/60 occupied, 15 free.
2. Driver with app arrives → Hùng scans their QR code → check-in auto-created, photo captured.
3. Walk-in driver with no app → Hùng enters license plate manually, selects vehicle type → system generates a session QR and shares it.
4. A driver returns to pick up their bike → Hùng scans the QR → system shows 3,000₫ flat rate → driver pays cash → Hùng taps "Confirm Cash Payment."
5. Another driver pays online instead → payment auto-confirmed → Hùng sees status update, opens the exit.
6. Realizes he entered a wrong plate earlier → edits the session, enters reason → change logged in SessionEdit.

### Journey 3: Lan — Operator Sets Up and Runs a Lot

**Persona:** Lan, 40, business operator who just leased a lot from a LotOwner.

**Journey:**
1. Lan already has a public account and applies to become an Operator → Admin approves the operator capability.
2. Lease approved by Admin → Lan accesses her lot in the operator workspace of the same account.
3. Configures lot: sets capacity (60 motorbikes, 10 cars), hours (6AM–10PM), uploads photos, writes description and policies.
4. Sets pricing: motorbike 3,000₫/session (day), 8,000₫/session (night); car 15,000₫/hr.
5. A holiday is coming → posts announcement: "Tết holiday hours: 8AM–6PM, expect high demand."
6. End of month → checks revenue dashboard: 4,200 sessions, 85M₫ revenue, 78% occupancy rate.
7. Creates a separate Attendant account for a staff member, who must log in with those dedicated credentials to operate the lot.

### Journey 4: Bảo — Lot Owner Lists Property for Lease

**Persona:** Bảo, 50, owns a commercial building with ground-floor parking space in District 7.

**Journey:**
1. Registers on the platform as a public user and starts as a Driver account.
2. Applies to become a LotOwner → uploads ownership proof and required business documents.
3. Admin approves the LotOwner capability on the same account.
4. Registers his parking lot: address, coordinates, photos, description → submits for Admin approval.
5. Admin approves → lot appears on the platform with APPROVED status.
6. Posts the lot for lease: monthly fee 15M₫, minimum 6-month contract.
7. Operator Lan applies to lease → Bảo reviews the application → Admin approves the contract → LotLease created as ACTIVE.
8. Bảo monitors his active contract and can see when it's expiring.

### Journey 5: Admin — Platform Oversight

**Persona:** System administrator managing platform operations.

**Journey:**
1. New lot registration from Bảo → reviews submitted documents and lot details → approves.
2. Lease request from Lan for Bảo's lot → reviews contract terms → approves → LotLease activated.
3. Receives a complaint about a user → searches user list → deactivates the flagged account.

### Journey Requirements Summary

| Journey | Key Capabilities Revealed |
|---------|---------------------------|
| **Minh (Driver)** | Map search, real-time availability, booking, QR check-in/out, online payment, parking history, monthly passes |
| **Hùng (Attendant)** | QR scanning, manual plate entry, photo capture, cash/online payment processing, session editing, lot stats |
| **Lan (Operator)** | Lot configuration, pricing management (flat-rate + hourly), announcements, revenue dashboard, config versioning |
| **Bảo (LotOwner)** | Lot registration, lease listing, contract management |
| **Admin** | Lot approval, lease approval, user management |

## Mobile App Specific Requirements

### Platform Requirements

| Aspect | Decision |
|--------|----------|
| **Framework** | Flutter |
| **Primary target** | Android (testing platform) |
| **iOS** | Optional / future |
| **Distribution** | Android APK for thesis demo — no store publishing |
| **Minimum Android** | API 24+ (Android 7.0) |

Flutter is selected because it allows the same frontend codebase to be extended to Android, iOS, web, or desktop in later phases. However, to keep the thesis scope manageable, the current implementation and demo remain focused on the mobile platform.

### Device Permissions & Features

**Core (MVP):**
- 📷 **Camera** — QR code scanning (check-in/out), vehicle photo capture
- 📍 **Location (GPS)** — Map-based lot discovery, nearby lot search
- 🌐 **Internet** — Always-online required; no offline mode

**Later Phase:**
- 📱 **NFC** — Attendant card scanning for check-in/out
- 🔔 **Push Notifications** — Lot busy alerts, event notices, subscription expiry (in-app first, push if straightforward)
- 🔐 **Biometrics** — Fingerprint/face login via Google authentication

### Offline Mode

Not required for thesis demo. Always-online is acceptable. Future consideration: cache lot stats for attendant resilience during network drops.

### Notification Strategy

| Phase | Type | Implementation |
|-------|------|----------------|
| **MVP** | In-app notifications | Query `Notification` table, display in-app notification list |
| **Later** | Push notifications | Firebase Cloud Messaging or `flutter_local_notifications` |

### Implementation Considerations

- **Flutter plugin setup** — Some plugins require Android and iOS configuration during integration. NFC and other advanced native capabilities remain outside the MVP and are deferred.
- **Account-model split** — Public-user experiences (`Driver`, `LotOwner`, `Operator`) live on the same account lifecycle, with `LotOwner` and `Operator` unlocked through approval-based capability expansion. `Attendant` and `Admin` use separate accounts and separate login sessions.
- **Core features first** — QR scanning, map, check-in/out, payment must work end-to-end before adding NFC, push notifications, biometrics.



## Functional Requirements

### Parking Discovery & Booking

- **FR1:** Driver can view nearby parking lots on a map with real-time availability
- **FR2:** Driver can filter/search lots by distance, price, vehicle type, and tags
- **FR3:** Driver can view lot details including pricing, hours, features, description, cover image, and announcements
- **FR4:** Driver can book a parking spot in advance for a specific lot and time
- **FR5:** Driver can cancel a booking before expiration
- **FR6:** System automatically expires bookings when the expected arrival time passes
- **FR7:** System updates `current_available` count when bookings are created, cancelled, or expired

### Check-In & Check-Out

- **FR8:** Driver can check in by showing their QR code to the attendant. The attendant scans the driver's QR to create a parking session. *(Future/IoT scope: driver scans a lot QR for self-service check-in without attendant)*
- **FR9:** Attendant can check in a vehicle by scanning the driver's QR code
- **FR10:** Attendant can check in a walk-in vehicle (no app) by capturing vehicle photos (at least one containing the license plate). The photo serves as the check-in record — no manual plate entry required. *(Future scope: AI model extracts license plate number from the photo automatically)*
- **FR11:** For registered app users with a fully set-up vehicle profile (photos and plate already on file), photo capture at check-in is optional — the system uses the existing vehicle record
- **FR12:** System creates a `ParkingSession` visible to both driver and attendant. The driver's QR operates as a **state machine**: when no active session exists, it is in `CHECKIN` state; after a session is created, it transitions to `CHECKOUT` state until the session ends, then returns to `CHECKIN` state
- **FR13:** Driver can check out by having their QR code scanned by the attendant (QR is in `CHECKOUT` state)
- **FR14:** Attendant can check out a vehicle by scanning the driver's QR code (or the session QR for walk-ins)
- **FR15:** System calculates the parking fee based on the lot's active pricing. The `Pricing` table uses a `pricing_mode` field supporting: **SESSION** (flat-rate per session), **HOURLY**, **DAILY**, **MONTHLY**, and **CUSTOM**. MVP implements SESSION and HOURLY; other modes are Phase Expansion
- **FR16:** System updates `current_available` count on check-in and check-out and pushes fresh availability to connected clients through FastAPI-managed realtime updates

### Payment

- **FR17:** Attendant can record a cash payment for a parking session
- **FR18:** Driver can pay for a parking session online. **MVP scope:** online payment is a simulated flow — the app marks the payment as COMPLETED in the database without calling a real payment gateway. Real Stripe/Momo integration is deferred to Phase 3
- **FR19:** System creates a `Payment` record with amount, method, and status
- **FR20:** System links payments to sessions, bookings, or subscriptions via polymorphic `payable_type`

### Session Management

- **FR21:** Attendant can view all vehicles currently checked in at their lot
- **FR22:** Attendant can view lot statistics (total capacity, occupied, free slots by vehicle type)
- **FR23:** Attendant can edit a parking session's details (license plate, slot, vehicle type) with a required reason
- **FR24:** System logs all session edits in `SessionEdit` with old/new values, reason, and editor

### Parking History & Receipts

- **FR25:** Driver can view their parking history with date, lot, duration, and amount paid
- **FR26:** Driver can view details of a specific past parking session

### Lot Configuration (Operator)

- **FR27:** Operator can update lot fixed information (name, address, description, photos, tags)
- **FR28:** Operator can create/update time-based lot configuration (capacity, hours, vehicle types) with effective dates
- **FR29:** Operator can set and update pricing rules (flat-rate per session or hourly, by vehicle type) with effective dates
- **FR30:** Operator can post announcements (events, traffic alerts, closures, peak hours) with visibility dates

### Revenue & Reporting (Operator)

- **FR31:** Operator can view revenue reports by day, week, or month
- **FR32:** Operator can view session counts, occupancy rates, and vehicle type breakdowns

### Attendant Management (Operator)

- **FR33:** Operator can create and provision a separate Attendant account for a staff member, then assign that account to one or more managed lots
- **FR34:** Operator can view the list of attendants assigned to their lot
- **FR35:** Operator can remove an attendant from their lot

### Lot Registration & Leasing

- **FR36:** Lot Owner can register a parking lot with address, coordinates, photos, and ownership documents
- **FR37:** Lot Owner can post a lot for lease with monthly fee and contract terms
- **FR38:** Operator can apply to lease a posted lot
- **FR39:** Lot Owner can view and manage active lease contracts
- **FR40:** System automatically generates a lease contract/invoice when a LotLease is approved and activated. Both LotOwner and Operator can view and download the contract

### Platform Administration

- **FR41:** Admin can approve or reject lot registrations from Lot Owners
- **FR42:** Admin can approve or reject lease requests from Operators
- **FR43:** Admin can search, view, activate, or deactivate user accounts

### User Management & Authentication

- **FR44:** User can register a public account through FastAPI using email and password. Public registration always creates a `Driver` account by default. Account records are stored in PostgreSQL and issued API tokens by the backend.
- **FR45:** A public account can later apply to gain `LotOwner` capability or `Operator` capability. These capabilities are granted on the same account after approval and unlock role-appropriate features without requiring separate public-account credentials.
- **FR46:** Driver can register vehicles with license plate, type, brand, color, and photos
- **FR47:** `Attendant` accounts are separate credentials created by an `Operator`. Users must sign out of any public account session and sign in again with the dedicated Attendant account to act as an attendant.
- **FR48:** `Admin` accounts are separate privileged accounts managed outside the public signup flow.

### Notifications (Phase 2)

- **FR49:** System can send in-app notifications to users (booking expiry, subscription expiry, lot closing, payment success)
- **FR50:** User can view their notification list and mark notifications as read

## Non-Functional Requirements

### Performance

- **NFR1:** Map screen loads with lot markers and availability data within 3 seconds
- **NFR2:** QR code scanning and check-in/out confirmation completes within 5 seconds
- **NFR3:** API responses for CRUD operations return within 1 second under normal load
- **NFR4:** `current_available` updates propagate to the map in near real time via FastAPI WebSocket or SSE broadcasting (sub-second target for connected clients)

### Security

- **NFR5:** All API communication uses HTTPS (TLS 1.2+)
- **NFR6:** User authentication and password management are handled directly by the FastAPI backend using secure password hashing and token issuance
- **NFR7:** All client auth flows (register, login, refresh, logout) go through FastAPI endpoints. The mobile app never talks directly to the database or any third-party auth provider
- **NFR8:** QR codes for parking sessions are unique, non-guessable, and single-use per session
- **NFR9:** Role-based access control is enforced at the FastAPI endpoint and service layers, with database ownership checks implemented in application queries and transaction boundaries
- **NFR10:** Payment data is not stored locally on the device; payment processing is handled by the backend, with MVP using a simulated online flow and future gateway integrations managed in FastAPI services

### Integration

- **NFR11:** Backend communicates with PostgreSQL through the existing FastAPI backend stack and migration tooling already present in the repository
- **NFR12:** Future payment processing integrates with Stripe and/or Momo through backend service modules or webhook handlers inside FastAPI
- **NFR13:** Map display integrates with Mapbox as primary provider; Google Maps as backup if Mapbox implementation is problematic
- **NFR14:** Image storage (vehicle photos, lot covers, ownership documents) uses Cloudinary, with uploads brokered by FastAPI

### Reliability

- **NFR15:** No data loss on parking sessions — check-in/check-out operations must be atomic
- **NFR16:** Booking expiration runs reliably through backend-managed scheduled jobs or database-backed worker execution
- **NFR17:** App handles network errors gracefully with user-friendly error messages

---

## Edge Case Handling

The following defines the expected system behavior for exceptional scenarios across core features.

### Check-In Edge Cases

| Scenario | System Behavior |
|----------|----------------|
| **EC1:** Attendant scans QR for a driver who already has an active session at this lot | Reject check-in. Return error: "Driver already checked in at this lot." |
| **EC2:** Attendant scans QR for a driver who has an active session at a *different* lot | Reject check-in. Return error: "Driver has an active session at [other lot name]." |
| **EC3:** Check-in attempted when `current_available = 0` (lot is full) | Reject check-in. Return error: "Lot is full — no available spots." |
| **EC4:** QR scan fails or QR data is malformed | Return error: "Invalid QR code. Please try again." Attendant can retry or fall back to walk-in photo capture. |
| **EC5:** Walk-in check-in with no photo uploaded | Reject. At least one photo containing the license plate is required for walk-in vehicles. |
| **EC6:** Driver's vehicle profile is incomplete (no plate or photos) | Allow check-in but flag `photo_required: true`. Attendant must capture photos before proceeding. |

### Check-Out Edge Cases

| Scenario | System Behavior |
|----------|----------------|
| **EC7:** Attendant scans QR for a driver with no active session (already checked out or never checked in) | Reject. Return error: "No active session found for this driver." |
| **EC8:** Same session QR scanned twice for checkout | First scan succeeds. Second scan returns: "Session already checked out." |
| **EC9:** Check-out attempted but no active pricing record found for the lot + vehicle type | Flag error to attendant. Allow manual override with a fixed fee, logged in `SessionEdit`. |
| **EC10:** Network failure during checkout (partial operation) | Operation must be atomic. If fee calculation succeeds but DB update fails, rollback. Client retries with same session QR. |

### Booking Edge Cases

| Scenario | System Behavior |
|----------|----------------|
| **EC11:** Driver creates booking when `current_available = 0` | Reject. Return error: "No available spots to book." |
| **EC12:** Driver tries to create a second booking at the same lot while one is active | Reject. Return error: "You already have an active booking at this lot." |
| **EC13:** Driver cancels a booking that has already expired | Return: "Booking has already expired." No availability change (cron already restored the spot). |
| **EC14:** Driver arrives with booking QR but booking has expired | Reject booking conversion. Attendant can create a regular check-in if spots are available. |
| **EC15:** Two drivers book the last available spot simultaneously | `adjust_available()` uses row-level locking. First request succeeds, second gets "lot full" error. |

### Payment Edge Cases

| Scenario | System Behavior |
|----------|----------------|
| **EC16:** Payment submitted for a session that already has a completed payment | Reject. Return error: "Payment already recorded for this session." |
| **EC17:** Cash payment amount recorded as 0 or negative | Reject. Validate `amount > 0` at API level. |
| **EC18:** Online payment (mock) fails | Mock always succeeds in MVP. In Phase 3 (real gateway), return payment failure status and allow retry. |

### Availability Edge Cases

| Scenario | System Behavior |
|----------|----------------|
| **EC19:** `current_available` becomes negative due to a bug or race condition | `GREATEST(0, ...)` in `adjust_available()` prevents negative values. If 0 is reached, further decrements are silently clamped. |
| **EC20:** Operator changes `total_capacity` while sessions are active | `current_available` is recalculated: `new_capacity - active_sessions_count`. If result < 0, set to 0 (lot is overbooked until sessions end). |

