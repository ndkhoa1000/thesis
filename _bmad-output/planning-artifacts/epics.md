---
stepsCompleted: ["step-01-validate-prerequisites"]
inputDocuments: ["_bmad-output/prd.md", "_bmad-output/architecture.md", "_bmad-output/tech-design.md", "index.md", "doc/usecase.md", "doc/erd.md", "doc/reference.md"]
---

# thesis - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for thesis, decomposing the requirements from the PRD, UX Design if it exists, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

- FR1: Driver can view nearby parking lots on a map with real-time availability
- FR2: Driver can filter/search lots by distance, price, vehicle type, and tags
- FR3: Driver can view lot details including pricing, hours, features, description, cover image, and announcements
- FR4: Driver can book a parking spot in advance for a specific lot and time
- FR5: Driver can cancel a booking before expiration
- FR6: System automatically expires bookings when the expected arrival time passes
- FR7: System updates current_available count when bookings are created, cancelled, or expired
- FR8: Driver can check in by showing their QR code to the attendant. The attendant scans the driver's QR to create a parking session.
- FR9: Attendant can check in a vehicle by scanning the driver's QR code
- FR10: Attendant can check in a walk-in vehicle (no app) by capturing vehicle photos (at least one containing the license plate).
- FR11: For registered app users with a fully set-up vehicle profile (photos and plate already on file), photo capture at check-in is optional.
- FR12: System creates a ParkingSession visible to both driver and attendant. The driver's QR operates as a state machine.
- FR13: Driver can check out by having their QR code scanned by the attendant.
- FR14: Attendant can check out a vehicle by scanning the driver's QR code (or the session QR for walk-ins)
- FR15: System calculates the parking fee based on the lot's active pricing (SESSION or HOURLY mode).
- FR16: System updates current_available count on check-in and check-out and broadcasts availability updates through FastAPI-managed realtime delivery.
- FR17: Attendant can record a cash payment for a parking session
- FR18: Driver can pay for a parking session online (MVP scope: simulated flow).
- FR19: System creates a Payment record with amount, method, and status
- FR20: System links payments to sessions, bookings, or subscriptions via polymorphic payable_type
- FR21: Attendant can view all vehicles currently checked in at their lot
- FR22: Attendant can view lot statistics (total capacity, occupied, free slots by vehicle type)
- FR23: Attendant can edit a parking session's details (license plate, slot, vehicle type) with a required reason
- FR24: System logs all session edits in SessionEdit with old/new values, reason, and editor
- FR25: Driver can view their parking history with date, lot, duration, and amount paid
- FR26: Driver can view details of a specific past parking session
- FR27: Operator can update lot fixed information (name, address, description, photos, tags)
- FR28: Operator can create/update time-based lot configuration (capacity, hours, vehicle types) with effective dates
- FR29: Operator can set and update pricing rules (flat-rate per session or hourly, by vehicle type) with effective dates
- FR30: Operator can post announcements (events, traffic alerts, closures, peak hours) with visibility dates
- FR31: Operator can view revenue reports by day, week, or month
- FR32: Operator can view session counts, occupancy rates, and vehicle type breakdowns
- FR33: Operator can create and provision a separate Attendant account for a staff member, then assign that account to one or more managed lots
- FR34: Operator can view the list of attendants assigned to their lot
- FR35: Operator can remove an attendant from their lot
- FR36: Lot Owner can register a parking lot with address, coordinates, photos, and ownership documents
- FR37: Lot Owner can post a lot for lease with monthly fee and contract terms
- FR38: Operator can apply to lease a posted lot
- FR39: Lot Owner can view and manage active lease contracts
- FR40: System automatically generates a lease contract/invoice when a LotLease is approved and activated.
- FR41: Admin can approve or reject lot registrations from Lot Owners
- FR42: Admin can approve or reject lease requests from Operators
- FR43: Admin can search, view, activate, or deactivate user accounts
- FR44: User can register a public account through FastAPI using email and password, with public signup creating a Driver account by default
- FR45: A public account can later apply to gain LotOwner capability or Operator capability on the same account after approval
- FR46: Driver can register vehicles with license plate, type, brand, color, and photos
- FR47: Attendant accounts are separate credentials created by an Operator and require a dedicated login session
- FR48: Admin accounts are separate privileged accounts outside the public signup flow
- FR49: System can send in-app notifications to users (Phase 2 scope)
- FR50: User can view their notification list and mark notifications as read (Phase 2 scope)

