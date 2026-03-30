# Workflow Truth Map — Smart Parking Management System

**Date:** 2026-03-29
**Author:** party-mode review (Mary/Analyst, Winston/Architect, Quinn/QA)
**Source artifacts:** PRD, architecture.md, tech-design.md, epics.md, stories 1.x–9.x, retros Epic 3–8
**Purpose:** Canonical cross-actor flow reference for testability, demo preparation, and workflow gap identification.

> **How to read this document**
> Each actor section contains: Preconditions → Happy Path (numbered steps) → Exception Paths → State Transitions → Open Gaps.
> Steps prefixed `[BE]` = backend API call; `[UI]` = mobile screen action; `[SYSTEM]` = automated/background.

---

## 0. Platform Lifecycle — The Supply Chain

Before any driver can park, the following platform states must exist in order.
This chain is the **single most critical cross-actor dependency** and was historically undocumented.

```
[LotOwner] Register lot → [Admin] Approve lot
         ↓
[LotOwner] Post lot for lease
         ↓
[Operator] Apply to lease posted lot → [Admin] Approve lease → LotLease = ACTIVE
         ↓
[Operator] Configure lot (capacity, hours, pricing)
         ↓
[Operator] Create Attendant account + assign to lot
         ↓
Lot becomes discoverable on Driver map (ACTIVE status)
         ↓
[Driver] Finds lot → Books/Walks in → [Attendant] Processes gate
```

**State precondition summary:**

| Stage | Required state | Who owns it |
|-------|---------------|-------------|
| Lot on map | ParkingLot.status = ACTIVE | Admin (approves lot) |
| Lot has capacity/pricing | ParkingLotConfig + Pricing records exist | Operator (configures) |
| Operator has lot access | LotLease.status = ACTIVE | Admin (approves lease) |
| Attendant can operate | User.role = ATTENDANT, assigned to lot | Operator (creates/assigns) |
| Driver can park | All above + current_available > 0 | System |

---

## 1. Actor: LotOwner

### 1.1 Preconditions
- Has registered a public Driver account (email + password)
- Has applied for and received Admin approval for LotOwner capability
- Has a linked lot_owner record and user.role = LOT_OWNER

### 1.2 Capability Application Flow

```
[UI]   Driver profile → "Đăng ký trở thành Chủ bãi" CTA
[UI]   Upload ownership documents via ImagePicker/FilePicker (not text URL)
[BE]   POST /users/apply-lot-owner → creates pending LotOwner application
[SYSTEM] Notification to Admin queue
[BE]   Admin approves → lot_owner record created, user.role updated to LOT_OWNER
[UI]   LotOwnerWorkspaceShell available on next login (or workspace switch)
```

Exception paths:
- Admin rejects → applicant notified, remains Driver
- Missing documents → validation error before submission

### 1.3 Lot Registration Flow

```
[UI]   LotOwner shell → "Bãi của tôi" tab → "Đăng ký bãi mới" button
[UI]   Fill: name, address, GPS coordinates, description
[UI]   Upload lot photos and ownership proof via ImagePicker (multipart → FastAPI → Cloudinary)
[BE]   POST /lots → creates ParkingLot with status = PENDING_APPROVAL
[SYSTEM] Notification to Admin queue
[BE]   Admin approves → ParkingLot.status = APPROVED
[UI]   Lot visible in "Bãi của tôi" tab with APPROVED badge
```

Exception paths:
- Admin rejects → lot stays PENDING or REJECTED; owner can resubmit
- Missing required fields → client-side + server-side validation

State: PENDING_APPROVAL → APPROVED → (later) FOR_LEASE or ACTIVE

### 1.4 Post Lot for Lease Flow

```
[UI]   "Bãi của tôi" tab → select approved lot → "Rao cho thuê"
[UI]   Set: monthly fee, min contract duration, terms
[BE]   POST /lots/{id}/lease-listing → creates LeaseListing record
[UI]   Lot now visible in Operator marketplace
```

