---
type: bmad-distillate
sources:
  - "epics.md"
downstream_consumer: "general"
created: "2026-03-28"
token_estimate: 2500
parts: 1
---

## Epics Overview
- Epic 1: User Identity & Profiles (FR44-FR48)
- Epic 2: Platform Inventory & Approvals (FR36, FR41, FR43)
- Epic 3: Lot Operations Setup (FR27-FR29, FR33-FR35)
- Epic 4: The Core Parking Loop (FR8-FR20)
- Epic 5: Map Discovery & History (FR1-FR3, FR25-FR26)
- Epic 6: Advanced Session Management (FR21-FR24, FR30)
- Epic 7: Advance Booking System (FR4-FR7)
- Epic 8: Business Management & Leasing (FR31-FR32, FR37-FR40, FR42)
- Epic 9: UX Shell & Navigation Foundation (Run LAST)
- Epic 10: Notifications (Phase 2, FR49-FR50)

## Global Constraints & UI Consistency
- Divergent UI Strategy: Attendant App = Dark Mode, massive typography, edge-to-edge touch targets, no on-screen keyboards at gate. Driver/Operator App = Light Mode, MD3 components, spacious layouts. Primary actions in bottom Thumb-Zone.
- Integration: FastAPI gateway pattern (mobile client must not talk directly to DB or Cloudinary). Real-time via WebSocket/SSE.
- Database: 23 migrated tables in PostgreSQL.

## Epic 1: User Identity & Profiles
- Story 1.1: Registration. Email/password -> creates public account initialized with Driver role by default via FastAPI.
- Story 1.2: Login. Authenticates user identity; capabilities determine accessible workspaces. Attendant/Admin accounts have separate login flows (no switching from public).
- Story 1.3: Manage License Plates. Add/remove plates.
- Story 1.4: Apply Lot Owner. Submit docs -> Admin approves -> `lot_owner` capability linked to existing account.
- Story 1.5: Apply Operator. Submit docs -> Admin approves -> `manager` capability linked to existing account.

## Epic 2: Platform Inventory & Approvals
- Story 2.1: Register Lot. Owner registers lot -> PENDING_APPROVAL.
- Story 2.2: Admin Dashboard. Admin vets capability applications and lot registrations.
- Story 2.3: Admin Suspension. Admin suspends active lots -> hidden from map, no check-ins.

## Epic 3: Lot Operations Setup
- Story 3.1: Lot Capacity. Operator sets max capacity (enforces check-in limits).
- Story 3.2: Pricing & Hours. Operator defines rates/hours (applied at check-out).
- Story 3.3: Attendant Accounts. Operator creates dedicated Attendant credentials.

## Epic 4: The Core Parking Loop (Hard Precondition: Epic 3 Setup)
- Story 4.1: Driver Check-in QR. Driver app generates check-in QR.
- Story 4.2: Attendant Scan QR. Attendant scans -> new active session. 5s SLA. UX: Immediate Green flash + heavy haptic/beep. 2s Cooldown Lens Lock. Degraded network -> pending sync.
- Story 4.3: Manual Check-In (Walk-in). Camera OCR or swipe; no typing.
- Story 4.4: Driver Checkout QR. Driver app shows elapsed time, cost, Checkout QR.
- Story 4.5: Attendant Scan Checkout. Backend calculates fee (preview step). UX: Oversized price typography, no-look verification.
- Story 4.6: Record Payment & Finalize. UX: Swipe-to-Resolve (Left = Cash, Right = Online). Non-blocking 3s Undo Toast. Backend revalidates fee/session.

## Epic 5: Map Discovery & History
- Story 5.1: Map. Pin colors (Green/Orange/Red), live slot count without tapping, clustered.
- Story 5.2: Lot Details. Price, hours, slots, "Historical Peak Hours" chart.
- Story 5.3: Parking History. View COMPLETED sessions.
- Story 5.4: En-route Alert. Alert if navigated lot fills up; no auto-reroute.

## Epic 6: Advanced Session Management
- Story 6.1: Attendant Stats. Dashboard shows occupancy vs capacity.
- Story 6.2: Configure Announcements. Operator posts announcements visible to drivers.
- Story 6.3: Force Close. Attendant ends stuck session -> TIMEOUT status.
- Story 6.4: Zero-Trust Shift Handover. QR transfer. Discrepancy requires full-screen red warning modal and text rationale.

## Epic 7: Advance Booking System
- Story 7.1: Pre-Book. Driver pays advance fee -> holds spot for 30 mins.
- Story 7.2: Attendant Scan Booking. Scanned booking -> converts to ACTIVE session.
- Story 7.3: Auto-Expire. Cron expires >30 min bookings -> restores capacity.

## Epic 8: Business Management & Leasing
- Story 8.1: Create Lease Contract. Owner invites Operator with revenue split.
- Story 8.2: Owner Dashboard. View revenue share.
- Story 8.3: Operator Dashboard. View lot performance and operator share.

## Epic 9: UX Shell & Navigation Foundation (Run after Epic 1-8 logic)
- Story 9.1: App Routing & Dual Theme. `go_router` via session role. Driver/Op/Owner/Admin = `AppTheme.light()`. Attendant = `AppTheme.dark()`. Services injected.
- Story 9.2: Driver Shell. Light theme, BottomNav (Bản đồ, Lịch sử, Cá nhân), Single-Tap Full-Width Buttons at bottom.
- Story 9.3: Attendant Shell. Dark theme, edge-to-edge Layout (#121212). Top 50% Camera, Bottom 50% Interaction. Dark header label ("BÃI XE — [Tên bãi]").
- Story 9.4: Management Shells. Operator (Bãi xe, Nhân viên, Doanh thu), Owner (Bãi của tôi, Hợp đồng, Cá nhân).
- Story 9.5: Admin Shell. Duyệt hồ sơ, Người dùng, Bãi xe.
- Story 9.6: Shared Components. `LoadingView`, `ErrorView`, `EmptyView` (Light/Dark). All labels in Vietnamese. Remove English placeholders.