### NonFunctional Requirements

- NFR1: Map screen loads with lot markers and availability data within 3 seconds
- NFR2: QR code scanning and check-in/out confirmation completes within 5 seconds
- NFR3: API responses for CRUD operations return within 1 second under normal load
- NFR4: current_available updates propagate to the map in near real time via FastAPI WebSocket or SSE broadcasting
- NFR5: All API communication uses HTTPS (TLS 1.2+)
- NFR6: User authentication and password management are handled by FastAPI using secure password hashing and backend-issued tokens
- NFR7: All client auth flows go through FastAPI endpoints. The mobile app never talks directly to the database or third-party auth services
- NFR8: QR codes for parking sessions are unique, non-guessable, and single-use per session
- NFR9: Role-based access control is enforced in FastAPI route dependencies, service-layer checks, and filtered database access patterns
- NFR10: Payment data is not stored locally; MVP online payment is simulated in the backend and future gateway integrations live in FastAPI services
- NFR11: Backend communicates directly with PostgreSQL using the existing backend stack and migration tooling
- NFR12: Future payment processing integrates with Stripe and/or Momo through FastAPI services or webhook handlers
- NFR13: Map display integrates with Mapbox as primary provider.
- NFR14: Image storage (vehicle photos, lot covers, ownership documents) uses Cloudinary via FastAPI-managed uploads.
- NFR15: No data loss on parking sessions — check-in/check-out operations must be atomic.
- NFR16: Booking expiration runs reliably through backend-managed scheduled jobs or worker execution.
- NFR17: App handles network errors gracefully with user-friendly error messages.

### Additional Requirements

- Starter Template: Backend is built upon `fastapi-boilerplate` connected via API gateways, which will define Epic 1 logic for initial setup.
- Infrastructure setup requirement: Mobile client is primarily deployed as a Flutter Android build for thesis demo on Android API 24+. Backend runs on local Docker Compose. 
- Integration requirement: Realtime integration is implemented in FastAPI using WebSocket or SSE to propagate `current_available`.
- Architecture constraint: All logic must run through the FastAPI server gateway, keeping the mobile client thin. Clients never talk directly to PostgreSQL or Cloudinary.
- Backend constraint: The existing `backend/` project is mandatory and must be adapted rather than replaced.
- Database constraint: 23 tables defined in the ERD must be migrated through the backend Alembic workflow into PostgreSQL.

### UX Design Requirements

N/A

### FR Coverage Map

{{requirements_coverage_map}}

## Epic List

> **UX Consistency Note (Applied across all Epics):** All UI development must strictly adhere to the Divergent UI Strategy. The Attendant App must use Dark Mode, massive typography, edge-to-edge touch targets, and avoid on-screen keyboards at the gate. The Driver/Operator App must use Light Mode, floating MD3 components, and spacious layouts. All primary actions must be anchored to the bottom "Thumb-Zone".

### Epic 1: User Identity & Profiles
**Goal:** Users can securely authenticate and manage their identities/vehicles, forming the foundation of the platform.
**FRs covered:** FR44, FR45, FR46, FR47, FR48

#### Story 1.1: User Registration
**As a** new user,
**I want** to register an account using my email and a password,
**So that** I can create a personal profile on the smart parking platform.

**Acceptance Criteria:**
* **Given** I am on the registration screen
* **When** I enter a valid email and a secure password and submit
* **Then** my account is created in the database atomically
* **And** the API uses the existing FastAPI backend stack to create the user and issue tokens
* **And** I am automatically logged in
* **And** the created public account is initialized with Driver capability by default.

#### Story 1.2: User Login
**As a** registered user,
**I want** to log into my account,
**So that** I can access the parking platform features securely.

**Acceptance Criteria:**
* **Given** I am on the login screen
* **When** I enter my correct email and password
* **Then** I am authenticated as one public `user` identity and navigated to the workspace indicated by its current primary role
* **And** public accounts can access any approved Driver, LotOwner, and Operator workspaces linked to that same `user` identity through capability records
* **And** Attendant and Admin accounts log in through separate credentials rather than switching from a public account session.
* **And** the user may explicitly choose to remember the public session for up to 1 day on that device; otherwise the app must require login again on the next launch.
* **And** authenticated shells expose a logout action that clears the local session and returns the user to the login screen.