State: APPROVED → FOR_LEASE

### 1.5 Lease Contract Management Flow

```
[SYSTEM] Operator applies to lease → LotOwner sees application in "Hợp đồng" tab
         NOTE: "Hợp đồng" tab currently EmptyView — data exists in backend, UI not wired
[BE]   Admin approves lease → LotLease.status = ACTIVE → auto-generated LeaseContract
[UI]   Contract visible in "Hợp đồng" tab with ACTIVE badge
```

AMBIGUITY: LotOwner's role in lease selection is still ambiguous between "I choose" vs "Admin decides" (see AMB-1).

### 1.6 Revenue Tracking

```
[UI]   "Hợp đồng" tab (or separate dashboard) → select active lease
[BE]   GET /reports/owner?period=month → revenue, session counts, occupancy, owner share
[UI]   Dashboard: owner revenue = total_revenue × owner_split_percent
```

### 1.7 Open Gaps — LotOwner

| Gap | Impact |
|-----|--------|
| "Hợp đồng" tab is EmptyView | Can't see or manage leases from UI |
| "Cá nhân" tab is EmptyView | Profile management not surfaced |
| LotOwner voice in lease selection unclear | Demo may confuse ownership vs. Admin authority |

---

## 2. Actor: Admin

### 2.1 Preconditions
- Separate account, user.role = ADMIN
- Created outside public signup flow (direct DB seeding for thesis)

### 2.2 Entry Point

```
Login → AdminWorkspaceShell (3 tabs: Duyệt hồ sơ | Người dùng | Bãi xe)
```

### 2.3 Approval Queue Flow (primary job)

```
[UI]   "Duyệt hồ sơ" tab → AdminApprovalsScreen → list of pending items
       Supported types:
         A. Lot registrations (from LotOwner)
         B. Capability applications (LotOwner, Operator requests from Drivers)
         C. Lease applications (from Operator for a specific lot)
[UI]   Select item → review details, uploaded documents
[BE]   POST /admin/approve or /admin/reject → item-specific action:
       A. ParkingLot.status = APPROVED
       B. lot_owner or manager record created + user.role updated
       C. LotLease.status = ACTIVE + LeaseContract auto-generated
[SYSTEM] Notification to affected party
```

Exception paths:
- Reject with reason → applicant notified
- Document incomplete → reject or request resubmission (manual message)

### 2.4 Lot Suspension

```
[UI]   "Bãi xe" tab → [Currently EmptyView — Lot Suspension screen not yet wired into shell]
       Direct: AdminApprovalsScreen has lot suspension capability (Story 2.3 done)
[BE]   PATCH /lots/{id} → status = SUSPENDED
[SYSTEM] Lot hidden from driver map; new check-ins rejected
```

Open gap: "Bãi xe" tab is EmptyView — lot suspension accessible only via "Duyệt hồ sơ" flow.

### 2.5 User Management

```
[UI]   "Người dùng" tab → [Currently EmptyView — not yet implemented]
       Planned: search user, view profile, deactivate/reactivate
[BE]   PATCH /users/{id} → is_active = false
```

### 2.6 Open Gaps — Admin

| Gap | Impact | Priority |
|-----|--------|----------|
| "Người dùng" tab EmptyView | Can't manage users from UI | Low (demo can skip) |
| "Bãi xe" tab EmptyView | Lot suspension buried in approvals flow | Low |
| Deactivating privileged accounts policy unclear | deferred-work.md item unresolved | Low |

---

## 3. Actor: Operator

### 3.1 FULL ONBOARDING CHAIN (Critical — previously undocumented)

