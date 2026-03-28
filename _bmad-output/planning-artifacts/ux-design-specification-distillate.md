---
type: bmad-distillate
sources:
  - "ux-design-specification.md"
downstream_consumer: "general"
created: "2026-03-28"
token_estimate: 1500
parts: 1
---

## Core UX Strategy
- Primary SLA: Check-in/Check-out operations must complete in < 5 seconds under any condition
- Paradigm: Phone-as-Kiosk (smartphones replace all kiosk hardware); 2-in-1 Standby Interface (camera and NFC sensor always awake simultaneously)
- Divergent Layout Strategy: Forces two completely opposed UX contexts; rejects uniform brand consistency in favor of operational efficiency
  - Attendant App: Edge-to-Edge & Dense (Dark mode, 0px margins, massive touch targets, proportion-based layout)
  - Driver App: Airy & Floating (Light mode, spacious 8-pt grid padding, MD3 components, map-dominant)

## Key Technical Integrations
- Mobile App Framework: Native Flutter Material Library (Material Design 3)
- Networking Fallback: Asynchronous Sync / Local Caching; displays "Pending Sync" to users instead of blocking operations
- Theming Component: Uses pre-configured `AppTheme.light()` (`#1A73E8` Tech Blue) and `AppTheme.dark()` (`#121212` background)
- Typography: Inter or Roboto for optimal OCR/data parsing; Extreme weighting (Black/ExtraBold) reserved strictly for License Plates, Prices, and Timers

## Core Workflows
- **Attendant Check-in (Universal Scan):** Scan QR/NFC -> Detects if vehicle data exists -> (Yes) Auto-creates session -> (No - Walk-in) Prompts photo capture (Conditional Friction) -> Success Flash
- **Attendant Check-out:** Scan media -> Shows price mapping -> "Swipe-to-Resolve" gesture -> Success Flash -> 3-Second Undo Toast
- **Shift Handover (Zero-Trust):** Outgoing generates Shift QR -> Incoming scans it -> Matches system cash -> Locks shift; Mismatch -> Hard-Blocking Discrepancy Modal requiring text rationale
- **Driver Booking:** Map view -> Color-Coded Pins -> Review Historical Peak Hours chart -> Book -> Navigate; En-route capacity alters fire visual alerts but NEVER force auto-reroute

## Custom Components & Patterns
- **Multisensory Flash Overlay:** 0.5s full-screen Z-index container flash: Green (`#00E676`) for success, Red (`#D50000`) for failure/warning. Always combined with `HapticFeedback.heavyImpact()` and a Beep. Replaces small text confirmations.
- **Swipe-to-Resolve Checkout Zone:** Replaces precise checkout buttons. An invisible `GestureDetector` over the bottom 50% of screen. Swiping Left = Cash, Right = Online.
- **Cooldown Lens Lock:** Semi-transparent mask covering camera for 2.0s post-scan. Uses `AbsorbPointer` to nullify double-scan touches of tailgating vehicles.
- **Non-Blocking 3s Undo Toast:** Low-risk friction. Pill-shaped floating SnackBar for 3s post-swipe to revert action without blocking the camera for the next vehicle.
- **Hard-Blocking Modal:** High-risk friction (e.g. cash discrepancy). Full-screen, high-contrast overlay demanding explicit text input; cannot be dismissed.
- **Color-Coded Map Pins:** Dynamic markers on the Map (Green/Orange/Red) detailing capacity limits without requiring user taps. Map points cluster when zoomed out.
- **The "Thumb-Zone Imperative":** Primary action buttons are full-width, anchored to the bottom edge. On-screen keyboards are strictly banned from active gate operations.