#### Story 1.3: Manage License Plates
**As a** driver,
**I want** to add and remove vehicle license plates on my profile,
**So that** the system and lot attendants can identify my vehicle.

**Acceptance Criteria:**
* **Given** I am logged into the app
* **When** I add a new license plate
* **Then** it is saved to my profile and visible in my registered vehicles list.

#### Story 1.4: Apply to Become Lot Owner
**As a** Driver,
**I want** to apply for LotOwner capability on my existing account,
**So that** I can register parking lots and post them for lease without creating a separate public account.

**Acceptance Criteria:**
* **Given** I am authenticated with a public account
* **When** I submit the required ownership and verification documents
* **Then** the system creates a pending LotOwner application linked to my existing account
* **And** after Admin approval, the same `user` identity gains a linked `lot_owner` capability record and may update `user.role` to `LOT_OWNER` as its primary public workspace.

#### Story 1.5: Apply to Become Operator
**As a** Driver,
**I want** to apply for Operator capability on my existing account,
**So that** I can lease lots and manage parking operations without creating a separate public account.

**Acceptance Criteria:**
* **Given** I am authenticated with a public account
* **When** I submit the required business and verification documents
* **Then** the system creates a pending Operator application linked to my existing account
* **And** after Admin approval, the same `user` identity gains a linked `manager` capability record and may update `user.role` to `MANAGER` as its primary public workspace.

### Epic 2: Platform Inventory & Approvals
**Goal:** Lot Owners can register their properties and Admin can approve them, establishing the supply of parking lots.
**FRs covered:** FR36, FR41, FR43

#### Story 2.1: Register New Parking Lot
**As a** Lot Owner,
**I want** to register a new parking lot,
**So that** I can offer my property on the platform (pending approval).

**Acceptance Criteria:**
* **Given** I am authenticated as a Lot Owner
* **When** I fill out the Lot Registration form with required details
* **Then** a new Lot record is created with PENDING_APPROVAL status.

#### Story 2.2: Admin Dashboard & Pending Approvals
**As an** Admin,
**I want** to view pending approvals from one dashboard,
**So that** I can vet public-account capability applications and newly registered parking lots without using raw backend endpoints.

**Acceptance Criteria:**
* **Given** I am an Admin
* **When** I view pending approvals
* **Then** I can review and approve or reject supported application types including capability approvals and parking-lot registrations.

#### Story 2.3: Admin System Management & Lot Suspension
**As an** Admin,
**I want** to manage users and suspend lots,
**So that** I can maintain a safe ecosystem.

**Acceptance Criteria:**
* **Given** I am an Admin
* **When** I suspend an ACTIVE lot
* **Then** it is hidden from the map and prevents new check-ins.

### Epic 3: Lot Operations Setup
**Goal:** Operators can configure their approved lots and provision dedicated attendant accounts.
**FRs covered:** FR27, FR28, FR29, FR33, FR34, FR35

#### Story 3.1: Configure Lot Details & Capacity
**As an** Operator,
**I want** to configure the capacity and details of my lot,
**So that** the system limits check-ins automatically.

**Acceptance Criteria:**
* **Given** I am an Operator of a lot
* **When** I set the maximum capacity
* **Then** the lot will not accept check-ins beyond this capacity.

#### Story 3.2: Set Operating Hours & Pricing Rules
**As an** Operator,
**I want** to define operating hours and price per hour,
**So that** fees calculate automatically at check-out.

**Acceptance Criteria:**
* **Given** I am the Operator
* **When** I set pricing rules
* **Then** they are saved and applied to future check-ins.

#### Story 3.3: Create Attendant Accounts
**As an** Operator,
**I want** to create and provision dedicated Attendant accounts for my lot staff,
**So that** attendants can process check-ins and check-outs using separate credentials.

**Acceptance Criteria:**
* **Given** I am the Operator
* **When** I create or provision an Attendant account for a staff member
* **Then** that account is assigned attendant privileges for my lot
* **And** the attendant must log in with the dedicated Attendant credentials rather than switching from a public account session.