```
Step 1. Start as Driver
        [UI] Register public account → user.role = DRIVER

Step 2. Apply for Operator capability
        [UI] Driver workspace → Cá nhân tab → "Đăng ký trở thành Vận hành viên"
        [UI] Upload business documents via FilePicker
        [BE] POST /users/apply-operator → pending manager application
        [SYSTEM] Admin notified

Step 3. Admin approves Operator capability
        [BE] Admin approves → manager record created, user.role = MANAGER
        [UI] OperatorWorkspaceShell available

Step 4. LotOwner registers and gets a lot approved (independent flow — see §1.3)

Step 5. LotOwner posts lot for lease (see §1.4)

Step 6. Operator applies to lease an available lot
        [UI] Operator workspace → "Bãi xe" tab → browse lease listings
        [UI] Select lot → "Đăng ký thuê"
        [BE] POST /leases → LotLease with status = PENDING

Step 7. Admin approves lease
        [BE] Admin approves → LotLease.status = ACTIVE → LeaseContract auto-generated
        [UI] Operator sees active lot in "Bãi xe" tab

Step 8. Operator configures lot (see §3.3)

Step 9. Operator creates Attendant account (see §3.4)

Step 10. Lot goes live — discoverable on Driver map
```

> Key insight: Steps 1–7 involve 3 actors and 2 Admin approvals.
> Demo requires pre-seeded state for steps 1–7 (see Section 7).

### 3.2 Entry Point

```
Login → OperatorWorkspaceShell (3 tabs: Bãi xe | Nhân viên | Doanh thu)
```

### 3.3 Configure Lot Flow

```
[UI]   "Bãi xe" tab → select active lot → "Cấu hình"
[UI]   Set total capacity (by vehicle type: MOTORBIKE, CAR)
[BE]   POST /lots/{id}/config → creates ParkingLotConfig with effective_date
       Edge case: new capacity < current occupied → OVERFLOW warning, lot continues
[UI]   Set operating hours (via TimePicker — no manual text entry)
[BE]   PATCH /lots/{id}/config
[UI]   Set pricing rules: mode (SESSION or HOURLY), amount, vehicle_type, effective_date
[BE]   POST /lots/{id}/pricing
       Edge case: open sessions not repriced by config change (effective_date logic)
[SYSTEM] Lot status: INCOMPLETE_CONFIG → ACTIVE when both capacity + pricing exist
```

State: APPROVED → INCOMPLETE_CONFIG → ACTIVE

### 3.4 Create Attendant Account

```
[UI]   "Nhân viên" tab → "Tạo nhân viên mới"
[UI]   Enter email + temporary password
[BE]   POST /attendants → creates User with role = ATTENDANT, assigned to operator's lot
[UI]   Attendant appears in staff list
       Revoke: PATCH /attendants/{id} → is_active = false
       Edge case: revoked attendant's existing tokens are invalidated
```

### 3.5 Post Announcement

```
[UI]   "Bãi xe" tab → select lot → "Thông báo" → "Tạo thông báo"
[UI]   Fill type (EVENT/ALERT/CLOSURE/PEAK_HOURS), content, visibility dates
[BE]   POST /announcements → visible on lot detail for drivers
```

### 3.6 Revenue Dashboard

```
[UI]   "Doanh thu" tab → select period (day/week/month)
[BE]   GET /reports/operator?period=month → sessions, revenue, occupancy %, operator share
[UI]   Charts: total revenue, session count, vehicle type breakdown, operator split amount
       Operator share = total_revenue × (1 - owner_split_percent)
```

### 3.7 Open Gaps — Operator

| Gap | Impact |
|-----|--------|
| Onboarding chain (Steps 1–7) no demo walkthrough | Pre-seed required for demo |
| "Bãi xe" tab — which lot is "selected"? | No explicit lot picker UI described |
| Sub-navigation within lot management | All config is one screen vs. step-by-step |
| Lease marketplace browsing UI | Where does Operator browse available lots? |

---

## 4. Actor: Attendant

### 4.1 Preconditions
- Operator has created this account (separate credentials)
- Assigned to an active lot with active pricing
- Cannot switch from a public account session

### 4.2 Entry Point

```
Login → AttendantWorkspaceShell (dark, edge-to-edge, 50/50 split)
Header: "BÃI XE — [Tên bãi]" (fallback: "CHƯA GÁN")
```

