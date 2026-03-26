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
* **Then** I am authenticated and navigated to the workspace allowed by that account type
* **And** public accounts can access Driver, LotOwner, and Operator capabilities granted to the same account
* **And** Attendant and Admin accounts log in through separate credentials rather than switching from a public account session.

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
* **And** after Admin approval, my same account gains LotOwner capability.

#### Story 1.5: Apply to Become Operator
**As a** Driver,
**I want** to apply for Operator capability on my existing account,
**So that** I can lease lots and manage parking operations without creating a separate public account.

**Acceptance Criteria:**
* **Given** I am authenticated with a public account
* **When** I submit the required business and verification documents
* **Then** the system creates a pending Operator application linked to my existing account
* **And** after Admin approval, my same account gains Operator capability.

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
**I want** to view and approve newly registered parking lots,
**So that** only vetted properties become active.

**Acceptance Criteria:**
* **Given** I am an Admin
* **When** I view pending approvals
* **Then** I can approve or reject the lot.

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
**I want** to scan a driver's QR code,
**So that** I can register their vehicle entry.

**Acceptance Criteria:**
* **Given** I am an Attendant
* **When** I scan a valid check-in QR
* **Then** a new active session is created for that vehicle.

#### Story 4.3: Manual License Plate Check-In
**As an** Attendant,
**I want** to manually log a check-in via photo/text,
**So that** I can process walk-in drivers without the app.

**Acceptance Criteria:**
* **Given** I am an Attendant
* **When** a driver arrives without the app
* **Then** I can take a photo of their plate or manual type it to start a session.

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
**I want** to scan a driver's check-out QR to calculate the fee,
**So that** I know how much to charge.

**Acceptance Criteria:**
* **Given** a driver wants to leave
* **When** I scan their check-out QR
* **Then** the final fee is computed based on lot pricing rules.

#### Story 4.6: Record Payment & Finalize Session
**As an** Attendant,
**I want** to mark the session as paid,
**So that** the session is closed and the spot freed.

**Acceptance Criteria:**
* **Given** the fee is calculated
* **When** I confirm payment received (mock mode)
* **Then** the session state changes to COMPLETED.

### Epic 5: Map Discovery & History
**Goal:** Drivers can find parking lots and view parking history.
**FRs covered:** FR1, FR2, FR3, FR25, FR26

#### Story 5.1: View Interactive Map & Lots
**As a** Driver,
**I want** to see active parking lots on a map,
**So that** I can locate nearby parking.

**Acceptance Criteria:**
* **Given** I am on the Map tab
* **When** it loads
* **Then** I see pins for ACTIVE lots.

#### Story 5.2: View Lot Details & Availability
**As a** Driver,
**I want** to tap a lot to see its details and realtime availability,
**So that** I can decide if I want to park there.

**Acceptance Criteria:**
* **Given** I select a lot on the map
* **When** the details open
* **Then** I see price, hours, and available spots.

#### Story 5.3: Driver Parking History
**As a** Driver,
**I want** to view my past parking sessions,
**So that** I can track my expenses.

**Acceptance Criteria:**
* **Given** I am on my Profile
* **When** I view History
* **Then** I see a list of my COMPLETED sessions.

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

### Epic 9: Notifications (Phase 2)
**Goal:** Users receive proactive in-app alerts.
**FRs covered:** FR47, FR48

#### Story 9.1: System Push Notifications
**As a** User,
**I want** to receive push notifications for important events,
**So that** I am alerted of booking expirations or approvals.

**Acceptance Criteria:**
* **Given** my app is configured for notifications
* **When** an event occurs (e.g. booking nearing expiry)
* **Then** I receive a local device notification.