### Epic 4: The Core Parking Loop
**Goal:** Drivers can check-in/out and attendants process payments.
**FRs covered:** FR8, FR9, FR10, FR11, FR12, FR13, FR14, FR15, FR16, FR17, FR18, FR19, FR20

> **Readiness Note (post Epic 3 retrospective):** Epic 3 now provides the core setup contracts this epic depends on: active leased-lot access, lot-wide capacity, operating hours, pricing rules, and dedicated Attendant accounts. Epic 4 stories should treat inactive-account enforcement as a hard precondition for gate integrity, and should not couple to temporary validation bridges for role switching or lease bootstrap beyond using them to reach the workflow during interim testing.

#### Story 4.1: Driver Generates Check-In QR
**As a** Driver,
**I want** to generate a check-in QR code,
**So that** the attendant can scan it upon my arrival.

**Acceptance Criteria:**
* **Given** I have an active vehicle
* **When** I tap Check-In
* **Then** a unique QR code is displayed on my screen.

#### Story 4.2: Attendant Scans QR for Check-In
**As an** Attendant,
**I want** to scan a driver's QR code or NFC card,
**So that** I can register their vehicle entry in under 5 seconds.

**Acceptance Criteria:**
* **Given** I am an Attendant
* **When** I scan a valid check-in QR or NFC
* **Then** a new active session is created for that vehicle.
* **And (UX)** the screen immediately flashes Green with heavy haptic vibration and a Beep (Multisensory Flash Overlay).
* **And (UX)** a 2-second Cooldown Lens Lock overlay engages to prevent accidental double-scans of tailgating vehicles.
* **And (UX)** if the network is degraded, the session is saved locally and a "Pending Sync" state is displayed to maintain gate throughput without blocking the UI.

#### Story 4.3: Manual License Plate Check-In (NFC Walk-in)
**As an** Attendant,
**I want** to check-in walk-in vehicles using Camera,
**So that** I can process walk-in drivers without the app while maintaining the 5-second SLA.

**Acceptance Criteria:**
* **Given** I am an Attendant
* **When** a driver arrives without the app or with an unregistered NFC card
* **Then** I am prompted to take a photo of the front and back of the vehicle (Conditional Friction).
* **And (UX)** the system relies entirely on camera OCR or swipe gestures; the on-screen keyboard is disabled at the gate to prevent manual typing delays.

#### Story 4.4: Driver Generates Check-Out QR
**As a** Driver,
**I want** to view my active session and generate a check-out QR,
**So that** I can leave the lot.

**Acceptance Criteria:**
* **Given** I have an active parking session
* **When** I view the session details
* **Then** I see my elapsed time, estimated cost, and a Check-Out QR.

#### Story 4.5: Attendant Scans QR for Check-Out & Calculates Fee
**As an** Attendant,
**I want** to scan a driver's check-out QR or NFC to calculate the fee,
**So that** I know how much to charge rapidly.

**Acceptance Criteria:**
* **Given** a driver wants to leave
* **When** I scan their check-out QR or NFC
* **Then** the final fee is computed based on lot pricing rules.
* **And (UX)** the price is displayed using oversized typography (ExtraBold).
* **And (UX)** I am not required to visually verify the entry photos on-screen (No-Look Verification) to maximize exit speed.

#### Story 4.6: Record Payment & Finalize Session
**As an** Attendant,
**I want** to mark the session as paid using macroscopic gestures,
**So that** the session is closed effortlessly without fat-finger errors.

**Acceptance Criteria:**
* **Given** the fee is calculated
* **When** I use the "Swipe-to-Resolve" gesture (Swipe Left for Cash, Swipe Right for Online paid)
* **Then** the session state changes to COMPLETED.
* **And (UX)** a non-blocking 3-second Undo Toast appears to allow reverting the swipe if a mistake was made, without interrupting the camera for the next vehicle.

### Epic 5: Map Discovery & History
**Goal:** Drivers can find parking lots and view parking history.
**FRs covered:** FR1, FR2, FR3, FR25, FR26

#### Story 5.1: View Interactive Map & Lots
**As a** Driver,
**I want** to see active parking lots on a map with clear capacity indicators,
**So that** I can locate nearby parking instantly.