### 4.3 Check-In Flow (App QR Driver)

```
[UI]   Camera viewfinder (top 50%) — always-awake standby
[UI]   Driver presents QR code
[BE]   POST /sessions/checkin → validates: no active session, lot not full
[BE]   Creates ParkingSession (status = ACTIVE), decrements current_available atomically
[UI]   GREEN full-screen flash + heavy haptics + beep (Multisensory Flash Overlay)
[UI]   2-second Cooldown Lens Lock (prevents double-scan)
[UI]   Shell resets to standby

Exception: QR invalid → RED flash + "Mã QR không hợp lệ"
Exception: Driver already checked in → RED flash + error
Exception: Lot full → RED flash + "Bãi đầy"
Exception: Network drop → Pending Sync [ARCH §4.6 — NOT YET IMPLEMENTED]
```

State: ParkingSession created → status = ACTIVE

### 4.4 Check-In Flow (Walk-in, No App)

```
[UI]   Standby → walk-in mode trigger
[UI]   Camera captures front photo of vehicle (required)
[UI]   Optional: back photo
[BE]   POST /sessions/walkin with multipart images → Cloudinary upload
       ParkingSession (status = ACTIVE) created with photo references
[UI]   Async upload — UI immediately resets (background upload)

Exception: No photo → reject (at least one photo required)
Note: Walk-in EXIT credential NOT defined in MVP
```

### 4.5 Check-Out Flow (App QR Driver)

```
[UI]   Camera viewfinder ready
[UI]   Driver presents QR (in CHECKOUT state per driver state machine)
[BE]   POST /sessions/checkout-preview → calculates fee
       Pricing engine: SESSION (flat) or HOURLY (elapsed × rate)
[UI]   Display: fee amount (ExtraBold typography), duration, lot name
[UI]   Swipe-to-Resolve zone (bottom 50%):
       Swipe LEFT → Cash | Swipe RIGHT → Online (simulated)
[BE]   POST /sessions/checkout → record Payment, session = CHECKED_OUT
       Increments current_available atomically
[UI]   3-second Undo Toast (camera still active for next vehicle)
       Tap undo → payment reversed, session stays ACTIVE
[UI]   GREEN flash → Cooldown Lock → Reset

Exception: No active session → "Không tìm thấy phiên đỗ xe"
Exception: Session already checked out → "Phiên đã kết thúc"
Exception: No pricing rule → flag error, allow manual override via SessionEdit
```

State: ParkingSession: ACTIVE → CHECKED_OUT

### 4.6 Lot Occupancy Stats

```
[UI]   Stats panel in interaction zone (bottom 50%) — always visible
[BE]   GET /lots/{id}/stats → total capacity, occupied, available, by vehicle type
[UI]   "45/60 xe | 15 chỗ trống"
```

### 4.7 Session Edit (Correction)

```
[UI]   "Danh sách xe" → select session → "Chỉnh sửa"
[UI]   Edit: license plate, slot number, vehicle type + required reason
[BE]   PATCH /sessions/{id} + POST /session-edits → SessionEdit logged
```

### 4.8 Force-Close Stuck Session

```
[UI]   Select overstayed session → "Đóng phiên"
[BE]   PATCH /sessions/{id} → status = TIMEOUT, current_available incremented
```

### 4.9 Shift Handover Flow

```
[UI]   Outgoing attendant → "Kết thúc ca"
[BE]   GET /shifts/current → expected_cash from all CASH payments this shift
[UI]   App generates Shift QR with shift payload
[UI]   Incoming attendant device → scan Shift QR
[UI]   Enter actual cash counted
[BE]   Compare actual vs expected
       Match → POST /shifts/handover → shift locked + transferred
       Mismatch → Hard-blocking full-screen modal (RED, cannot dismiss without reason text)
[UI]   Enter discrepancy reason → submit → shift locked, Operator notified
```

### 4.10 Final Shift Close (End of Day)

```
[UI]   Verify lot is empty (0 active sessions)
[UI]   "Đóng ngày"
[BE]   POST /shifts/close-final → auto-settles cash total, creates operator close-out alert
[UI]   Operator must confirm from management workspace
```

### 4.11 Open Gaps — Attendant

| Gap | Impact |
|-----|--------|
| Pending Sync offline queue | Gate blocked on network failure — SLA broken |
| Walk-in exit credential undefined | Walk-in check-out mechanism unclear in MVP |
| Swipe-to-Resolve: gesture vs buttons | Need to verify Flutter implementation |
| Lot name in header from backend | Requires correct lot assignment at shell boundary |

---

## 5. Actor: Driver

### 5.1 Preconditions
- Registered public account, user.role = DRIVER
- At least one vehicle with license plate registered
- Target lot must be ACTIVE with capacity + pricing configured

### 5.2 Entry Point

```
Login → DriverWorkspaceShell (3 tabs: Bản đồ | Lịch sử | Cá nhân)
```

### 5.3 Find Parking Flow

```
[UI]   "Bản đồ" tab → MapDiscoveryScreen with Mapbox map
[BE]   GET /lots?nearby=lat,lng → ACTIVE lots with current_available
[UI]   Color-coded pins: Green (>50% free) | Orange (filling up) | Red (full)
[UI]   Tap pin → lot detail bottom sheet: name, address, pricing, hours, availability, announcements
[UI]   "Điều hướng" → opens map navigation

Exception: GPS denied → toast + default city center fallback
Exception: Lot full → RED pin, booking/navigation still possible (user choice)
```

State dependency: ParkingLot.current_available updated via WebSocket/SSE (NFR4).

### 5.4 Booking Flow

```
[UI]   Lot detail → "Đặt chỗ"
[UI]   Confirm: lot, vehicle, estimated arrival
[BE]   POST /bookings → Booking (status = CONFIRMED), decrements current_available
       30-minute hold on spot
[UI]   Booking QR displayed

Exception: Lot full → "Không còn chỗ để đặt" (EC11)
Exception: Driver already has active booking → reject (EC12)
Exception: Two drivers book last spot → row-level lock, second rejected (EC15)
[SYSTEM] After 30 min with no check-in → booking EXPIRED, current_available restored
```

State: Booking CONFIRMED → (check-in) ParkingSession | (timeout) EXPIRED

### 5.5 Check-In Flow (driver side)

```
[UI]   Driver presents phone to attendant's scanner
       QR in "CHECK-IN" state (no active session exists)
[SYSTEM] Attendant scans → session created (see Attendant §4.3)
[UI]   Driver app: session visible as ACTIVE
```

### 5.6 Check-Out Flow (driver side)

```
[UI]   Active session visible → QR now in "CHECKOUT" state (backend detected active session)
[UI]   Driver presents QR to attendant's scanner
[SYSTEM] Attendant processes checkout (see Attendant §4.5)
[UI]   Driver sees: session CHECKED_OUT, payment confirmed, duration, amount
```

### 5.7 Parking History

```
[UI]   "Lịch sử" tab → ParkingHistoryScreen
[BE]   GET /sessions?driver_id=me&status=CHECKED_OUT
[UI]   List: lot name, date, duration, amount paid
[UI]   Tap → session detail
```

### 5.8 Vehicle Management

```
[UI]   "Cá nhân" tab → "Quản lý xe"
[UI]   Add vehicle: license plate, type, brand, color, photos (via ImagePicker)
[BE]   POST /vehicles + POST /media/upload → saved with Cloudinary photo URLs
       Business rule: cannot delete if active session exists
```

### 5.9 En-Route Capacity Alert

```
[SYSTEM] Driver taps "Điều hướng" → subscription starts for lot availability
[BE]    WebSocket/SSE → pushes lot.availability.updated events
[UI]   If current_available drops to 0 while en route:
       In-app toast: "Bãi xe vừa đầy chỗ"
       System does NOT force reroute (driver autonomy respected)
```