**Acceptance Criteria:**
* **Given** I am on the Map tab
* **When** it loads
* **Then** I see pins for ACTIVE lots.
* **And (UX)** lot markers are Dynamic Color-Coded Pins (Green/Orange/Red) that display the live available slot number without requiring a tap.
* **And (UX)** map pins are clustered when zoomed out to prevent UI clutter.

#### Story 5.2: View Lot Details & Availability
**As a** Driver,
**I want** to tap a lot to see its details, realtime availability, and historical trends,
**So that** I can decide if I want to park there.

**Acceptance Criteria:**
* **Given** I select a lot on the map
* **When** the details open
* **Then** I see price, hours, and available spots.
* **And (UX)** I can view a "Historical Peak Hours" chart to anticipate if the lot will fill up by my estimated arrival time.

#### Story 5.3: Driver Parking History
**As a** Driver,
**I want** to view my past parking sessions,
**So that** I can track my expenses.

**Acceptance Criteria:**
* **Given** I am on my Profile
* **When** I view History
* **Then** I see a list of my COMPLETED sessions.

#### Story 5.4: En-route Lot Capacity Alert
**As a** Driver,
**I want** to be notified if the lot I am navigating to becomes full,
**So that** my expectations are managed without forced rerouting.

**Acceptance Criteria:**
* **Given** I have tapped Navigate for a specific lot
* **When** the lot capacity reaches 100% while I am en-route
* **Then** I receive a temporary UI alert indicating the lot has recently filled up.
* **And (UX)** the system does NOT force an auto-reroute, respecting my navigation autonomy.

### Epic 6: Advanced Session Management
**Goal:** Attendants can view real-time lot stats and operators post announcements.
**FRs covered:** FR21, FR22, FR23, FR24, FR30

#### Story 6.1: Attendant Views Lot Occupancy Stats
**As an** Attendant,
**I want** to see how many spots are currently taken,
**So that** I know when we are full.

**Acceptance Criteria:**
* **Given** I am an Attendant
* **When** I view my dashboard
* **Then** I see current occupancy vs total capacity.

#### Story 6.2: Configure Announcements
**As an** Operator,
**I want** to post announcements to my lot profile,
**So that** drivers see important notices.

**Acceptance Criteria:**
* **Given** I am the Operator
* **When** I create an announcement
* **Then** it appears on the lot details page for drivers.

#### Story 6.3: Force Close/Timeout Session
**As an** Attendant,
**I want** to manually end a stuck session,
**So that** lot occupancy remains accurate.

**Acceptance Criteria:**
* **Given** a session never checked out
* **When** I forcefully close it
* **Then** the spot is freed and session marked TIMEOUT.

#### Story 6.4: Zero-Trust Shift Handover
**As an** Attendant,
**I want** to transfer my shift and cash balance to the incoming attendant via QR scan,
**So that** financial accountability is strictly enforced.

**Acceptance Criteria:**
* **Given** I am ending my shift
* **When** I generate a Shift QR containing my collected cash total, and the incoming attendant scans it
* **Then** the shift is locked and transferred if the physical cash matches.
* **And (UX)** if there is a mismatch, the incoming attendant must submit a Mandatory Discrepancy Report via a Full-Screen hard-blocking modal (Red warning UI) that requires a text rationale before proceeding.

### Epic 7: Advance Booking System
**Goal:** Drivers can pre-book a spot with automatic expiration.
**FRs covered:** FR4, FR5, FR6, FR7

#### Story 7.1: Driver Pre-Books Parking Spot
**As a** Driver,
**I want** to pay advance reservation fee to book a spot,
**So that** my spot is guaranteed upon arrival.

**Acceptance Criteria:**
* **Given** a lot allows bookings and has capacity
* **When** I initiate a booking and confirm
* **Then** my reservation is active and a spot is held for 30 mins.

#### Story 7.2: Attendant Scans Pre-Booked Check-In
**As an** Attendant,
**I want** to scan a driver's booking QR code,
**So that** their booking converts to an active session.

**Acceptance Criteria:**
* **Given** a driver arrives with a booking
* **When** I scan their QR
* **Then** the booking transfers into an ACTIVE session seamlessly.

#### Story 7.3: Auto-Expire No-Show Bookings
**As the** System,
**I want** to automatically expire bookings older than 30 minutes,
**So that** spots are not held indefinitely.