### 5.10 Open Gaps — Driver

| Gap | Impact |
|-----|--------|
| Walk-in driver check-out mechanism | Cannot use QR app — attendant lookup needed |
| Online payment UI (simulated) | What does "pay online" look like end-to-end? |
| Subscription passes (Phase 2) | Not in MVP scope — should not appear in UI |
| Real-time: WebSocket vs SSE | Which is actually implemented? |

---

## 6. Cross-Actor State Dependency Matrix

| If this actor's action fails... | ...then this becomes unreachable |
|--------------------------------|----------------------------------|
| Admin doesn't approve lot | Lot never appears on map; Operator can't lease it |
| Admin doesn't approve Operator capability | Operator workspace never accessible |
| Admin doesn't approve lease | Operator has no lots; Attendants can't be assigned |
| Operator doesn't configure lot | Lot stays INCOMPLETE_CONFIG, hidden from map |
| Operator doesn't create Attendant | No one can process check-ins |
| Attendant can't scan QR | Core parking loop broken |
| Driver doesn't register vehicle | Walk-in check-in path needed |

---

## 7. Thesis Demo Pre-Seed Requirements

To demonstrate all actor flows, the following state must exist before demo:

| # | Pre-seed action | Level |
|---|----------------|-------|
| 1 | Create Admin account | DB seed |
| 2 | Create LotOwner account + approve LotOwner capability | API |
| 3 | Create + approve a ParkingLot | API |
| 4 | Post lot for lease | API |
| 5 | Create Operator account + approve Operator capability | API |
| 6 | Operator applies to lease → Admin approves | API |
| 7 | Operator configures lot (capacity + pricing) | API |
| 8 | Operator creates Attendant account assigned to lot | API |
| 9 | Create Driver account + register a vehicle | API |
| 10 | Verify lot appears on Driver map | Manual |

> Recommendation: Create backend/scripts/seed_demo.py that automates steps 1–9 via API.
> This script also serves as an implicit E2E integration test for the operator onboarding chain.

---

## 8. Known Scope Boundaries (NOT in MVP)

Items clearly deferred to Phase 2/3. Should not appear in demo UI or test expectations:

| Item | Deferred in | Notes |
|------|------------|-------|
| NFC card scanning | PRD Phase 2 | UX spec mentions it but PRD scope governs |
| Pending Sync offline queue | Not in any story | Architecture §4.6 describes it, deferred |
| Redis caching layer | Not in any story | Architecture lists it, not implemented |
| Push notifications (FCM) | Epic 10 backlog | In-app notification read is MVP, push is not |
| Subscription/monthly passes | PRD Phase 2 | UC03 in use case diagram but not in Epics 1–9 |
| Real Stripe/Momo payment | PRD Phase 3 | Online payment is simulated in MVP |
| Walk-in exit credential | Epic 4 convention note | Explicitly deferred from MVP scope |
| Google sign-in | architecture.md open items | Not implemented |

---

## 9. Ambiguities Requiring Decision Before Demo

| ID | Ambiguity | Options | Impact |
|----|-----------|---------|--------|
| AMB-1 | LotOwner's voice in lease selection | A: Posts, Admin decides. B: LotOwner sees applicants and voices preference | Demo script depends on which actor "controls" lease |
| AMB-2 | Walk-in driver check-out | A: Session-scoped QR on Attendant screen. B: Attendant lookup by occupancy list. C: Not demoed | MVP scope says "not implemented" — recommend skip |
| AMB-3 | WebSocket vs SSE for live availability | A: WebSocket only. B: SSE fallback also. C: Polling | Affects map live-update demo |
| AMB-4 | Online payment "simulate" UX | A: Button with instant success. B: Loading screen then success | Minor but must not confuse judges |
| AMB-5 | Operator "lot picker" in shell | A: Operator manages 1 lot, auto-selected. B: Explicit lot switch UI | Affects Operator demo script |