**Acceptance Criteria:**
* **Given** a cron job or edge function runs
* **When** a booking exceeds its time-to-live
* **Then** its status becomes EXPIRED and capacity returns.

### Epic 8: Business Management & Leasing
**Goal:** Operators and Owners establish contracts and track revenue.
**FRs covered:** FR31, FR32, FR37, FR38, FR39, FR40, FR42

> **Readiness Note (post Epic 3 retrospective):** Epic 8 is no longer only a business-management enhancement. Proper lease creation and acceptance now directly determine whether Operator workflows are naturally reachable in the app. This epic should replace the temporary lease-bootstrap path used for Epic 3 UAT with the first-class contract lifecycle.

#### Story 8.1: Create Lease Contract
**As a** Lot Owner,
**I want** to send a lease contract to an Operator,
**So that** they can manage my lot for a revenue split.

**Acceptance Criteria:**
* **Given** I am a Lot Owner
* **When** I invite an Operator with a revenue split %
* **Then** they receive the contract and can accept it.

#### Story 8.2: Owner Revenue Dashboard
**As a** Lot Owner,
**I want** to view my share of the revenue,
**So that** I can track my income.

**Acceptance Criteria:**
* **Given** I am an Owner
* **When** I check my dashboard
* **Then** I see my earnings calculated by the split percentage.

#### Story 8.3: Operator Revenue Dashboard
**As an** Operator,
**I want** to view my lot's performance and operator share,
**So that** I know how much my business makes.

**Acceptance Criteria:**
* **Given** I am an Operator
* **When** I check my dashboard
* **Then** I see total revenue and my operator share.

### Epic 9: UX Shell & Navigation Foundation
**Goal:** Establish standardized workspace shells, routing, theme profiles, and shared components for all 5 actor contexts, aligned with the Divergent Dual-Context UX strategy.
**FRs covered:** (cross-cutting — no new FRs; directly enables correct delivery of NFR17 and all UX spec requirements across Epics 1–8)
**UX Refs:** `ux-design-specification.md` §Design System Foundation, §Spacing & Layout Foundation, §Design Direction Decision, §Component Strategy

> **Implementation Constraint:** This epic runs LAST before thesis demo, after all business logic epics (1–8) are complete. Stories in Epics 3–8 implement screens as self-contained widgets; Epic 9 wraps them in correct shells. No story in Epics 3–8 should hardcode shell structure or layout dimensions.
>
> **Readiness Note (post Epic 3 retrospective):** Multi-capability public users now have a proven routing requirement, not just a UX preference. Epic 9 must absorb the current temporary workspace-switch bridge into durable role-aware shells and navigation. This epic should be treated as workflow validation infrastructure, not cosmetic polish.

#### Story 9.1: App Routing Foundation & Dual Theme System
**As a** developer,
**I want** a centralized routing system and two ThemeData profiles,
**So that** all workspace screens consistently use correct themes and navigation from the start.

**Acceptance Criteria:**
* **Given** the app launches
* **When** authentication state resolves
* **Then** `go_router` routes the user to the correct workspace entry point by session role
* **And** unauthenticated users are routed to `AuthGate`; authenticated users land in their workspace
* **And** `AppTheme.light()` (MD3, primary `#1A73E8`, standard MD3 paddings) is applied to Driver, Operator, LotOwner, and Admin workspaces
* **And** `AppTheme.dark()` (oversized typography, dark surface `#121212`, high contrast) is applied exclusively to the Attendant workspace
* **And** `main.dart` delegates app bootstrap to a dedicated `app.dart`; service factories are initialized once and injected via constructor or provider
* **And** the architecture.md `go_router` navigation entry is met.

#### Story 9.2: Driver Workspace Shell
**As a** Driver,
**I want** a consistent app shell with clear bottom navigation,
**So that** I can access all driving features predictably without hidden icon-bar actions.

**Acceptance Criteria:**
* **Given** I am authenticated as a Driver
* **When** the workspace loads
* **Then** a `BottomNavigationBar` with 3 tabs is shown: **Bản đồ** (home), **Lịch sử**, **Cá nhân**
* **And** all Driver screens use `AppTheme.light()`
* **And** primary actions are anchored to the bottom Thumb-Zone (Single-Tap Full-Width Buttons per UX spec)
* **And** the existing `MapScreen` integrates as the Bản đồ tab without any functional changes
* **And** Lịch sử tab shows `EmptyView` with placeholder message until Story 5.3 is implemented
* **And** Cá nhân tab exposes vehicle management entry point and capability application shortcuts

#### Story 9.3: Attendant Workspace Shell
**As an** Attendant,
**I want** a dedicated dark-mode shell optimized for gate operations,
**So that** the correct high-contrast, edge-to-edge Dark UI is in place for all Epic 4 stories.

**Acceptance Criteria:**
* **Given** I am authenticated as an Attendant
* **When** the workspace loads
* **Then** `AppTheme.dark()` is applied; `Scaffold` background is `#121212`
* **And** the shell uses edge-to-edge layout: status bar integrates into the dark header zone, no wasted AppBar padding
* **And** the screen body uses proportional layout — top 50% reserved for camera/viewfinder, bottom 50% for interaction zone (via `Expanded`/`Flex` per UX spec §Responsive Strategy)
* **And** a dark header label shows the assigned lot name when available: "BÃI XE — [Tên bãi]"
* **And** the existing placeholder text is replaced with this proper shell entry
* **And** the shell is ready to accept the gate scanning screen from Story 4.2 without structural changes

#### Story 9.4: Management Workspace Shells (Operator & Lot Owner)
**As an** Operator or Lot Owner,
**I want** a management workspace organized by function,
**So that** I can navigate between lot management, financial, and operational tasks clearly.

**Acceptance Criteria:**
* **[Operator Shell]** NavigationBar with tabs: **Bãi xe**, **Nhân viên**, **Doanh thu**
* **[Operator Shell]** Existing Operator screens integrate as correct tab content; empty tabs show `EmptyView` until respective Epic 3/6/8 stories are implemented
* **[Lot Owner Shell]** NavigationBar with tabs: **Bãi của tôi**, **Hợp đồng**, **Cá nhân**
* **[Lot Owner Shell]** Existing `ParkingLotRegistrationScreen` is accessible from the Bãi của tôi tab; other tabs show `EmptyView` until Epic 8 stories are implemented
* **[Both]** Light theme applies consistently; no feature logic changes — only shell structure is added

#### Story 9.5: Admin Workspace Shell
**As an** Admin,
**I want** a clear workspace structure organized by administrative function,
**So that** approvals, user management, and lot suspension are navigable from one place.

**Acceptance Criteria:**
* **Given** I am authenticated as an Admin
* **When** the workspace loads
* **Then** a tab structure is shown: **Duyệt hồ sơ**, **Người dùng**, **Bãi xe**
* **And** the existing `AdminApprovalsScreen` integrates as the Duyệt hồ sơ tab with no functional changes
* **And** Người dùng and Bãi xe tabs show `EmptyView` until Story 2.3 and later admin stories are implemented
* **And** `AdminApprovalsScreen` is no longer a standalone workspace entry; it is routed through `AdminShell`
* **And** Light theme applies

#### Story 9.6: Shared UI Components & Localization
**As** any app user,
**I want** consistent loading, error, and empty states across all workspaces,
**So that** the UI feels coherent and polished for the thesis demo.

**Acceptance Criteria:**
* **Given** any workspace is in a loading, error, or empty state
* **When** those states render
* **Then** they use shared widgets: `LoadingView`, `ErrorView`, `EmptyView` (Light and Dark variants)
* **And** all workspace labels use Vietnamese:
  - Role display names: Tài xế, Nhân viên, Vận hành viên, Chủ bãi xe, Quản trị viên
  - Navigation tab labels: per Stories 9.2–9.5 acceptance criteria
  - User-facing error messages: Vietnamese strings
* **And** all existing English placeholder workspace title strings are removed
* **And** each shared widget is used by at least one screen per workspace to validate integration

---

### Epic 10: Notifications (Phase 2)
**Goal:** Users receive proactive in-app alerts.
**FRs covered:** FR49, FR50

#### Story 10.1: System Push Notifications
**As a** User,
**I want** to receive push notifications for important events,
**So that** I am alerted of booking expirations or approvals.

**Acceptance Criteria:**
* **Given** my app is configured for notifications
* **When** an event occurs (e.g. booking nearing expiry)
* **Then** I receive a local device notification.
